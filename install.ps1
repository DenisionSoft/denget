### DENGET INSTALLER SCRIPT ###

param (
   [string]$path = "$env:USERPROFILE\denget"
)

# function - installation aborted (takes write-host message as parameter)
function Write-Aborted {
   param(
      [string]$string
      )
    Write-Host $string @args
    Write-Host "Installation aborted."
}

$dgpath = $path

# check the powershell version, should be 5.1 or higher
if (($PSVersionTable.PSVersion.Major) -lt 5) {
  Write-Aborted "PowerShell version 5.1 or higher is required to run denget. Go to https://microsoft.com/powershell to get the latest version of PowerShell."
  return
}

# check execution policy
$policies = @('Unrestricted', 'RemoteSigned', 'ByPass')
if ((Get-ExecutionPolicy).ToString() -notin $policies) {
  Write-Aborted "To run denget, a PowerShell execution policy should be set to '$($policies -join "' or '")'.`nFor example, run 'Set-ExecutionPolicy RemoteSigned -Scope CurrentUser'."
  return
}

# check if denget is already installed
if (Get-Command denget -ErrorAction SilentlyContinue) {
  Write-Aborted "denget is already installed. Run 'denget upgrade denget' to get the latest version."
  return
}

# create denget folder
if (!(Test-Path $dgpath)) {
  New-Item -ItemType Directory -Path $dgpath -ErrorAction SilentlyContinue | Out-Null
}

# check if successfully created, use HOME if not
if (!(Test-Path $dgpath)) {
  Write-Host "Failed to create denget folder in $dgpath. Using HOME directory instead."
  $dgpath = "$env:USERPROFILE\denget"
  New-Item -ItemType Directory -Path $dgpath -ErrorAction SilentlyContinue | Out-Null
}

# check if failed anyway
if (!(Test-Path $dgpath)) {
  Write-Aborted "Failed to create denget folder in the default path."
  return
}

# download the latest release of denget from a github release
$oldProgressPreference = $ProgressPreference
$global:ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://github.com/DenisionSoft/denget/releases/latest/download/denget.zip -OutFile "$dgpath\denget.zip" -ErrorAction SilentlyContinue
$global:ProgressPreference = $oldProgressPreference

# check if download was successful
if (!(Test-Path "$dgpath\denget.zip")) {
  Write-Aborted "Failed to download denget."
  return
}

# extract the archive
$oldProgressPreference = $ProgressPreference
$global:ProgressPreference = 'SilentlyContinue'
Expand-Archive -Path "$dgpath\denget.zip" -DestinationPath $dgpath -Force
$global:ProgressPreference = $oldProgressPreference

# create folders structure
New-Item -ItemType Directory -Path "$dgpath\apps" | Out-Null
New-Item -ItemType Directory -Path "$dgpath\temp" | Out-Null
New-Item -ItemType Directory -Path "$dgpath\data\buckets" | Out-Null
New-Item -ItemType Directory -Path "$dgpath\data\buckets\main" | Out-Null

# create data.json file
$datajson = @"
{
  "installed": [],
  "sources": [
    {
      "name": "main",
      "url": "https://github.com/DenisionSoft/dgmain"
    }
  ]
}
"@

$datajson | Out-File "$dgpath\data\data.json"

# get the latest main bucket
$oldProgressPreference = $ProgressPreference
$global:ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://github.com/DenisionSoft/dgmain/archive/main.zip -OutFile "$dgpath\main.zip" 
$global:ProgressPreference = $oldProgressPreference

# extract the archive
$oldProgressPreference = $ProgressPreference
$global:ProgressPreference = 'SilentlyContinue'
Expand-Archive -Path "$dgpath\main.zip" -DestinationPath "$dgpath\data\buckets\main" -Force
$global:ProgressPreference = $oldProgressPreference

# move the files to their final destination
Get-ChildItem "$dgpath\data\buckets\main\dgmain-main" | Move-Item -Destination "$dgpath\data\buckets\main" -Force

# cleanup
Remove-Item "$dgpath\denget.zip" -Force
Remove-Item "$dgpath\main.zip" -Force
Remove-Item "$dgpath\data\buckets\main\dgmain-main" -Force -Recurse

# add denget to PATH
# for future sessions
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$dgpath", "User")
# for current session
$env:PATH = "$dgpath;$env:PATH"

# finish
Write-Host "denget was successfully installed! Run 'denget help' to get started or 'denget about' for an overview."