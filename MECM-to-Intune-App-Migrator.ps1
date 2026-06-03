<#
.SYNOPSIS
  Extracts Application metadata from SCCM and automatically packages into .intunewin, with optional direct Intune upload.
.DESCRIPTION
  MECM to Intune App Migrator is a premium, open-source enterprise utility.
  Combines a robust WinForms GUI extractor with the IntuneWinAppUtil packager and IntuneWin32App upload module.
  Includes a live Progress UI to track WMI extraction, Enhanced Detection Translation,
  Description deep-searching, .intunewin compilation, and MS Graph Uploads.
#>

#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# 2. CONFIGURATION GUI REFACTOR
# ==============================================================================
[System.Windows.Forms.Application]::EnableVisualStyles()

$configForm = New-Object System.Windows.Forms.Form
$configForm.Text = "MECM to Intune App Migrator - Configuration"
$configForm.Size = New-Object System.Drawing.Size(500, 480)
$configForm.StartPosition = "CenterScreen"
$configForm.FormBorderStyle = 'FixedDialog'
$configForm.MaximizeBox = $false
$configForm.BackColor = [System.Drawing.Color]::SlateGray
$configForm.ForeColor = [System.Drawing.Color]::White

# Helper function to add controls
function Add-Label ($Text, $Y, $ParentControl = $configForm) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Location = New-Object System.Drawing.Point(20, $Y)
    $lbl.AutoSize = $true
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $ParentControl.Controls.Add($lbl)
    return $lbl
}

function Add-TextBox ($Y, $Width = 440, $ParentControl = $configForm) {
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, ($Y + 20))
    $txt.Size = New-Object System.Drawing.Size($Width, 20)
    $txt.BackColor = [System.Drawing.Color]::White
    $txt.ForeColor = [System.Drawing.Color]::Black
    $ParentControl.Controls.Add($txt)
    return $txt
}


$modeGroup = New-Object System.Windows.Forms.GroupBox
$modeGroup.Text = "Operation Mode"
$modeGroup.Location = New-Object System.Drawing.Point(20, 20)
$modeGroup.Size = New-Object System.Drawing.Size(440, 100)
$modeGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$modeGroup.ForeColor = [System.Drawing.Color]::White
$configForm.Controls.Add($modeGroup)

$rbMode1 = New-Object System.Windows.Forms.RadioButton
$rbMode1.Text = "Extract & Package Locally (Air-gapped)"
$rbMode1.Location = New-Object System.Drawing.Point(20, 20)
$rbMode1.Size = New-Object System.Drawing.Size(400, 20)
$rbMode1.Checked = $true
$modeGroup.Controls.Add($rbMode1)

$rbMode2 = New-Object System.Windows.Forms.RadioButton
$rbMode2.Text = "Extract & Auto-Upload to Intune"
$rbMode2.Location = New-Object System.Drawing.Point(20, 45)
$rbMode2.Size = New-Object System.Drawing.Size(400, 20)
$modeGroup.Controls.Add($rbMode2)

$rbMode3 = New-Object System.Windows.Forms.RadioButton
$rbMode3.Text = "Upload Existing Package to Intune"
$rbMode3.Location = New-Object System.Drawing.Point(20, 70)
$rbMode3.Size = New-Object System.Drawing.Size(400, 20)
$modeGroup.Controls.Add($rbMode3)

$sccmPanel = New-Object System.Windows.Forms.Panel
$sccmPanel.Size = New-Object System.Drawing.Size(480, 160)
$configForm.Controls.Add($sccmPanel)

Add-Label "SCCM Site Code:" 0 $sccmPanel | Out-Null
$txtSiteCode = Add-TextBox 0 440 $sccmPanel

# Auto-detect SCCM Site Code
try {
    $providerLoc = Get-WmiObject -Namespace "root\SMS" -Class SMS_ProviderLocation -ErrorAction SilentlyContinue
    if ($providerLoc) {
        $txtSiteCode.Text = $providerLoc.SiteCode
    }
} catch { }

$lblOutputDir = Add-Label "Output Directory:" 50 $sccmPanel
$txtOutputDir = Add-TextBox 50 350 $sccmPanel
$btnBrowseOut = New-Object System.Windows.Forms.Button
$btnBrowseOut.Text = "Browse"
$btnBrowseOut.Location = New-Object System.Drawing.Point(380, 70)
$btnBrowseOut.Size = New-Object System.Drawing.Size(80, 22)
$btnBrowseOut.BackColor = [System.Drawing.Color]::LightGray
$btnBrowseOut.ForeColor = [System.Drawing.Color]::Black
$btnBrowseOut.add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutputDir.Text = $fbd.SelectedPath
    }
})
$sccmPanel.Controls.Add($btnBrowseOut)

Add-Label "IntuneWinAppUtil.exe Location:" 100 $sccmPanel | Out-Null
$txtIntuneUtil = Add-TextBox 100 350 $sccmPanel
$btnBrowseUtil = New-Object System.Windows.Forms.Button
$btnBrowseUtil.Text = "Browse"
$btnBrowseUtil.Location = New-Object System.Drawing.Point(380, 120)
$btnBrowseUtil.Size = New-Object System.Drawing.Size(80, 22)
$btnBrowseUtil.BackColor = [System.Drawing.Color]::LightGray
$btnBrowseUtil.ForeColor = [System.Drawing.Color]::Black
$btnBrowseUtil.add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtIntuneUtil.Text = $ofd.FileName
    }
})
$sccmPanel.Controls.Add($btnBrowseUtil)

$intunePanel = New-Object System.Windows.Forms.Panel
$intunePanel.Size = New-Object System.Drawing.Size(480, 130)
$configForm.Controls.Add($intunePanel)

$lblTenantID = Add-Label "Entra Tenant ID:" 0 $intunePanel
$txtTenantID = Add-TextBox 0 440 $intunePanel

