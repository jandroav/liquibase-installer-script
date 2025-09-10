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
    
    # Add GitHub token if available and URL is GitHub API
    local auth_args=()
    if [[ "$url" == *"api.github.com"* ]] && [ -n "$GITHUB_TOKEN" ]; then
        auth_args=(-H "Authorization: token $GITHUB_TOKEN")
        log_verbose "Using GitHub token for API authentication"
    fi
    
    if [ "$DOWNLOADER" = "curl" ]; then
        if [ -n "$output" ]; then
            curl -fsSL "${auth_args[@]}" -o "$output" "$url"
        else
            curl -fsSL "${auth_args[@]}" "$url"
        fi
    elif [ "$DOWNLOADER" = "wget" ]; then
        if [ -n "$output" ]; then
            if [ ${#auth_args[@]} -gt 0 ]; then
                wget --header="Authorization: token $GITHUB_TOKEN" -q -O "$output" "$url"
            else
                wget -q -O "$output" "$url"
            fi
        else
            if [ ${#auth_args[@]} -gt 0 ]; then
                wget --header="Authorization: token $GITHUB_TOKEN" -q -O - "$url"
            else
                wget -q -O - "$url"
            fi
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
    log_verbose "uname -s output: $(uname -s)"
    log_verbose "uname -m output: $(uname -m)"
    
    case "$(uname -s)" in
        Darwin) 
            OS="darwin" 
            log_verbose "Detected macOS"
            ;;
        Linux) 
            OS="linux"
            log_verbose "Detected Linux"
            ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT|*_NT-*|*NT*)
            OS="windows"
            log_verbose "Detected Windows ($(uname -s))"
            ;;
        *) 
            log_error "Unsupported operating system: $(uname -s)"
            log_error "If you're using a Unix-like environment, please report this issue"
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
        i386|i686)
            ARCH="x64"  # Treat 32-bit as x64 since Liquibase is Java-based
            log_verbose "Detected 32-bit architecture, using x64 archives"
            ;;
        *) 
            log_error "Unsupported architecture: $(uname -m)"
            log_error "System details: OS=$(uname -s), ARCH=$(uname -m), KERNEL=$(uname -r)"
            log_error "Please report this issue at: https://github.com/jandroav/liquibase-installer-script/issues"
            # For now, default to x64 for unknown architectures since Liquibase is Java-based
            ARCH="x64"
            log_warn "Defaulting to x64 architecture for Java compatibility"
            ;;
    esac

    PLATFORM="${OS}-${ARCH}"
    log_verbose "Platform: $PLATFORM"
    
    # Note: Liquibase uses universal Java archives, so platform detection
    # is mainly for installation path and shell profile handling
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
    if ! api_response=$(download_file "https://api.github.com/repos/liquibase/liquibase/releases/latest") || [ -z "$api_response" ]; then
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
        if ! api_response=$(download_file "https://api.github.com/repos/liquibase/liquibase/releases/tags/v$version" 2>/dev/null); then
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
    if ! download_and_verify "$download_url" "$archive_name" "" "$archive_path"; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Determine installation directory
    local install_dir
    
    # Check if we can install to system-wide location
    if { [ -w "/usr/local" ] || [ "$(id -u)" -eq 0 ]; } && [ -d "/usr/local" ]; then
        install_dir="/usr/local"
        log_verbose "Installing to system-wide location: $install_dir"
    else
        install_dir="$HOME/.local"
        log_verbose "Installing to user location: $install_dir"
        mkdir -p "$install_dir/bin" "$install_dir/lib"
    fi
    
    log_info "Installing to $install_dir..."
    
    # Extract the archive
    local extract_dir="$temp_dir/extract"
    mkdir -p "$extract_dir"
    
    if ! tar -xzf "$archive_path" -C "$extract_dir"; then
        log_error "Failed to extract $archive_name"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find the extracted directory
    local liquibase_dir
    
    # Try to find directory containing liquibase executable
    liquibase_dir=$(find "$extract_dir" -name "liquibase" -type f | head -1 | xargs dirname 2>/dev/null)
    
    # If that fails, try to find any directory with "liquibase" in the name  
    if [ -z "$liquibase_dir" ] || [ ! -d "$liquibase_dir" ]; then
        liquibase_dir=$(find "$extract_dir" -maxdepth 2 -type d -name "*liquibase*" | head -1)
    fi
    
    # If that fails, try the first subdirectory (skip . and ..)
    if [ -z "$liquibase_dir" ] || [ ! -d "$liquibase_dir" ]; then
        liquibase_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -1)
    fi
    
    # Validate that we found a proper liquibase directory
    if [ -n "$liquibase_dir" ] && [ -d "$liquibase_dir" ]; then
        # Check if this directory contains liquibase files
        if ! ([ -f "$liquibase_dir/liquibase" ] || [ -f "$liquibase_dir/liquibase.bat" ] || ls "$liquibase_dir"/*.jar >/dev/null 2>&1); then
            log_verbose "Directory $liquibase_dir doesn't look like a proper Liquibase installation"
            liquibase_dir=""
        fi
    fi
    
    if [ -z "$liquibase_dir" ] || [ ! -d "$liquibase_dir" ]; then
        log_error "Failed to find extracted Liquibase directory"
        log_error "Contents of extract directory:"
        ls -la "$extract_dir" >&2 || true
        rm -rf "$temp_dir"
        return 1
    fi
    
    log_verbose "Found Liquibase directory: $liquibase_dir"
    
    # Install Liquibase
    local target_dir="$install_dir/lib/liquibase"
    
    # Remove existing installation
    if [ -d "$target_dir" ]; then
        log_verbose "Removing existing installation at $target_dir"
        rm -rf "$target_dir"
    fi
    
    # Copy Liquibase
    if ! mkdir -p "$(dirname "$target_dir")"; then
        log_error "Failed to create directory: $(dirname "$target_dir")"
        log_error "Try running with sudo or install to user directory"
        rm -rf "$temp_dir"
        return 1
    fi
    
    if ! cp -r "$liquibase_dir" "$target_dir"; then
        log_error "Failed to copy Liquibase to $target_dir"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Create symlink in bin directory
    local bin_link="$install_dir/bin/liquibase"
    if [ -L "$bin_link" ] || [ -f "$bin_link" ]; then
        rm -f "$bin_link"
    fi
    
    if ! mkdir -p "$install_dir/bin"; then
        log_error "Failed to create bin directory: $install_dir/bin"
        rm -rf "$temp_dir"
        return 1
    fi
    
    if ! ln -s "$target_dir/liquibase" "$bin_link"; then
        log_error "Failed to create symlink: $bin_link"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Make sure the liquibase executable is executable
    chmod +x "$target_dir/liquibase" 2>/dev/null || true
    chmod +x "$bin_link" 2>/dev/null || true
    
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
    if ! download_file "$url" "$output_path"; then
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
            {
                echo ""
                echo "# Added by Liquibase installer"
                echo "export PATH=\"$dir:\$PATH\""
            } >> "$shell_profile"
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
    
    # First, try to find liquibase in current PATH
    if command -v liquibase >/dev/null 2>&1; then
        local installed_version
        installed_version=$(liquibase --version 2>/dev/null | head -1)
        log_success "Liquibase installed successfully!"
        log_success "Version: $installed_version"
        return 0
    fi
    
    # If not in PATH, check the direct installation locations
    local install_locations=()
    install_locations+=("/usr/local/bin/liquibase")
    install_locations+=("$HOME/.local/bin/liquibase")
    
    log_verbose "Checking installation locations: ${install_locations[*]}"
    
    for location in "${install_locations[@]}"; do
        log_verbose "Checking location: $location"
        if [ -e "$location" ]; then
            log_verbose "Found file at $location, checking if executable"
            if [ -x "$location" ]; then
                log_verbose "File is executable, testing version command"
                local installed_version
                installed_version=$("$location" --version 2>/dev/null | head -1)
                if [ -n "$installed_version" ]; then
                    log_success "Liquibase installed successfully at: $location"
                    log_success "Version: $installed_version"
                    log_info "To use liquibase command globally, restart your terminal or run:"
                    log_info "  export PATH=\"$(dirname "$location"):\$PATH\""
                    return 0
                else
                    log_verbose "Version command failed for $location"
                fi
            else
                log_verbose "File exists but is not executable: $location"
            fi
        else
            log_verbose "No file found at: $location"
        fi
    done
    
    log_error "Liquibase installation verification failed"
    log_error "Could not find liquibase executable in expected locations"
    return 1
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
        if ! VERSION=$(get_latest_version) || [ -z "$VERSION" ]; then
            exit 1
        fi
    else
        VERSION="$VERSION_ARG"
        if ! validate_version "$VERSION"; then
            exit 1
        fi
        
        if ! validate_version_exists "$VERSION" "$EDITION_ARG"; then
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
    if verify_installation && [ "$DRY_RUN" = "false" ]; then
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