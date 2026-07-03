#!/usr/bin/env bash
# kolwarp - Beautiful CLI for WARP MASQUE/WireGuard client
# Telegram: @kolandjs1 | GitHub: github.com/kolandone

set -euo pipefail

# ─────────────────────────────────────────────
# Colors & Formatting
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────
# Symbols
# ─────────────────────────────────────────────
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}→${NC}"
BULLET="${BLUE}●${NC}"
SPARKLE="${MAGENTA}✦${NC}"
STAR="${YELLOW}★${NC}"
LINE="${DIM}────────────────────────────────────────${NC}"
DOUBLE_LINE="${DIM}════════════════════════════════════════${NC}"

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOLWARP_BIN="${SCRIPT_DIR}/kolwarp"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
RESULTS_DIR="${SCRIPT_DIR}/scan_results"

# WARP Endpoint IP ranges (from Cloudflare)
WARP_IPV4_PREFIXES=(
    "188.114.96" "188.114.97" "188.114.98" "188.114.99"
    "162.159.192" "162.159.193" "162.159.195"
    "8.34.146" "8.39.214" "8.39.204"
    "8.6.112" "8.35.211" "8.39.125" "8.47.69"
)

WARP_PORTS=(
    500 854 859 864 878 880 890 891 894 903
    908 928 934 939 942 943 945 946 955 968
    987 988 1002 1010 1014 1018 1070 1074 1180 1387
    1701 1843 2371 2408 2506 3138 3476 3581 3854 4177
    4198 4233 4500 5279 5956 7103 7152 7156 7281 7559
    8319 8742 8854 8886
)

# ─────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────
print_header() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═════════════════════════════════════════════════════════════════════════╗
    ║                                                                         ║
    ║                    ${BOLD}${WHITE}K O L A N D${NC}${CYAN}                                     ║
    ║                                                                         ║
    ║          ${DIM}WARP MASQUE/WireGuard Client with Smart Scanner${NC}${CYAN}            ║
    ║                                                                         ║
    ╚═════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "  ${DIM}Telegram: ${MAGENTA}@kolandjs1${NC}  |  ${DIM}GitHub: ${BLUE}github.com/kolandone${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BOLD}${BLUE}╔═══ $1 ═══╗${NC}\n"
}

print_success() {
    echo -e "  ${CHECK} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "  ${CROSS} ${RED}$1${NC}"
}

print_info() {
    echo -e "  ${BULLET} ${CYAN}$1${NC}"
}

print_warning() {
    echo -e "  ${BULLET} ${YELLOW}$1${NC}"
}

print_arrow() {
    echo -e "  ${ARROW} ${WHITE}$1${NC}"
}

print_banner() {
    echo -e "\n${MAGENTA}${DOUBLE_LINE}${NC}"
    echo -e "  ${BOLD}${WHITE}  kolwarp - Fast & Secure WARP Client${NC}"
    echo -e "  ${DIM}  Created by Kolandone${NC}"
    echo -e "${MAGENTA}${DOUBLE_LINE}${NC}\n"
}

check_dependencies() {
    local missing=()
    
    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v bc &>/dev/null; then
        missing+=("bc")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing dependencies: ${missing[*]}"
        echo -e "\n  Install them with:"
        echo -e "    ${CYAN}# Debian/Ubuntu${NC}"
        echo -e "    sudo apt install ${missing[*]}"
        echo -e "\n    ${CYAN}# macOS${NC}"
        echo -e "    brew install ${missing[*]}"
        echo -e "\n    ${CYAN}# Arch Linux${NC}"
        echo -e "    sudo pacman -S ${missing[*]}"
        return 1
    fi
    return 0
}

check_kolwarp() {
    if [[ ! -f "$KOLWARP_BIN" ]]; then
        print_warning "kolwarp binary not found at ${KOLWARP_BIN}"
        echo -e "\n  Would you like to download it? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            download_kolwarp
        else
            print_error "Cannot continue without kolwarp binary"
            return 1
        fi
    fi
    return 0
}

