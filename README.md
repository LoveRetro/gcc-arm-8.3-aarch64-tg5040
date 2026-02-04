# NextUI ARM64 Cross-Compilation Toolchain

A simplified, production-ready GCC 8.3.0 cross-compilation toolchain for ARM64/AArch64 development built with crosstool-NG.

## Quick Start

```bash
# Build the complete toolchain
./build-toolchain.sh

# The script will:
# 1. Build Docker container with crosstool-NG
# 2. Compile GCC 8.3.0 toolchain directly to /opt/aarch64-nextui-linux-gnu
# 3. Extract complete toolchain with all headers and libraries
# 4. Create deployment-ready tarball (390MB)
```

## Built Components

### Target Architecture:
- **Platform:** ARM64 (aarch64)
- **Processor:** ARM Cortex-A53 optimized
- **ABI:** aarch64-nextui-linux-gnu

### Components:
- **GCC 8.3.0** - C/C++ compiler with full language support
- **glibc 2.28** - Complete C standard library
- **binutils 2.31.1** - Assembler, linker, and binary utilities
- **GDB 8.2.1** - Cross-debugger
- **Complete sysroot** - All headers and target libraries

## Usage with Docker

The toolchain is designed to work in Docker containers:
```bash
# Extract toolchain
tar -xzf aarch64-nextui-toolchain.tar.gz

# Compile in Linux container
docker run --rm -v "$PWD:/workspace" -v "$PWD/aarch64-nextui-linux-gnu:/opt/toolchain" \
    debian:bullseye-slim bash -c "/opt/toolchain/bin/aarch64-nextui-linux-gnu-gcc -o hello hello.c"

# Test ARM64 binary
docker run --rm -v "$PWD:/workspace" --platform linux/arm64 ubuntu:20.04 \
    bash -c "cd /workspace && ./hello"
```

## Verification

Our toolchain has been tested and verified:
- C compilation: Successfully cross-compiles C programs
- C++ compilation: Full STL support with iostream, vector, string
- ARM64 execution: Binaries run correctly on ARM64 platforms
- Complete sysroot: All system headers and libraries included
- All tools present: 33 cross-compilation utilities available

## Output

- **Package**: `aarch64-nextui-toolchain.tar.gz` (390MB)
- **Build time**: ~16 minutes
- **Tools**: 33 cross-compilation utilities
- **Documentation**: `TOOLCHAIN-README.md` with usage examples

## Building from Source

```bash
git clone <repo>
cd toolchain_ng
./build-toolchain.sh
```

The build process is fully automated and creates a ready-to-deploy toolchain package.

## Repository Structure

```
toolchain_ng/
├── build-toolchain.sh      # Main build script
├── aarch64.config                 # crosstool-NG configuration
├── Dockerfile.ct-ng               # Docker build environment
├── TOOLCHAIN-README.md            # Usage guide for built toolchain
├── aarch64-nextui-toolchain.tar.gz # Ready-to-deploy package
└── README.md                      # This file
```

## Technical Details

- **crosstool-NG Version**: 1.25.0
- **Host Requirements**: Linux/macOS with Docker, >20GB free space
- **Build Environment**: Debian bullseye-slim container
- **Static Prefix**: `/opt/aarch64-nextui-linux-gnu`
- **Target**: aarch64-nextui-linux-gnu (ARM Cortex-A53)

## License

This project builds upon:
- **GCC** - GNU General Public License
- **glibc** - GNU Lesser General Public License  
- **binutils** - GNU General Public License
- **crosstool-NG** - GNU General Public License


See individual component licenses for details.

---

Ready for production use in containerized ARM64 cross-compilation environments.
