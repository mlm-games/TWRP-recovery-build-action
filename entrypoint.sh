#!/bin/bash
set -e

# Function to set output variables
set_output() {
    echo "$1=$2" >> $GITHUB_OUTPUT
}

# Install necessary packages
echo "Installing necessary packages..."
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick \
    lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev \
    libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev \
    python3 python2 bash tmux ccache curl unzip

# Install OpenJDK 8
echo "Installing OpenJDK 8..."
sudo apt-get install -y openjdk-8-jdk

# Install repo tool
echo "Installing repo tool..."
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo -o ~/bin/repo
chmod a+x ~/bin/repo
sudo ln -sf ~/bin/repo /usr/bin/repo

# Set up the build environment
echo "Setting up build environment..."
MANIFEST_DIR="$GITHUB_WORKSPACE/android-recovery"
mkdir -p "$MANIFEST_DIR"
cd "$MANIFEST_DIR"

# Configure git
git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$GITHUB_ACTOR_ID+$GITHUB_ACTOR@users.noreply.github.com"

# Determine MANIFEST_URL based on MANIFEST_BRANCH
if [ -z "$MANIFEST_BRANCH" ] || [ "$MANIFEST_BRANCH" == "twrp-11" ] || [ "$MANIFEST_BRANCH" == "twrp-12.1" ]; then
    MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git"
    CHECK_LEGACY_BRANCH="false"
else
    MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git"
    CHECK_LEGACY_BRANCH="true"
fi

echo "MANIFEST_URL=${MANIFEST_URL}" >> $GITHUB_ENV
echo "CHECK_LEGACY_BRANCH=${CHECK_LEGACY_BRANCH}" >> $GITHUB_ENV

# Initialize the repo
echo "Initializing TWRP repo..."
if [ -n "$MANIFEST_BRANCH" ]; then
    echo "Initializing repo with branch: $MANIFEST_BRANCH"
    repo init --depth=1 -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH"
else
    echo "Initializing repo without specifying a branch (default branch will be used)"
    repo init --depth=1 -u "$MANIFEST_URL"
fi

# Sync the repo
echo "Syncing TWRP repo..."
repo sync -j$(nproc --all) --force-sync

# If DEVICE_TREE is not provided, default to the current repository
if [ -z "$DEVICE_TREE" ]; then
    DEVICE_TREE="https://github.com/${GITHUB_REPOSITORY}"
    echo "DEVICE_TREE not specified. Using current repository: ${DEVICE_TREE}"
    echo "DEVICE_TREE=${DEVICE_TREE}" >> $GITHUB_ENV
fi

# Clone device tree into a temporary directory
echo "Cloning device tree..."
if [ -n "$DEVICE_TREE_BRANCH" ]; then
    echo "Cloning device tree with branch: $DEVICE_TREE_BRANCH"
    git clone "$DEVICE_TREE" -b "$DEVICE_TREE_BRANCH" tmp_device_tree
else
    echo "Cloning device tree without specifying a branch (default branch will be used)"
    git clone "$DEVICE_TREE" tmp_device_tree
fi