download_kolwarp() {
    print_info "Downloading kolwarp..."
    
    local os_type=""
    local arch=""
    
    case "$(uname -s)" in
        Linux*)     os_type="linux" ;;
        Darwin*)    os_type="darwin" ;;
        MINGW*|MSYS*|CYGWIN*)  os_type="windows" ;;
        *)          print_error "Unsupported OS: $(uname -s)"; return 1 ;;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        arm64|aarch64)  arch="arm64" ;;
        armv7*|armv8*)  arch="arm" ;;
        *)              print_error "Unsupported architecture: $(uname -m)"; return 1 ;;
    esac
    
    local download_url="https://github.com/Kolandone/kolwarp/releases/latest/download/kolwarp-${os_type}-${arch}.tar.gz"
    
    echo -e "  ${DIM}Downloading from: ${download_url}${NC}"
    
    if curl -L -# -o /tmp/kolwarp.tar.gz "$download_url"; then
        tar xzf /tmp/kolwarp.tar.gz -C "$SCRIPT_DIR" 2>/dev/null || tar xzf /tmp/kolwarp.tar.gz --strip-components=1 -C "$SCRIPT_DIR" 2>/dev/null
        rm -f /tmp/kolwarp.tar.gz
        chmod +x "$KOLWARP_BIN"
        print_success "kolwarp downloaded successfully"
    else
        print_error "Failed to download kolwarp"
        return 1
    fi
}

# ─────────────────────────────────────────────
# Menu Functions
# ─────────────────────────────────────────────
show_main_menu() {
    print_header
    
    echo -e "${BOLD}${WHITE}  Main Menu${NC}\n"
    
    echo -e "  ${GREEN}1.${NC} ${BOLD}Register${NC}              ${DIM}- Create new WARP account${NC}"
    echo -e "  ${GREEN}2.${NC} ${BOLD}Scan & Connect${NC}        ${DIM}- Find best endpoint & connect${NC}"
    echo -e "  ${GREEN}3.${NC} ${BOLD}Quick Connect${NC}         ${DIM}- Connect with current config${NC}"
    echo -e "  ${GREEN}4.${NC} ${BOLD}Account Info${NC}          ${DIM}- View account details${NC}"
    echo -e "  ${GREEN}5.${NC} ${BOLD}Settings${NC}              ${DIM}- Configure kolwarp${NC}"
    echo -e "  ${GREEN}6.${NC} ${BOLD}About${NC}                 ${DIM}- Credits & social links${NC}"
    echo -e "  ${RED}0.${NC} ${BOLD}Exit${NC}"
    
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Select an option [0-6]:${NC} "
}

show_protocol_menu() {
    print_section "Select Protocol"
    
    echo -e "  ${GREEN}1.${NC} ${BOLD}MASQUE${NC}               ${DIM}- HTTP/3 QUIC (recommended)${NC}"
    echo -e "  ${GREEN}2.${NC} ${BOLD}WireGuard${NC}            ${DIM}- UDP tunnel (userspace)${NC}"
    echo -e "  ${GREEN}3.${NC} ${BOLD}MASQUE + HTTP/2${NC}      ${DIM}- TCP fallback${NC}"
    echo -e "  ${RED}0.${NC} ${BOLD}Back${NC}"
    
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Select protocol [0-3]:${NC} "
}

show_mode_menu() {
    print_section "Select Connection Mode"
    
    echo -e "  ${GREEN}1.${NC} ${BOLD}SOCKS5 Proxy${NC}         ${DIM}- Full proxy with UDP support${NC}"
    echo -e "  ${GREEN}2.${NC} ${BOLD}HTTP Proxy${NC}           ${DIM}- HTTP CONNECT proxy${NC}"
    echo -e "  ${GREEN}3.${NC} ${BOLD}L4 SOCKS${NC}             ${DIM}- Fast TCP-only SOCKS${NC}"
    echo -e "  ${GREEN}4.${NC} ${BOLD}L4 HTTP${NC}              ${DIM}- Fast TCP-only HTTP${NC}"
    echo -e "  ${GREEN}5.${NC} ${BOLD}Native TUN${NC}           ${DIM}- Full tunnel interface (root)${NC}"
    echo -e "  ${GREEN}6.${NC} ${BOLD}Port Forward${NC}         ${DIM}- SSH-like port forwarding${NC}"
    echo -e "  ${RED}0.${NC} ${BOLD}Back${NC}"
    
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Select mode [0-6]:${NC} "
}

