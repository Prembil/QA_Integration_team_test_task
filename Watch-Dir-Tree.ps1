param (
    [Parameter(Mandatory = $true)]
    [string]$sourceDir,

    [Parameter(Mandatory = $false, HelpMessage = "Delay in seconds")]
    [int]$watcherDelay = 1
)

<#
# Links:
    https://learn.microsoft.com/en-us/dotnet/api/system.io.filesystemwatcher?view=net-8.0
    https://learn.microsoft.com/en-us/dotnet/fundamentals/runtime-libraries/system-io-filesystemwatcher
    https://learn.microsoft.com/en-us/dotnet/api/system.io.watcherchangetypes?view=net-8.0

# WatcherChangeTypes
    Created     1 	
    Deleted     2 	
    Changed     4 	
    Renamed     8 	
    All         15 	

# Remarks:
    - In some systems, FileSystemWatcher reports changes to files using the short 8.3 file name format. For example, a change to "LongFileName.LongExtension" could be reported as "LongFil~.Lon".
#>

# Define an array of event names
$eventNames = @("Changed", "Created", "Deleted", "Renamed")

# Define the onExit function
function onExit {
    Write-Host "Unregistering FileSystemWatcher events and cleaning up..."
    Get-EventSubscriber | Where-Object { $_.SourceIdentifier -like "FileSystemWatcher.*" } | Unregister-Event
    $watcher.Dispose()
    Write-Host "Watch-Dir-Tree Cleanup complete."
}

# Validate source directory
if (-Not (Test-Path -Path $sourceDir -PathType Container)) {
    Write-Error "Source directory '$sourceDir' does not exist."
    exit 1
}

# Validate watcher delay
if ($watcherDelay -lt 1) {
    Write-Error "Watcher delay must be at least 1 second."
    exit 1
}

# translate path to full path 
$sourceDir = (Get-Item -Path $sourceDir).FullName



# Initialize array to store changes
$global:qChanges = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())

# Define the action to take when a change is detected
$action = {
    param($source, $eArgs)
    # add datetime to the event args
    $eArgs | Add-Member -MemberType NoteProperty -Name "DateTime" -Value (Get-Date)
    # add the structure change to the queue
    $global:qChanges.Enqueue($eArgs)
}

# Register the event to watch the directory
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $sourceDir
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.Filter = "" # Watch all files
# todo: remove
# $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::DirectoryName -bor [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::CreationTime -bor [System.IO.NotifyFilters]::Size

# need to unregister events and clean up when the script exits
try {
    # Register events for different change types
    foreach ($eventName in $eventNames) {
        $null = (Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier "FileSystemWatcher.$eventName" -Action $action)
    }
    
    # Keep the script running to monitor changes
    Write-Host "Watching directory: $sourceDir"
    while ($true) {
        while ($global:qChanges.Count -gt 0) {
            $change = $global:qChanges.Dequeue()
            Write-Output $change
        }
        Start-Sleep -Seconds $watcherDelay
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    onExit
}