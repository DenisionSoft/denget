### DENGET UPGRADER SCRIPT ###

param (
   [string]$curver,
   [string]$dgpath
)

try {
Write-Quiet "Downloading the latest release from GitHub..."
Invoke-WebRequest -Uri https://github.com/DenisionSoft/denget/releases/latest/download/denget.zip -OutFile "$dgpath\denget.zip" -ErrorAction SilentlyContinue

# check if download was successful
if (!(Test-Path "$dgpath\denget.zip")) {
  Write-Host "Failed to download denget."
  return -1
}

Write-Quiet "Extracting files..."
Expand-Archive -Path "$dgpath\denget.zip" -DestinationPath $dgpath -Force

Write-Quiet "Updating buckets..."
& denget update

Write-Quiet "Cleaning up..."
Remove-Item "$dgpath\denget.zip" -Force
}
catch {
   Write-Host "Error: " -f r -n
   Write-Host "upgrading has failed. Here's an error message:"
   Write-Host $_
   return -1
}

### ADDITIONAL UPGRADE STEPS ###

## 1.0.1 - .dengetrc file was removed

if ([System.Version]$curver -lt [System.Version]"1.0.1") {
   Write-Quiet "Removing .dengetrc file..."
   if(Test-Path "$env:USERPROFILE\.dengetrc") {
      Remove-Item "$env:USERPROFILE\.dengetrc" -Force
   }
}

## 1.1.0 - links folder was added

if ([System.Version]$curver -lt [System.Version]"1.1.0") {
   Write-Quiet "Creating links folder..."
   New-Item -ItemType Directory -Path "$dgpath\links" | Out-Null
}

return 0