# ─────────────────────────────────────────────
# Register Command
# ─────────────────────────────────────────────
do_register() {
    if [[ ! -f "$KOLWARP_BIN" ]]; then
        print_error "kolwarp binary not found at ${KOLWARP_BIN}"
        echo -e "\n  ${DIM}Press Enter to continue...${NC}"
        read -r
        return
    fi
    
    print_section "Register New WARP Account"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "  ${YELLOW}⚠ Existing config found at ${CONFIG_FILE}${NC}"
        echo -e "  Do you want to overwrite? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    echo -e "  ${DIM}Enter device name (optional, press Enter to skip):${NC} "
    read -r device_name
    
    echo -e "\n  ${DIM}Select registration type:${NC}"
    echo -e "  ${GREEN}1.${NC} Personal WARP"
    echo -e "  ${GREEN}2.${NC} ZeroTrust (requires JWT token)"
    echo -e "  ${DIM}Select [1-2]:${NC} "
    read -r reg_type
    
    local cmd="$KOLWARP_BIN register"
    
    if [[ -n "$device_name" ]]; then
        cmd="$cmd -n \"$device_name\""
    fi
    
    if [[ "$reg_type" == "2" ]]; then
        echo -e "  ${DIM}Enter ZeroTrust JWT token:${NC} "
        read -r jwt_token
        cmd="$cmd --jwt \"$jwt_token\""
    fi
    
    echo -e "\n  ${CYAN}Running registration...${NC}\n"
    
    eval "$cmd"
    
    if [[ $? -eq 0 ]]; then
        print_success "Registration successful!"
    else
        print_error "Registration failed"
    fi
    
    echo -e "\n  ${DIM}Press Enter to continue...${NC}"
    read -r
}

