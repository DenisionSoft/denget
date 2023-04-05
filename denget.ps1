param (
   [string]$cmd = "about",
   [string]$name,
   [string]$bucket = $null,
   [string]$path = $null,
   [switch]$version = $false,
   [switch]$help = $false,
   [switch]$force = $false,
   [switch]$quiet = $false
)

$dgver = "1.0.1"

# function - general - Write-Host quiet-sensitive wrapper
function Write-Quiet {
   param(
      [string]$string
      )
    if ($quiet) {
         return
    }
    else {
      Write-Host $string @args
    }
}

# function - general - retrieve denget path
function getdgpath {
   return $PSScriptRoot
}

$dgpath = getdgpath

# function - add a new app to the list of installed apps
function add([string]$item, [string]$bucket, [string]$path) {
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.installed # cast to ArrayList to use Add() method
   [void]$list.Add(@{name = $item; bucket = $bucket; version = $global:appversion; portable = $global:portable; path = $path; executable = $global:executable}) # void to suppress output
   $data.installed = $list
   $data | ConvertTo-Json | Out-File -FilePath "$dgpath\data\data.json"
}

# function - remove an app from the list of installed apps
function remove([string]$item) {
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.installed
   $obj = $list | Where-Object {$_.name -eq $item}
   $list.Remove($obj)
   $data.installed = $list
   $data | ConvertTo-Json | Out-File -FilePath "$dgpath\data\data.json"
}

# function - check if an item is in the list of installed apps
function find([string]$item) {
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.installed
   $obj = $list | Where-Object {$_.name -eq $item}
   if ($null -eq $obj)
   {
      return $false
   }
   else
   {
      return $true
   }
}

# function - check if an item is in a bucket
function findinbucket([string]$item, [string]$bucket) {
   $files = Get-ChildItem -Path "$dgpath\data\buckets\$bucket" | Where-Object {$_.Name -like "*.ps1"}
   foreach ($file in $files)
   {
      if ($file.Name -eq $item + ".ps1")
      {
         return $true
      }
   }
   return $false
}

# function - get a field from the data.json file for an installed item
function getinstalled([string]$item, [string]$field) {
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.installed
   foreach ($i in $list)
   {
      if ($i.name -eq $item)
      {
         return $i.$field
      }
   }
   return $null
}

# function - get the source url of a bucket from sources
function getsourceurl([string]$bucket) {
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.sources
      foreach ($item in $list)
      {
         if ($item.name -eq $bucket)
         {
            return $item.url
         }
      }
      return $null
}

# function - get the path to rclone with priority to denget, then global
function getrclone() {
   if (find -item "rclone")
   {
      $rcpath = getinstalled "rclone" path
      $folder = Get-ChildItem -Path "$rcpath\rclone"
      $folder = $folder.Name
      if ($rcpath -match "/")
      {
         return "$rcpath/rclone/$folder/rclone.exe"
      }
      else
      {
         return "$rcpath\rclone\$folder\rclone.exe"
      }
   }
   if (Get-Command rclone -ErrorAction SilentlyContinue)
   {
      return "rclone"
   }
   else
   {
      return $null
   }
}

# flag - force
if($force)
{
   Write-Quiet "Warning: " -f y -n
   Write-Quiet "running denget with -force may cause issues and damage, proceed with caution."
}

# flag - version
if($version)
{
   Write-Host "denget v$dgver"
   exit
}

# cmd - help
if($cmd -eq "help" -or $help)
{
   $general = $false
   if($name -ne "" -and $help) {
      $pattern = "Command - $cmd \(l[0-9]*\)"
   }
   elseif($name -ne "") {
      $pattern = "Command - $name \(l[0-9]*\)"
   }
   elseif($cmd -ne "help") {
      $pattern = "Command - $cmd \(l[0-9]*\)"
   }
   else {
      $pattern = "General \(l[0-9]*\)"
      $general = $true
   }
   $len = ((Get-Content $dgpath\HELP | Select-String -Pattern $pattern).Matches.Value | Select-String -Pattern '[0-9][0-9]*').Matches.Value
   $text = Get-Content $dgpath\HELP | Select-String -Pattern $pattern -Context 0, $len
   if ($text -eq $null) { Write-Host "Error: " -f r -n; Write-Host "command not found."; exit }
   $text = $text.ToString()
   $text = $text.Remove(0, $text.IndexOf("`n") + 1)
   Write-Host $text
   if($general) {
      Write-Host ""
      Write-Host "  Color coding:"
      Write-Host "      " -n; Write-Host "notes" -f blu
      Write-Host "      " -n; Write-Host "warnings" -f y
      Write-Host "      " -n; Write-Host "errors" -f r
      Write-Host "      " -n; Write-Host "names" -f gre
      Write-Host "      " -n; Write-Host "commands" -f m
   }
   exit
}


# cmd - install an app
if($cmd -eq "install")
{
   if ($name -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name is not specified."
      exit
   }

   if (find -item $name)
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n; Write-Host " is already installed."
      exit
   }

   if ($bucket -eq "")
   {
      Write-Quiet "Note: " -f blu -n
      Write-Quiet "bucket is not specified, using " -n; Write-Quiet "main" -f gre -n; Write-Quiet " bucket."
      $bucket = "main"
   }

   if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
   {
      Write-Host "Error: " -f r -n
      Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " is not available."
      exit
   }

   if (!(findinbucket -item $name -bucket $bucket))
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n; Write-Host " is not in the bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host "."
      exit
   }

   Write-Quiet "Installing " -n; Write-Quiet "$name" -f gre -n; Write-Quiet "."
   $script = "$dgpath\data\buckets\$bucket\" + $name + ".ps1"
   try
   {
      $oldProgressPreference = $ProgressPreference
      $global:ProgressPreference = 'SilentlyContinue'
      & $script -cmd install -path $path -force:$force -quiet:$quiet
   }
   catch
   {
      Write-Host "Error: " -f r -n
      Write-Host "installation failed."
      $global:ProgressPreference = $oldProgressPreference
      exit
   }
   $global:ProgressPreference = $oldProgressPreference

   if ($LASTEXITCODE -eq -1)
   {
      Write-Host "Warning: " -f y -n
      Write-Host "installation aborted."
   }
   else
   {
      if ($portable -and $path -eq '') {$path = "$dgpath\apps"}
      add -item $name -bucket $bucket -path $path
      Remove-Variable appversion -Scope Global
      Remove-Variable portable -Scope Global
      Remove-Variable executable -Scope Global
      Write-Quiet "Installed " -n; Write-Quiet "$name" -f gre -n; Write-Quiet " successfully."
   }
}