$lblClientID = Add-Label "App Registration Client ID (Default: Native MS Graph CLI):" 50 $intunePanel
$txtClientID = Add-TextBox 50 440 $intunePanel
$txtClientID.Text = "14d82eec-204b-4c2f-b7e8-296a70dab67e"

$lblModuleStatus = New-Object System.Windows.Forms.Label
$lblModuleStatus.Location = New-Object System.Drawing.Point(20, 100)
$lblModuleStatus.Size = New-Object System.Drawing.Size(260, 20)
$lblModuleStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
if (Get-Module -ListAvailable -Name IntuneWin32App) {
    $lblModuleStatus.Text = "IntuneWin32App Module: Installed"
    $lblModuleStatus.ForeColor = [System.Drawing.Color]::LightGreen
} else {
    $lblModuleStatus.Text = "IntuneWin32App Module: Not Installed"
    $lblModuleStatus.ForeColor = [System.Drawing.Color]::LightCoral
}
$intunePanel.Controls.Add($lblModuleStatus)

$btnInstallModule = New-Object System.Windows.Forms.Button
$btnInstallModule.Text = "Install Module"
$btnInstallModule.Location = New-Object System.Drawing.Point(290, 95)
$btnInstallModule.Size = New-Object System.Drawing.Size(100, 25)
$btnInstallModule.BackColor = [System.Drawing.Color]::LightGray
$btnInstallModule.ForeColor = [System.Drawing.Color]::Black
$btnInstallModule.add_Click({
    $btnInstallModule.Enabled = $false
    $lblModuleStatus.Text = "Installing..."
    $lblModuleStatus.ForeColor = [System.Drawing.Color]::Yellow
    [System.Windows.Forms.Application]::DoEvents()

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction SilentlyContinue
        [System.Windows.Forms.Application]::DoEvents()

        Install-Module -Name IntuneWin32App -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop

        $lblModuleStatus.Text = "IntuneWin32App Module: Installed"
        $lblModuleStatus.ForeColor = [System.Drawing.Color]::LightGreen
        [System.Windows.Forms.MessageBox]::Show("Successfully installed IntuneWin32App.", "Success", 0, 64)
    } catch {
        $lblModuleStatus.Text = "IntuneWin32App Module: Not Installed"
        $lblModuleStatus.ForeColor = [System.Drawing.Color]::LightCoral
        [System.Windows.Forms.MessageBox]::Show("Failed to install IntuneWin32App. Please install it manually.`n`nError: $_", "Error", 0, 16)
    } finally {
        $btnInstallModule.Enabled = $true
        [System.Windows.Forms.Application]::DoEvents()
    }
})
$intunePanel.Controls.Add($btnInstallModule)

$uploadPanel = New-Object System.Windows.Forms.Panel
$uploadPanel.Size = New-Object System.Drawing.Size(480, 60)
$configForm.Controls.Add($uploadPanel)

Add-Label "Existing .intunewin Package:" 0 $uploadPanel | Out-Null
$txtUploadFile = Add-TextBox 0 350 $uploadPanel
$btnBrowseUpload = New-Object System.Windows.Forms.Button
$btnBrowseUpload.Text = "Browse"
$btnBrowseUpload.Location = New-Object System.Drawing.Point(380, 20)
$btnBrowseUpload.Size = New-Object System.Drawing.Size(80, 22)
$btnBrowseUpload.BackColor = [System.Drawing.Color]::LightGray
$btnBrowseUpload.ForeColor = [System.Drawing.Color]::Black
$btnBrowseUpload.add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "IntuneWin files (*.intunewin)|*.intunewin|All files (*.*)|*.*"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtUploadFile.Text = $ofd.FileName
    }
})
$uploadPanel.Controls.Add($btnBrowseUpload)

function Update-UILayout {
    $currentY = 130 # Start below Mode GroupBox

    if ($rbMode1.Checked) {
        $sccmPanel.Visible = $true
        $sccmPanel.Location = New-Object System.Drawing.Point(0, $currentY)
        $currentY += $sccmPanel.Height
        $intunePanel.Visible = $false
        $uploadPanel.Visible = $false
    } elseif ($rbMode2.Checked) {
        $sccmPanel.Visible = $true
        $sccmPanel.Location = New-Object System.Drawing.Point(0, $currentY)
        $currentY += $sccmPanel.Height
        $intunePanel.Visible = $true
        $intunePanel.Location = New-Object System.Drawing.Point(0, $currentY)
        $currentY += $intunePanel.Height + 20
        $uploadPanel.Visible = $false
    } elseif ($rbMode3.Checked) {
        $sccmPanel.Visible = $false
        $uploadPanel.Visible = $true
        $uploadPanel.Location = New-Object System.Drawing.Point(0, $currentY)
        $currentY += $uploadPanel.Height
        $intunePanel.Visible = $true
        $intunePanel.Location = New-Object System.Drawing.Point(0, $currentY)
        $currentY += $intunePanel.Height + 20
    }

    $btnInit.Location = New-Object System.Drawing.Point(20, $currentY)
    $configForm.Height = $currentY + 100
}

$rbMode1.add_CheckedChanged({ Update-UILayout })
$rbMode2.add_CheckedChanged({ Update-UILayout })
$rbMode3.add_CheckedChanged({ Update-UILayout })

Update-UILayout