# ─────────────────────────────────────────────
# Endpoint Scanner
# ─────────────────────────────────────────────
generate_endpoints() {
    local count=${1:-100}
    
    local endpoints=()
    local seen=()
    
    while [[ ${#endpoints[@]} -lt $count ]]; do
        local prefix="${WARP_IPV4_PREFIXES[$((RANDOM % ${#WARP_IPV4_PREFIXES[@]}))]}"
        local last_octet=$((RANDOM % 256))
        local port="${WARP_PORTS[$((RANDOM % ${#WARP_PORTS[@]}))]}"
        local endpoint="${prefix}.${last_octet}:${port}"
        
        local duplicate=false
        for e in "${seen[@]}"; do
            if [[ "$e" == "$endpoint" ]]; then
                duplicate=true
                break
            fi
        done
        
        if [[ "$duplicate" == "false" ]]; then
            endpoints+=("$endpoint")
            seen+=("$endpoint")
        fi
    done
    
    printf '%s\n' "${endpoints[@]}"
}

test_endpoint() {
    local endpoint="$1"
    local timeout="${2:-2}"
    
    local host="${endpoint%%:*}"
    local port="${endpoint##*:}"
    
    # Test TCP connectivity
    local start_time=$(date +%s%N 2>/dev/null || date +%s)
    
    if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        local end_time=$(date +%s%N 2>/dev/null || date +%s)
        local latency=$(( (end_time - start_time) / 1000000 )) 2>/dev/null || latency=0
        
        # Test with curl for HTTP response
        local curl_result=$(curl -s -o /dev/null -w "%{time_total}" \
            --connect-timeout "$timeout" \
            --max-time "$timeout" \
            "https://${endpoint}/" 2>/dev/null || echo "0")
        
        local curl_latency=$(echo "$curl_result * 1000" | bc 2>/dev/null || echo "0")
        
        echo "${endpoint}|${latency}|${curl_latency}|success"
    else
        echo "${endpoint}|0|0|failed"
    fi
}

do_scan_and_connect() {
    print_section "Smart Endpoint Scanner & Connect"
    
    echo -e "  ${BOLD}This will scan WARP endpoints and let you choose the best one${NC}\n"
    
    echo -e "  ${DIM}How many endpoints to scan?${NC}"
    echo -e "  ${GREEN}1.${NC} ${BOLD}Quick${NC}               ${DIM}- 30 endpoints (fast)${NC}"
    echo -e "  ${GREEN}2.${NC} ${BOLD}Normal${NC}              ${DIM}- 100 endpoints${NC}"
    echo -e "  ${GREEN}3.${NC} ${BOLD}Deep${NC}                ${DIM}- 300 endpoints (thorough)${NC}"
    echo -e "  ${GREEN}4.${NC} ${BOLD}Custom${NC}              ${DIM}- Your choice${NC}"
    echo -e "  ${RED}0.${NC} ${BOLD}Back${NC}"
    
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Select [0-4]:${NC} "
    read -r scan_mode
    
    local endpoint_count=30
    
    case "$scan_mode" in
        1) endpoint_count=30 ;;
        2) endpoint_count=100 ;;
        3) endpoint_count=300 ;;
        4)
            echo -e "\n  ${DIM}Enter number of endpoints [1-500]:${NC} "
            read -r endpoint_count
            endpoint_count=${endpoint_count:-30}
            if [[ "$endpoint_count" -lt 1 || "$endpoint_count" -gt 500 ]]; then
                print_error "Invalid count. Using 30."
                endpoint_count=30
            fi
            ;;
        0) return ;;
        *) print_error "Invalid choice"; return ;;
    esac
    
    print_section "Scanning ${endpoint_count} WARP Endpoints"
    
    mkdir -p "$RESULTS_DIR"
    
    # Generate endpoints
    local endpoints_file="${RESULTS_DIR}/endpoints.txt"
    generate_endpoints "$endpoint_count" > "$endpoints_file"
    
    local total=$(wc -l < "$endpoints_file")
    echo -e "  ${CYAN}Testing ${total} endpoints for connectivity and latency...${NC}\n"
    
    # Scan endpoints
    local results_file="${RESULTS_DIR}/scan_results.txt"
    local scan_start=$(date +%s)
    
    > "$results_file"
    
    local processed=0
    local successful=0
    
    while IFS= read -r endpoint; do
        processed=$((processed + 1))
        
        # Show progress
        printf "\r  ${DIM}[%d/%d]${NC} Testing ${CYAN}%-21s${NC} " "$processed" "$total" "$endpoint"
        
        # Test endpoint
        local result=$(test_endpoint "$endpoint" 2)
        local status=$(echo "$result" | cut -d'|' -f4)
        
        if [[ "$status" == "success" ]]; then
            echo "$result" >> "$results_file"
            successful=$((successful + 1))
            printf "${GREEN}✓${NC} "
        else
            printf "${RED}✗${NC} "
        fi
        
        # Rate limiting
        sleep 0.05
    done < "$endpoints_file"
    
    local scan_end=$(date +%s)
    local scan_duration=$((scan_end - scan_start))
    
    echo -e "\n\n${LINE}"
    echo -e "  ${CYAN}Scan completed in ${scan_duration} seconds${NC}"
    echo -e "  ${GREEN}Found ${successful} working endpoints${NC}"
    
    # Show results to user
    if [[ -s "$results_file" ]]; then
        show_scan_results "$results_file"
    else
        print_error "No working endpoints found"
        echo -e "\n  ${DIM}Press Enter to continue...${NC}"
        read -r
    fi
}