# cmd - uninstall an app
if($cmd -eq "uninstall")
{
   if ($name -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name is not specified."
      exit
   }

   # special command - denget uninstall denget
   if ($name -eq "denget")
   {
      if(!($force)) {
         Write-Host "Warning: " -f y -n
         Write-Host "this will also delete all the portable apps you've installed, including their data and start menu shortcuts."
         Write-Host "Desktop shortcuts, created by denget, and non-portable apps won't be removed. Also, any changes that portable apps made outside of denget, such as creating additional files or changing PATH variable, won't be removed too. You might want to delete such apps first."

         Write-Host "Are you sure you want to proceed? (y/n): " -n
         $answer = Read-Host

         if($answer -eq "n" -or $answer -eq "N")
         {
            exit
         }
      }

      $startfolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\denget"
      if(Test-Path "$startfolder")
      {
         Get-ChildItem "$startfolder" -Recurse | Remove-Item -Force -Recurse
         Remove-Item "$startfolder" -Recurse -Force
      }

      $pathvar = [Environment]::GetEnvironmentVariable("Path", "User")
      $pathvar = ($pathvar.Split(';') | Where-Object { $_ -ne "$dgpath" }) -join ';'
      [Environment]::SetEnvironmentVariable("Path", $pathvar, "User")

      Get-ChildItem "$dgpath" -Recurse | Remove-Item -Force -Recurse
      Remove-Item "$dgpath" -Recurse -Force

      Write-Quiet "denget succesfully uninstalled! Hope to see you soon!"
      exit
   }
   
   if (!(find -item $name) -and !($force))
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n; Write-Host " is not installed."
      exit
   }

   if ($bucket -eq "")
   {
      $bucket = getinstalled $name bucket
      if ($bucket -eq "")
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket is not specified and cannot be found in '" -n; Write-Host "data.json" -f gre -n; Write-Host "'."

         if ($force)
         {
            Write-Host "Since you are using -force, try to specify the bucket here: " -n
            $bucket = Read-Host
         }
         else {
            exit
         }
      }
   }

   if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
   {
      Write-Host "Error: " -f r -n
      Write-Host "bucket of origin " -n; Write-Host "$bucket" -f gre -n; Write-Host " is no longer available."
      exit
   }

   if (!(findinbucket -item $name -bucket $bucket))
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n
      Write-Host " is not in the bucket " -n
      Write-Host "$bucket" -f gre -n
      Write-Host " where it originated. If you want to uninstall " -n
      Write-Host "$name" -f gre -n
      Write-Host " using a manifest from another bucket, specify the bucket with '" -n
      Write-Host "-bucket" -f m -n
      Write-Host "' parameter."
      exit
   }

   $path = getinstalled $name path

   Write-Quiet "Uninstalling " -n; Write-Quiet "$name" -f gre -n; Write-Quiet "."
   $script = "$dgpath\data\buckets\$bucket\" + $name + ".ps1"
   $trgversion = getinstalled $name version

   $oldProgressPreference = $ProgressPreference
   $global:ProgressPreference = 'SilentlyContinue'
   & $script -cmd uninstall -path $path -trgversion $trgversion -force:$force -quiet:$quiet
   $global:ProgressPreference = $oldProgressPreference

   if ($LASTEXITCODE -eq -1)
   {
      Write-Host "Warning: " -f y -n
      Write-Host "uninstallation aborted."
   }
   else
   {
      remove -item $name
      Write-Quiet "Uninstalled " -n; Write-Quiet "$name" -f gre -n; Write-Quiet " successfully."
   }
}

