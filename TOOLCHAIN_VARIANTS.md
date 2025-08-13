# ARM64 Cross-Compilation Toolchains

This project now supports building two ARM64 cross-compilation toolchain variants:

## Available Toolchains

### 1. aarch64 Native Toolchain
- **Target:** `aarch64-nextui-linux-gnu`
- **Host:** `arm64`
- **Build script:** `build-toolchain.sh`
- **Config file:** `aarch64.config`
- **Output:** `aarch64-nextui-toolchain.tar.gz`

### 2. x86_64 Host Cross Toolchain  
- **Target:** `aarch64-nextui-linux-gnu`
- **Host:** `x86_64`
- **Build script:** `build-x86_64-toolchain.sh`
- **Config file:** `x86_64-aarch64.config`
- **Output:** `x86_64-aarch64-nextui-toolchain.tar.gz`

## Quick Start

```bash
# Build all toolchains
./build-all-toolchains.sh

# Build specific toolchain
./build-all-toolchains.sh --arm64     # arm64 host
./build-all-toolchains.sh --x86_64    # x86_64 host

# Build in parallel (experimental)
./build-all-toolchains.sh --all --parallel
```

## Individual Builds

```bash
# arm64 toolchain
./build-toolchain.sh

# x86_64 toolchain  
./build-x86_64-toolchain.sh
```

## GitHub Actions

The workflow now supports building both toolchains using a matrix strategy with **architecture-optimized runners**:

- **ARM64 builds:** Run on native ARM64 runners (`ubuntu-24.04-arm64`)
- **x86_64 builds:** Run on standard x86_64 runners (`ubuntu-24.04`)
- **Manual trigger:** Choose which toolchain(s) to build via workflow dispatch
- **Automatic builds:** Both toolchains are built on push/PR to main/develop
- **Parallel verification:** Each toolchain is verified independently on appropriate runners
- **Architecture-specific caching:** Separate caches for ARM64 and x86_64 runners

### Workflow Features

- **Native compilation:** ARM64 toolchain builds natively on ARM64 hardware
- **Matrix builds:** Both toolchains build in parallel on optimal hardware
- **Conditional execution:** Skip builds based on workflow input
- **Comprehensive verification:** Basic and extended tests for both variants
- **Separate artifacts:** Each toolchain produces its own artifacts
- **Enhanced logging:** Variant-specific logs and runner architecture information
- **Optimized caching:** Architecture-aware cache keys for better performance

## Key Differences

| Feature | NextUI Toolchain | x86_64 Toolchain |
|---------|------------------|-------------------|
| Prefix | `/opt/aarch64-nextui-linux-gnu` | `/opt/x86_64-aarch64-nextui-linux-gnu` |
| Target Triple | `aarch64-nextui-linux-gnu` | `aarch64-nextui-linux-gnu` |
| Vendor | `nextui` | `nextui` |
| GCC Binary | `aarch64-nextui-linux-gnu-gcc` | `aarch64-nextui-linux-gnu-gcc` |

## Repository Structure

```
toolchain_ng/
├── .github/workflows/
│   └── build-toolchain.yml           # Enhanced multi-variant workflow
├── build-all-toolchains.sh           # Master build script
├── build-toolchain.sh                # arm64 host toolchain build  
├── build-x86_64-toolchain.sh         # x86_64 host toolchain build
├── aarch64.config                    # arm64 host crosstool-NG config
├── x86_64-aarch64.config             # x86_64 host crosstool-NG config
├── Dockerfile.ct-ng                  # Docker build environment
├── deploy-toolchain.sh               # Deployment script
├── TOOLCHAIN_VARIANTS.md             # This documentation
└── README.md                         # Main documentation
```

## Usage Examples

### arm64 Toolchain
```bash
# Extract and use
tar -xzf aarch64-nextui-toolchain.tar.gz
export PATH="/opt/aarch64-nextui-linux-gnu/bin:$PATH"
aarch64-nextui-linux-gnu-gcc --version
```

### x86_64 Toolchain
```bash
# Extract and use
tar -xzf x86_64-aarch64-nextui-toolchain.tar.gz  
export PATH="/opt/x86_64-aarch64-nextui-linux-gnu/bin:$PATH"
aarch64-nextui-linux-gnu-gcc --version
```

## Cross-Platform Building

### Building x86_64 Toolchain on ARM64 Hosts

The x86_64 toolchain build script automatically handles cross-platform compilation:

#### **Automatic Platform Detection**
- **ARM64 hosts:** Uses Docker emulation (`--platform linux/amd64`) to ensure true x86_64 binaries
- **x86_64 hosts:** Builds natively without emulation overhead
- **Platform verification:** Shows host vs. container architecture during build

#### **Docker Requirements**
```bash
# Required: Docker with BuildKit support
docker buildx version  # Must be available

# The script automatically:
# 1. Forces linux/amd64 platform for containers
# 2. Warns about emulation overhead on ARM64 hosts  
# 3. Verifies container architecture during build
```

#### **Performance Considerations**
- **ARM64 → x86_64:** Slower due to emulation, but produces true x86_64 binaries
- **x86_64 → x86_64:** Native speed, optimal performance
- **Build time:** Expect 2-3x longer on ARM64 hosts due to emulation

#### **Output Verification**
The resulting toolchain will always be true x86_64 binaries regardless of host:
```bash
# Check the actual binary architecture
file /opt/x86_64-aarch64-nextui-linux-gnu/bin/aarch64-nextui-linux-gnu-gcc
# Output: ELF 64-bit LSB executable, x86-64, version 1 (SYSV)...
```

## Implementation Details

### Performance Benefits

#### Native ARM64 Compilation
- **Faster build times:** Native ARM64 runners eliminate cross-compilation overhead  
- **Better resource utilization:** Direct access to ARM64 instruction set
- **Reduced complexity:** No emulation or translation layers required
- **Authentic testing:** Verification runs on actual target architecture

#### Architecture-Specific Optimizations
- **Dedicated caching:** Separate cache keys prevent architecture conflicts
- **Runner selection:** Automatic selection of optimal hardware for each variant
- **Parallel execution:** Both toolchains build simultaneously on their native platforms
- **Compressed artifacts:** XZ compression for smaller downloads
- **Comprehensive checksums:** Multiple hash algorithms for verification

Both toolchains include the same core components (GCC 8.3.0, glibc 2.28, binutils 2.31.1, GDB 8.2.1) with variant-specific naming and optimization settings.