show_scan_results() {
    local results_file="$1"
    
    print_section "Scan Results - Choose Your Endpoint"
    
    # Sort and number the results
    local sorted_file="${RESULTS_DIR}/sorted_results.txt"
    sort -t'|' -k2 -n "$results_file" > "$sorted_file"
    
    echo -e "  ${BOLD}${CYAN} #   Endpoint                    TCP Latency    Status${NC}"
    echo -e "  ${DIM}─────────────────────────────────────────────────────────────${NC}"
    
    local count=0
    while IFS='|' read -r ep tcp_latency http_latency _; do
        count=$((count + 1))
        printf "  ${GREEN}%-3d${NC} ${WHITE}%-28s${NC} ${YELLOW}%-13s${NC} ${GREEN}✓ Working${NC}\n" \
            "$count" "$ep" "${tcp_latency}ms"
        
        if [[ $count -ge 20 ]]; then
            break
        fi
    done < "$sorted_file"
    
    echo -e "\n${LINE}"
    
    # Ask user to choose
    local total_results=$(wc -l < "$sorted_file")
    if [[ $total_results -gt 20 ]]; then
        echo -e "  ${DIM}... and $((total_results - 20)) more endpoints${NC}"
    fi
    
    echo -e "\n  ${BOLD}${WHITE}Choose an endpoint:${NC}"
    echo -e "  ${DIM}Enter number [1-${total_results}] or 'q' to go back:${NC} "
    read -r choice
    
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        return
    fi
    
    # Validate choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$total_results" ]]; then
        local selected_endpoint=$(sed -n "${choice}p" "$sorted_file" | cut -d'|' -f1)
        local selected_host="${selected_endpoint%%:*}"
        
        echo -e "\n  ${CHECK} Selected: ${GREEN}${selected_endpoint}${NC}"
        
        # Apply to config
        apply_endpoint_to_config "$selected_host" "$selected_endpoint"
        
        # Ask to connect
        echo -e "\n  ${BOLD}${WHITE}What would you like to do?${NC}"
        echo -e "  ${GREEN}1.${NC} ${BOLD}Connect now${NC}            ${DIM}- Start tunnel with this endpoint${NC}"
        echo -e "  ${GREEN}2.${NC} ${BOLD}Save only${NC}              ${DIM}- Just save to config${NC}"
        echo -e "  ${RED}0.${NC} ${BOLD}Cancel${NC}"
        echo -e "\n  ${DIM}Select [0-2]:${NC} "
        read -r action_choice
        
        case "$action_choice" in
            1)
                # Proceed to connect
                do_connect_with_endpoint "$selected_endpoint"
                ;;
            2)
                print_success "Endpoint saved to config"
                ;;
            0)
                print_warning "Endpoint not saved"
                ;;
        esac
    else
        print_error "Invalid selection"
    fi
    
    echo -e "\n  ${DIM}Press Enter to continue...${NC}"
    read -r
}

apply_endpoint_to_config() {
    local host="$1"
    local full_endpoint="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Config file not found. Please register first."
        return 1
    fi
    
    # Extract port from endpoint
    local port="${full_endpoint##*:}"
    
    print_info "Applying endpoint to config..."
    
    if command -v jq &>/dev/null; then
        local temp_file=$(mktemp)
        jq --arg ep "$host" --arg port "$port" \
            '.endpoint_v4 = $ep' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
    else
        # Fallback to sed
        sed -i.bak "s/\"endpoint_v4\":\s*\"[^\"]*\"/\"endpoint_v4\": \"${host}\"/" "$CONFIG_FILE"
        rm -f "${CONFIG_FILE}.bak"
    fi
    
    print_success "Endpoint ${host} applied to config"
}

