#!/bin/bash

# Master build script for multiple ARM64 toolchain variants
# Supports building both NextUI custom and standard x86_64 host toolchains

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build ARM64 cross-compilation toolchains

OPTIONS:
    -n, --arm64          Build arm64 host toolchain (aarch64-nextui-linux-gnu)
    -x, --x86_64         Build x86_64 host toolchain (x86_64-aarch64-nextui-linux-gnu)
    -a, --all            Build all toolchains (default)
    -p, --parallel       Build toolchains in parallel (experimental)
    -h, --help           Show this help message

EXAMPLES:
    $0                   # Build all toolchains sequentially
    $0 --arm64           # Build only arm64 toolchain
    $0 --x86_64          # Build only x86_64 toolchain
    $0 --all --parallel  # Build all toolchains in parallel

OUTPUT:
    - aarch64-nextui-toolchain.tar.gz           (arm64 host toolchain)
    - x86_64-aarch64-nextui-toolchain.tar.gz    (x86_64 host toolchain)

EOF
}

build_nextui_toolchain() {
    log_info "Building NextUI custom toolchain..."
    
    if [ -f "${SCRIPT_DIR}/build-toolchain.sh" ]; then
        "${SCRIPT_DIR}/build-toolchain.sh"
        log_success "NextUI toolchain build completed"
    else
        log_error "NextUI build script not found: build-toolchain.sh"
        return 1
    fi
}

build_x86_64_toolchain() {
    log_info "Building x86_64 host toolchain..."
    
    if [ -f "${SCRIPT_DIR}/build-x86_64-toolchain.sh" ]; then
        "${SCRIPT_DIR}/build-x86_64-toolchain.sh"
        log_success "x86_64 toolchain build completed"
    else
        log_error "x86_64 build script not found: build-x86_64-toolchain.sh"
        return 1
    fi
}

build_parallel() {
    log_info "Starting parallel toolchain builds..."
    
    # Start both builds in background
    log_info "Starting NextUI toolchain build in background..."
    build_nextui_toolchain &
    local nextui_pid=$!
    
    log_info "Starting x86_64 toolchain build in background..."
    build_x86_64_toolchain &
    local x86_64_pid=$!
    
    # Wait for both to complete
    local nextui_status=0
    local x86_64_status=0
    
    log_info "Waiting for NextUI build (PID: $nextui_pid)..."
    wait $nextui_pid || nextui_status=$?
    
    log_info "Waiting for x86_64 build (PID: $x86_64_pid)..."
    wait $x86_64_pid || x86_64_status=$?
    
    # Report results
    if [ $nextui_status -eq 0 ]; then
        log_success "NextUI toolchain build completed successfully"
    else
        log_error "NextUI toolchain build failed with status: $nextui_status"
    fi
    
    if [ $x86_64_status -eq 0 ]; then
        log_success "x86_64 toolchain build completed successfully"
    else
        log_error "x86_64 toolchain build failed with status: $x86_64_status"
    fi
    
    # Return combined status
    return $((nextui_status + x86_64_status))
}

build_sequential() {
    log_info "Starting sequential toolchain builds..."
    
    local status=0
    
    if $BUILD_ARM64; then
        build_nextui_toolchain || status=$?
    fi
    
    if $BUILD_X86_64; then
        build_x86_64_toolchain || ((status += $?))
    fi
    
    return $status
}

verify_outputs() {
    log_info "Verifying build outputs..."
    
    local all_good=true
    
    if $BUILD_ARM64; then
        if [ -f "${SCRIPT_DIR}/aarch64-nextui-toolchain.tar.gz" ]; then
            local size=$(ls -lh "${SCRIPT_DIR}/aarch64-nextui-toolchain.tar.gz" | awk '{print $5}')
            log_success "NextUI toolchain package found (${size})"
        else
            log_error "NextUI toolchain package not found"
            all_good=false
        fi
    fi
    
    if $BUILD_X86_64; then
        if [ -f "${SCRIPT_DIR}/x86_64-aarch64-nextui-toolchain.tar.gz" ]; then
            local size=$(ls -lh "${SCRIPT_DIR}/x86_64-aarch64-nextui-toolchain.tar.gz" | awk '{print $5}')
            log_success "x86_64 toolchain package found (${size})"
        else
            log_error "x86_64 toolchain package not found"
            all_good=false
        fi
    fi
    
    if $all_good; then
        log_success "All requested toolchain packages created successfully"
        return 0
    else
        log_error "Some toolchain packages are missing"
        return 1
    fi
}

# Parse command line arguments
BUILD_ARM64=false
BUILD_X86_64=false
BUILD_PARALLEL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--arm64)
            BUILD_ARM64=true
            shift
            ;;
        -x|--x86_64)
            BUILD_X86_64=true
            shift
            ;;
        -a|--all)
            BUILD_ARM64=true
            BUILD_X86_64=true
            shift
            ;;
        -p|--parallel)
            BUILD_PARALLEL=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Default to building all if no specific options given
if ! $BUILD_ARM64 && ! $BUILD_X86_64; then
    BUILD_ARM64=true
    BUILD_X86_64=true
fi

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_info "Starting ARM64 toolchain builds..."
    log_info "Build arm64: $BUILD_ARM64"
    log_info "Build x86_64: $BUILD_X86_64"
    log_info "Build in parallel: $BUILD_PARALLEL"
    
    # Check if required scripts exist
    if $BUILD_ARM64 && [ ! -f "${SCRIPT_DIR}/build-toolchain.sh" ]; then
        log_error "arm64 build script not found: build-toolchain.sh"
        exit 1
    fi
    
    if $BUILD_X86_64 && [ ! -f "${SCRIPT_DIR}/build-x86_64-toolchain.sh" ]; then
        log_error "x86_64 build script not found: build-x86_64-toolchain.sh"
        exit 1
    fi
    
    # Execute builds
    if $BUILD_PARALLEL && $BUILD_ARM64 && $BUILD_X86_64; then
        log_warning "Parallel builds are experimental and may consume significant resources"
        build_parallel
    else
        build_sequential
    fi
    
    local build_status=$?
    
    # Verify outputs
    verify_outputs
    local verify_status=$?
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local minutes=$((total_time / 60))
    local seconds=$((total_time % 60))
    
    if [ $build_status -eq 0 ] && [ $verify_status -eq 0 ]; then
        log_success "All toolchain builds completed successfully in ${minutes}m${seconds}s!"
        
        # Show final output summary
        echo ""
        log_info "=== Build Summary ==="
        if $BUILD_ARM64; then
            echo "  ✓ arm64 toolchain: aarch64-nextui-toolchain.tar.gz"
        fi
        if $BUILD_X86_64; then
            echo "  ✓ x86_64 toolchain: x86_64-aarch64-nextui-toolchain.tar.gz"
        fi
        echo ""
        log_info "Ready for deployment!"
    else
        log_error "Some builds failed. Check logs above for details."
        exit 1
    fi
}

# Run main function
main "$@"
