# 🚀 Liquibase Universal Installer

A smart, universal installer script for [Liquibase](https://www.liquibase.com/) that automatically detects your platform and chooses the most appropriate installation method.

## ⚡ Quick Start

Install Liquibase with a single command:

```bash
curl -fsSL https://get.liquibase.com | bash
```

## ✨ Features

- 🔍 **Smart Detection**: Automatically detects your OS, architecture, and available package managers
- 📦 **Multiple Methods**: Supports Homebrew, APT, YUM, DNF, SDKMAN, Chocolatey, and direct downloads
- 🔒 **Secure**: Verifies SHA256 checksums for direct downloads
- 🎯 **Flexible**: Install latest or specific versions
- 🔄 **Cross-Platform**: Works on Linux, macOS, and Windows (via WSL/Git Bash)
- 🧪 **Testing**: Built-in dry-run mode for testing

## 📖 Usage

### 🎯 Basic Installation

```bash
# Install latest version (default)
curl -fsSL https://get.liquibase.com | bash

# Local testing
curl -fsSL https://raw.githubusercontent.com/jandroav/liquibase-installer-script/refs/heads/main/install.sh | bash

# Or using wget
wget -qO- https://get.liquibase.com | bash
```

### 🏷️ Version Selection

```bash
# Install latest version (default)
curl -fsSL https://get.liquibase.com | bash

# Install latest version explicitly
curl -fsSL https://get.liquibase.com | bash -s latest

# Install specific version
curl -fsSL https://get.liquibase.com | bash -s 4.33.0
```

### ⚙️ Options

```bash
# Verbose output
curl -fsSL https://get.liquibase.com | VERBOSE=true bash

# Dry run (see what would be installed)
curl -fsSL https://get.liquibase.com | DRY_RUN=true bash

# Combine options
curl -fsSL https://get.liquibase.com | VERBOSE=true DRY_RUN=true bash -s 4.33.0
```

### 💻 Local Usage

If you have the script locally:

```bash
# Make executable
chmod +x install.sh

# Basic usage
./install.sh

# With options
./install.sh --verbose --dry-run 4.33.0

# Environment variables
VERBOSE=true DRY_RUN=true ./install.sh latest
```

## 📦 Installation Methods

The installer tries installation methods in this order of preference:

### 1️⃣ Package Managers (Preferred)

- **macOS**: [Homebrew](https://brew.sh/) (`brew install liquibase`)
- **Ubuntu/Debian**: APT (`sudo apt-get install liquibase`)
- **RHEL/CentOS/Fedora**: YUM/DNF (`sudo yum/dnf install liquibase`)
- **Cross-platform**: [SDKMAN](https://sdkman.io/) (`sdk install liquibase`)
- **Windows**: [Chocolatey](https://chocolatey.org/) (`choco install liquibase`)

### 2️⃣ Direct Download (Fallback)

If no package managers are available, the installer downloads the appropriate archive:

- **Linux/macOS**: Downloads `.tar.gz` and extracts to `/usr/local` or `~/.local`
- **Windows**: Downloads `.zip` and extracts to appropriate location

Direct downloads include:
- ✅ SHA256 checksum verification
- ✅ Automatic PATH configuration
- ✅ Shell integration setup

## 📋 Requirements

### ✅ Minimum Requirements

- **curl** or **wget** (for downloading)
- **Bash** 3.0+ (most systems have this)

### 🔧 Optional Dependencies

- **jq** - For faster JSON parsing (falls back to sed if unavailable)
- **sha256sum** or **shasum** - For checksum verification

### 🌐 Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|---------|
| Linux | x64 | ✅ Supported |
| Linux | ARM64 | ✅ Supported |
| macOS | x64 (Intel) | ✅ Supported |
| macOS | ARM64 (Apple Silicon) | ✅ Supported |
| Windows | x64 | ✅ Supported (via WSL/Git Bash) |

## 📚 Command Reference

### 🎛️ Options

| Option | Environment Variable | Description |
|--------|---------------------|-------------|
| `--verbose`, `-v` | `VERBOSE=true` | Enable verbose output |
| `--dry-run` | `DRY_RUN=true` | Show what would be installed without installing |
| `--help`, `-h` | - | Show help message |

### 🏷️ Version Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `latest` | Latest release (default) | `./install.sh latest` |
| `X.Y.Z` | Specific version | `./install.sh 4.33.0` |

## 🛠️ Examples

### 🧪 Development & Testing

```bash
# Test installation without actually installing
./install.sh --dry-run --verbose latest

# Check what package managers are available
VERBOSE=true ./install.sh --dry-run

# Test specific version
./install.sh --dry-run 4.28.0
```

### 🚀 Production Deployment

```bash
# Silent installation for automation
curl -fsSL https://get.liquibase.com | bash

# Install specific version in CI/CD
curl -fsSL https://get.liquibase.com | bash -s 4.33.0

# Install with error handling
if curl -fsSL https://get.liquibase.com | bash; then
    echo "Liquibase installed successfully"
    liquibase --version
else
    echo "Installation failed" >&2
    exit 1
fi
```

## 🔧 Troubleshooting

### ⚠️ Common Issues

#### 💥 Installation Fails

```bash
# Try with verbose output to see details
VERBOSE=true ./install.sh

# Check if dependencies are available
command -v curl || command -v wget
```

#### 🔒 Permission Denied

```bash
# Install to user directory instead of system-wide
# The installer automatically falls back to ~/.local if /usr/local is not writable
```

#### ❓ Command Not Found After Installation

```bash
# Restart terminal or source profile
source ~/.bashrc
# or
source ~/.zshrc

# Or manually add to PATH
export PATH="/usr/local/bin:$PATH"
```

#### 🔐 Checksum Verification Failed

```bash
# Try again (might be a temporary issue)
./install.sh

# Or skip checksum verification (not recommended)
# The installer will warn but continue if sha256sum/shasum is not available
```

### 📞 Getting Help

1. **Check verbose output**: Run with `--verbose` to see detailed execution
2. **Try dry run**: Use `--dry-run` to see what would be installed
3. **Manual installation**: Fall back to [official Liquibase installation](https://www.liquibase.com/download)

### 🐛 Debug Information

To report issues, please include:

```bash
# System information
uname -a

# Available tools
command -v curl wget jq sha256sum shasum

# Installer output with verbose mode
VERBOSE=true ./install.sh --dry-run 2>&1
```

## 🔐 Security

### ✅ Verification

- All downloads use HTTPS
- Direct downloads verify SHA256 checksums
- No arbitrary code execution from user input
- Version strings are validated before use

### 🛡️ Best Practices

```bash
# Always verify the script source before piping to bash
curl -fsSL https://get.liquibase.com | less

# Use specific versions for reproducible deployments
curl -fsSL https://get.liquibase.com | bash -s 4.33.0

# Test with dry-run first
curl -fsSL https://get.liquibase.com | DRY_RUN=true bash
```

## 🔧 Development

### 🧪 Testing the Script

```bash
# Test basic functionality
./install.sh --help

# Test version detection
VERBOSE=true ./install.sh --dry-run

# Test specific version
./install.sh --dry-run 4.33.0

# Test error handling
./install.sh invalid.version
```

### 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly on multiple platforms
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by installation scripts from [Claude Code](https://claude.ai/install.sh)
- Built for the [Liquibase](https://www.liquibase.com/) community
- Follows best practices from similar universal installers