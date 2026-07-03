package config

import (
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"os"
)

// Config represents the application configuration structure, containing essential details such as keys, endpoints, and access tokens.
type Config struct {
	PrivateKey     string `json:"private_key"`      // Base64-encoded ECDSA private key
	EndpointV4     string `json:"endpoint_v4"`      // IPv4 address of the endpoint
	EndpointV6     string `json:"endpoint_v6"`      // IPv6 address of the endpoint
	EndpointH2V4   string `json:"endpoint_h2_v4"`   // IPv4 address used in HTTP/2 mode
	EndpointH2V6   string `json:"endpoint_h2_v6"`   // IPv6 address used in HTTP/2 mode
	EndpointPubKey string `json:"endpoint_pub_key"` // PEM-encoded ECDSA public key of the endpoint to verify against
	ID             string `json:"id"`               // Device unique identifier
	AccessToken    string `json:"access_token"`     // Authentication token for API access
	IPv4           string `json:"ipv4"`             // Assigned IPv4 address
	IPv6           string `json:"ipv6"`             // Assigned IPv6 address
	// WireGuard fields
	WGPrivateKey     string `json:"wg_private_key,omitempty"`      // Base64-encoded WireGuard private key (Curve25519)
	WGPeerPublicKey  string `json:"wg_peer_public_key,omitempty"`  // Base64-encoded WireGuard peer public key (Cloudflare WARP)
	WGEndpointV4     string `json:"wg_endpoint_v4,omitempty"`      // WireGuard endpoint IPv4
	WGEndpointV6     string `json:"wg_endpoint_v6,omitempty"`      // WireGuard endpoint IPv6
}

// AppConfig holds the global application configuration.
var AppConfig Config

// ConfigLoaded indicates whether the configuration has been successfully loaded.
var ConfigLoaded bool

// LoadConfig loads the application configuration from a JSON file.
//
// Parameters:
//   - configPath: string - The path to the configuration JSON file.
//
// Returns:
//   - error: An error if the configuration file cannot be loaded or parsed.
func LoadConfig(configPath string) error {
	file, err := os.Open(configPath)
	if err != nil {
		return fmt.Errorf("failed to open config file: %v", err)
	}
	defer func() { _ = file.Close() }()

	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&AppConfig); err != nil {
		return fmt.Errorf("failed to decode config file: %v", err)
	}

	ConfigLoaded = true

	return nil
}

// SaveConfig writes the current application configuration to a prettified JSON file.
//
// Parameters:
//   - configPath: string - The path to save the configuration JSON file.
//
// Returns:
//   - error: An error if the configuration file cannot be written.
func (*Config) SaveConfig(configPath string) error {
	file, err := os.Create(configPath)
	if err != nil {
		return fmt.Errorf("failed to create config file: %v", err)
	}
	defer func() { _ = file.Close() }()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(AppConfig); err != nil {
		return fmt.Errorf("failed to encode config file: %v", err)
	}

	return nil
}

// GetEcPrivateKey retrieves the ECDSA private key from the stored Base64-encoded string.
//
// Returns:
//   - *ecdsa.PrivateKey: The parsed ECDSA private key.
//   - error: An error if decoding or parsing the private key fails.
func (*Config) GetEcPrivateKey() (*ecdsa.PrivateKey, error) {
	privKeyB64, err := base64.StdEncoding.DecodeString(AppConfig.PrivateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to decode private key: %v", err)
	}

	privKey, err := x509.ParseECPrivateKey(privKeyB64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse private key: %v", err)
	}

	return privKey, nil
}

// GetEcEndpointPublicKey retrieves the ECDSA public key from the stored PEM-encoded string.
//
// Returns:
//   - *ecdsa.PublicKey: The parsed ECDSA public key.
//   - error: An error if decoding or parsing the public key fails.
func (*Config) GetEcEndpointPublicKey() (*ecdsa.PublicKey, error) {
	endpointPubKeyB64, _ := pem.Decode([]byte(AppConfig.EndpointPubKey))
	if endpointPubKeyB64 == nil {
		return nil, fmt.Errorf("failed to decode endpoint public key")
	}

	pubKey, err := x509.ParsePKIXPublicKey(endpointPubKeyB64.Bytes)
	if err != nil {
		return nil, fmt.Errorf("failed to parse public key: %v", err)
	}

	ecPubKey, ok := pubKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("failed to assert public key as ECDSA")
	}

	return ecPubKey, nil
}

// GetWGPrivateKey returns the WireGuard private key bytes.
func (*Config) GetWGPrivateKey() ([]byte, error) {
	if AppConfig.WGPrivateKey == "" {
		return nil, fmt.Errorf("wireguard private key not configured")
	}
	key, err := base64.StdEncoding.DecodeString(AppConfig.WGPrivateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to decode wireguard private key: %v", err)
	}
	if len(key) != 32 {
		return nil, fmt.Errorf("invalid wireguard private key length: %d", len(key))
	}
	return key, nil
}

// GetWGPeerPublicKey returns the WireGuard peer public key bytes.
func (*Config) GetWGPeerPublicKey() ([]byte, error) {
	if AppConfig.WGPeerPublicKey == "" {
		return nil, fmt.Errorf("wireguard peer public key not configured")
	}
	key, err := base64.StdEncoding.DecodeString(AppConfig.WGPeerPublicKey)
	if err != nil {
		return nil, fmt.Errorf("failed to decode wireguard peer public key: %v", err)
	}
	if len(key) != 32 {
		return nil, fmt.Errorf("invalid wireguard peer public key length: %d", len(key))
	}
	return key, nil
}

// HasWireGuardConfig returns true if WireGuard configuration is present.
func (*Config) HasWireGuardConfig() bool {
	return AppConfig.WGPrivateKey != "" && AppConfig.WGPeerPublicKey != ""
}