# cmd - upgrade an app
if($cmd -eq "upgrade")
{
   if ($name -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name is not specified."
      exit
   }

   # special command - denget upgrade denget
   if ($name -eq "denget")
   {
      $oldProgressPreference = $ProgressPreference
      $global:ProgressPreference = 'SilentlyContinue'
      $tag = (Invoke-WebRequest "https://api.github.com/repos/DenisionSoft/denget/releases" | ConvertFrom-Json)[0].tag_name

      if ($dgver -eq $tag)
      {
         Write-Host "Note: " -f blu -n
         Write-Host "denget is already up to date."
         $global:ProgressPreference = $oldProgressPreference
         exit
      }

      Write-Quiet "Upgrading denget..."
      Write-Quiet "Downloading the latest upgrade script..."
      $download = "https://github.com/DenisionSoft/denget/releases/download/$tag/upgrade.ps1"
      Invoke-WebRequest $download -OutFile "$dgpath\temp\upgrade.ps1"
      $global:ProgressPreference = $oldProgressPreference

      try {
         $oldProgressPreference = $ProgressPreference
         $global:ProgressPreference = 'SilentlyContinue'
         & $dgpath\temp\upgrade.ps1 -dgpath $dgpath -curver $dgver | Out-Null
      }
      catch {
         Write-Host "Error: " -f r -n
         Write-Host "upgrading failed."
         $global:ProgressPreference = $oldProgressPreference
         exit
      }
      $global:ProgressPreference = $oldProgressPreference

      if ($LASTEXITCODE -eq -1)
      {
         Write-Host "Upgrading aborted."
      }
      else
      {
         Write-Quiet "denget was successfully updated!"
      }

      Remove-Item $dgpath\temp\upgrade.ps1 -Force
      exit
   }

   if (!(find -item $name) -and !($force))
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n; Write-Host " is not installed."
      exit
   }

   if (!($quiet)) {
      Write-Host "Warning: " -f y -n
      Write-Host "this command is experimental and updates apps by uninstalling and reinstalling them. This may cause data loss. Use at your own risk."
      & denget status -name $name
      Write-Host "Do you want to proceed and try to upgrade " -n; Write-Host "$name" -f gre -n; Write-Host "? (y/n): " -n
      $answer = Read-Host
   }
   if ($answer -eq "n" -or $answer -eq "N")
   {
      Write-Host "Warning: " -f y -n
      Write-Host "upgrade aborted."
      exit
   }
   else
   {
      if ($bucket -eq "") 
      {
         $bucket = getinstalled $name bucket
      }

      if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket of origin " -n; Write-Host "$bucket" -f gre -n; Write-Host " is not available."
         exit
      }

      if (!(findinbucket -item $name -bucket $bucket))
      {
         Write-Host "Error: " -f r -n
         Write-Host "$name" -f gre -n
         Write-Host " is not in the bucket " -n
         Write-Host "$bucket" -f gre -n
         Write-Host " where it originated. If you want to upgrade " -n
         Write-Host "$name" -f gre -n
         Write-Host " using a manifest from another bucket, specify the bucket with '" -n
         Write-Host "-bucket" -f m -n
         Write-Host "' parameter."
         exit
      }

      $path = getinstalled $name path
      Write-Quiet "Upgrading " -n; Write-Quiet "$name" -f gre -n; Write-Quiet "."
      $script = "$dgpath\data\buckets\$bucket\" + $name + ".ps1"
      $trgversion = getinstalled $name version

      $oldProgressPreference = $ProgressPreference
      $global:ProgressPreference = 'SilentlyContinue'
      & $script -cmd uninstall -path $path -trgversion $trgversion -force -quiet
      $global:ProgressPreference = $oldProgressPreference

      if ($LASTEXITCODE -eq -1)
      {
         Write-Host "Warning: " -f y -n
         Write-Host "uninstallation aborted. Aborting upgrade."
         exit
      }
      else
      {
         remove -item $name
      }

      $oldProgressPreference = $ProgressPreference
      $global:ProgressPreference = 'SilentlyContinue'
      & $script -cmd install -path $path -force -quiet
      $global:ProgressPreference = $oldProgressPreference

      if ($LASTEXITCODE -eq -1)
      {
         Write-Host "Warning: " -f y -n
         Write-Host "installation aborted. Aborting upgrade."
         Write-Host "Note: " -f blu -n
         Write-Host "the previous version of " -n; Write-Host "$name" -f gre -n; Write-Host " was uninstalled, try to reinstall it using '" -n; Write-Host "denget install $name $bucket" -f m -n; Write-Host "'."
         exit
      }
      else
      {
         if ($portable -and $path -eq '') {$path = "$dgpath\apps"}
         add -item $name -bucket $bucket -path $path
         Remove-Variable appversion -Scope Global
         Remove-Variable portable -Scope Global
      }

      Write-Quiet "Upgraded " -n; Write-Quiet "$name" -f gre -n; Write-Quiet " successfully."
      exit
   }
}

# cmd - list installed apps
if($cmd -eq "list")
{
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.installed
   if ($list.Count -eq 0)
   {
      Write-Host "There are no installed apps."
      exit
   }
   Write-Host "Installed apps:"
   if ($name -eq "full")
   {
      $list | Sort-Object -Property name | Select-Object -Property name, version, bucket, @{Name='portable';Expression={"$($_.portable)"}}, path, executable | Format-Table -AutoSize
      exit
   }
   else
   {
      $list | Sort-Object -Property name | Select-Object -Property name, version, bucket, @{Name='portable';Expression={"$($_.portable)"}}, path | Format-Table -AutoSize
      exit
   }
}

# cmd - list available to install apps in their buckets
if($cmd -eq "available")
{
   $buckets = Get-ChildItem -Path "$dgpath\data\buckets" -Recurse -Directory | Select-Object -ExpandProperty Name

   if ($name -ne "")
   {
      if (!(Test-Path -Path "$dgpath\data\buckets\$name"))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$name" -f gre -n; Write-Host " doesn't exist."
         exit
      }
      $buckets = $name
   }
   if ($bucket -ne "")
   {
      if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$name" -f gre -n; Write-Host " doesn't exist."
         exit
      }
      $buckets = $bucket
   }

   Write-Host "Note: " -f blu -n
   Write-Host "don't forget to update buckets using '" -n
   Write-Host "denget update" -f m -n
   Write-Host "' command."
   Write-Host ""

   if ($buckets.Count -eq 0)
   {
      Write-Host "There are no available buckets."
      exit
   }
   
   Write-Host "Available apps:"

   foreach ($bucket in $buckets)
   {
      Write-Host $bucket -ForegroundColor Green
      $files = Get-ChildItem -Path "$dgpath\data\buckets\$bucket" | Where-Object {$_.Name -like "*.ps1"}
      foreach ($file in $files)
      {
         $name = $file.Name -replace ".ps1"
         Write-Host $name
      }
      Write-Host ""
   }
}

