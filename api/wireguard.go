package api

import (
	"context"
	"crypto/rand"
	"fmt"
	"net"
	"net/netip"
	"time"

	"github.com/Diniboy1123/usque/internal"
	"golang.zx2c4.com/wireguard/conn"
	"golang.zx2c4.com/wireguard/device"
	"golang.zx2c4.com/wireguard/tun"
	"golang.zx2c4.com/wireguard/tun/netstack"
	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"
)

// WireGuardConfig holds configuration for a WireGuard WARP tunnel.
type WireGuardConfig struct {
	PrivateKey     []byte
	PeerPublicKey  []byte
	EndpointV4     string
	EndpointV6     string
	LocalIPv4      string
	LocalIPv6      string
	MTU            int
	KeepAlive      time.Duration
}

// WireGuardTunnel represents an active WireGuard tunnel.
type WireGuardTunnel struct {
	TunDev tun.Device
	Net    *netstack.Net
	Device *device.Device
	cancel context.CancelFunc
}

// CreateWireGuardTunnel creates a userspace WireGuard tunnel using netstack.
func CreateWireGuardTunnel(cfg WireGuardConfig) (*WireGuardTunnel, error) {
	if len(cfg.PrivateKey) != 32 {
		return nil, fmt.Errorf("invalid wireguard private key length: %d", len(cfg.PrivateKey))
	}
	if len(cfg.PeerPublicKey) != 32 {
		return nil, fmt.Errorf("invalid wireguard peer public key length: %d", len(cfg.PeerPublicKey))
	}

	var localAddresses []netip.Addr
	if cfg.LocalIPv4 != "" {
		addr, err := netip.ParseAddr(cfg.LocalIPv4)
		if err != nil {
			return nil, fmt.Errorf("invalid local IPv4: %w", err)
		}
		localAddresses = append(localAddresses, addr)
	}
	if cfg.LocalIPv6 != "" {
		addr, err := netip.ParseAddr(cfg.LocalIPv6)
		if err != nil {
			return nil, fmt.Errorf("invalid local IPv6: %w", err)
		}
		localAddresses = append(localAddresses, addr)
	}

	mtu := cfg.MTU
	if mtu <= 0 {
		mtu = 1280
	}

	tunDev, tunNet, err := netstack.CreateNetTUN(localAddresses, nil, mtu)
	if err != nil {
		return nil, fmt.Errorf("failed to create netstack TUN: %w", err)
	}

	wgDev := device.NewDevice(tunDev, conn.NewDefaultBind(), device.NewLogger(device.LogLevelError, ""))

	// Determine endpoint
	var endpoint net.UDPAddr
	if cfg.EndpointV4 != "" {
		ip := net.ParseIP(cfg.EndpointV4)
		if ip != nil {
			endpoint = net.UDPAddr{IP: ip, Port: internal.WGDefaultPort}
		}
	}
	if endpoint.IP == nil && cfg.EndpointV6 != "" {
		ip := net.ParseIP(cfg.EndpointV6)
		if ip != nil {
			endpoint = net.UDPAddr{IP: ip, Port: internal.WGDefaultPort}
		}
	}
	if endpoint.IP == nil {
		_ = tunDev.Close()
		return nil, fmt.Errorf("no valid wireguard endpoint configured")
	}

	keepAlive := cfg.KeepAlive
	if keepAlive <= 0 {
		keepAlive = 25 * time.Second
	}

	// Use IPC to configure the device
	// Build the IPC configuration string
	ipcConfig := fmt.Sprintf("private_key=%s\n", bytesToHex(cfg.PrivateKey))
	ipcConfig += "listen_port=0\n"
	ipcConfig += "replace_peers=true\n"
	ipcConfig += fmt.Sprintf("public_key=%s\n", bytesToHex(cfg.PeerPublicKey))
	ipcConfig += fmt.Sprintf("endpoint=%s\n", endpoint.String())
	ipcConfig += "allowed_ip=0.0.0.0/0\n"
	ipcConfig += "allowed_ip=::/0\n"
	ipcConfig += fmt.Sprintf("persistent_keepalive_interval=%d\n", int(keepAlive.Seconds()))

	if err := wgDev.IpcSet(ipcConfig); err != nil {
		_ = tunDev.Close()
		return nil, fmt.Errorf("failed to configure wireguard device: %w", err)
	}

	if err := wgDev.Up(); err != nil {
		_ = tunDev.Close()
		return nil, fmt.Errorf("failed to bring up wireguard device: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())

	go func() {
		<-ctx.Done()
		wgDev.Close()
	}()

	return &WireGuardTunnel{
		TunDev: tunDev,
		Net:    tunNet,
		Device: wgDev,
		cancel: cancel,
	}, nil
}

// Close shuts down the WireGuard tunnel.
func (t *WireGuardTunnel) Close() {
	if t.cancel != nil {
		t.cancel()
	}
	if t.TunDev != nil {
		_ = t.TunDev.Close()
	}
}

// WireGuardTunnelAdapter wraps a WireGuardTunnel to satisfy the TunnelDevice interface.
type WireGuardTunnelAdapter struct {
	tunnel *WireGuardTunnel
}

func (a *WireGuardTunnelAdapter) ReadPacket(buf []byte) (int, error) {
	return a.tunnel.TunDev.Read([][]byte{buf}, []int{len(buf)}, 0)
}

func (a *WireGuardTunnelAdapter) WritePacket(pkt []byte) error {
	_, err := a.tunnel.TunDev.Write([][]byte{pkt}, 0)
	return err
}

// NewWireGuardTunnelAdapter creates a TunnelDevice adapter for WireGuard.
func NewWireGuardTunnelAdapter(t *WireGuardTunnel) TunnelDevice {
	return &WireGuardTunnelAdapter{tunnel: t}
}

// GenerateWireGuardKeyPair generates a new WireGuard key pair.
func GenerateWireGuardKeyPair() (privateKey []byte, publicKey []byte, err error) {
	key, err := wgtypes.GeneratePrivateKey()
	if err != nil {
		return nil, nil, fmt.Errorf("failed to generate private key: %w", err)
	}
	privKeyBytes := key[:]
	pubKey := key.PublicKey()
	pubKeyBytes := pubKey[:]
	return privKeyBytes, pubKeyBytes, nil
}

// GenerateRandomBytes generates random bytes of the specified length.
func GenerateRandomBytes(n int) ([]byte, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return b, nil
}

// bytesToHex converts bytes to a hex string.
func bytesToHex(b []byte) string {
	const hexChars = "0123456789abcdef"
	result := make([]byte, len(b)*2)
	for i, byte := range b {
		result[i*2] = hexChars[byte>>4]
		result[i*2+1] = hexChars[byte&0x0f]
	}
	return string(result)
}
