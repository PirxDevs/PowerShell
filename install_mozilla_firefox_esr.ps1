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
# Mozilla Firefox Installation Script for Automatic Deployment in AD via GPO.
# Add it via Computer Configuration > Policies > Windows Settings > Scripts.
# Specify the desired language code as a script parameter. The default is en-US.
# A list of available codes is available here:
# https://ftp.mozilla.org/pub/firefox/releases/latest-esr/README.txt

param (
    [string]$lang = "en-US"
)

# Set download URL based on architecture
if ([Environment]::Is64BitOperatingSystem) {
    $url = "https://download.mozilla.org/?product=firefox-esr-msi-latest-ssl&os=win64&lang=$lang"
} else {
    $url = "https://download.mozilla.org/?product=firefox-esr-msi-latest-ssl&os=win&lang=$lang"
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

# Check if the package is already installed. If it is, exit the script.
$program = Get-Package -Provider Programs -Name "Mozilla Firefox ESR*" -ErrorAction SilentlyContinue
if ($program) {
    Write-Log "Mozilla Firefox ESR is already installed"
    return
}


# Check if the non-ESR version of package is installed. If it is, uninstall it.
$program = Get-Package -Provider Programs -Name "Mozilla Firefox (*" -ErrorAction SilentlyContinue
if ($program) {
    Write-Log "Uninstalling non-ESR Google Chrome"
    $uninstallString = ([xml]$program.SwidTagText).SoftwareIdentity.Meta.UninstallString
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$uninstallString", "/S" -Wait
}

# Download the MSI package
Write-Log "Downloading $url"
$msiPath = Join-Path $env:TEMP "mozilla_firefox_esr.msi"
curl.exe -sS -L --output $msiPath $url

# Install the MSI package
Write-Log "Installing $msiPath"
if ($enableLogs -eq $true) {
    $msiLogPath = Join-Path $logShare ($env:COMPUTERNAME + "_Mozilla_Firefox_Install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log")
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
