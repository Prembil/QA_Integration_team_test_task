# Test task for QA_Integration_team

Github repository by Ing. Premysl Bilek

Mirror one directory to another directory and react to changes in the source directory.

# Input parameters
Input parameters for scripts in this repository

## Sync-Main.ps1

The main script to synchronize two directories. This script will utilize the other scripts in this repository. 

```powershell
[Parameter(Mandatory = $true)]
[string]$sourceDir,

[Parameter(Mandatory = $true)]
[string]$destinationDir,

[Parameter(Mandatory = $true)]
[string]$logFilePath
```

## Watch-Dir-Tree.ps1

Watch and report directory tree changes. 

```powershell
[Parameter(Mandatory = $true)]
[string]$sourceDir,

[Parameter(Mandatory = $false, HelpMessage = "Delay in seconds")]
[int]$watcherDelay = 1
```
`$watcherDelay` is the Write-Output delay in seconds. 

## Mirror-Dir.ps1

Mirror a directory tree.

```powershell
[Parameter(Mandatory = $true)]
[string]$sourceDir,

[Parameter(Mandatory = $true)]
[string]$destinationDir,

[Parameter(Mandatory = $false)]
[int]$depth = 0,

[Parameter(Mandatory = $false, HelpMessage = "Force creation of destination directory")]
[switch]$force
```
`$depth` is the depth of the directory tree to be mirrored. Default is 0, which means all subdirectories and files are copied. 

`$force` is a switch to force the creation of the destination directory.

# Tested On

* Windows 10 Pro 64-bit
  * PowerShell 7.4.6
* Windows 11 Pro 64-bit
  * PowerShell 7.4.6

# Useful Links

* Datetime ISO 8601 - [Datetime ISO 8601](https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings#the-round-trip-o-o-format-specifier)

* System.IO.FileSystemWatcher
  * [FileSystemWatcher](https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher?view=net-8.0)
  * [Remarks](https://learn.microsoft.com/en-us/dotnet/fundamentals/runtime-libraries/system-io-filesystemwatcher)
  * [WatcherChangeTypes Enum](https://learn.microsoft.com/en-us/dotnet/api/system.io.watcherchangetypes?view=net-8.0)