# cmd - check for updates of installed apps
if($cmd -eq "status")
{
   if ($name -ne "")
   {
      # special command - denget status denget
      if ($name -eq "denget")
      {
         $oldProgressPreference = $ProgressPreference
         $ProgressPreference = 'SilentlyContinue'
         $tag = (Invoke-WebRequest "https://api.github.com/repos/DenisionSoft/denget/releases" | ConvertFrom-Json)[0].tag_name
         $ProgressPreference = $oldProgressPreference
         if ($dgver -eq $tag)
         {
            Write-Host "denget is up to date."
         }
         else
         {
            Write-Host "denget installed version: " -n; Write-Host "$dgver" -f gre -n; Write-Host ", available version: " -n; Write-Host "$tag" -f gre
            Write-Host "Update using '" -n; Write-Host "denget upgrade denget" -f m -n; Write-Host "'."
         }
         exit
      }

      if (!(find -item $name) -and !($force))
      {
         Write-Host "Error: " -f r -n
         Write-Host "$name" -f gre -n; Write-Host " is not installed."
         exit
      }

      if ($bucket -eq "")
      {
         $bucket = getinstalled $name bucket
      }

      if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket of origin " -n; Write-Host "$bucket" -f gre -n; Write-Host " is no longer available."
         exit
      }

      if (!(findinbucket -item $name -bucket $bucket))
      {
         Write-Host "Error: " -f r -n
         Write-Host "$name" -f gre -n
         Write-Host " is not in the bucket " -n
         Write-Host "$bucket" -f gre -n
         Write-Host " where it originated. If you want to check for " -n
         Write-Host "$name" -f gre -n
         Write-Host " updates using a manifest from another bucket, specify the bucket with '" -n
         Write-Host "-bucket" -f m -n
         Write-Host "' parameter."
         exit
      }

      $sourcetype = (Select-String -Path "$dgpath\data\buckets\$bucket\$name.ps1" -Pattern 'sourcetype = "[a-zA-Z0-9]*"').Matches.Value -replace 'sourcetype = "'
      $sourcetype = $sourcetype -replace '"'

      if ($sourcetype -eq "resolver")
      {
         $oldProgressPreference = $ProgressPreference
         $ProgressPreference = 'SilentlyContinue'
         $resolver = (Select-String -Path "$dgpath\data\buckets\$bucket\$name.ps1" -Pattern '\$version = .*').Matches.Value -replace '\$version = '
         $newversion = Invoke-Expression $resolver
         $ProgressPreference = $oldProgressPreference
      }
      else
      {
         $newversion = (Select-String -Path "$dgpath\data\buckets\$bucket\$name.ps1" -Pattern 'version = "[a-zA-Z0-9.]*"').Matches.Value -replace 'version = "'
         $newversion = $newversion -replace '"'
      }

      $curversion = getinstalled $name version

      if ($newversion -eq "current")
      {
         Write-Quiet "$name" -f gre -n; Write-Quiet " manifest source type is 'permalink', so it can't be checked for updates."
      }
      elseif ($newversion -eq $curversion)
      {
         Write-Quiet "$name" -f gre -n; Write-Quiet " is up to date."
      }
      else
      {
         Write-Host "$name" -f gre -n; Write-Host " installed version: " -n; Write-Host "$curversion" -f gre -n; Write-Host ", available version: " -n; Write-Host "$newversion" -f gre
         Write-Host "Update using '" -n; Write-Host "denget upgrade $name" -f m -n; Write-Host "'."
      }

      exit
   }  
   else
   {
      $json = Get-Content -Path "$dgpath\data\data.json" -Raw
      $data = $json | ConvertFrom-Json
      [System.Collections.ArrayList]$list = $data.installed
      if ($list.Count -eq 0)
      {
         Write-Host "There are no installed apps."
         exit
      }

      foreach ($item in $list)
      {
         $name = $item.name
         $bucket = $item.bucket
         
         & denget status -name $name -bucket $bucket -quiet
      }

      Write-Host "Checked for updates. If nothing is displayed, all apps are up to date or can't be checked for updates."
   }
}

# cmd - search for an app in available buckets
if($cmd -eq "search")
{
   if ($name -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name is not specified."
      exit
   }

   $found = $false
   $buckets = Get-ChildItem -Path "$dgpath\data\buckets" -Recurse -Directory | Select-Object -ExpandProperty Name
   foreach ($bucket in $buckets)
   {
      $files = Get-ChildItem -Path "$dgpath\data\buckets\$bucket" | Where-Object {$_.Name -like "*.ps1"}
      foreach ($file in $files)
      {
         $appname = $file.Name -replace ".ps1"
         if ($appname -like "*$name*")
         {
            Write-Host $bucket -ForegroundColor Green
            Write-Host $appname
            Write-Host ""
            $found = $true
         }
      }
   }
   if ($found -eq $false)
   {
      Write-Host "Nothing found in available buckets."
   }
}

# cmd - show a path to an app
if($cmd -eq "which")
{
   if ($name -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name is not specified."
      exit
   }

   # special command - denget which denget
   if ($name -eq "denget")
   {
      Write-Host "$dgpath"
      exit
   }

   if (!(find -item $name))
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n
      Write-Host " is not installed."
      exit
   }

   $executable = getinstalled $name executable
   Write-Host $executable
}

# cmd - launch an installed app
if($cmd -eq "launch")
{
   if ($name -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name is not specified."
      exit
   }

   if (!(find -item $name))
   {
      Write-Host "Error: " -f r -n
      Write-Host "$name" -f gre -n
      Write-Host " is not installed."
      exit
   }

   $executable = getinstalled $name executable

   if (!(Test-Path $executable))
   {
      Write-Host "Error: " -f r -n
      Write-Host "executable file " -n
      Write-Host "$executable" -f gre -n
      Write-Host " does not exist."
      exit
   }
   
   Write-Host "Put arguments if needed and press Enter."
   Write-Host "> $name " -NoNewline
   $command = Read-Host
   if ($command -eq "")
   {
      & $executable
   }
   else
   {
      & $executable $command
   }

   exit
}

