#!/bin/bash

set -e

# Liquibase Universal Installer Script
# Install Liquibase OSS or Secure with automatic platform detection
# Usage: curl -fsSL https://get.liquibase.com | bash [latest|VERSION] [oss|secure]

VERSION_ARG=""
EDITION_ARG=""
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            latest)
                if [ -z "$VERSION_ARG" ]; then
                    VERSION_ARG="$1"
                fi
                shift
                ;;
            oss|secure)
                if [ -z "$EDITION_ARG" ]; then
                    EDITION_ARG="$1"
                fi
                shift
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            [0-9]*.[0-9]*.[0-9]*)
                if [ -z "$VERSION_ARG" ]; then
                    VERSION_ARG="$1"
                fi
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                log_error "Valid arguments: latest, X.Y.Z (e.g., 4.33.0), oss, secure"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Liquibase Universal Installer

USAGE:
    curl -fsSL https://get.liquibase.com | bash [OPTIONS] [VERSION] [EDITION]

OPTIONS:
    --verbose, -v    Enable verbose output
    --dry-run        Show what would be installed without actually installing
    --help, -h       Show this help message

VERSION:
    latest           Install latest version (default)
    X.Y.Z            Install specific version (e.g., 4.33.0, 5.0.0)

EDITION:
    oss              Install Liquibase Open Source (default)
    secure           Install Liquibase Secure (5.0.0+) or Pro (4.32.0-4.33.0)

EXAMPLES:
    # Install latest OSS version
    curl -fsSL https://get.liquibase.com | bash

    # Install latest Secure version
    curl -fsSL https://get.liquibase.com | bash -s latest secure

    # Install specific OSS version
    curl -fsSL https://get.liquibase.com | bash -s 4.33.0 oss

    # Install specific Secure version
    curl -fsSL https://get.liquibase.com | bash -s 5.0.0 secure

    # Install with verbose output
    curl -fsSL https://get.liquibase.com | VERBOSE=true bash -s latest secure

EOF
}

# Validate version format
validate_version() {
    local version="$1"
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        return 0
    else
        log_error "Invalid version format: $version"
        log_error "Expected format: X.Y.Z (e.g., 4.33.0)"
        return 1
    fi
}

# Check for required dependencies
check_dependencies() {
    log_verbose "Checking for required dependencies..."
    
    DOWNLOADER=""
    if command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
        log_verbose "Found curl"
    elif command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
        log_verbose "Found wget"
    else
        log_error "Either curl or wget is required but neither is installed"
        exit 1
    fi

    # Check if jq is available (optional)
    HAS_JQ=false
    if command -v jq >/dev/null 2>&1; then
        HAS_JQ=true
        log_verbose "Found jq (will use for JSON parsing)"
    else
        log_verbose "jq not found (will use fallback JSON parsing)"
    fi
}

# Download function that works with both curl and wget
download_file() {
    local url="$1"
    local output="$2"
    
    log_verbose "Downloading: $url"
    
    if [ "$DOWNLOADER" = "curl" ]; then
        if [ -n "$output" ]; then
            curl -fsSL -o "$output" "$url"
        else
            curl -fsSL "$url"
        fi
    elif [ "$DOWNLOADER" = "wget" ]; then
        if [ -n "$output" ]; then
            wget -q -O "$output" "$url"
        else
            wget -q -O - "$url"
        fi
    else
        log_error "No downloader available"
        return 1
    fi
}

