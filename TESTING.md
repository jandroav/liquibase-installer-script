# 🧪 Liquibase Installer Testing Suite

A comprehensive Docker-based testing environment that validates the Liquibase installer across multiple operating systems and architectures.

## 🚀 Quick Start

```bash
# Run quick tests on popular distributions
./run-tests.sh --quick

# Run full test suite
./run-tests.sh --full --coordinator --clean

# Test specific OS family
./run-tests.sh ubuntu
```

## 📦 Test Environment

The test suite includes **16 different operating systems** across multiple architectures:

### 🐧 Linux Distributions

| Distribution | Versions | Package Manager | Notes |
|-------------|----------|-----------------|-------|
| **Ubuntu** | 20.04, 22.04, 24.04 | APT | Most popular Linux distribution |
| **Debian** | 11, 12 | APT | Stable enterprise choice |
| **CentOS** | 7 | YUM | Legacy RHEL-compatible |
| **Rocky Linux** | 8, 9 | YUM/DNF | Modern RHEL alternative |
| **Fedora** | 38, 39 | DNF | Cutting-edge RPM-based |
| **Alpine** | 3.18, 3.19 | APK | Minimal musl-based |
| **Amazon Linux** | 2, 2023 | YUM | AWS-optimized |
| **Arch Linux** | Latest | Pacman | Rolling release |
| **openSUSE Leap** | 15.5 | Zypper | Enterprise SUSE |

### 🏗️ Architecture Support

- **x64**: All distributions (default)
- **ARM64**: Ubuntu 22.04, Alpine 3.19 (with `--arm64` flag)

## 🎯 Test Coverage

Each container runs comprehensive tests:

### ✅ **Core Functionality Tests**
- **Help Command**: `./install.sh --help`
- **Platform Detection**: OS and architecture identification
- **Dependency Detection**: curl/wget, jq availability
- **Version Detection**: Latest OSS version from GitHub API

### 🏢 **Edition-Specific Tests**
- **OSS Edition**: GitHub releases URL validation
- **Secure Edition**: 
  - Pro versions (4.32.0-4.33.0): `repo.liquibase.com/releases/pro/`
  - Secure versions (5.0.0+): `repo.liquibase.com/releases/secure/`

### 🛡️ **Error Handling Tests**
- Invalid version formats
- Invalid edition parameters
- Network failure scenarios

### 🏃 **Installation Tests**
- **Dry Run**: Validates URLs and paths without installing
- **Actual Installation**: Full OSS installation with verification
- **PATH Configuration**: Ensures `liquibase` command is available
- **Version Verification**: Confirms working installation

## 📋 Test Commands

### Basic Usage

```bash
# Quick test (6 popular distributions)
./run-tests.sh --quick

# Full test suite (all 16 distributions)
./run-tests.sh --full

# Test specific OS families
./run-tests.sh ubuntu    # Ubuntu variants only
./run-tests.sh debian    # Debian variants only  
./run-tests.sh rhel      # RHEL-like (CentOS, Rocky, Fedora)
./run-tests.sh alpine    # Alpine variants only
```

### Advanced Options

```bash
# Include ARM64 architecture tests
./run-tests.sh --arm64

# Run with coordinator for summary report
./run-tests.sh --coordinator

# Clean up containers after tests
./run-tests.sh --clean

# Combine options
./run-tests.sh --full --arm64 --coordinator --clean
```

### Manual Container Testing

```bash
# Test specific container manually
docker-compose -f docker-compose.test.yml run ubuntu-22-04

# Run specific services
docker-compose -f docker-compose.test.yml up ubuntu-20-04 debian-12 alpine-3-19

# View logs from specific container
docker logs liquibase-test-ubuntu-22-04
```

## 📊 Test Results

### Success Criteria
- ✅ All core functionality tests pass
- ✅ Platform detection works correctly  
- ✅ OSS and Secure URL generation is accurate
- ✅ Error handling behaves as expected
- ✅ Actual installation completes successfully
- ✅ `liquibase --version` command works after installation

### Sample Output