do_connect_with_endpoint() {
    local endpoint="$1"
    
    show_protocol_menu
    read -r protocol_choice
    
    local protocol_args=""
    local protocol_name="MASQUE"
    
    case "$protocol_choice" in
        1) protocol_args="" ;;
        2) protocol_args="--wireguard"; protocol_name="WireGuard" ;;
        3) protocol_args="--http2"; protocol_name="MASQUE+H2" ;;
        0) return ;;
        *) print_error "Invalid choice"; return ;;
    esac
    
    show_mode_menu
    read -r mode_choice
    
    local mode_cmd=""
    local mode_name=""
    
    case "$mode_choice" in
        1) mode_cmd="socks"; mode_name="SOCKS5 Proxy" ;;
        2) mode_cmd="http-proxy"; mode_name="HTTP Proxy" ;;
        3) mode_cmd="l4-socks"; mode_name="L4 SOCKS" ;;
        4) mode_cmd="l4-http-proxy"; mode_name="L4 HTTP" ;;
        5) mode_cmd="nativetun"; mode_name="Native TUN" ;;
        6) mode_cmd="portfw"; mode_name="Port Forward" ;;
        0) return ;;
        *) print_error "Invalid choice"; return ;;
    esac
    
    print_section "Configure ${mode_name}"
    
    local bind_addr="0.0.0.0"
    local port=""
    local extra_args=""
    
    case "$mode_cmd" in
        socks|http-proxy|l4-socks|l4-http-proxy)
            echo -e "  ${DIM}Bind address [${bind_addr}]:${NC} "
            read -r input
            [[ -n "$input" ]] && bind_addr="$input"
            
            case "$mode_cmd" in
                socks) port="1080" ;;
                l4-socks) port="1080" ;;
                http-proxy) port="8000" ;;
                l4-http-proxy) port="8000" ;;
            esac
            
            echo -e "  ${DIM}Port [${port}]:${NC} "
            read -r input
            [[ -n "$input" ]] && port="$input"
            
            echo -e "\n  ${DIM}Enable authentication? (y/n):${NC} "
            read -r auth_choice
            if [[ "$auth_choice" =~ ^[Yy]$ ]]; then
                echo -e "  ${DIM}Username:${NC} "
                read -r username
                echo -e "  ${DIM}Password:${NC} "
                read -rs password
                echo
                extra_args="$extra_args -u \"$username\" -w \"$password\""
            fi
            ;;
        nativetun)
            echo -e "  ${DIM}Interface name [auto]:${NC} "
            read -r iface_name
            [[ -n "$iface_name" ]] && extra_args="$extra_args -n \"$iface_name\""
            ;;
        portfw)
            echo -e "  ${DIM}Local port mappings (-L):${NC} "
            echo -e "  ${DIM}Example: localhost:8080:100.96.0.2:8080${NC}"
            read -r local_ports
            [[ -n "$local_ports" ]] && extra_args="$extra_args -L \"$local_ports\""
            
            echo -e "  ${DIM}Remote port mappings (-R):${NC} "
            read -r remote_ports
            [[ -n "$remote_ports" ]] && extra_args="$extra_args -R \"$remote_ports\""
            ;;
    esac
    
    local cmd="$KOLWARP_BIN $mode_cmd $protocol_args"
    
    if [[ -n "$bind_addr" && -n "$port" ]]; then
        cmd="$cmd -b $bind_addr -p $port"
    fi
    
    cmd="$cmd $extra_args"
    
    print_banner
    echo -e "  ${CYAN}Protocol:${NC}    ${BOLD}${protocol_name}${NC}"
    echo -e "  ${CYAN}Mode:${NC}        ${BOLD}${mode_name}${NC}"
    echo -e "  ${CYAN}Endpoint:${NC}    ${BOLD}${endpoint}${NC}"
    if [[ -n "$bind_addr" && -n "$port" ]]; then
        echo -e "  ${CYAN}Listen:${NC}      ${BOLD}${bind_addr}:${port}${NC}"
    fi
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Press Ctrl+C to stop${NC}\n"
    
    eval "$cmd"
}