# Simple JSON parser for extracting values when jq is not available
extract_json_value() {
    local json="$1"
    local key="$2"
    
    # Remove whitespace and extract value
    echo "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

# Extract asset info from GitHub API response
extract_asset_info() {
    local json="$1"
    local asset_name="$2"
    
    if [ "$HAS_JQ" = true ]; then
        echo "$json" | jq -r ".assets[] | select(.name == \"$asset_name\") | .browser_download_url, .size"
    else
        # Fallback parser - extract URL and size for specific asset
        echo "$json" | grep -A 10 -B 10 "\"name\": \"$asset_name\"" | \
        grep -E "(browser_download_url|size)" | \
        sed 's/.*": "\?\([^",]*\)"\?.*/\1/' | \
        head -2
    fi
}

# Detect platform and architecture
detect_platform() {
    log_verbose "Detecting platform and architecture..."
    
    case "$(uname -s)" in
        Darwin) 
            OS="darwin" 
            log_verbose "Detected macOS"
            ;;
        Linux) 
            OS="linux"
            log_verbose "Detected Linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            log_verbose "Detected Windows"
            ;;
        *) 
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64) 
            ARCH="x64"
            log_verbose "Detected x64 architecture"
            ;;
        arm64|aarch64) 
            ARCH="arm64"
            log_verbose "Detected ARM64 architecture"
            ;;
        *) 
            log_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac

    PLATFORM="${OS}-${ARCH}"
    log_verbose "Platform: $PLATFORM"
}

# Get archive filename for the specified version and edition
get_archive_filename() {
    local version="$1"
    local edition="$2"
    
    if [ "$edition" = "oss" ]; then
        echo "liquibase-${version}.tar.gz"
    elif [ "$edition" = "secure" ]; then
        if is_version_5_or_newer "$version"; then
            echo "liquibase-secure-${version}.tar.gz"
        else
            echo "liquibase-pro-${version}.tar.gz"
        fi
    else
        log_error "Unknown edition: $edition"
        return 1
    fi
}