# cmd - update all buckets using denget bucket update command recursively for each bucket
if($cmd -eq "update")
{
   $oldProgressPreference = $ProgressPreference
   $ProgressPreference = 'SilentlyContinue'
   $tag = (Invoke-WebRequest "https://api.github.com/repos/DenisionSoft/denget/releases" | ConvertFrom-Json)[0].tag_name
   $ProgressPreference = $oldProgressPreference
   if (!($dgver -eq $tag))
   {
      Write-Host "Note: " -f blu -n
      Write-Host "denget is out of date. To ensure safe bucket updates upgrade to the latest version using '" -n
      Write-Host "denget upgrade denget" -f m -n
      Write-Host "'."
      Write-Host ""
   }

   if (!(Get-Command git -ErrorAction SilentlyContinue))
   {
      Write-Host "Error: " -f r -n
      Write-Host "git is not installed. Please install it and try again. You can add a bucket manually by putting a folder with apps manifests in '" -n; Write-Host "denget\data\buckets" -f gre -n; Write-Host "' folder."
      exit
   }

   $buckets = Get-ChildItem -Path "$dgpath\data\buckets" -Recurse -Directory | Select-Object -ExpandProperty Name
   foreach ($bucket in $buckets)
   {
      Write-Host "Updating bucket $bucket" -ForegroundColor Green
      & denget -cmd bucket -name update -bucket $bucket
      Write-Host ""
   }
   Write-Host "Finished updating all buckets." -ForegroundColor Green
}

# cmd - buckets related commands
if($cmd -eq "bucket")
{
   if ($name -eq "")
   {
      & denget -cmd help -name bucket
      exit
   }

   if ($name -eq "list")
   {
      $files = Get-ChildItem -Path "$dgpath\data\buckets"
      if ($files.Count -eq 0)
      {
         Write-Host "There are no installed buckets."
         exit
      }
      Write-Host "Available buckets:"
      foreach ($file in $files)
      {
         Write-Host $file.Name
      }
      exit
   }

   # all functions below require bucket name
   if ($bucket -eq "")
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket name is not specified."
         exit
      }

   if ($name -eq "remove")
   {
      if ($bucket -eq "main" -and !($force))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " is a default bucket and cannot be removed."
         exit
      }

      if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " doesn't exist."
         exit
      }

      Remove-Item -Path "$dgpath\data\buckets\$bucket" -Recurse -Force
      Write-Quiet "Bucket " -n; Write-Quiet "$bucket" -f gre -n; Write-Quiet " removed successfully!"
      exit
   }

   # all functions below require git to be installed
   if (!(Get-Command git -ErrorAction SilentlyContinue))
   {
      Write-Host "Error: " -f r -n
      Write-Host "git is not installed. Please install it and try again. You can add a bucket manually by putting a folder with apps manifests in '" -n; Write-Host "denget\data\buckets" -f gre -n; Write-Host "' folder."
      exit
   }

   if ($name -eq "add")
   {
      if (Test-Path -Path "$dgpath\data\buckets\$bucket")
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " already exists."
         exit
      }

      $url = getsourceurl -bucket $bucket
      if ($null -eq $url)
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " isn't in the list of sources in '" -n; Write-Host "data.json" -f gre -n; Write-Host "'. Configure its source first using '" -n; Write-Host "denget source add" -f m -n; Write-Host "'."
         exit
      }
      Write-Quiet "Attempting to add bucket " -n; Write-Quiet "$bucket" -f gre -n; Write-Quiet " from source " -n; Write-Quiet "$url" -f gre -n; Write-Quiet "..."
      try {
         git clone $url "$dgpath\data\buckets\$bucket" -q
      }
      catch {
         Write-Host "Error occured." -ForegroundColor Red
         exit
      }
      $exitcode = $LASTEXITCODE
      if ($exitcode -eq 0)
      {
         Write-Quiet "Bucket " -n; Write-Quiet "$bucket" -f gre -n; Write-Quiet " added successfully! To update it, use '" -n; Write-Quiet "denget bucket update $bucket" -f m -n; Write-Quiet "'."
      }
      else
      {
         Write-Host "Error: " -f r -n
         Write-Host "repository doesn't exist or other error occured."
      }
      exit
   }

   if ($name -eq "update")
   {
      if (!(Test-Path -Path "$dgpath\data\buckets\$bucket"))
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " doesn't exist."
         exit
      }

      $url = getsourceurl -bucket $bucket
      if ($null -eq $url)
      {
         Write-Host "Error: " -f r -n
         Write-Host "bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " isn't in the list of sources in '" -n; Write-Host "data.json" -f gre -n; Write-Host "'."
         exit
      }
      Write-Quiet "Attempting to update bucket " -n; Write-Quiet "$bucket" -f gre -n; Write-Quiet "..."

      # main bucket is not a git repository from the start, so we need to add it
      if ($bucket -eq "main" -and !(Test-Path -Path "$dgpath\data\buckets\$bucket\.git"))
      {
         Remove-Item -Path "$dgpath\data\buckets\$bucket" -Recurse -Force
         git clone $url "$dgpath\data\buckets\$bucket" -q
      }

      try {
         git -C "$dgpath\data\buckets\$bucket" pull -q
      }
      catch {
         Write-Host "Error occured." -ForegroundColor Red
         exit
      }
      $exitcode = $LASTEXITCODE
      if ($exitcode -eq 0)
      {
         Write-Quiet "Bucket " -n; Write-Quiet "$bucket" -f gre -n; Write-Quiet " updated successfully!"
         exit
      }
      else
      {
         Write-Host "Error occured." -ForegroundColor Red
         exit
      }
   }
}