# ─────────────────────────────────────────────
# Quick Connect
# ─────────────────────────────────────────────
do_quick_connect() {
    if [[ ! -f "$KOLWARP_BIN" ]]; then
        print_error "kolwarp binary not found at ${KOLWARP_BIN}"
        echo -e "\n  ${DIM}Press Enter to continue...${NC}"
        read -r
        return
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "No config found. Please register first."
        echo -e "\n  ${DIM}Press Enter to continue...${NC}"
        read -r
        return
    fi
    
    show_protocol_menu
    read -r protocol_choice
    
    local protocol_args=""
    local protocol_name="MASQUE"
    
    case "$protocol_choice" in
        1) protocol_args="" ;;
        2) protocol_args="--wireguard"; protocol_name="WireGuard" ;;
        3) protocol_args="--http2"; protocol_name="MASQUE+H2" ;;
        0) return ;;
        *) print_error "Invalid choice"; return ;;
    esac
    
    show_mode_menu
    read -r mode_choice
    
    local mode_cmd=""
    local mode_name=""
    
    case "$mode_choice" in
        1) mode_cmd="socks"; mode_name="SOCKS5 Proxy" ;;
        2) mode_cmd="http-proxy"; mode_name="HTTP Proxy" ;;
        3) mode_cmd="l4-socks"; mode_name="L4 SOCKS" ;;
        4) mode_cmd="l4-http-proxy"; mode_name="L4 HTTP" ;;
        5) mode_cmd="nativetun"; mode_name="Native TUN" ;;
        6) mode_cmd="portfw"; mode_name="Port Forward" ;;
        0) return ;;
        *) print_error "Invalid choice"; return ;;
    esac
    
    print_section "Configure ${mode_name}"
    
    local bind_addr="0.0.0.0"
    local port=""
    local extra_args=""
    
    case "$mode_cmd" in
        socks|http-proxy|l4-socks|l4-http-proxy)
            echo -e "  ${DIM}Bind address [${bind_addr}]:${NC} "
            read -r input
            [[ -n "$input" ]] && bind_addr="$input"
            
            case "$mode_cmd" in
                socks) port="1080" ;;
                l4-socks) port="1080" ;;
                http-proxy) port="8000" ;;
                l4-http-proxy) port="8000" ;;
            esac
            
            echo -e "  ${DIM}Port [${port}]:${NC} "
            read -r input
            [[ -n "$input" ]] && port="$input"
            
            echo -e "\n  ${DIM}Enable authentication? (y/n):${NC} "
            read -r auth_choice
            if [[ "$auth_choice" =~ ^[Yy]$ ]]; then
                echo -e "  ${DIM}Username:${NC} "
                read -r username
                echo -e "  ${DIM}Password:${NC} "
                read -rs password
                echo
                extra_args="$extra_args -u \"$username\" -w \"$password\""
            fi
            ;;
        nativetun)
            echo -e "  ${DIM}Interface name [auto]:${NC} "
            read -r iface_name
            [[ -n "$iface_name" ]] && extra_args="$extra_args -n \"$iface_name\""
            ;;
        portfw)
            echo -e "  ${DIM}Local port mappings (-L):${NC} "
            read -r local_ports
            [[ -n "$local_ports" ]] && extra_args="$extra_args -L \"$local_ports\""
            
            echo -e "  ${DIM}Remote port mappings (-R):${NC} "
            read -r remote_ports
            [[ -n "$remote_ports" ]] && extra_args="$extra_args -R \"$remote_ports\""
            ;;
    esac
    
    local cmd="$KOLWARP_BIN $mode_cmd $protocol_args"
    
    if [[ -n "$bind_addr" && -n "$port" ]]; then
        cmd="$cmd -b $bind_addr -p $port"
    fi
    
    cmd="$cmd $extra_args"
    
    # Get current endpoint from config
    local current_endpoint=$(jq -r '.endpoint_v4 // "unknown"' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
    
    print_banner
    echo -e "  ${CYAN}Protocol:${NC}    ${BOLD}${protocol_name}${NC}"
    echo -e "  ${CYAN}Mode:${NC}        ${BOLD}${mode_name}${NC}"
    echo -e "  ${CYAN}Endpoint:${NC}    ${BOLD}${current_endpoint}${NC}"
    if [[ -n "$bind_addr" && -n "$port" ]]; then
        echo -e "  ${CYAN}Listen:${NC}      ${BOLD}${bind_addr}:${port}${NC}"
    fi
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Press Ctrl+C to stop${NC}\n"
    
    eval "$cmd"
}

# ─────────────────────────────────────────────
# Account Info
# ─────────────────────────────────────────────
do_account_info() {
    if [[ ! -f "$KOLWARP_BIN" ]]; then
        print_error "kolwarp binary not found at ${KOLWARP_BIN}"
        echo -e "\n  ${DIM}Press Enter to continue...${NC}"
        read -r
        return
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "No config found. Please register first."
        echo -e "\n  ${DIM}Press Enter to continue...${NC}"
        read -r
        return
    fi
    
    print_section "Account Information"
    
    echo -e "  ${CYAN}Config File:${NC} ${CONFIG_FILE}\n"
    
    if command -v jq &>/dev/null; then
        local device_id=$(jq -r '.id // "N/A"' "$CONFIG_FILE")
        local ipv4=$(jq -r '.ipv4 // "N/A"' "$CONFIG_FILE")
        local ipv6=$(jq -r '.ipv6 // "N/A"' "$CONFIG_FILE")
        local endpoint=$(jq -r '.endpoint_v4 // "N/A"' "$CONFIG_FILE")
        
        echo -e "  ${BOLD}Device ID:${NC}     ${device_id}"
        echo -e "  ${BOLD}Internal IPv4:${NC} ${ipv4}"
        echo -e "  ${BOLD}Internal IPv6:${NC} ${ipv6}"
        echo -e "  ${BOLD}Endpoint:${NC}      ${endpoint}"
    fi
    
    echo -e "\n  ${DIM}Press Enter to continue...${NC}"
    read -r
}

