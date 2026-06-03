# MECM to Intune App Migrator

An automated, GUI-driven enterprise utility that connects to local MECM/SCCM environments, extracts application source files and complex detection metadata, packages them into `.intunewin` formats, and generates Intune-ready JSON payloads for seamless cloud migration.

## Features

- **Configuration GUI:** A sleek, slate-grey Windows Forms interface for configuration input. Auto-detects SCCM Site Code.
- **Dynamic Operation Modes:** The UI automatically resizes based on three versatile modes: Air-gapped Extraction, Auto-Upload, or standalone Upload-Only.
- **Dependency Management:** Automatically ensures the `IntuneWin32App` module is installed and imported.
- **Extraction & Packaging:** Extracts SCCM applications, deep-searches metadata, decodes detection methods, and packages using `IntuneWinAppUtil.exe`.
- **JSON Metadata Engine:** Generates structured `.json` payloads mapping Application WMI data for future reference or migration pipelines.
- **Direct Intune Upload Pipeline:** Optionally authenticates to MS Graph and utilizes `Add-IntuneWin32App` to upload the generated `.intunewin` file and map metadata directly into the Intune application payload.
- **Live Progress UI:** Dynamic progress window tracks extraction, compilation, and upload stages.

## Prerequisites

1. **SCCM Admin Console module:** The script expects the SCCM console to be installed on the machine running the script to use `ConfigurationManager.psd1`.
2. **IntuneWinAppUtil.exe:** The Microsoft Win32 Content Prep Tool executable is bundled directly within the repository for immediate plug-and-play usage.
3. **IntuneWin32App module:** The script automatically checks and installs this module if missing, but requires an active internet connection to download from PSGallery.

## Usage

Users can simply double-click `Launch-Utility.cmd`, and the tool will automatically prompt for the necessary Administrator permissions via UAC.

### 3-Step Air-Gapped SCCM Workflow
For enterprise environments where the SCCM primary site server is completely offline or segmented from the internet, you can use the versatile 3-step workflow:
1. **Mode 1 (Offline Server):** Run the tool on the offline SCCM server, select **"Extract & Package Locally (Air-gapped)"**, and extract your packages. The script will generate both the `.intunewin` package and a matching `.json` metadata file.
2. **Transfer:** Move the resulting `.intunewin` and `.json` files to a secure, online administration machine.
3. **Mode 3 (Online Machine):** Run the tool on the online machine, select **"Upload Existing Package to Intune"**, select the transferred `.intunewin` file, and let the tool automatically read the metadata and upload it to Intune via MS Graph.

### Live Cloud Uploading (Mode 2)
For environments where the SCCM server has direct internet and MS Graph access:
1. Run the tool and select **"Extract & Auto-Upload to Intune"**.
2. Provide your **Entra Tenant ID** and **App Registration Client ID** (ensure the App Registration has appropriate Graph API permissions for Intune app deployment).
3. Select the output directory where you want the .intunewin and metadata files saved. Note: For direct uploads, a temporary workspace is utilized.
4. Select the applications you wish to extract and package.
5. After packaging, the script will automatically authenticate to Microsoft Graph and upload the `.intunewin` application directly into your Intune tenant, matching the extracted metadata.

## Notes
- If running into issues, ensure you are running PowerShell as Administrator.
- Ensure the selected SCCM source paths are accessible by the account running the script.