# cmd - cloud/rclone related commands
if($cmd -eq "cloud")
{
   if ($name -eq "")
   {
      & denget -cmd help -name cloud
      exit
   }

   if ($name -eq "support")
   {
      $temp = getrclone
      if (!($null -eq $temp))
      {
         Write-Host "rclone is already installed, cloud support is enabled."
         if ($temp -eq "rclone")
         {
            $temp2 = where.exe rclone
            Write-Host "Using globally installed rclone at " -n; Write-Host "$temp2" -f gre
            Write-Host ""
            Write-Host "Note: " -f blu -n
            Write-Host "it's recommended to use the rclone installed via denget for clean remotes management by keeping all in one place."
            Write-Host "When installed via denget, it will automatically be used as a default rclone for cloud support."
            Write-Host "Also, the 'rclone.conf' file will be available to edit using '" -n; Write-Host "denget config" -f m -n; Write-Host "'."
            Write-Host "You can install rclone via denget by running '" -n; Write-Host "denget install rclone" -f m -n; Write-Host "'. You'll have to reconfigure your remotes if you already have them configured on the global rclone."
            exit
         }
         Write-Host "Using rclone at " -n; Write-Host "$temp" -f gre
         exit
      }

      Write-Host "denget supports cloud storage via rclone as a source for apps."
      Write-Host ""
      Write-Host "To use manifests that get apps from cloud storages you need to install rclone."
      Write-Host "You can install rclone via denget by running '" -n; Write-Host "denget install rclone" -f m -n; Write-Host "'. It's recommended to use the rclone installed via denget for cleaner remotes management by keeping everything denget related in one separate place."
      Write-Host "When installed via denget, it will automatically be used as a default rclone for cloud support."
      Write-Host "Also, the 'rclone.conf' file will be available to edit using '" -n; Write-Host "denget config" -f m -n; Write-Host "'."
      Write-Host ""
      Write-Host "You can also install rclone globally using any method available."
      Write-Host "It's only required to be available via 'rclone' command from your terminal."

      if (Get-Command scoop -ErrorAction SilentlyContinue)
      {
         Write-Host ""
         Write-Host "Note: " -f blu -n
         Write-Host "denget detected that you have scoop installed. You can install rclone globally by running '" -n; Write-Host "scoop install rclone" -f m -n; Write-Host "'."
      }
      exit
   }

   # all functions below require rclone to be installed
   $remote = $bucket # for consistency
   $rclone = getrclone
   if ($null -eq $rclone)
   {
      Write-Host "Error: " -f r -n
      Write-Host "rclone is not installed. Please refer to '" -n; Write-Host "denget cloud support" -f m -n; Write-Host "'."
      exit
   }

   if ($name -eq "list")
   {
      $remotes = & $rclone listremotes -q
      if ($null -eq $remotes)
      {
         Write-Host "No remotes configured."
         exit
      }

      if ($remote -eq "")
      {
         Write-Host "Available remotes:"
         Write-Host $remotes
         exit
      }
      else {
         if (!($remote.EndsWith(":")))
         {
            $remote = $remote + ":"
         }

         if (!($remotes -contains $remote))
         {
            Write-Host "Error: " -f r -n
            Write-Host "remote " -n; Write-Host "$remote" -f gre -n; Write-Host " doesn't exist."
            exit
         }
         Write-Host "Remote " -n; Write-Host "$remote" -f gre -n; Write-Host " contents:"
         & $rclone ls $remote
      }
   }

   if ($name -eq "add")
   {
      & $rclone config
   }

   if ($name -eq "remove")
   {
      if ($remote -eq "")
      {
         Write-Host "Error: " -f r -n
         Write-Host "remote name is not specified."
         exit
      }

      if (!($remote.EndsWith(":")))
      {
         $remote = $remote + ":"
      }

      $remotes = & $rclone listremotes -q
      if (!($remotes -contains $remote))
      {
         Write-Host "Error: " -f r -n
         Write-Host "remote " -n; Write-Host "$remote" -f gre -n; Write-Host " doesn't exist."
         exit
      }

      Write-Host "Are you sure you want to remove remote " -n; Write-Host "$remote" -f gre -n; Write-Host " ? (y/n): " -n
      $answer = Read-Host
      if ($answer -eq "y" -or $answer -eq "Y")
      {
         & $rclone config delete $remote
      }
   }

}