# ─────────────────────────────────────────────
# Settings
# ─────────────────────────────────────────────
do_settings() {
    print_section "Settings"
    
    echo -e "  ${GREEN}1.${NC} ${BOLD}View Current Config${NC}"
    echo -e "  ${GREEN}2.${NC} ${BOLD}Reset Config${NC}"
    echo -e "  ${GREEN}3.${NC} ${BOLD}Open Config Folder${NC}"
    echo -e "  ${RED}0.${NC} ${BOLD}Back${NC}"
    
    echo -e "\n${LINE}"
    echo -e "  ${DIM}Select option [0-3]:${NC} "
    read -r setting_choice
    
    case "$setting_choice" in
        1)
            if [[ -f "$CONFIG_FILE" ]]; then
                echo -e "\n${CYAN}Current Configuration:${NC}\n"
                cat "$CONFIG_FILE"
            else
                print_error "No config file found"
            fi
            ;;
        2)
            echo -e "  ${YELLOW}⚠ This will delete your current config${NC}"
            echo -e "  ${DIM}Are you sure? (y/n):${NC} "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f "$CONFIG_FILE"
                print_success "Config deleted"
            fi
            ;;
        3)
            if [[ -d "$SCRIPT_DIR" ]]; then
                if command -v xdg-open &>/dev/null; then
                    xdg-open "$SCRIPT_DIR"
                elif command -v open &>/dev/null; then
                    open "$SCRIPT_DIR"
                else
                    echo -e "  ${DIM}Config folder: ${SCRIPT_DIR}${NC}"
                fi
            fi
            ;;
        0) return ;;
    esac
    
    echo -e "\n  ${DIM}Press Enter to continue...${NC}"
    read -r
}

# ─────────────────────────────────────────────
# About
# ─────────────────────────────────────────────
do_about() {
    print_section "About kolwarp"
    
    echo -e "  ${BOLD}${WHITE}kolwarp${NC} - WARP MASQUE/WireGuard Client"
    echo -e "  ${DIM}Version: 1.0.0${NC}\n"
    
    echo -e "  ${BOLD}Features:${NC}"
    echo -e "    ${GREEN}•${NC} MASQUE protocol (HTTP/3 QUIC)"
    echo -e "    ${GREEN}•${NC} WireGuard protocol (userspace)"
    echo -e "    ${GREEN}•${NC} HTTP/2 fallback"
    echo -e "    ${GREEN}•${NC} Smart endpoint scanning"
    echo -e "    ${GREEN}•${NC} Multiple proxy modes"
    echo -e "    ${GREEN}•${NC} Cross-platform support\n"
    
    echo -e "  ${BOLD}Connect with us:${NC}"
    echo -e "    ${MAGENTA}Telegram:${NC}  @kolandjs1"
    echo -e "    ${BLUE}GitHub:${NC}    github.com/kolandone"
    echo -e "    ${CYAN}Project:${NC}   github.com/Kolandone/kolwarp\n"
    
    echo -e "  ${BOLD}Credits:${NC}"
    echo -e "    ${DIM}Built on top of usque (github.com/Diniboy1123/usque)${NC}"
    echo -e "    ${DIM}Endpoint scanning inspired by BPB-Warp-Scanner${NC}\n"
    
    echo -e "${LINE}"
    echo -e "  ${DIM}Press Enter to continue...${NC}"
    read -r
}

# ─────────────────────────────────────────────
# Main Loop
# ─────────────────────────────────────────────
main() {
    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi
    
    # Check kolwarp binary
    if ! check_kolwarp; then
        exit 1
    fi
    
    while true; do
        show_main_menu
        read -r choice
        
        case "$choice" in
            1) do_register ;;
            2) do_scan_and_connect ;;
            3) do_quick_connect ;;
            4) do_account_info ;;
            5) do_settings ;;
            6) do_about ;;
            0)
                print_banner
                echo -e "  ${GREEN}Thanks for using kolwarp!${NC}"
                echo -e "  ${DIM}Telegram: @kolandjs1 | GitHub: kolandone${NC}\n"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"
