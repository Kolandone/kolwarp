#!/bin/bash
# kolwarp Installer - Automatic download and setup
# Telegram: @kolandjs1 | GitHub: github.com/kolandone

set -e

BINARY="kolwarp"
GITHUB_REPO="Kolandone/kolwarp"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                   kolwarp Installer                       ║
║                      Version 1.0.0                        ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo -e "  ${MAGENTA}Telegram: @kolandjs1${NC} | ${CYAN}GitHub: github.com/kolandone${NC}\n"

# Detect OS
OS=$(uname -s)
if [ "$OS" != "Linux" ] && [ "$OS" != "Darwin" ]; then
    echo -e "${RED}Error: This script only supports Linux and macOS.${NC}"
    echo -e "${YELLOW}For Windows, download kolwarp-windows-amd64.zip from releases.${NC}"
    exit 1
fi

OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')

# Detect architecture
ARCH=$(uname -m)
if [ "$OS_LOWER" = "darwin" ]; then
    case "$ARCH" in
        arm64) ARCH="arm64" ;;
        x86_64) ARCH="amd64" ;;
        *) echo -e "${RED}Unsupported macOS architecture: $ARCH${NC}" && exit 1 ;;
    esac
else
    case "$ARCH" in
        aarch64|arm64) ARCH="arm64" ;;
        armv7*|armv8*) ARCH="arm" ;;
        x86_64) ARCH="amd64" ;;
        i386|i686)   ARCH="386" ;;
        *) echo -e "${RED}Unsupported Linux architecture: $ARCH${NC}" && exit 1 ;;
    esac
fi

echo -e "${GREEN}Detected: ${OS_LOWER} ${ARCH}${NC}"

# Determine file extension
if [ "$OS_LOWER" = "darwin" ]; then
    EXT="zip"
else
    EXT="tar.gz"
fi

ARCHIVE="${BINARY}-${OS_LOWER}-${ARCH}.${EXT}"

# Check if already installed
if [ -x "./${BINARY}" ]; then
    echo -e "${GREEN}kolwarp is already installed. Running...${NC}"
    exec ./"${BINARY}"
else
    echo -e "${CYAN}Installing kolwarp...${NC}"
fi

# Download
echo -e "${CYAN}Downloading ${ARCHIVE}...${NC}"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/${ARCHIVE}"
if ! curl -L -# -o "${ARCHIVE}" "${DOWNLOAD_URL}"; then
    echo -e "${RED}Failed to download. Please check your internet connection.${NC}"
    exit 1
fi

# Extract
echo -e "${CYAN}Extracting...${NC}"
if [ "$EXT" = "zip" ]; then
    if command -v unzip &>/dev/null; then
        unzip -q -o "${ARCHIVE}"
    else
        python3 -c "import zipfile; zipfile.ZipFile('${ARCHIVE}').extractall('.')" 2>/dev/null || { echo -e "${RED}unzip not found. Please install unzip.${NC}" exit 1; }
    fi
else
    tar xzf "${ARCHIVE}"
fi

# Move and Rename binary
EXTRACTED_TARGET="${BINARY}-${OS_LOWER}-${ARCH}"
if [ -d "${EXTRACTED_TARGET}" ]; then
    mv "${EXTRACTED_TARGET}/${BINARY}" . 2>/dev/null || true
    rm -rf "${EXTRACTED_TARGET}"
elif [ -f "${EXTRACTED_TARGET}" ]; then
    mv "${EXTRACTED_TARGET}" "${BINARY}"
fi

# Cleanup
rm -f "${ARCHIVE}"
rm -f LICENSE

# Make executable
chmod +x "./${BINARY}"

echo -e "\n${GREEN}✓ kolwarp installed successfully!${NC}\n"
echo -e "${CYAN}Running kolwarp...${NC}\n"

exec ./"${BINARY}"