# cmd - sources in data.json related commands
if($cmd -eq "source")
{
   if ($name -eq "")
   {
      & denget -cmd help -name source
      exit
   }

   # all sources related commands first retrieve the data.json file
   $json = Get-Content -Path "$dgpath\data\data.json" -Raw
   $data = $json | ConvertFrom-Json
   [System.Collections.ArrayList]$list = $data.sources

   if ($name -eq "list")
   {
      if ($list.Count -eq 0)
      {
         Write-Host "No sources configured."
         exit
      }
      Write-Host "Available bucket sources:"
      $list | Select-Object -Property name, url
   }

   if ($name -eq "remove")
   {
      Write-Host "Enter source name to remove: " -NoNewline
      $name = Read-Host

      if ($name -eq "")
      {
         Write-Host "Error: " -f r -n
         Write-Host "source name can't be empty."
         exit
      }

      if ($name -eq "main" -and !($force))
      {
         Write-Host "Error: " -f r -n
         Write-Host "source " -n; Write-Host "main" -f gre -n; Write-Host " can't be removed."
         exit
      }

      $obj = $list | Where-Object {$_.name -eq $name}
      if ($null -eq $obj)
      {
         Write-Host "Error: " -f r -n
         Write-Host "source with name " -n; Write-Host "$name" -f gre -n; Write-Host " doesn't exist."
         exit
      }

      $list.Remove($obj)
      $data.sources = $list
      $data | ConvertTo-Json | Out-File -FilePath "$dgpath\data\data.json"
      Write-Host "Source " -n; Write-Host "$name" -f gre -n; Write-Host " was successfully removed."
   }

   # all functions below require git to be installed
   if (!(Get-Command git -ErrorAction SilentlyContinue))
   {
      Write-Host "Error: " -f r -n
      Write-Host "git is not installed. Please install it and try again. You can add a bucket manually by putting a folder with apps manifests in '" -n; Write-Host "denget\data\buckets" -f gre -n; Write-Host "' folder."
      exit
   }

   if ($name -eq "add")
   {
      Write-Host "Enter source name: " -NoNewline
      $name = Read-Host

      if ($name -eq "")
      {
         Write-Host "Error: " -f r -n
         Write-Host "source name can't be empty."
         exit
      }

      $obj = $list | Where-Object {$_.name -eq $name}
      if (!($null -eq $obj))
      {
         Write-Host "Error: " -f r -n
         Write-Host "source with name " -n; Write-Host "$name" -f gre -n; Write-Host " already exists."
         exit
      }

      Write-Host "Enter source url (in format '" -n; Write-Host "https://github.com/<your_repo>" -f gre -n; Write-Host "' for a GitHub repo): "
      $url = Read-Host

      $response = git ls-remote $url
      if ($null -eq $response)
      {
         Write-Host "Error: " -f r -n
         Write-Host "source url is not accessible via git. Denget only supports git repositories as sources for automatic bucket handling. You can manually add a bucket as a folder in '" -n; Write-Host "denget\data\buckets" -f gre -n; Write-Host "'."
         exit
      }

      [void]$list.Add(@{name = $name; url = $url})
      $data.sources = $list
      $data | ConvertTo-Json | Out-File -FilePath "$dgpath\data\data.json"
      Write-Host "Source " -n; Write-Host "$name" -f gre -n; Write-Host " was successfully added."
   }

   if ($name -eq "edit")
   {
      Write-Host "Enter source name to edit: " -NoNewline
      $name = Read-Host

      if ($name -eq "")
      {
         Write-Host "Error: " -f r -n
         Write-Host "source name can't be empty."
         exit
      }

      if ($name -eq "main" -and !($force))
      {
         Write-Host "Error: " -f r -n
         Write-Host "source " -n; Write-Host "main" -f gre -n; Write-Host " can't be edited."
         exit
      }

      $obj = $list | Where-Object {$_.name -eq $name}
      if ($null -eq $obj)
      {
         Write-Host "Error: " -f r -n
         Write-Host "source with name " -n; Write-Host "$name" -f gre -n; Write-Host " doesn't exist."
         exit
      }

      Write-Host "Enter new source name (leave blank to keep the same): " -NoNewline
      $newname = Read-Host

      if ($newname -eq "" -or $newname -eq $name)
      {
         $newname = $name
      }
      else
      {
         $obj = $list | Where-Object {$_.name -eq $newname}
         if (!($null -eq $obj))
         {
            Write-Host "Error: " -f r -n
            Write-Host "source with name " -n; Write-Host "$name" -f gre -n; Write-Host " already exists."
            exit
         }
      }

      Write-Host "Enter new source url (leave blank to keep the same): " -NoNewline
      $newurl = Read-Host

      if ($newurl -eq "" -or $newurl -eq $obj.url)
      {
         $newurl = $obj.url
      }
      else
      {
         $response = git ls-remote $newurl
         if ($null -eq $response)
         {
            Write-Host "Error: " -f r -n
            Write-Host "source url is not accessible via git. Denget only supports git repositories as sources for automatic bucket handling. You can manually add a bucket as a folder in '" -n; Write-Host "denget\data\buckets" -f gre -n; Write-Host "'."
            exit
         }
      }

      $obj.name = $newname
      $obj.url = $newurl
      $data.sources = $list
      $data | ConvertTo-Json | Out-File -FilePath "$dgpath\data\data.json"
      Write-Host "Source " -n; Write-Host "$newname" -f gre -n; Write-Host " was successfully edited."
   }
}

# cmd - local rclone wrapper
if($cmd -eq "rclone")
{
   $rclone = getrclone
   if ($null -eq $rclone)
   {
      Write-Host "Error: " -f r -n
      Write-Host "rclone is not installed. Please refer to '" -n; Write-Host "denget cloud support" -f m -n; Write-Host "'."
      exit
   }

   Write-Host "> rclone " -NoNewline
   $command = Read-Host

   $rcloneparams = @{
        FilePath     = $rclone
        ArgumentList = $command
        Wait         = $true
        NoNewWindow  = $true
    }
    Start-Process @rcloneparams
}

# cmd - dependencies list
if($cmd -eq "dependencies")
{
   if ($name -eq "" -or $bucket -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name and its bucket must be specified."
      exit
   }

   if (!(Test-Path "$dgpath\data\buckets\$bucket\$name.ps1"))
   {
      Write-Host "Error: " -f r -n
      Write-Host "app " -n; Write-Host "$name" -f gre -n; Write-Host " in bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " doesn't exist."
      exit
   }

   $dlist = (((Select-String -Path "$dgpath\data\buckets\$bucket\$name.ps1" -Pattern 'dependencies = @\(["[a-zA-Z0-9]*"]*[, ]*["[a-zA-Z0-9]*"]*\)').Matches.Value | Select-String -Pattern '"[a-zA-Z0-9]*"' -AllMatches).Matches.Value | Select-String -Pattern '[a-zA-Z0-9]*' -AllMatches).Matches.Value
   if ($dlist.Length -eq 0)
   {
      Write-Host "No dependencies found."
   }
   else
   {
      Write-Host "Dependencies:"
      $dlist | Where-Object {$_ -ne ""} | ForEach-Object {Write-Host $_}
   }
   exit
}

