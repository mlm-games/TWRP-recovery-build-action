# TWRP Build Action

This GitHub Action automates the process of building [TeamWin Recovery Project (TWRP)](https://twrp.me/) for a specified Android device. It sets up the build environment, syncs sources, and compiles the recovery image using your device tree and the TWRP source code.

This action is flexible and can automatically extract necessary build parameters from your device tree if they are not provided explicitly.

---

## Table of Contents

- [Features](#features)
- [Usage](#usage)
- [Inputs](#inputs)
- [Environment Variables](#environment-variables)
- [Example Workflows](#example-workflows)
  - [Example with Provided Device Information](#example-with-provided-device-information)
  - [Example with Auto-Detection of Device Information](#example-with-auto-detection-of-device-information)
- [Notes](#notes)
- [Support](#support)
- [License](#license)
- [Additional Information](#additional-information)
  - [Uploading Artifacts](#uploading-artifacts)
  - [Incorporating Swap Space](#incorporating-swap-space)
  - [Troubleshooting](#troubleshooting)

---

## Features

- **Automatic Environment Setup:** Installs all necessary packages and tools required for building TWRP.
- **Flexible Device Tree Handling:** Clones your device tree and can extract `DEVICE_NAME`, `DEVICE_PATH`, and `MAKEFILE_NAME` from `.mk` files if not provided.
- **Customizable Build Options:** Allows you to specify the build target (and to use LDCHECK for dependency checking externally.
- **Branch Handling:** If the device tree branch or manifest branch is not specified, the action will clone the default branch of the repository.
- **Support for Legacy Branches:** Adjusts Python version and build environment based on the chosen manifest branch.

---

## Usage

To use this action in your workflow, add it as a step in your GitHub Actions workflow YAML file. The action can either accept device-specific parameters or attempt to extract them from your device tree's `.mk` files if they are not provided.

---

## Inputs

This action accepts the following inputs:

| Input                | Description                                                                                                                                     | Required | Default               |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|----------|-----------------------|
| `MANIFEST_BRANCH`    | TWRP Manifest Branch (e.g., 'twrp-12.1'). If not provided, the default manifest branch will be used.                                            | No       | `''` (empty string)   |
| `DEVICE_TREE`        | Device Tree URL (your device tree repository).                                                                                                  | No       | `"https://github.com/${{ github.repository }}"` |
| `DEVICE_TREE_BRANCH` | Device Tree Branch. If not provided, the default branch of the repository will be used.                                                         | No       | `''` (empty string)   |
| `DEVICE_NAME`        | Device Codename (leave blank to auto-detect from the device tree).                                                                              | No       | `''` (empty string)   |
| `DEVICE_PATH`        | Device Path (leave blank to auto-detect; e.g., 'device/manufacturer/codename').                                                                 | No       | `''` (empty string)   |
| `MAKEFILE_NAME`      | Makefile Name (leave blank to auto-detect; e.g., 'omni_device').                                                                                | No       | `''` (empty string)   |
| `BUILD_TARGET`       | Build Target ('recovery', 'boot', or 'vendorboot').                                                                                             | No       | `'recovery'`          |

**Notes:**

- If `DEVICE_NAME`, `DEVICE_PATH`, and `MAKEFILE_NAME` are not provided, the action will attempt to extract them from the `.mk` files in your device tree.
- If `DEVICE_TREE_BRANCH` is not provided, the action will clone the default branch of the device tree repository.
- If `MANIFEST_BRANCH` is not provided, the action will initialize the TWRP repo with its default branch.

---

## Environment Variables

The action sets the following environment variables that can be used in subsequent steps:

- `OUTPUT_DIR`: The directory where the built recovery image and associated files are located.

You can access this variable using `${{ env.OUTPUT_DIR }}` in your workflow.

---

## Example Workflows

### Example with Provided Device Information

```yaml
name: Build TWRP Recovery

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    name: Build TWRP Recovery with Provided Device Info
    runs-on: ubuntu-20.04
    steps:
    - uses: actions/checkout@v4

    - name: Set Swap Space (Optional)
      uses: pierotofy/set-swap-space@master
      with:
        swap-size-gb: 16

    - name: Build TWRP
      uses: mlm-games/twrp-build-action@main
      with:
        MANIFEST_BRANCH: 'twrp-12.1'
        DEVICE_TREE: 'https://github.com/mlm-games/device_manufacturer_codename'
        DEVICE_TREE_BRANCH: 'main'
        DEVICE_NAME: 'your_device_codename'
        DEVICE_PATH: 'device/manufacturer/codename'
        MAKEFILE_NAME: 'omni_your_device_codename'
        BUILD_TARGET: 'recovery'

    - name: Upload Recovery Image
      uses: actions/upload-artifact@v3
      with:
        name: TWRP-Recovery
        path: ${{ env.OUTPUT_DIR }}/*.img
```

### Example with Auto-Detection of Device Information

```yaml
name: Build TWRP Recovery

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    name: Build TWRP Recovery with Auto-Detection
    runs-on: ubuntu-20.04
    steps:
    - uses: actions/checkout@v4

    - name: Set Swap Space (Optional)
      uses: pierotofy/set-swap-space@master
      with:
        swap-size-gb: 16

    - name: Build TWRP
      uses: mlm-games/twrp-build-action@main
      with:
        # MANIFEST_BRANCH is omitted to use the default branch
        DEVICE_TREE: 'https://github.com/mlm-games/device_manufacturer_codename'
        # DEVICE_TREE_BRANCH is omitted to use the default branch
        BUILD_TARGET: 'recovery'     # Options: 'recovery', 'boot', 'vendorboot'
        # DEVICE_NAME, DEVICE_PATH, and MAKEFILE_NAME are omitted to auto-detect

    - name: Upload Recovery Image
      uses: actions/upload-artifact@v3
      with:
        name: TWRP-Recovery
        path: ${{ env.OUTPUT_DIR }}/*.img
```

In this example:

- `DEVICE_NAME`, `DEVICE_PATH`, and `MAKEFILE_NAME` are omitted. The action will attempt to extract these values from the `.mk` files in your device tree.
- `DEVICE_TREE_BRANCH` is omitted, so the default branch of the device tree repository will be used.
- `MANIFEST_BRANCH` is omitted, so the action will initialize the TWRP repo with its default branch.

---

## Notes

- **Device Tree Requirements:** Ensure your device tree is properly configured for TWRP. The action relies on variables like `PRODUCT_NAME`, `PRODUCT_DEVICE`, and `PRODUCT_MANUFACTURER` being correctly set in your `.mk` files.
- **Build Time:** The build process can take a significant amount of time depending on the device and available system resources.
- **Storage Space:** Make sure you have sufficient storage space available. Consider using actions like `actions/upload-artifact` to store build artifacts.
- **Swap Space:** For devices with large build requirements, incorporating swap space can improve build success and performance. Use the [pierotofy/set-swap-space](https://github.com/pierotofy/set-swap-space) action to add swap space to your runner.
- **Python Version:** The action adjusts the Python version based on the `MANIFEST_BRANCH`. For legacy branches, it uses Python 2; for current branches, it ensures that Python 3 is used.
- **LDCHECK:** LDCHECK is used for checking missing dependencies in the recovery's blobs. It is not included but can be used via another action.

---

## Support

If you encounter any issues, have questions, or need assistance, please open an issue in the [GitHub repository](https://github.com/mlm-games/twrp-build-action/issues).

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Additional Information

### Uploading Artifacts

After building, you may want to upload the recovery image or ZIP file as an artifact:

```yaml
- name: Upload Recovery Image
  uses: actions/upload-artifact@v3
  with:
    name: TWRP-Recovery
    path: ${{ env.OUTPUT_DIR }}/*.img

- name: Upload Recovery ZIP
  if: success() && env.CHECK_ZIP_IS_OK == 'true'
  uses: actions/upload-artifact@v3
  with:
    name: TWRP-Recovery-ZIP
    path: ${{ env.OUTPUT_DIR }}/*.zip
```

### Incorporating Swap Space

For devices with large build requirements, incorporating swap space can improve build success and performance:

```yaml
- name: Set Swap Space
  uses: pierotofy/set-swap-space@master
  with:
    swap-size-gb: 24
```

Make sure to adjust the swap size according to your needs.

### Troubleshooting

- **Failed to Extract Device Information:** If the action fails to extract `DEVICE_NAME`, `DEVICE_PATH`, or `MAKEFILE_NAME`, ensure that your `.mk` files contain the necessary variables (`PRODUCT_NAME`, `PRODUCT_DEVICE`, `PRODUCT_MANUFACTURER`).
- **Build Failures:** Check the build logs for error messages. Common issues include missing dependencies or misconfigured device trees.
- **Insufficient Resources:** GitHub Actions runners have limitations on CPU and memory. For resource-intensive builds, consider using self-hosted runners or optimizing your device tree.
- **Branch Compatibility:** Ensure that the `MANIFEST_BRANCH` and `DEVICE_TREE_BRANCH` are compatible with each other. Using mismatched branches may result in build errors.

---

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/mlm-games/twrp-build-action/issues) if you want to contribute.

---

## Acknowledgements

- [TeamWin Recovery Project (TWRP)](https://twrp.me/)
- [GitHub Actions](https://github.com/features/actions)

---

## Disclaimer

This action is provided as-is without any warranty. Use it at your own risk. The maintainers are not responsible for any damages or issues arising from its use.

Feel free to customize and extend this action to suit your specific needs. Contributions and improvements are welcome!
