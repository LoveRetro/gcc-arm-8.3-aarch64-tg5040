#!/bin/bash

# Simple ARM64 GCC 8.3.0 Toolchain Build Script
# Builds directly to /opt/aarch64-nextui-linux-gnu with minimal post-processing

set -euo pipefail

# Detect operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/aarch64.config"
DOCKER_IMAGE="crosstool-ng-builder"

# OS-specific path configuration
if [ "$OS" = "macos" ]; then
    DMG_FILE="${SCRIPT_DIR}/docker-build-env.dmg"
    MOUNT_POINT="/Volumes/docker-build-env"
    WORK_DIR="${MOUNT_POINT}/toolchain_work"
else
    # Linux: Use regular directory in script location
    WORK_DIR="${SCRIPT_DIR}/toolchain_work"
fi

# Optimize build jobs for current system (cross-platform)
if [ "$OS" = "macos" ]; then
    BUILD_JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
else
    BUILD_JOBS="$(nproc 2>/dev/null || echo 4)"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

# Function to create and mount case-sensitive volume (macOS only)
create_case_sensitive_volume() {
    if [ "$OS" != "macos" ]; then
        log_info "Skipping case-sensitive volume creation on Linux"
        return 0
    fi
    
    log_info "Setting up case-sensitive file system for crosstool-NG..."
    
    # Unmount if already mounted
    if [ -d "${MOUNT_POINT}" ]; then
        hdiutil detach "${MOUNT_POINT}" 2>/dev/null || true
        sleep 2
    fi
    
    # Remove existing DMG file
    if [ -f "${DMG_FILE}" ]; then
        rm -f "${DMG_FILE}"
    fi
    
    # Create new case-sensitive HFS+ disk image
    log_info "Creating case-sensitive disk image (20GB)..."
    hdiutil create -size 20g -fs 'Case-sensitive HFS+' -volname docker-build-env "${DMG_FILE}"
    
    # Mount the disk image
    log_info "Mounting case-sensitive volume..."
    hdiutil mount "${DMG_FILE}"
    
    log_success "Case-sensitive volume created and mounted at ${MOUNT_POINT}"
}

# Function to cleanup on exit
cleanup() {
    log_info "Cleaning up..."
    
    if [ "$OS" = "macos" ]; then
        # Unmount volume if mounted
        if [ -d "${MOUNT_POINT}" ]; then
            hdiutil detach "${MOUNT_POINT}" 2>/dev/null || true
        fi
        
        # Remove DMG file
        rm -f "${DMG_FILE}" 2>/dev/null || true
    else
        # Linux: Clean up work directory
        rm -rf "${WORK_DIR}" 2>/dev/null || true
    fi
}

# Function to prepare work directory
prepare_directories() {
    log_info "Preparing work directory..."
    
    rm -rf "${WORK_DIR}"
    mkdir -p "${WORK_DIR}"
    
    if [ "$OS" = "macos" ]; then
        log_success "Work directory prepared at ${WORK_DIR} (case-sensitive volume)"
    else
        log_success "Work directory prepared at ${WORK_DIR}"
    fi
}

# Function to build Docker image
build_docker_image() {
    log_info "Building Docker image..."
    
    # Detect host architecture and warn if running on x86_64
    host_arch=$(uname -m)
    if [ "$host_arch" = "x86_64" ]; then
        log_warning "Detected x86_64 host. Building ARM64 toolchain using Docker platform emulation."
        log_warning "For better performance, consider using an ARM64 host or GitHub ARM64 runners."
        docker_platform="--platform linux/arm64"
    else
        docker_platform=""
    fi
    
    if ! docker build -f "${SCRIPT_DIR}/Dockerfile.ct-ng" -t "${DOCKER_IMAGE}" ${docker_platform} "${SCRIPT_DIR}"; then
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    log_success "Docker image built successfully"
}

# Function to copy configuration
copy_configuration() {
    log_info "Copying toolchain configuration..."
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        exit 1
    fi
    
    cp "${CONFIG_FILE}" "${WORK_DIR}/.config"
    log_success "Configuration copied"
}

