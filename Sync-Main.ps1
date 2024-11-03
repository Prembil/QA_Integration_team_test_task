Using Module "./Logger.psm1"

param (
    [Parameter(Mandatory = $true)]
    [string]$sourceDir,

    [Parameter(Mandatory = $true)]
    [string]$destinationDir,

    [Parameter(Mandatory = $true)]
    [string]$logFilePath
)

<#
    todo:
        dst bigger than src on init
        copy paste of folders creates duplicates
#>


enum JobType : int {
    WatchDirTree
    CopyDir
}

# Function to check if all jobs are in the specified state
function AreAllJobsInState {
    param (
        [Parameter(Mandatory = $true)]
        [array]$jobs,

        [Parameter(Mandatory = $false)]
        [string]$state = "Running"
    )

    foreach ($job in $jobs) {
        if ($job.State -ne $state) {
            return $false
        }
    }
    return $true
}

# # Import the Logger class
# Import-Module -Name "$PSScriptRoot/Log-Data.psm1" -Force -ErrorAction Stop

# Validate log file path
$logDir = Split-Path -Path $logFilePath -Parent
if (-Not (Test-Path -Path $logDir -PathType Container)) {
    Write-Error "Log directory '$logDir' does not exist."
    exit 1
}


[Logger]::SAppendLog($logFilePath, "Sync-Main started.")
# SAppendLog -logFilePath $logFilePath -message "Sync-Main started."

# Validate source directory
if (-Not (Test-Path -Path $sourceDir -PathType Container)) {
    [Logger]::SAppendLog($logFilePath, "Source directory '$sourceDir' does not exist.", [MessageType]::Error)
    exit 1
}

# Validate destination directory
if (-Not (Test-Path -Path $destinationDir -PathType Container)) {
    [Logger]::SAppendLog($logFilePath, "Destination directory '$destinationDir' does not exist.", [MessageType]::Error)
    exit 1
}

# Convert to full path
$sourceDir = (Get-Item -Path $sourceDir).FullName
$destinationDir = (Get-Item -Path $destinationDir).FullName

# Check if the source and destination directories are the same
if ($sourceDir -eq $destinationDir) {
    [Logger]::SAppendLog( "Source and destination directories cannot be the same.", [MessageType]::Error)
    exit 1
}

# Initialize arrays, qInitTree (q1) for initial directory structure and qChanges (q2) for changes
$global:qInitTree = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
$global:qChanges = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())

# Initialize the jobs array
$jobs = @()
# Logger object that keeps the log file open
$logger = $null

try {
    $logger = [Logger]::new($logFilePath)
    
    # Start Watch-Dir-Tree.ps1 as a job
    $jobs += Start-Job -ScriptBlock {
        param ($root, $sourceDir)
        & "$root/Watch-Dir-Tree.ps1" -sourceDir $sourceDir
    } -ArgumentList $PSScriptRoot, $sourceDir
    
    # Start Copy-Dir.ps1 as a job
    $jobs += Start-Job -ScriptBlock {
        param ($root, $sourceDir, $destinationDir)
        & "$root/Copy-Dir.ps1" -sourceDir $sourceDir -destinationDir $destinationDir
    } -ArgumentList $PSScriptRoot, $sourceDir, $destinationDir
   

    # Wait for the initial directory structure to be built and all files to be copied
    while ((AreAllJobsInState($jobs, "Running")) -or $jobs[[JobType]::CopyDir].HasMoreData) {
        $transfers = Receive-Job -Job $jobs[[JobType]::CopyDir] -Wait
        foreach ($transfer in $transfers) {
            $logger.AppendLog($transfer.ToString(), $transfer.Status -eq "Failed" ? [MessageType]::Warning : [MessageType]::Info)
        }
        Start-Sleep -Seconds 1
    }

    # Check exit codes
    if ($jobs[[JobType]::CopyDir] -eq "Failed") {
        $logger.AppendLog("CopyDir Job failed.", [MessageType]::Error)
        exit 1
    }

    $syncDateTime = Get-Date

    while ($jobs[[JobType]::WatchDirTree].State -eq "Running") {
        # Check for changes in the source directory
        $changes = Receive-Job -Job $jobs[[JobType]::WatchDirTree]
        foreach ($change in $Changes) {
            $isoTimestamp = $change.DateTime.ToString("o")
            $changeDestination = $change.FullPath -replace [regex]::Escape($sourceDir), $destinationDir
            switch ($change.ChangeType) {
                "Created" {
                    try {
                        $null = Copy-Item -Path $change.FullPath -Destination $changeDestination -Force
                    }
                    catch {
                        $logger.AppendLog("Failed to create: $($changeDestination) at [$isoTimestamp]", [MessageType]::Warning)
                        break;
                    }
                    $logger.AppendLog("Created: $($change.FullPath) at [$isoTimestamp]")
                }
                "Changed" {
                    try {
                        $null = Copy-Item -Path $change.FullPath -Destination $changeDestination -Force
                    }
                    catch {
                        $logger.AppendLog("Failed to update: $($changeDestination) at [$isoTimestamp]", [MessageType]::Warning)
                        break;
                    }
                    $logger.AppendLog("Changed: $($change.FullPath) at [$isoTimestamp]")
                }
                "Deleted" {
                    try {
                        $null = Remove-Item -Path $changeDestination -Force -Recurse
                    }
                    catch {
                        $logger.AppendLog("Failed to delete: $($changeDestination) at [$isoTimestamp]", [MessageType]::Warning)
                        break;
                    }
                    $logger.AppendLog("Deleted: $($change.FullPath) at [$isoTimestamp]")
                }
                "Renamed" {
                    $changeOldDestination = $change.OldFullPath -replace [regex]::Escape($sourceDir), $destinationDir
                    $failedRename = $false
                    try {
                        $null = Rename-Item -Path $changeOldDestination -NewName $changeDestination -Force
                    }
                    catch {
                        $failedRename = $true
                        $logger.AppendLog("Failed to rename: $($changeDestination) -> $($change.FullPath) at [$isoTimestamp]", [MessageType]::Warning)
                    }
                    try {
                        if ($failedRename -or $syncDateTime -gt $change.DateTime) {
                            $out = & "$PSScriptRoot/Copy-Dir.ps1" -sourceDir $change.FullPath -destinationDir $changeDestination -depth 0
                            $logger.AppendLog($out.ToString(), $out.Status -eq "Failed" ? [MessageType]::Warning : [MessageType]::Info)
                        }
                    }
                    catch {
                        $logger.AppendLog("Failed to copy renamed: $($changeDestination) -> $($change.FullPath) at [$isoTimestamp]", [MessageType]::Warning)
                    }                    
                    $logger.AppendLog("Renamed: $($change.OldFullPath) -> $($change.FullPath) at [$isoTimestamp]")
                }
            }
        }
        Start-Sleep -Seconds 1
    }
}
catch {
    if ($logger) {
        $logger.AppendLog($_.Exception.Message, [MessageType]::Error)
        exit 1
    }
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    # Cleanup
    $jobs | ForEach-Object { $_.Dispose() }
    $logger.Dispose()
    Write-Host "Sync-Main Cleanup complete."
}

