# MECM to Intune App Migrator

An automated, GUI-driven enterprise utility that connects to local MECM/SCCM environments, extracts application source files and complex detection metadata, packages them into `.intunewin` formats, and generates Intune-ready JSON payloads for seamless cloud migration.

## Features

- **Configuration GUI:** A sleek, slate-grey Windows Forms interface for configuration input. Auto-detects SCCM Site Code.
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

### Offline Extraction
1. Double-click `Launch-Utility.cmd` to run the tool.
2. In the Configuration GUI, verify your **SCCM Site Code**.
3. Browse for the **Output Directory** where you want the packaged apps to be saved.
4. Browse for the **IntuneWinAppUtil.exe Location**.
5. Do *not* check "Auto-Upload to Intune via MS Graph".
6. Click **Initialize Connection**.
7. Select the applications you wish to extract and package from the secondary GUI.
8. The script will generate `.intunewin` files and `.json` metadata payloads in the output directory.

### Live Cloud Uploading
1. Double-click `Launch-Utility.cmd` to run the tool.
2. Fill out the **SCCM Site Code**, **Output Directory**, and **IntuneWinAppUtil.exe Location**.
3. Provide your **Entra Tenant ID** and **App Registration Client ID** (ensure the App Registration has appropriate Graph API permissions for Intune app deployment).
4. Check the **Auto-Upload to Intune via MS Graph** box.
5. Click **Initialize Connection**.
6. Select the applications you wish to extract and package.
7. After packaging, the script will automatically authenticate to Microsoft Graph and upload the `.intunewin` application directly into your Intune tenant, matching the extracted metadata.

## Notes
- If running into issues, ensure you are running PowerShell as Administrator.
- Ensure the selected SCCM source paths are accessible by the account running the script.