# Check if DEVICE_NAME or DEVICE_PATH or MAKEFILE_NAME are not provided
if [ -z "$DEVICE_NAME" ] || [ -z "$DEVICE_PATH" ] || [ -z "$MAKEFILE_NAME" ]; then
    echo "Extracting variables from .mk files..."
    cd tmp_device_tree

    # Initialize variables
    DEVICE_NAME=""
    BRAND=""
    DEVICE_PATH=""
    MAKEFILE_NAME=""

    # Search for .mk files recursively in the device tree
    mk_files=$(find . -type f -name '*.mk')

    # Loop through each .mk file found
    for file in $mk_files; do
        # Extract variables using sed
        product_name=$(sed -n 's/^[[:space:]]*PRODUCT_NAME[[:space:]]*:=\s*\(.*\)/\1/p' "$file")
        product_device=$(sed -n 's/^[[:space:]]*PRODUCT_DEVICE[[:space:]]*:=\s*\(.*\)/\1/p' "$file")
        product_manufacturer=$(sed -n 's/^[[:space:]]*PRODUCT_MANUFACTURER[[:space:]]*:=\s*\(.*\)/\1/p' "$file")
        if [[ -n "$product_name" && -n "$product_device" && -n "$product_manufacturer" ]]; then
            DEVICE_NAME="$product_device"
            BRAND="$product_manufacturer"
            DEVICE_PATH="device/$BRAND/$DEVICE_NAME"
            MAKEFILE_NAME="${product_name}"
            echo "DEVICE_NAME=${DEVICE_NAME}" >> $GITHUB_ENV
            echo "BRAND=${BRAND}" >> $GITHUB_ENV
            echo "DEVICE_PATH=${DEVICE_PATH}" >> $GITHUB_ENV
            echo "MAKEFILE_NAME=${MAKEFILE_NAME}" >> $GITHUB_ENV
            break
        fi
    done

    # Verify that DEVICE_NAME was found
    if [ -z "$DEVICE_NAME" ]; then
        echo "::error::Failed to extract DEVICE_NAME from .mk files."
        exit 1
    fi

    # Navigate back to the MANIFEST_DIR
    cd "$MANIFEST_DIR"

    # Move the device tree into the correct directory
    echo "Moving device tree to $DEVICE_PATH"
    mkdir -p "$DEVICE_PATH"
    mv tmp_device_tree/* "$DEVICE_PATH/"
    rm -rf tmp_device_tree
else
    echo "Using provided DEVICE_NAME, DEVICE_PATH, and MAKEFILE_NAME"
    # Move device tree to the specified DEVICE_PATH
    mkdir -p "$DEVICE_PATH"
    mv tmp_device_tree/* "$DEVICE_PATH/"
    rm -rf tmp_device_tree
fi

# Install additional dependencies for legacy branches
if [ "$CHECK_LEGACY_BRANCH" == "true" ]; then
    echo "Installing Python 2 for legacy branches..."
    sudo apt-get install -y python2
    # Use update-alternatives to set python to point to python2
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python2 1
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 2
    sudo update-alternatives --set python /usr/bin/python2
else
    echo "No need to install Python 2 for this branch."
    # Ensure python points to python3
    sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    sudo update-alternatives --set python /usr/bin/python3
fi

# Set OUTPUT_DIR
OUTPUT_DIR="$MANIFEST_DIR/out/target/product/$DEVICE_NAME"
echo "OUTPUT_DIR=${OUTPUT_DIR}" >> $GITHUB_ENV

# Build TWRP
echo "Building TWRP..."
cd "$MANIFEST_DIR"
source build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true

lunch "${MAKEFILE_NAME}-eng"
make clean
make -j$(nproc --all) "${BUILD_TARGET}image"

echo "Done building your ${BUILD_TARGET}.img"

# Set build date
echo "BUILD_DATE=$(TZ=UTC date +%Y%m%d)" >> $GITHUB_ENV

# Check if the recovery image exists
echo "Checking if the recovery image exists..."
img_file=$(find "$OUTPUT_DIR" -name "${BUILD_TARGET}.img" -print -quit)
zip_file=$(find "$OUTPUT_DIR" -name "*installer*zip" -print -quit)

if [ -f "$img_file" ]; then
    echo "CHECK_IMG_IS_OK=true" >> $GITHUB_ENV
    set_output "out_img" "$img_file"
    echo "MD5_IMG=$(md5sum "$img_file" | cut -d ' ' -f 1)" >> $GITHUB_ENV
else
    echo "::warning::Recovery image not found."
fi

if [ -f "$zip_file" ]; then
    echo "CHECK_ZIP_IS_OK=true" >> $GITHUB_ENV
    set_output "out_zip" "$zip_file"
    echo "MD5_ZIP=$(md5sum "$zip_file" | cut -d ' ' -f 1)" >> $GITHUB_ENV
else
    echo "::warning::Recovery ZIP not found."
fi
