# Copyright (C) 2026 Pirx Developers - https://pirx.dev/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# 7-Zip Installation Script for Automatic Deployment in AD via GPO.
# Add it via Computer Configuration > Policies > Windows Settings > Scripts.

# Specify the version and platform of 7-Zip that you wish to install
$urlVersion = "2501"
$fullVersion = "25.01"

# Set download URL
if ([Environment]::Is64BitOperatingSystem) {
    $url = "https://7-zip.org/a/7z$urlVersion-x64.msi"
} else {
    $url = "https://7-zip.org/a/7z$urlVersion.msi"
}

# This script can save the logs to a network share.
# Enable or disable logging by setting this variable to $true or $false.
$enableLogs = $false

# If logging is enabled, specify the network share to which the log files should be saved.
# The network share must have write permission for the SYSTEM group.
$logShare = "\\server.domain.lan\ScriptLogs"

# Construct log file path
$logPath = Join-Path $logShare ($env:COMPUTERNAME + ".log")
# Get script name
$scriptName = [IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

# This function is used to write a message to a log file.
function Write-Log {
    param ([string]$message)
    if ($enableLogs -eq $true) {
        "{0} {1} {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $scriptName, $message |
            Out-File -FilePath $logPath -Append -Encoding UTF8
    }
}

# Check if the MSI package with the specified version is already installed.
# If it is, exit the script.
$msiInstalled = Get-Package -ProviderName msi -Name "7-Zip*$fullVersion*" -ErrorAction SilentlyContinue
if ($msiInstalled) {
    Write-Log "7-Zip $fullVersion is already installed"
    return
}

# Check if the EXE version of package is installed. If it is, uninstall it.
$program = Get-Package -Provider Programs -Name "7-Zip*" -ErrorAction SilentlyContinue
if ($program) {
    Write-Log "Uninstalling non-MSI 7-Zip"
    $uninstallString = ([xml]$program.SwidTagText).SoftwareIdentity.Meta.UninstallString
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$uninstallString", "/S" -Wait
}

# Download the MSI package
Write-Log "Downloading $url"
$msiPath = Join-Path $env:TEMP (Split-Path $url -Leaf)
curl.exe -sS -L --output $msiPath $url

# Install the MSI package
Write-Log "Installing $msiPath"
if ($enableLogs -eq $true) {
    $msiLogPath = Join-Path $logShare ($env:COMPUTERNAME + "_7-Zip_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log")
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart /L*v `"$msiLogPath`"" -Wait -NoNewWindow
}
else {
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -NoNewWindow
}

# Remove downloaded MSI package file
if (Test-Path $msiPath) {
    Write-Log "Deleting $msiPath"
    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
}