$btnInit = New-Object System.Windows.Forms.Button
$btnInit.Text = "Initialize Connection"
$btnInit.Location = New-Object System.Drawing.Point(20, 330)
$btnInit.Size = New-Object System.Drawing.Size(440, 40)
$btnInit.BackColor = [System.Drawing.Color]::LightBlue
$btnInit.ForeColor = [System.Drawing.Color]::Black
$btnInit.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$script:ConfigValid = $false
$btnInit.add_Click({
    if ($rbMode1.Checked -or $rbMode2.Checked) {
        if ([string]::IsNullOrWhiteSpace($txtSiteCode.Text) -or
            [string]::IsNullOrWhiteSpace($txtIntuneUtil.Text) -or
            [string]::IsNullOrWhiteSpace($txtOutputDir.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please fill out Site Code, Output Directory, and IntuneWinAppUtil path.", "Validation Error", 0, 16)
            return
        }
    }

    if ($rbMode3.Checked) {
        if ([string]::IsNullOrWhiteSpace($txtUploadFile.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please select an existing .intunewin package to upload.", "Validation Error", 0, 16)
            return
        }
    }

    if ($rbMode2.Checked -or $rbMode3.Checked) {
        if ([string]::IsNullOrWhiteSpace($txtTenantID.Text) -or [string]::IsNullOrWhiteSpace($txtClientID.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please provide Tenant ID and Client ID for Intune operations.", "Validation Error", 0, 16)
            return
        }
        if (-not (Get-Module -ListAvailable -Name IntuneWin32App)) {
            [System.Windows.Forms.MessageBox]::Show("IntuneWin32App module is not installed. Please install it first using the 'Install Module' button.", "Module Missing", 0, 48)
            return
        }
        Import-Module IntuneWin32App -ErrorAction SilentlyContinue
    }

    $script:OpMode = if ($rbMode1.Checked) { 1 } elseif ($rbMode2.Checked) { 2 } else { 3 }
    $script:SiteCode = $txtSiteCode.Text
    $script:OutputDirectory = $txtOutputDir.Text
    $script:IntuneWinUtilPath = $txtIntuneUtil.Text
    $script:TenantID = $txtTenantID.Text
    $script:ClientID = $txtClientID.Text
    $script:UploadFile = $txtUploadFile.Text
    $script:AutoUpload = $rbMode2.Checked

    $script:ConfigValid = $true
    $configForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $configForm.Close()
})
$configForm.Controls.Add($btnInit)

$configForm.ShowDialog() | Out-Null

if (-not $script:ConfigValid) { exit }

if ($script:OpMode -eq 3) {
    if (-not (Test-Path $script:UploadFile)) {
        [System.Windows.Forms.MessageBox]::Show("Selected .intunewin file does not exist.", "Error", 0, 16) | Out-Null
        exit
    }

    $fileDir = Split-Path $script:UploadFile -Parent
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($script:UploadFile)

    # Look for matching json
    $jsonPath = Join-Path $fileDir "$fileNameWithoutExt`_Metadata.json"
    if (-not (Test-Path $jsonPath)) {
        $jsonPath = Join-Path $fileDir "$fileNameWithoutExt.json"
    }

    if (-not (Test-Path $jsonPath)) {
        [System.Windows.Forms.MessageBox]::Show("Could not find matching metadata JSON file in the same directory (`"$fileNameWithoutExt`_Metadata.json`" or `"$fileNameWithoutExt.json`").", "Missing Metadata", 0, 16) | Out-Null
        exit
    }

    $metadata = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json

    # Progress UI
    $formProgress = New-Object System.Windows.Forms.Form
    $formProgress.Text = "Uploading Existing Package"
    $formProgress.Size = New-Object System.Drawing.Size(500, 200)
    $formProgress.StartPosition = "CenterScreen"
    $formProgress.FormBorderStyle = 'FixedDialog'
    $formProgress.MaximizeBox = $false
    $formProgress.BackColor = [System.Drawing.Color]::SlateGray
    $formProgress.ForeColor = [System.Drawing.Color]::White

    $lblProg = New-Object System.Windows.Forms.Label
    $lblProg.Text = "Connecting to MS Graph..."
    $lblProg.Location = New-Object System.Drawing.Point(20, 20)
    $lblProg.AutoSize = $true
    $lblProg.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $formProgress.Controls.Add($lblProg)

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Multiline = $true
    $txtLog.ReadOnly = $true
    $txtLog.ScrollBars = "Vertical"
    $txtLog.Location = New-Object System.Drawing.Point(20, 50)
    $txtLog.Size = New-Object System.Drawing.Size(440, 90)
    $txtLog.BackColor = [System.Drawing.Color]::Black
    $txtLog.ForeColor = [System.Drawing.Color]::LightGreen
    $formProgress.Controls.Add($txtLog)

    $formProgress.Show()
    [System.Windows.Forms.Application]::DoEvents()

    function Write-LogUI_Upload {
        param([string]$Message)
        $txtLog.AppendText("$Message`r`n")
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    try {
        Write-LogUI_Upload "Authenticating to Intune via Graph..."
        Connect-MSIntuneGraph -TenantId $script:TenantID -ClientId $script:ClientID -ErrorAction Stop

        Write-LogUI_Upload "Uploading package to Intune..."
        Add-IntuneWin32App -FilePath $script:UploadFile `
                           -DisplayName $metadata.Name `
                           -Description $metadata.Description `
                           -Publisher $metadata.Developer `
                           -InstallCommandLine $metadata.InstallCommand `
                           -UninstallCommandLine $metadata.UninstallCommand `
                           -InformationUrl "https://example.com" `
                           -ErrorAction Stop

        Write-LogUI_Upload "Upload Complete!"
        [System.Windows.Forms.MessageBox]::Show("Successfully uploaded $($metadata.Name) to Intune.", "Upload Complete", 0, 64) | Out-Null
    } catch {
        Write-LogUI_Upload "[ERROR] Upload failed: $_"
        [System.Windows.Forms.MessageBox]::Show("Failed to upload package.`n`nError: $_", "Upload Error", 0, 16) | Out-Null
    } finally {
        $formProgress.Close()
        exit
    }
}


if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# ==============================================================================
# LOCATE AND IMPORT SCCM MODULE
# ==============================================================================
Write-Host "Locating SCCM Admin Console..." -ForegroundColor Cyan

$sccmModulePath = ""
if ($env:SMS_ADMIN_UI_PATH) {
    $sccmModulePath = Join-Path (Split-Path $env:SMS_ADMIN_UI_PATH -Parent) "ConfigurationManager.psd1"
} else {
    $pathsToTry = @(
        "${env:ProgramFiles(x86)}\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1",
        "${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1",
        "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"
    )
    foreach ($path in $pathsToTry) {
        if (Test-Path $path) {
            $sccmModulePath = $path
            break
        }
    }
}

if (-not (Test-Path $sccmModulePath)) {
    Write-Host "[ERROR] SCCM Admin Console module not found." -ForegroundColor Red
    exit
}

Write-Host "Importing SCCM Module..." -ForegroundColor Cyan
Import-Module $sccmModulePath -ErrorAction Stop

$siteDrive = "$($SiteCode):"
if (-not (Test-Path $siteDrive)) {
    Write-Host "[ERROR] Could not connect to SCCM Site Drive ($siteDrive)." -ForegroundColor Red
    exit
}
Set-Location $siteDrive

# ==============================================================================
# FETCH APPLICATIONS AND OPEN GUI
# ==============================================================================
Write-Host "Fetching all applications from SCCM. This might take a moment..." -ForegroundColor Cyan
$allApps = Get-CMApplication -Fast

if (-not $allApps) {
    Write-Host "[WARNING] No applications found in SCCM." -ForegroundColor Yellow
    Set-Location "C:"
    exit
}

# --- Custom App Selection GUI ---
$formSelect = New-Object System.Windows.Forms.Form
$formSelect.Text = "Select Application(s) to Extract & Package"
$formSelect.Size = New-Object System.Drawing.Size(600, 500)
$formSelect.StartPosition = "CenterScreen"
$formSelect.FormBorderStyle = 'FixedDialog'
$formSelect.MaximizeBox = $false
$formSelect.BackColor = [System.Drawing.Color]::SlateGray
$formSelect.ForeColor = [System.Drawing.Color]::White

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = "Filter Apps:"
$lblFilter.Location = New-Object System.Drawing.Point(10, 15)
$lblFilter.AutoSize = $true

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(80, 12)
$txtFilter.Size = New-Object System.Drawing.Size(490, 20)

$chkSelectAll = New-Object System.Windows.Forms.CheckBox
$chkSelectAll.Text = "Select All (Filtered)"
$chkSelectAll.Location = New-Object System.Drawing.Point(12, 40)
$chkSelectAll.AutoSize = $true

$clbApps = New-Object System.Windows.Forms.CheckedListBox
$clbApps.Location = New-Object System.Drawing.Point(10, 65)
$clbApps.Size = New-Object System.Drawing.Size(560, 340)
$clbApps.CheckOnClick = $true
$clbApps.ForeColor = [System.Drawing.Color]::Black

$btnExtract = New-Object System.Windows.Forms.Button
$btnExtract.Text = "Extract & Package Selected Apps"
$btnExtract.Location = New-Object System.Drawing.Point(10, 415)
$btnExtract.Size = New-Object System.Drawing.Size(560, 40)
$btnExtract.BackColor = [System.Drawing.Color]::LightBlue
$btnExtract.ForeColor = [System.Drawing.Color]::Black
$btnExtract.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$formSelect.Controls.AddRange(@($lblFilter, $txtFilter, $chkSelectAll, $clbApps, $btnExtract))

$appNames = $allApps | Select-Object -ExpandProperty LocalizedDisplayName | Sort-Object -Unique
function Update-AppList {
    $clbApps.BeginUpdate()
    $clbApps.Items.Clear()
    $f = $txtFilter.Text
    foreach ($a in $appNames) {
        if ([string]::IsNullOrEmpty($f) -or $a -match [regex]::Escape($f)) { $clbApps.Items.Add($a) | Out-Null }
    }
    $clbApps.EndUpdate()
}
Update-AppList

$txtFilter.add_TextChanged({ $chkSelectAll.Checked = $false; Update-AppList })
$chkSelectAll.add_CheckedChanged({
    $clbApps.BeginUpdate()
    for ($i = 0; $i -lt $clbApps.Items.Count; $i++) { $clbApps.SetItemChecked($i, $chkSelectAll.Checked) }
    $clbApps.EndUpdate()
})

$script:chosenAppNames = @()
$btnExtract.add_Click({
    if ($clbApps.CheckedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please check at least one application.", "Warning", 0, 48)
        return
    }
    foreach ($item in $clbApps.CheckedItems) { $script:chosenAppNames += $item.ToString() }
    $formSelect.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $formSelect.Close()
})

$dialogResult = $formSelect.ShowDialog()
if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or $script:chosenAppNames.Count -eq 0) {
    Set-Location "C:"
    exit
}

# ==============================================================================
# EXTRACTION & PACKAGING LOOP (WITH PROGRESS UI)
# ==============================================================================
$selectedApps = $allApps | Where-Object { $_.LocalizedDisplayName -in $script:chosenAppNames }

# --- Build the Live Progress Window ---
$formProgress = New-Object System.Windows.Forms.Form
$formProgress.Text = "SCCM Extractor & Packager"
$formProgress.Size = New-Object System.Drawing.Size(550, 400)
$formProgress.StartPosition = "CenterScreen"
$formProgress.FormBorderStyle = 'FixedDialog'
$formProgress.ControlBox = $false # Hides the 'X' so users don't close it mid-run
$formProgress.TopMost = $true
$formProgress.BackColor = [System.Drawing.Color]::SlateGray
$formProgress.ForeColor = [System.Drawing.Color]::White

$lblApp = New-Object System.Windows.Forms.Label
$lblApp.Location = New-Object System.Drawing.Point(20, 20)
$lblApp.Size = New-Object System.Drawing.Size(500, 20)
$lblApp.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblApp.Text = "Initializing..."

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 45)
$lblStatus.Size = New-Object System.Drawing.Size(500, 20)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblStatus.Text = "Please wait..."

$pb = New-Object System.Windows.Forms.ProgressBar
$pb.Location = New-Object System.Drawing.Point(20, 75)
$pb.Size = New-Object System.Drawing.Size(490, 30)
$pb.Style = 'Continuous'
$pb.Maximum = $selectedApps.Count
$pb.Value = 0

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 115)
$txtLog.Size = New-Object System.Drawing.Size(490, 230)
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.BackColor = [System.Drawing.Color]::Black
$txtLog.ForeColor = [System.Drawing.Color]::LightGray
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Regular)

