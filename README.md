# 🚀 Liquibase Universal Installer

A smart, universal installer script for [Liquibase](https://www.liquibase.com/) that automatically installs Liquibase OSS or Secure editions via native tar.gz downloads.

## ⚡ Quick Start

Install Liquibase with a single command:

```bash
curl -fsSL https://get.liquibase.com | bash
```

## ✨ Features

- 🏢 **Dual Edition Support**: Install Liquibase OSS or Secure editions
- 🔍 **Smart Detection**: Automatically detects your OS and architecture  
- 📥 **Native Installation**: Direct tar.gz downloads and extraction
- 🔒 **Secure**: HTTPS downloads with SHA256 verification
- 🎯 **Version Flexible**: Install latest or specific versions
- 🔄 **Cross-Platform**: Works on Linux, macOS, and Windows (via WSL/Git Bash)
- 🧪 **Testing**: Built-in dry-run mode for testing

## 📖 Usage

### 🎯 Basic Installation

```bash
# Install latest OSS version (default)
curl -fsSL https://get.liquibase.com | bash

# Install latest Secure version
curl -fsSL https://get.liquibase.com | bash -s latest secure

# Local testing
curl -fsSL https://raw.githubusercontent.com/jandroav/liquibase-installer-script/refs/heads/main/install.sh | bash

# Or using wget
wget -qO- https://get.liquibase.com | bash
```

### 🏷️ Version Selection

```bash
# Install latest OSS (default)
curl -fsSL https://get.liquibase.com | bash

# Install latest OSS explicitly  
curl -fsSL https://get.liquibase.com | bash -s latest oss

# Install specific OSS version
curl -fsSL https://get.liquibase.com | bash -s 4.33.0 oss

# Install specific Secure version (5.0.0+)
curl -fsSL https://get.liquibase.com | bash -s 5.0.0 secure

# Install Pro version (4.32.0-4.33.0)
curl -fsSL https://get.liquibase.com | bash -s 4.33.0 secure
```

### ⚙️ Options

```bash
# Verbose output
curl -fsSL https://get.liquibase.com | VERBOSE=true bash

# Dry run (see what would be installed)
curl -fsSL https://get.liquibase.com | DRY_RUN=true bash -s latest secure

# Combine options
curl -fsSL https://get.liquibase.com | VERBOSE=true DRY_RUN=true bash -s 5.0.0 secure
```

### 💻 Local Usage

If you have the script locally:

```bash
# Make executable
chmod +x install.sh

# Install latest OSS
./install.sh

# Install latest Secure
./install.sh latest secure

# With options
./install.sh --verbose --dry-run 5.0.0 secure

# Environment variables
VERBOSE=true DRY_RUN=true ./install.sh 4.33.0 oss
```

## 📦 Installation Methods

The installer uses **native tar.gz downloads** for all installations:

### 🏢 Edition Support

#### **Liquibase OSS (Open Source)**
- **Source**: GitHub Releases
- **URL Pattern**: `https://github.com/liquibase/liquibase/releases/download/vX.Y.Z/liquibase-X.Y.Z.tar.gz`
- **Versions**: All available versions
- **Default**: Installed when no edition specified

#### **Liquibase Secure/Pro**  
- **Source**: Liquibase Repository (`repo.liquibase.com`)
- **Pro Versions (4.32.0-4.33.0)**:
  - URL: `https://repo.liquibase.com/releases/pro/X.Y.Z/liquibase-pro-X.Y.Z.tar.gz`
- **Secure Versions (5.0.0+)**:
  - URL: `https://repo.liquibase.com/releases/secure/X.Y.Z/liquibase-secure-X.Y.Z.tar.gz`

### 📥 Installation Process

1. **Download**: Fetches appropriate tar.gz archive via HTTPS
2. **Verify**: SHA256 checksum verification (when available)
3. **Extract**: Extracts to `/usr/local/lib/liquibase` (or `~/.local/lib/liquibase`)
4. **Link**: Creates symlink in `/usr/local/bin/liquibase` (or `~/.local/bin/liquibase`)
5. **Configure**: Adds to PATH and updates shell profiles
6. **Verify**: Tests installation with `liquibase --version`

### 🎯 Edition Selection Guide

| Use Case | Recommended Edition | Command |
|----------|-------------------|---------|
| **Open Source Projects** | OSS | `curl -fsSL https://get.liquibase.com \| bash` |
| **Enterprise/Commercial** | Secure (5.0.0+) | `curl -fsSL https://get.liquibase.com \| bash -s latest secure` |
| **Legacy Pro (4.32.0-4.33.0)** | Pro | `curl -fsSL https://get.liquibase.com \| bash -s 4.33.0 secure` |
| **Specific OSS Version** | OSS | `curl -fsSL https://get.liquibase.com \| bash -s 4.33.0 oss` |

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
| `X.Y.Z` | Specific version | `./install.sh 4.33.0 oss` |

### 🏢 Edition Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `oss` | Liquibase Open Source (default) | `./install.sh latest oss` |
| `secure` | Liquibase Secure (5.0.0+) or Pro (4.32.0-4.33.0) | `./install.sh 5.0.0 secure` |

## 🛠️ Examples

### 🧪 Development & Testing

```bash
# Test OSS installation without actually installing
./install.sh --dry-run --verbose latest oss

# Test Secure installation with verbose output
VERBOSE=true ./install.sh --dry-run latest secure

# Test specific OSS version
./install.sh --dry-run 4.33.0 oss

# Test specific Secure version
./install.sh --dry-run 5.0.0 secure
```

### 🚀 Production Deployment

```bash
# Silent OSS installation for automation
curl -fsSL https://get.liquibase.com | bash

# Install specific OSS version in CI/CD
curl -fsSL https://get.liquibase.com | bash -s 4.33.0 oss

# Install Secure version in CI/CD
curl -fsSL https://get.liquibase.com | bash -s 5.0.0 secure

# Install with error handling
if curl -fsSL https://get.liquibase.com | bash -s latest secure; then
    echo "Liquibase Secure installed successfully"
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

# Test OSS version detection  
VERBOSE=true ./install.sh --dry-run latest oss

# Test Secure version detection
VERBOSE=true ./install.sh --dry-run latest secure

# Test specific versions
./install.sh --dry-run 4.33.0 oss
./install.sh --dry-run 5.0.0 secure

# Test error handling
./install.sh invalid.version
./install.sh 4.33.0 invalid.edition
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