```bash
=========================================
LIQUIBASE INSTALLER TEST SUITE
OS: ubuntu-22.04
Date: Mon Dec 25 10:30:00 UTC 2023
=========================================

[INFO] System Information:
[INFO]   OS: Linux
[INFO]   Architecture: x86_64
[INFO]   Kernel: 5.15.0

[INFO] Running test_help...
[SUCCESS] Help command works

[INFO] Running test_platform_detection...
[SUCCESS] Platform detection works

[INFO] Running test_oss_version_detection...
[SUCCESS] OSS version detection works

[INFO] Running test_secure_version_handling...
[SUCCESS] Pro version URL (4.33.0) correct
[SUCCESS] Secure version URL (5.0.0) correct

[INFO] Running test_actual_installation...
[SUCCESS] OSS installation completed
[SUCCESS] Liquibase installed and working: Liquibase Version: 4.33.0

=========================================
TEST SUMMARY FOR ubuntu-22.04
=========================================
Total Tests: 7
Passed: 7
Failed: 0
RESULT: PASS
```

## 🐳 Container Architecture

### File Structure
```
liquibase-installer-script/
├── docker-compose.test.yml    # Main test configuration
├── test-runner.sh             # Runs inside each container
├── test-coordinator.sh        # Coordinates results
├── run-tests.sh              # Convenient test launcher
├── install.sh                # The installer being tested
└── TESTING.md                # This documentation
```

### Container Workflow
1. **Setup**: Install OS-specific dependencies (curl, wget, tar, etc.)
2. **Test Execution**: Run comprehensive test suite
3. **Result Collection**: Log all test outcomes
4. **Cleanup**: Report final status

## 🔧 Development & Debugging

### Running Individual Tests

```bash
# Test just the help functionality
docker-compose -f docker-compose.test.yml run ubuntu-22-04 bash -c "
    apt-get update && apt-get install -y curl &&
    bash /test/install.sh --help
"

# Test version detection manually
docker-compose -f docker-compose.test.yml run alpine-3-19 bash -c "
    apk add curl bash &&
    DRY_RUN=true VERBOSE=true bash /test/install.sh latest oss
"
```

### Debugging Failed Tests

```bash
# Get detailed logs from failed container
docker logs liquibase-test-centos-7

# Run container interactively
docker-compose -f docker-compose.test.yml run centos-7 bash

# Check container status
docker ps -a | grep liquibase-test
```

### Adding New Test Distributions

1. Add service to `docker-compose.test.yml`
2. Update OS detection in `test-runner.sh`
3. Add to service list in `run-tests.sh`

## 🎯 Test Scenarios Covered

### URL Generation Tests
- ✅ **OSS**: `https://github.com/liquibase/liquibase/releases/download/v4.33.0/liquibase-4.33.0.tar.gz`
- ✅ **Pro 4.33.0**: `https://repo.liquibase.com/releases/pro/4.33.0/liquibase-pro-4.33.0.tar.gz`  
- ✅ **Secure 5.0.0**: `https://repo.liquibase.com/releases/secure/5.0.0/liquibase-secure-5.0.0.tar.gz`

### Installation Paths
- ✅ **System-wide**: `/usr/local/lib/liquibase` → `/usr/local/bin/liquibase`
- ✅ **User-local**: `~/.local/lib/liquibase` → `~/.local/bin/liquibase`
- ✅ **PATH**: Automatic shell profile updates

### Cross-Platform Compatibility  
- ✅ **glibc**: Ubuntu, Debian, CentOS, Rocky, Fedora, Amazon Linux
- ✅ **musl**: Alpine Linux
- ✅ **Package Managers**: APT, YUM, DNF, APK, Pacman, Zypper
- ✅ **Architectures**: x64, ARM64

## 📈 Performance Metrics

- **Test Duration**: ~3-5 minutes per container
- **Full Suite**: ~15-20 minutes for all 16 distributions
- **Quick Suite**: ~5-8 minutes for 6 popular distributions
- **Resource Usage**: ~100MB RAM per container
- **Disk Usage**: ~50MB per container

## 🛠️ Maintenance

### Regular Updates
- Update base images monthly
- Add new OS versions as they're released
- Test against latest Liquibase releases
- Monitor for dependency changes

### Monitoring
- Watch for upstream OS image updates
- Track Liquibase release patterns
- Monitor GitHub API rate limits
- Check repo.liquibase.com availability

## 🚀 GitHub Actions Integration

The installer includes comprehensive GitHub Actions workflows for automated testing across all platforms.

### 🔄 Automated Testing Triggers