$formProgress.Controls.AddRange(@($lblApp, $lblStatus, $pb, $txtLog))

function Write-LogUI ($Message) {
    $Timestamp = Get-Date -Format 'HH:mm:ss'
    $txtLog.AppendText("[$Timestamp] $Message`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$formProgress.Show() | Out-Null
[System.Windows.Forms.Application]::DoEvents() # Force UI to paint

if ($AutoUpload) {
    Write-LogUI "Connecting to Intune via MS Graph..."
    try {
        Connect-MSIntuneGraph -TenantId $TenantID -ClientId $ClientID
        Write-LogUI "Successfully connected to Intune Graph."
    } catch {
        Write-LogUI "[ERROR] Failed to connect to Intune Graph: $_"
        exit
    }
}

# --- Begin Loop ---
Set-Location $siteDrive
$TotalProcessed = 0

foreach ($selApp in $selectedApps) {
    # Update UI for new App
    $lblApp.Text = "Processing: $($selApp.LocalizedDisplayName)"
    $lblStatus.Text = "Querying SCCM Deployment Types..."
    [System.Windows.Forms.Application]::DoEvents()

    Write-LogUI "---------------------------------------------------"
    Write-LogUI "Processing: $($selApp.LocalizedDisplayName)"

    $safeAppName = $selApp.LocalizedDisplayName -replace '[\\/:\*\?"<>\|]', '_'
    $deploymentTypes = Get-CMDeploymentType -ApplicationName $selApp.LocalizedDisplayName

    if (-not $deploymentTypes) {
        Write-LogUI " -> No Deployment Types found. Skipping."
        $TotalProcessed++; $pb.Value = $TotalProcessed; [System.Windows.Forms.Application]::DoEvents()
        continue
    }

    $dt = $deploymentTypes | Select-Object -First 1
    $rawXmlText = $dt.SDMPackageXML

    # --- ROBUST XML FALLBACK ---
    $lblStatus.Text = "Extracting raw XML via WMI..."
    [System.Windows.Forms.Application]::DoEvents()

    if ([string]::IsNullOrWhiteSpace($rawXmlText)) { try { $dt.Get(); $rawXmlText = $dt.SDMPackageXML } catch { } }
    if ([string]::IsNullOrWhiteSpace($rawXmlText)) {
        try {
            $wmiDt = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_ConfigurationItem -Filter "CI_ID = $($dt.CI_ID)"
            if ($wmiDt -and $wmiDt.SDMPackageXML) { $rawXmlText = $wmiDt.SDMPackageXML }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($rawXmlText)) { try { $selApp.Get(); $rawXmlText = $selApp.SDMPackageXML } catch { } }
    if ([string]::IsNullOrWhiteSpace($rawXmlText)) {
        try {
            $wmiApp = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_Application -Filter "CI_ID = $($selApp.CI_ID)"
            if ($wmiApp) { $wmiApp.Get(); $rawXmlText = $wmiApp.SDMPackageXML }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($rawXmlText)) {
        Write-LogUI " -> CRITICAL ERROR: SDMPackageXML is empty. Cannot extract app."
        $TotalProcessed++; $pb.Value = $TotalProcessed; [System.Windows.Forms.Application]::DoEvents()
        continue
    }

    [xml]$dtXml = $rawXmlText

    # ---------------------------------------------------------
    # DEEP DESCRIPTION & METADATA EXTRACTION
    # ---------------------------------------------------------
    $lblStatus.Text = "Scraping deep metadata (Descriptions & Dependencies)..."
    [System.Windows.Forms.Application]::DoEvents()

    $AppDescription = ""
    try { $AppDescription = $selApp.LocalizedDescription } catch {}

    if ([string]::IsNullOrWhiteSpace($AppDescription)) {
        try {
            $FullApp = Get-CMApplication -ApplicationName $selApp.LocalizedDisplayName
            if ($FullApp -and $FullApp.LocalizedDescription) { $AppDescription = $FullApp.LocalizedDescription }
            elseif ($FullApp -and $FullApp.LocalizedAppInfos) { $AppDescription = ($FullApp.LocalizedAppInfos | Select-Object -First 1).Description }
        } catch {}
    }

    if ([string]::IsNullOrWhiteSpace($AppDescription)) {
        try {
            $appXmlText = $selApp.SDMPackageXML
            if ([string]::IsNullOrWhiteSpace($appXmlText)) { $selApp.Get(); $appXmlText = $selApp.SDMPackageXML }
            if ([string]::IsNullOrWhiteSpace($appXmlText)) {
                $wmiApp = Get-WmiObject -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_Application -Filter "CI_ID = $($selApp.CI_ID)"
                if ($wmiApp) { $appXmlText = $wmiApp.SDMPackageXML }
            }
            if (-not [string]::IsNullOrWhiteSpace($appXmlText)) {
                [xml]$appXml = $appXmlText
                $descNode = Select-Xml -Xml $appXml -XPath "//*[local-name()='DisplayInfo']//*[local-name()='Info']//*[local-name()='Description']" | Select-Object -First 1 -ExpandProperty Node
                if ($descNode) { $AppDescription = $descNode.InnerText }
                if ([string]::IsNullOrWhiteSpace($AppDescription)) {
                    if ($appXmlText -match '<Description[^>]*>(.*?)</Description>') {
                        $AppDescription = $matches[1] -replace '&lt;', '<' -replace '&gt;', '>' -replace '&amp;', '&'
                    }
                }
            }
        } catch {}
    }

    if ([string]::IsNullOrWhiteSpace($AppDescription)) { $AppDescription = "Not provided in SCCM." }

    $AppDeveloper = ""
    try { $AppDeveloper = $selApp.Publisher } catch {}
    if ([string]::IsNullOrWhiteSpace($AppDeveloper)) { $AppDeveloper = "Unknown" }

    $SupersedenceStr = "None"
    try {
        $sups = Get-CMApplicationSupersedence -ApplicationName $selApp.LocalizedDisplayName -ErrorAction SilentlyContinue
        if ($sups) {
            $supNames = @()
            foreach ($s in $sups) {
                if ($s.SupersededApplicationName) { $supNames += $s.SupersededApplicationName }
                elseif ($s.LocalizedDisplayName) { $supNames += $s.LocalizedDisplayName }
            }
            if ($supNames.Count -gt 0) { $SupersedenceStr = ($supNames | Select-Object -Unique) -join ", " }
        }
    } catch { }

    $DependenciesStr = "None"
    try {
        $deps = Get-CMDeploymentTypeDependency -ApplicationName $selApp.LocalizedDisplayName -DeploymentTypeName $dt.LocalizedDisplayName -ErrorAction SilentlyContinue
        if ($deps) {
            $depNames = @()
            foreach ($d in $deps) {
                if ($d.TargetApplicationName) { $depNames += $d.TargetApplicationName }
                elseif ($d.DependencyGroupName) { $depNames += $d.DependencyGroupName }
            }
            if ($depNames.Count -gt 0) { $DependenciesStr = ($depNames | Select-Object -Unique) -join ", " }
        }
    } catch { }

    # ---------------------------------------------------------
    # EXTRACT CONTENT LOCATION
    # ---------------------------------------------------------
    $lblStatus.Text = "Locating network source paths..."
    [System.Windows.Forms.Application]::DoEvents()

    $ContentLocation = ""
    try { $ContentLocation = $dtXml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location } catch {}

    if ([string]::IsNullOrWhiteSpace($ContentLocation)) {
        $locNode = Select-Xml -Xml $dtXml -XPath "//*[local-name()='Content']/@Location" | Select-Object -ExpandProperty Node
        if ($locNode) { $ContentLocation = $locNode.Value }
    }
    if ([string]::IsNullOrWhiteSpace($ContentLocation)) {
        if ($rawXmlText -match 'Location="(\\\\[^"]+)"') { $ContentLocation = $matches[1] }
        elseif ($rawXmlText -match 'Location="([A-Za-z]:\\[^"]+)"') { $ContentLocation = $matches[1] }
    }

    if ([string]::IsNullOrWhiteSpace($ContentLocation)) {
        Write-LogUI " -> ERROR: Could not find any Source Path in SCCM for this app. Skipping packaging."
        $TotalProcessed++; $pb.Value = $TotalProcessed; [System.Windows.Forms.Application]::DoEvents()
        continue
    }

    $ContentLocation = $ContentLocation.Trim().TrimEnd('\')
    Write-LogUI " -> Source located: $ContentLocation"

    # ---------------------------------------------------------
    # EXTRACT COMMANDS & DETECTION RULES
    # ---------------------------------------------------------
    $lblStatus.Text = "Decoding Enhanced Detection Methods..."
    [System.Windows.Forms.Application]::DoEvents()

    $installCmd = "Unknown"
    $iCmdNode = Select-Xml -Xml $dtXml -XPath "//*[local-name()='InstallCommandLine'] | //*[local-name()='InstallAction']//*[local-name()='Arg' and @Name='CommandLine']" | Select-Object -First 1 -ExpandProperty Node
    if ($iCmdNode) { $installCmd = if ($iCmdNode.InnerText) { $iCmdNode.InnerText } else { $iCmdNode.Value } }

    $uninstallCmd = "Unknown"
    $uCmdNode = Select-Xml -Xml $dtXml -XPath "//*[local-name()='UninstallCommandLine'] | //*[local-name()='UninstallAction']//*[local-name()='Arg' and @Name='CommandLine']" | Select-Object -First 1 -ExpandProperty Node
    if ($uCmdNode) { $uninstallCmd = if ($uCmdNode.InnerText) { $uCmdNode.InnerText } else { $uCmdNode.Value } }

    if ([string]::IsNullOrWhiteSpace($installCmd) -or $installCmd -eq "Unknown") {
        $installCmd = 'powershell -executionPolicy bypass -file "quick.ps1" /SMSLaunch'
    }

    $ReadableDetection = @()
    $SettingsHash = @{}

    $regSettings = Select-Xml -Xml $dtXml -XPath "//*[local-name()='SimpleSetting'][*[local-name()='RegistryDiscoverySource']] | //*[local-name()='RegistrySetting']" | Select-Object -ExpandProperty Node
    if ($regSettings) {
        foreach ($reg in @($regSettings)) {
            $logicalName = if ($reg.LogicalName) { $reg.LogicalName } else { [guid]::NewGuid().ToString() }
            $dataType = if ($reg.DataType) { $reg.DataType } else { "Unknown" }
            $source = Select-Xml -Xml $reg -XPath "*[local-name()='RegistryDiscoverySource']" | Select-Object -First 1 -ExpandProperty Node
            if (-not $source) { $source = $reg }

            $hive = if ($source.HasAttribute('Hive')) { $source.GetAttribute('Hive') } elseif ($source.RootKey) { $source.RootKey.InnerText } else { "Unknown" }
            $keyNode = Select-Xml -Xml $source -XPath "*[local-name()='Key']" | Select-Object -First 1 -ExpandProperty Node
            $key = if ($keyNode) { $keyNode.InnerText } else { "Unknown" }
            $valNode = Select-Xml -Xml $source -XPath "*[local-name()='ValueName']" | Select-Object -First 1 -ExpandProperty Node
            $valName = if ($valNode) { $valNode.InnerText } else { "Default" }

            $SettingsHash[$logicalName] = [PSCustomObject]@{ Type = "Registry"; Key = "$hive\$key"; ValueName = $valName; DataType = $dataType; Processed = $false }
        }
    }

    $fileSettings = Select-Xml -Xml $dtXml -XPath "//*[local-name()='SimpleSetting'][*[local-name()='FileOrFolderDiscoverySource']] | //*[local-name()='FileSystemSetting'] | //*[local-name()='Settings']/*[local-name()='File']" | Select-Object -ExpandProperty Node
    if ($fileSettings) {
        foreach ($fs in @($fileSettings)) {
            $logicalName = if ($fs.LogicalName) { $fs.LogicalName } else { [guid]::NewGuid().ToString() }
            $dataType = if ($fs.DataType) { $fs.DataType } else { "Unknown" }
            $source = Select-Xml -Xml $fs -XPath "*[local-name()='FileOrFolderDiscoverySource']" | Select-Object -First 1 -ExpandProperty Node
            if (-not $source) { $source = $fs }

            $pathNode = Select-Xml -Xml $source -XPath "*[local-name()='Path']" | Select-Object -First 1 -ExpandProperty Node
            $nameNode = Select-Xml -Xml $source -XPath "*[local-name()='FileOrFolderName'] | *[local-name()='Filter']" | Select-Object -First 1 -ExpandProperty Node
            $path = if ($pathNode) { $pathNode.InnerText } else { "" }
            $name = if ($nameNode) { $nameNode.InnerText } else { "" }

            $fullPath = "$path\$name" -replace '\\\\', '\'
            $SettingsHash[$logicalName] = [PSCustomObject]@{ Type = "File"; Key = $fullPath; ValueName = ""; DataType = $dataType; Processed = $false }
        }
    }

    $msiSettings = Select-Xml -Xml $dtXml -XPath "//*[local-name()='Settings']/*[local-name()='MSI'] | //*[local-name()='MsiSetting']" | Select-Object -ExpandProperty Node
    if ($msiSettings) {
        foreach ($msi in @($msiSettings)) {
            $logicalName = if ($msi.LogicalName) { $msi.LogicalName } else { [guid]::NewGuid().ToString() }
            $dataType = if ($msi.DataType) { $msi.DataType } else { "String" }

            $prodCodeNode = Select-Xml -Xml $msi -XPath "*[local-name()='ProductCode']" | Select-Object -First 1 -ExpandProperty Node
            $prodCode = if ($prodCodeNode) { $prodCodeNode.InnerText } else { "" }

            $SettingsHash[$logicalName] = [PSCustomObject]@{ Type = "MSI"; Key = $prodCode; ValueName = ""; DataType = $dataType; Processed = $false }
        }
    }

    $basicMsiNode = Select-Xml -Xml $dtXml -XPath "//*[local-name()='Provider' and text()='MSI']/..//*[local-name()='Arg' and @Name='ProductCode']" | Select-Object -First 1 -ExpandProperty Node
    if ($basicMsiNode) {
        $msiCode = if ($basicMsiNode.HasAttribute('Value')) { $basicMsiNode.GetAttribute('Value') } else { $basicMsiNode.InnerText }
        $ReadableDetection += "Rule Type: MSI`nProduct Code: $msiCode`nDetection Method: Must Exist`n"
    }

    $rules = Select-Xml -Xml $dtXml -XPath "//*[local-name()='Rule']" | Select-Object -ExpandProperty Node
    if ($rules) {
        foreach ($rule in @($rules)) {
            $opNode = Select-Xml -Xml $rule -XPath ".//*[local-name()='Operator']" | Select-Object -First 1 -ExpandProperty Node
            $operator = if ($opNode) { $opNode.InnerText } else { "Exists" }

            $settingRefNode = Select-Xml -Xml $rule -XPath ".//*[local-name()='SettingReference']" | Select-Object -First 1 -ExpandProperty Node
            $constValNode = Select-Xml -Xml $rule -XPath ".//*[local-name()='ConstantValue']" | Select-Object -First 1 -ExpandProperty Node

            if ($settingRefNode -and $SettingsHash.ContainsKey($settingRefNode.GetAttribute("SettingLogicalName"))) {
                $setting = $SettingsHash[$settingRefNode.GetAttribute("SettingLogicalName")]
                $constantValue = if ($constValNode) { $constValNode.GetAttribute("Value") } else { "" }
                $method = $settingRefNode.GetAttribute("Method")

                $ruleBlock = "Rule Type: $($setting.Type)`n"
                if ($setting.Type -eq "MSI") { $ruleBlock += "Product Code: $($setting.Key)`n" } else { $ruleBlock += "Path/Key: $($setting.Key)`n" }
                if ($setting.ValueName -and $setting.ValueName -ne "Default") { $ruleBlock += "Value Name: $($setting.ValueName)`n" }

                if ($method -eq "Count" -and $operator -eq "NotEquals" -and $constantValue -eq "0") {
                    $ruleBlock += "Detection Method: Must Exist`n"
                } elseif ($operator -ne "Exists") {
                    $ruleBlock += "Detection Method: $($setting.DataType) comparison`nOperator: $operator`nValue: $constantValue`n"
                } else {
                    $ruleBlock += "Detection Method: Must Exist`n"
                }

                $ReadableDetection += $ruleBlock
                $setting.Processed = $true
            }
        }
    }

    foreach ($k in $SettingsHash.Keys) {
        if (-not $SettingsHash[$k].Processed) {
            $setting = $SettingsHash[$k]
            $ruleBlock = "Rule Type: $($setting.Type)`n"
            if ($setting.Type -eq "MSI") { $ruleBlock += "Product Code: $($setting.Key)`n" } else { $ruleBlock += "Path/Key: $($setting.Key)`n" }
            if ($setting.ValueName -and $setting.ValueName -ne "Default") { $ruleBlock += "Value Name: $($setting.ValueName)`n" }
            $ruleBlock += "Detection Method: Must Exist`n"
            $ReadableDetection += $ruleBlock
        }
    }

    if (Select-Xml -Xml $dtXml -XPath "//*[local-name()='ScriptDiscoverySource']") { $ReadableDetection += "Rule Type: SCRIPT`nDetection Method: Custom PowerShell/VBScript check.`n" }

    $DetectionOutputStr = if ($ReadableDetection.Count -gt 0) { ($ReadableDetection | Select-Object -Unique) -join "`n-------------------`n" } else { "Manual Check Required." }

    # ---------------------------------------------------------
    # PACKAGE THE APP (.intunewin)
    # ---------------------------------------------------------
    Set-Location "C:"

    if ($AutoUpload) {
        $OutputDirectory = Join-Path $PSScriptRoot "Temp_Intune_Migration"
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }
    }

    if (-not (Test-Path $ContentLocation)) {
        Write-LogUI " -> ERROR: Path found, but inaccessible. Skipping."
        Set-Location $siteDrive
        $TotalProcessed++; $pb.Value = $TotalProcessed; [System.Windows.Forms.Application]::DoEvents()
        continue
    }

    $SetupFile = ""
    $matches = [regex]::Matches($installCmd, '(?i)([^\\/\"''\*?<>|]+?\.(?:exe|msi|ps1|bat|cmd|vbs))')
    foreach ($m in $matches) {
        $candidate = $m.Groups[1].Value.Trim()
        if (Test-Path (Join-Path $ContentLocation $candidate)) {
            $SetupFile = $candidate
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($SetupFile)) {
        $FallbackFile = Get-ChildItem -Path $ContentLocation -Include *.msi, *.exe -Recurse | Select-Object -First 1
        if ($FallbackFile) { $SetupFile = $FallbackFile.Name }
        else {
            $firstFile = Get-ChildItem -Path $ContentLocation -File | Select-Object -First 1
            if ($firstFile) { $SetupFile = $firstFile.Name }
            else { $SetupFile = "Quick.ps1" }
        }
    }

    $lblStatus.Text = "Packaging .intunewin (Window will freeze temporarily during compile)..."
    [System.Windows.Forms.Application]::DoEvents()

    Write-LogUI " -> Generating .intunewin..."
    $Process = Start-Process -FilePath $IntuneWinUtilPath -ArgumentList "-c `"$ContentLocation`" -s `"$SetupFile`" -o `"$OutputDirectory`" -q" -Wait -NoNewWindow -PassThru

    $GeneratedFile = ""
    if ($Process.ExitCode -eq 0) {
        $DefaultOutputName = "$([System.IO.Path]::GetFileNameWithoutExtension($SetupFile)).intunewin"
        $GeneratedFile = Join-Path $OutputDirectory $DefaultOutputName
        if (Test-Path $GeneratedFile) { Rename-Item -Path $GeneratedFile -NewName "$safeAppName.intunewin" -Force }
        $GeneratedFile = Join-Path $OutputDirectory "$safeAppName.intunewin"
        Write-LogUI " -> Packaging Complete: $safeAppName.intunewin"
    } else {
        Write-LogUI " -> Packaging Failed! Exit Code: $($Process.ExitCode)"
    }

    # ---------------------------------------------------------
    # GENERATE THE METADATA JSON FILE
    # ---------------------------------------------------------
    $lblStatus.Text = "Writing Intune Metadata JSON..."
    [System.Windows.Forms.Application]::DoEvents()

    $MetadataObj = [PSCustomObject]@{
        Name = $selApp.LocalizedDisplayName
        Version = $selApp.SoftwareVersion
        Developer = $AppDeveloper
        Description = $AppDescription
        Dependencies = $DependenciesStr
        Supersedence = $SupersedenceStr
        SourcePath = $ContentLocation
        PrimarySetupFile = $SetupFile
        InstallCommand = $installCmd
        UninstallCommand = $uninstallCmd
        DetectionRules = $DetectionOutputStr
        ExtractedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }

    $MetadataFile = Join-Path $OutputDirectory "$safeAppName`_Metadata.json"
    $MetadataObj | ConvertTo-Json -Depth 10 | Set-Content -Path $MetadataFile
    Write-LogUI " -> Metadata Saved: $safeAppName`_Metadata.json"

    # ---------------------------------------------------------
    # AUTO UPLOAD TO INTUNE VIA MS GRAPH
    # ---------------------------------------------------------
    if ($AutoUpload -and $Process.ExitCode -eq 0 -and (Test-Path $GeneratedFile)) {
        $lblStatus.Text = "Uploading directly to Intune via Graph..."
        [System.Windows.Forms.Application]::DoEvents()

        Write-LogUI " -> Uploading $safeAppName to Intune..."
        try {
            # Map metadata and upload
            Add-IntuneWin32App -FilePath $GeneratedFile `
                               -DisplayName $MetadataObj.Name `
                               -Description $MetadataObj.Description `
                               -Publisher $MetadataObj.Developer `
                               -InstallCommandLine $MetadataObj.InstallCommand `
                               -UninstallCommandLine $MetadataObj.UninstallCommand `
                               -InformationUrl "https://example.com" `
                               -ErrorAction Stop

            Write-LogUI " -> Upload Complete!"
        } catch {
            Write-LogUI " -> [ERROR] Upload failed: $_"
        }
    }

    if ($AutoUpload -and (Test-Path $OutputDirectory)) {
        Remove-Item -Path $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }

    $TotalProcessed++
    $pb.Value = $TotalProcessed
    [System.Windows.Forms.Application]::DoEvents()

    Set-Location $siteDrive
}

# ==============================================================================
# 5. FINISH
# ==============================================================================
$formProgress.Close() # Close the progress window
Set-Location "C:"
[System.Windows.Forms.MessageBox]::Show("Successfully processed and packaged $TotalProcessed applications.`n`nOutput Directory: $OutputDirectory", "Extraction Complete", 0, 64) | Out-Null