# cmd - show an information about an available app
if($cmd -eq "cat")
{
   if ($name -eq "" -or $bucket -eq "")
   {
      Write-Host "Error: " -f r -n
      Write-Host "app name and its bucket must be specified."
      exit
   }

   if (!(Test-Path "$dgpath\data\buckets\$bucket\$name.ps1"))
   {
      Write-Host "Error: " -f r -n
      Write-Host "app " -n; Write-Host "$name" -f gre -n; Write-Host " in bucket " -n; Write-Host "$bucket" -f gre -n; Write-Host " doesn't exist."
      exit
   }

   Select-String -Path "$dgpath\data\buckets\$bucket\$name.ps1" -Pattern '\$name = \"' -Context 0, 7 | ForEach-Object {$($_.Line; $_.Context.PostContext) | Out-String}
   exit
}

# cmd - list features and their status
if($cmd -eq "features")
{
   Write-Host "denget supports public, cloud and bittorrent sources for apps."

   Write-Host "public" -f gre -n; Write-Host " - always enabled."

   if ($null -eq $(getrclone))
   {
      Write-Host "cloud" -f r -n; Write-Host " - disabled, refer to '" -n; Write-Host "denget cloud support" -f m -n; Write-Host "'."
   }
   elseif (!($(find rclone)))
   {
      Write-Host "cloud" -f y -n; Write-Host " - enabled, but local rclone is recommended. See '" -n; Write-Host "denget cloud support" -f m -n; Write-Host "'."
   }
   else
   {
      Write-Host "cloud" -f gre -n; Write-Host " - enabled."
   }

   if (!($(find aria2)))
   {
      Write-Host "bittorrent" -f r -n;
      Write-Host " - disabled, run '" -n; Write-Host "denget install aria2" -f m -n; Write-Host "'."
   }
   else
   {
      Write-Host "bittorrent" -f gre -n; Write-Host " - enabled."
   }

   Write-Host ""
   Write-Host "denget can help you manage buckets and their sources automatically, which requires git."
   Write-Host "This includes availability of commands 'update', 'bucket add/update', 'source add/edit'."
   if (!(Get-Command git -ErrorAction SilentlyContinue))
   {
      Write-Host "disabled" -f r -n; Write-Host " - install git to your system."
   }
   else
   {
      Write-Host "enabled" -f gre -n; Write-Host " - git is installed."
   }

   Write-Host ""
   Write-Host "denget can use aria2 to download apps faster. If present, it's used by default in manifests with public sources."
   if (!($(find aria2)))
   {
      Write-Host "disabled" -f r -n;
      Write-Host " - run '" -n; Write-Host "denget install aria2" -f m -n; Write-Host "'."
   }
   else
   {
      Write-Host "enabled" -f gre -n; Write-Host " - aria2 is installed."
   }

}

# cmd - edit denget configuration files
if($cmd -eq "config")
{
   if (find rclone)
   {
      $rclone = getrclone
      $configoptions = @("data.json", "rclone.conf")
      $isrclone = $true
      $rclonever = (Get-ChildItem "$dgpath\apps\rclone").Name
      $rcloneconf = "$dgpath\apps\rclone\$rclonever\rclone.conf"
   }
   else
   {
      $configoptions = @("data.json")
      $isrclone = $false
   }

   for ($i = 0; $i -lt $configoptions.Length; $i++)
   {
      Write-Host "$($i + 1) - $($configoptions[$i])"
   }

   Write-Host "Enter a number of a file to edit: " -NoNewline
   $choice = Read-Host

   if ($choice -eq 1) { $file = "$dgpath\data\data.json" }
   elseif ($isrclone -and $choice -eq 2) { $file = $rcloneconf }
   else { Write-Host "Error: " -f r -n; Write-Host "invalid choice."; exit }

   $editoroptions = @()
   $editors = @("nvim", "emacs", "nano", "subl", "atom", "code", "notepad++", "notepad")
   if ((Get-Command vi -ErrorAction SilentlyContinue) -or (Get-Command vim -ErrorAction SilentlyContinue)) { $editoroptions += "vi" }

   foreach ($i in $editors)
   {
      if (Get-Command $i -ErrorAction SilentlyContinue) { $editoroptions += $i }
   }

   Write-Host "denget detected the following editors: " -NoNewline
   Write-Host "$($editoroptions -join ", ")" -f gre
   Write-Host "Type its name or press Enter to use the default editor: " -NoNewline
   $choice = Read-Host
   if ($choice -eq '') { $editor = "Invoke-Item" }
   elseif ($editoroptions -notcontains $choice) { Write-Host "Error: " -f r -n; Write-Host "invalid choice."; exit }
   else { $editor = $choice }

   & $editor $file
}

# cmd - about
if($cmd -eq "about")
{
   Write-Host "denget" -f gre -n; Write-Host " v$dgver"
   Write-Host "denget is a software manager with support for downloading portable applications and regular installers from public`nsources, cloud sources via rclone and bittorrent via aria2."
   Write-Host "It utilizes PowerShell scripts as apps manifests, which comprise buckets that can be added manually or using a 'source'."
   Write-Host "To get software from private cloud storages, denget wraps rclone, so you can upload apps to your cloud storage."
   Write-Host "For usage information, refer to '" -n; Write-Host "denget help [command]" -f m -n; Write-Host "' or to documentation at the denget GitHub repository."
   Write-Host ""
   & Get-Content "$dgpath\LICENSE"
   Write-Host "P.S. Special thanks to Masha who made this possible."
}