- **Push/Pull Request**: Runs validation and platform tests on `main`/`develop` branches
- **Daily Schedule**: Runs at 2 AM UTC to catch upstream changes
- **Manual Dispatch**: Allows custom test configuration via GitHub UI

### 🎯 Workflow Jobs

#### 1. **Installer Validation** (`validate-installer`)
- ShellCheck linting for script quality
- Syntax validation for all test scripts
- Help functionality test
- Dry run tests for both OSS and Secure editions

#### 2. **Platform Tests** (`test-installer`) 
- Matrix strategy testing multiple suites:
  - Quick Suite (6 popular distributions)
  - Ubuntu Only variants
  - Debian Only variants  
  - Alpine Only variants
- Runs on every push/PR for fast feedback

#### 3. **Full Test Suite** (`test-full-suite`)
- Tests all 16 operating systems
- Only runs on `main` branch or manual trigger
- 30-minute timeout protection
- Comprehensive platform coverage

#### 4. **ARM64 Tests** (`test-arm64`)
- Uses QEMU emulation for ARM64 architecture
- Tests Ubuntu 22.04 ARM64 and Alpine 3.19 ARM64
- Only runs on `main` branch or manual trigger with ARM64 flag
- 45-minute timeout for slower emulated tests

#### 5. **Manual Testing** (`test-manual-target`)
- Configurable test type via GitHub UI:
  - `quick` - Popular distributions only
  - `full` - All 16 distributions  
  - `ubuntu` - Ubuntu variants only
  - `debian` - Debian variants only
  - `rhel` - RHEL-like variants only
  - `alpine` - Alpine variants only
- Optional ARM64 architecture inclusion
- Perfect for targeted testing

### 🎮 Manual Test Execution

#### Via GitHub UI
1. Go to **Actions** → **Test Liquibase Installer**
2. Click **Run workflow**
3. Select test type and ARM64 option
4. Click **Run workflow** button

#### Via GitHub CLI
```bash
# Quick test
gh workflow run test.yml -f test_type=quick

# Full test with ARM64
gh workflow run test.yml -f test_type=full -f include_arm64=true

# Test specific OS family
gh workflow run test.yml -f test_type=ubuntu
```

### 📊 Test Results & Monitoring

#### GitHub Actions Dashboard
- Real-time test execution status
- Detailed logs for each container test
- Test result summaries with pass/fail counts
- Docker resource usage monitoring

#### Test Result Summary
Each workflow run generates a summary showing:
- ✅ **Installer Validation**: Script quality checks
- ✅ **Platform Tests**: Core functionality across OS variants  
- ✅ **Full Test Suite**: Comprehensive 16-OS validation
- 📈 **Coverage**: OSS & Secure editions, platform detection, error handling

### 🔍 Debugging Failed Tests

#### View Detailed Logs
```bash
# Get workflow run details
gh run list --workflow=test.yml --limit=5

# View specific run logs  
gh run view <run_id> --log

# View logs for specific job
gh run view <run_id> --log --job="Test on Ubuntu Only"
```

#### Container-Specific Debugging
- Each container outputs detailed test results
- Failed containers show error logs in workflow output
- Container status and exit codes are reported
- Resource usage and timing information included

### ⚡ Performance & Optimization

#### Resource Management
- Docker BuildKit for faster image builds
- Automatic Docker cleanup between jobs
- QEMU setup only when ARM64 tests are needed
- Timeout protection prevents hanging tests

#### Test Timing
- **Quick Suite**: ~8-12 minutes
- **Platform Tests**: ~5-8 minutes per matrix job
- **Full Suite**: ~25-30 minutes  
- **ARM64 Tests**: ~35-45 minutes (emulation overhead)

### 🛠️ Maintenance & Updates

#### Workflow Maintenance
- Update base Ubuntu runner versions quarterly
- Monitor Docker image updates for test containers
- Update timeout values based on performance metrics
- Add new OS distributions as they become available

#### Integration with Development
- PR validation ensures installer changes don't break existing functionality
- Daily runs catch upstream API changes (GitHub releases, repo.liquibase.com)
- Manual testing enables pre-release validation
- Test results feed into release decision process

---

This testing suite ensures the Liquibase installer works reliably across the vast Linux ecosystem, giving confidence in deployment to any supported platform! 🎉