# Get latest version from GitHub API
get_latest_version() {
    log_verbose "Fetching latest version from GitHub API..."
    
    local api_response
    api_response=$(download_file "https://api.github.com/repos/liquibase/liquibase/releases/latest")
    
    if [ $? -ne 0 ] || [ -z "$api_response" ]; then
        log_error "Failed to fetch latest version from GitHub API"
        return 1
    fi
    
    local version
    if [ "$HAS_JQ" = true ]; then
        version=$(echo "$api_response" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//')
    else
        version=$(extract_json_value "$api_response" "tag_name" | sed 's/^v//')
    fi
    
    if [ -z "$version" ] || [ "$version" = "null" ]; then
        log_error "Failed to parse version from GitHub API response"
        log_verbose "API response preview: $(echo "$api_response" | head -3)"
        return 1
    fi
    
    log_verbose "Latest version: $version"
    echo "$version"
}

# Determine if version is 5.0.0 or newer for secure edition naming
is_version_5_or_newer() {
    local version="$1"
    local major
    major=$(echo "$version" | cut -d. -f1)
    
    if [ "$major" -ge 5 ]; then
        return 0
    else
        return 1
    fi
}

# Get download URL for the specified version and edition
get_download_url() {
    local version="$1"
    local edition="$2"
    
    if [ "$edition" = "oss" ]; then
        # OSS versions are always from GitHub releases
        echo "https://github.com/liquibase/liquibase/releases/download/v${version}/liquibase-${version}.tar.gz"
    elif [ "$edition" = "secure" ]; then
        # Secure/Pro versions depend on version number
        if is_version_5_or_newer "$version"; then
            # 5.0.0+ uses 'secure' in the URL
            echo "https://repo.liquibase.com/releases/secure/${version}/liquibase-secure-${version}.tar.gz"
        else
            # 4.32.0-4.33.0 uses 'pro' in the URL
            echo "https://repo.liquibase.com/releases/pro/${version}/liquibase-pro-${version}.tar.gz"
        fi
    else
        log_error "Unknown edition: $edition"
        return 1
    fi
}

# Validate that a specific version exists
validate_version_exists() {
    local version="$1"
    local edition="$2"
    log_verbose "Validating $edition version $version exists..."
    
    if [ "$edition" = "oss" ]; then
        # For OSS, check GitHub releases
        local api_response
        api_response=$(download_file "https://api.github.com/repos/liquibase/liquibase/releases/tags/v$version" 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            log_error "OSS version $version not found in GitHub releases"
            return 1
        fi
    elif [ "$edition" = "secure" ]; then
        # For secure editions, we'll trust the version format is correct
        # since we can't easily check repo.liquibase.com without authentication
        log_verbose "Assuming secure version $version exists (cannot validate without auth)"
    fi
    
    log_verbose "Version $version validated successfully"
    return 0
}

# Install Liquibase via direct download
install_liquibase() {
    local version="$1"
    local edition="$2"
    
    log_info "Installing Liquibase $edition $version via direct download..."
    
    # Get download URL and filename
    local download_url
    local archive_name
    download_url=$(get_download_url "$version" "$edition")
    archive_name=$(get_archive_filename "$version" "$edition")
    
    if [ -z "$download_url" ] || [ -z "$archive_name" ]; then
        log_error "Failed to determine download URL or filename"
        return 1
    fi
    
    log_verbose "Download URL: $download_url"
    log_verbose "Archive name: $archive_name"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would download: $download_url"
        log_info "[DRY RUN] Would extract to: /usr/local (or ~/.local)"
        return 0
    fi
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    local archive_path="$temp_dir/$archive_name"
    
    # Download the archive
    log_info "Downloading $archive_name..."
    download_and_verify "$download_url" "$archive_name" "" "$archive_path"
    
    if [ $? -ne 0 ]; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Determine installation directory
    local install_dir
    if [ -w "/usr/local/bin" ] || [ "$(id -u)" -eq 0 ]; then
        install_dir="/usr/local"
    else
        install_dir="$HOME/.local"
        mkdir -p "$install_dir/bin"
    fi
    
    log_info "Installing to $install_dir..."
    
    # Extract the archive
    local extract_dir="$temp_dir/extract"
    mkdir -p "$extract_dir"
    
    tar -xzf "$archive_path" -C "$extract_dir"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to extract $archive_name"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find the extracted directory
    local liquibase_dir
    liquibase_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "*liquibase*" | head -1)
    
    if [ -z "$liquibase_dir" ] || [ ! -d "$liquibase_dir" ]; then
        log_error "Failed to find extracted Liquibase directory"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Install Liquibase
    local target_dir="$install_dir/lib/liquibase"
    
    # Remove existing installation
    if [ -d "$target_dir" ]; then
        log_verbose "Removing existing installation at $target_dir"
        rm -rf "$target_dir"
    fi
    
    # Copy Liquibase
    mkdir -p "$(dirname "$target_dir")"
    cp -r "$liquibase_dir" "$target_dir"
    
    # Create symlink in bin directory
    local bin_link="$install_dir/bin/liquibase"
    if [ -L "$bin_link" ] || [ -f "$bin_link" ]; then
        rm -f "$bin_link"
    fi
    
    ln -s "$target_dir/liquibase" "$bin_link"
    chmod +x "$bin_link"
    
    # Clean up
    rm -rf "$temp_dir"
    
    log_success "Liquibase $edition $version installed to $target_dir"
    
    # Add to PATH if necessary
    if ! echo "$PATH" | grep -q "$install_dir/bin"; then
        add_to_path "$install_dir/bin"
    fi
    
    return 0
}

# Download and verify file
download_and_verify() {
    local url="$1"
    local filename="$2"
    local expected_checksum="$3"
    local output_path="$4"
    
    log_verbose "Downloading $filename..."
    download_file "$url" "$output_path"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download $filename"
        return 1
    fi
    
    if [ -n "$expected_checksum" ]; then
        log_verbose "Verifying checksum..."
        local actual_checksum
        
        if command -v sha256sum >/dev/null 2>&1; then
            actual_checksum=$(sha256sum "$output_path" | cut -d' ' -f1)
        elif command -v shasum >/dev/null 2>&1; then
            actual_checksum=$(shasum -a 256 "$output_path" | cut -d' ' -f1)
        else
            log_warn "No SHA256 tool available, skipping checksum verification"
            return 0
        fi
        
        if [ "$actual_checksum" != "$expected_checksum" ]; then
            log_error "Checksum verification failed"
            log_error "Expected: $expected_checksum"
            log_error "Actual: $actual_checksum"
            rm -f "$output_path"
            return 1
        fi
        
        log_verbose "Checksum verified successfully"
    else
        log_warn "No checksum provided, skipping verification"
    fi
    
    return 0
}

# Legacy function removed - now using install_liquibase()
add_to_path() {
    local dir="$1"
    
    log_info "Adding $dir to PATH..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would add $dir to PATH in shell profile"
        return 0
    fi
    
    # Determine which shell profile to update
    local shell_profile=""
    if [ -n "$BASH_VERSION" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            shell_profile="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            shell_profile="$HOME/.bash_profile"
        fi
    elif [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -f "$HOME/.profile" ]; then
        shell_profile="$HOME/.profile"
    fi
    
    if [ -n "$shell_profile" ]; then
        log_verbose "Updating $shell_profile"
        
        # Check if PATH export already exists
        if ! grep -q "export PATH.*$dir" "$shell_profile" 2>/dev/null; then
            echo "" >> "$shell_profile"
            echo "# Added by Liquibase installer" >> "$shell_profile"
            echo "export PATH=\"$dir:\$PATH\"" >> "$shell_profile"
            log_info "Added $dir to PATH in $shell_profile"
            log_info "Run 'source $shell_profile' or start a new terminal session"
        else
            log_verbose "PATH already contains $dir in $shell_profile"
        fi
    else
        log_warn "Could not determine shell profile to update"
        log_info "Please manually add $dir to your PATH"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "[DRY RUN] Would verify installation with: liquibase --version"
        return 0
    fi
    
    if command -v liquibase >/dev/null 2>&1; then
        local installed_version
        installed_version=$(liquibase --version 2>/dev/null | head -1)
        log_success "Liquibase installed successfully!"
        log_success "Version: $installed_version"
        return 0
    else
        log_error "Liquibase command not found in PATH"
        log_error "You may need to restart your terminal or run 'source ~/.bashrc'"
        return 1
    fi
}

# Main installation logic
main() {
    log_info "Liquibase Universal Installer"
    log_info "=============================="
    
    # Parse arguments (if any were passed to the script directly)
    parse_args "$@"
    
    # Set default version and edition
    if [ -z "$VERSION_ARG" ]; then
        VERSION_ARG="latest"
    fi
    
    if [ -z "$EDITION_ARG" ]; then
        EDITION_ARG="oss"
    fi
    
    log_verbose "Version argument: $VERSION_ARG"
    log_verbose "Edition argument: $EDITION_ARG"
    log_verbose "Verbose: $VERBOSE"
    log_verbose "Dry run: $DRY_RUN"
    
    # Check dependencies
    check_dependencies
    
    # Detect platform
    detect_platform
    
    # Determine version to install
    if [ "$VERSION_ARG" = "latest" ]; then
        VERSION=$(get_latest_version)
        if [ $? -ne 0 ] || [ -z "$VERSION" ]; then
            exit 1
        fi
    else
        VERSION="$VERSION_ARG"
        validate_version "$VERSION"
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        validate_version_exists "$VERSION" "$EDITION_ARG"
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
    
    log_info "Installing Liquibase $EDITION_ARG $VERSION"
    
    # Install Liquibase via direct download
    if ! install_liquibase "$VERSION" "$EDITION_ARG"; then
        log_error "Installation failed"
        exit 1
    fi
    
    # Verify installation
    verify_installation
    
    if [ $? -eq 0 ] && [ "$DRY_RUN" = "false" ]; then
        echo ""
        log_success "🎉 Liquibase installation completed successfully!"
        echo ""
        log_info "Next steps:"
        log_info "  1. Restart your terminal or run 'source ~/.bashrc'"
        log_info "  2. Run 'liquibase --version' to verify installation"
        log_info "  3. Visit https://docs.liquibase.com/start/home.html to get started"
        echo ""
    fi
}

# Run main function
main "$@"