# Function to run the main build and create archive in one step
run_toolchain_build() {
    log_info "Starting toolchain build with ${BUILD_JOBS} jobs..."
    
    # Detect host architecture and set platform flag if needed
    host_arch=$(uname -m)
    if [ "$host_arch" = "x86_64" ]; then
        log_warning "Running ARM64 container on x86_64 host using emulation."
        docker_platform="--platform linux/arm64"
    else
        docker_platform=""
    fi
    
    # Run the build, test, and compression in a single container to preserve results
    docker run --rm \
        ${docker_platform} \
        -v "${WORK_DIR}:/home/builder/work" \
        -v "${SCRIPT_DIR}:/output" \
        --entrypoint="" \
        "${DOCKER_IMAGE}" \
        bash -c "
            # Ensure proper permissions for mounted directory
            sudo chown -R builder:builder /home/builder/work
            cd /home/builder/work
            ct-ng build.${BUILD_JOBS}
            echo 'Build completed, locating toolchain...'
            
            # Find the toolchain directory
            if [ -d /opt/aarch64-nextui-linux-gnu ]; then
                TOOLCHAIN_DIR=/opt/aarch64-nextui-linux-gnu
                echo 'Toolchain found at /opt/aarch64-nextui-linux-gnu'
            else
                echo 'Checking for toolchain in other locations...'
                TOOLCHAIN_DIR=\$(find / -name 'aarch64-nextui-linux-gnu-gcc' 2>/dev/null | head -1 | xargs dirname | xargs dirname 2>/dev/null)
                if [ -n \"\$TOOLCHAIN_DIR\" ] && [ -d \"\$TOOLCHAIN_DIR\" ]; then
                    echo \"Toolchain found at \$TOOLCHAIN_DIR\"
                else
                    echo 'ERROR: No toolchain found'
                    exit 1
                fi
            fi
            
            # Test the toolchain inside the container
            echo 'Running toolchain tests inside container...'
            GCC_PATH=\"\$TOOLCHAIN_DIR/bin/aarch64-nextui-linux-gnu-gcc\"
            if [ -f \"\$GCC_PATH\" ]; then
                echo 'Testing GCC version:'
                \"\$GCC_PATH\" --version | head -1
                
                echo 'Testing C compilation:'
                echo 'int main(){return 0;}' | \"\$GCC_PATH\" -x c - -o /tmp/test_c
                echo 'C compilation test passed'
                
                GPP_PATH=\"\$TOOLCHAIN_DIR/bin/aarch64-nextui-linux-gnu-g++\"
                if [ -f \"\$GPP_PATH\" ]; then
                    echo 'Testing C++ compilation:'
                    echo 'int main(){return 0;}' | \"\$GPP_PATH\" -x c++ - -o /tmp/test_cpp
                    echo 'C++ compilation test passed'
                fi
            else
                echo 'ERROR: GCC compiler not found at expected location'
                exit 1
            fi
            
            # Create archive inside container
            echo 'Creating toolchain archive...'
            cd \$(dirname \"\$TOOLCHAIN_DIR\")
            tar -czf /output/aarch64-nextui-toolchain.tar.gz \$(basename \"\$TOOLCHAIN_DIR\")
            echo 'Archive created successfully'
        "
    
    log_success "Toolchain build, test, and compression completed"
}

# Function to verify the created package
verify_package() {
    log_info "Verifying created package..."
    
    local package_name="aarch64-nextui-toolchain.tar.gz"
    local package_path="${SCRIPT_DIR}/${package_name}"
    
    if [ -f "${package_path}" ]; then
        # Show package info
        local size=$(ls -lh "${package_path}" | awk '{print $5}')
        log_info "Package size: ${size}"
        
        # Test archive integrity
        if tar -tzf "${package_path}" >/dev/null 2>&1; then
            log_success "Package created and verified: ${package_name}"
            
            # Show some contents
            log_info "Package contents (first 10 entries):"
            tar -tzf "${package_path}" | head -10
        else
            log_error "Package verification failed - archive may be corrupted"
            return 1
        fi
    else
        log_error "Package not found at ${package_path}"
        return 1
    fi
}

# Main execution
main() {
    local start_time=$(date +%s)
    
    log_info "Starting simplified ARM64 GCC 8.3.0 toolchain build..."
    log_info "Operating System: $OS"
    log_info "Target: /opt/aarch64-nextui-linux-gnu"
    log_info "Build Jobs: $BUILD_JOBS"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Build steps
    create_case_sensitive_volume  # Function handles OS detection internally
    prepare_directories
    build_docker_image
    copy_configuration
    run_toolchain_build
    verify_package
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local minutes=$((total_time / 60))
    local seconds=$((total_time % 60))
    
    log_success "Simplified toolchain build completed in ${minutes}m${seconds}s!"
    log_info "Ready-to-deploy toolchain archive: aarch64-nextui-toolchain.tar.gz"
}

# Run main function
main "$@"
