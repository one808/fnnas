#!/bin/bash
#=====================================================================================
# Build u-boot for OrangePi Zero2W (Allwinner H618)
# https://github.com/one808/fnnas
#
# This script builds the u-boot binary needed for OrangePi Zero2W support in FnNAS.
# Run this on Ubuntu 22.04 x64 with root privileges.
#
# Prerequisites:
#   sudo apt-get update && sudo apt-get install -y git
#
# Usage:
#   chmod +x build-zerow2-uboot.sh
#   sudo ./build-zerow2-uboot.sh
#
# Output:
#   u-boot-sunxi-with-spl.bin (ready to be placed in ophub/u-boot repo)
#=====================================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/.build-zerow2-uboot"
OUTPUT_FILE="${SCRIPT_DIR}/u-boot-sunxi-with-spl.bin"

echo "============================================"
echo "  OrangePi Zero2W u-boot Builder"
echo "  SoC: Allwinner H618"
echo "============================================"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script requires root privileges. Run with: sudo $0"
    exit 1
fi

# Check Ubuntu version
UBUNTU_VER=$(lsb_release -rs 2>/dev/null || echo "unknown")
echo "[INFO] Ubuntu version: ${UBUNTU_VER}"

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "[INFO] Step 1: Cloning orangepi-build (next branch)..."
git clone https://github.com/orangepi-xunlong/orangepi-build.git -b next --depth 1
cd orangepi-build

echo "[INFO] Step 2: Building u-boot for orangepizero2w..."
echo "[INFO] This will download toolchains and u-boot source automatically."
echo "[INFO] The build takes about 5-15 minutes depending on your machine."
echo ""

# Build u-boot non-interactively
./build.sh BOARD=orangepizero2w BRANCH=next BUILD_OPT=u-boot

# Find the built u-boot
UBOOT_DEB=$(find output/debs/u-boot -name "linux-u-boot-next-orangepizero2w*.deb" | head -1)

if [[ -z "${UBOOT_DEB}" ]]; then
    echo "[ERROR] u-boot build failed. Check the build log for errors."
    exit 1
fi

echo "[INFO] Step 3: Extracting u-boot-sunxi-with-spl.bin from deb package..."

# Create temp extraction dir
EXTRACT_DIR=$(mktemp -d)
cd "${EXTRACT_DIR}"
ar x "${BUILD_DIR}/orangepi-build/${UBOOT_DEB}"
tar xf data.tar.* 2>/dev/null || tar xf data.tar

# Find the binary
SPL_BIN=$(find . -name "u-boot-sunxi-with-spl.bin" | head -1)

if [[ -z "${SPL_BIN}" ]]; then
    echo "[ERROR] Could not find u-boot-sunxi-with-spl.bin in the deb package."
    echo "[INFO] Contents of the deb:"
    find . -type f | head -20
    exit 1
fi

cp "${SPL_BIN}" "${OUTPUT_FILE}"
chmod 644 "${OUTPUT_FILE}"

# Cleanup
rm -rf "${EXTRACT_DIR}" "${BUILD_DIR}"

echo ""
echo "============================================"
echo "  SUCCESS!"
echo "============================================"
echo ""
echo "Built u-boot: ${OUTPUT_FILE}"
echo "Size: $(ls -lh "${OUTPUT_FILE}" | awk '{print $5}')"
echo ""
echo "Next steps:"
echo "  1. Copy u-boot-sunxi-with-spl.bin to ophub/u-boot repo:"
echo "     mkdir -p u-boot/allwinner/orangepi-zero2w/"
echo "     cp ${OUTPUT_FILE} u-boot/allwinner/orangepi-zero2w/"
echo "  2. Commit and push to https://github.com/ophub/u-boot"
echo "  3. The FnNAS Actions workflow can now build images for OrangePi Zero2W"
echo ""
