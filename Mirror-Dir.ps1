Using Module "./FileOperation.psm1"
param (
    [Parameter(Mandatory = $true)]
    [string]$sourceDir,

    [Parameter(Mandatory = $true)]
    [string]$destinationDir,

    [Parameter(Mandatory = $false)]
    [int]$depth = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Force creation of destination directory")]
    [switch]$force
)

$ErrorActionPreference = "Stop"

# Validate source directory
if (-Not (Test-Path -Path $sourceDir -PathType Container)) {
    Write-Error "Source directory '$sourceDir' does not exist."
    exit 1
}

# Validate destination directory
if (-Not (Test-Path -Path $destinationDir -PathType Container)) {
    if (!$force) {
        Write-Error "Destination directory '$destinationDir' does not exist."
        exit 1
    }
    # Force creation of destination directory
    try {
        $null = New-Item -Path $destinationDir -ItemType Directory -Force
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

function RemoveMatchingSrcDst {
    param (
        [string]$srcPath,
        [array]$dstArray
    )
        
    return $dstArray | Where-Object { 
        $wouldBeSrcPath = $_.FullName -replace [regex]::Escape($destinationDir), $sourceDir
        # $wouldBeSrcPath = (Get-Item -Path $wouldBeSrcPath).FullName
        $srcPath -ne $wouldBeSrcPath
    }
}

# convert to full path
$sourceDir = Join-Path -Path (Get-Item -Path $sourceDir).FullName -ChildPath ''
$destinationDir = Join-Path -Path (Get-Item -Path $destinationDir).FullName -ChildPath ''

# Check if the source and destination directories are the same
if ($sourceDir -eq $destinationDir) {
    Write-Error "Source and destination directories cannot be the same."
    exit 1
}
# Check if the source directory is a parent of the destination directory
if ($destinationDir.StartsWith($sourceDir) -or $sourceDir.StartsWith($destinationDir)) {
    Write-Error "Source directory cannot be a subdirectory of the destination directory and vice versa."
    exit 1
}

# Get the list of items in the source directory
$srcItems = Get-ChildItem -Path $sourceDir -Recurse @($null, "-Depth $depth")[$depth -gt 0]
# Get the list of items in the destination directory
$dstItems = Get-ChildItem -Path $destinationDir -Recurse @($null, "-Depth $depth")[$depth -gt 0]

# Copy the directory structure and files
for ($i = 0; $i -lt $srcItems.Count; $i++) {
    $item = $srcItems[$i]

    # Check if source still exists 
    if (-Not (Test-Path -Path $item.FullName)) {
        Write-Output ([FileOperation]::new($item.FullName, $null, $item.PSIsContainer ? "Directory" : "File", "Missing"))
        continue
    }

    # if it is a directory, create the directory in the destination
    if ($item.PSIsContainer) {
        # replace source directory with destination directory in the path
        $destinationDirPath = $item.FullName -replace [regex]::Escape($sourceDir), $destinationDir

        # Skip directory creation if it already exists
        if (Test-Path -Path $destinationDirPath -PathType Container) {
            Write-Output ([FileOperation]::new($item.FullName, $destinationDirPath, "Directory", "Skipped"))
            $dstItems = RemoveMatchingSrcDst $item.FullName $dstItems
            continue
        }
        
        # Catch the exception if the directory cannot be created
        try {
            $null = New-Item -Path $destinationDirPath -ItemType Directory -Force
        }
        catch {
            Write-Output ([FileOperation]::new($item.FullName, $destinationDirPath, "Directory", "Failed Create"))
            Write-Error $_.Exception.Message  -ErrorAction 'Continue'
            continue
        }
        Write-Output ([FileOperation]::new($item.FullName, $destinationDirPath, "Directory", "Created"))           
        continue
    }

    # if it is a file, copy the file to the destination
    $destinationFilePath = $item.FullName -replace [regex]::Escape($sourceDir), $destinationDir
    # $destinationFileParentDir = Split-Path -Path $destinationFilePath -Parent

    # if (-Not (Test-Path -Path $destinationFileParentDir -PathType Container)) {
    #     $null = New-Item -Path $destinationFileParentDir -ItemType Directory -Force
    #     Write-Output ([FileOperation]::new($item.FullName, $destinationFileParentDir, "Directory", "Created"))
    # }

    $fileExists = $false
    # Check if the file already exists in the destination
    if (Test-Path -Path $destinationFilePath -PathType Leaf) {
        $fileExists = $true

        # Compare writetime and size of the file
        $sourceFile = Get-Item -Path $item.FullName
        $destinationFile = Get-Item -Path $destinationFilePath
        if ($sourceFile.LastWriteTime -eq $destinationFile.LastWriteTime -and $sourceFile.Length -eq $destinationFile.Length) {
            $dstItems = RemoveMatchingSrcDst $item.FullName $dstItems
            Write-Output ([FileOperation]::new($item.FullName, $destinationFilePath, "File", "Skipped"))
            continue
        }
    }

    # Copy the file to the destination
    try {
        $null = Copy-Item -Path $item.FullName -Destination $destinationFilePath -Force
    }
    catch {
        Write-Output ([FileOperation]::new($item.FullName, $destinationFilePath, "File", "Failed"))
        Write-Error $_.Exception.Message  -ErrorAction 'Continue'
        continue
    }
    Write-Output ([FileOperation]::new($item.FullName, $destinationFilePath, "File", $fileExists ? "Updated" : "Copied"))
}

# Iterate over the remaining items in the destination directory
for ($i = 0; $i -lt $dstItems.Count; $i++) {
    $item = $dstItems[$i]
    try {
        $null = Remove-Item -Path $item.FullName -Force -Recurse
    }
    catch {
        Write-Output ([FileOperation]::new($null, $item.FullName, $item.PSIsContainer ? "Directory" : "File", "Failed Delete"))
        Write-Error $_.Exception.Message  -ErrorAction 'Continue'
        continue
    }
    Write-Output ([FileOperation]::new($null, $item.FullName, $item.PSIsContainer ? "Directory" : "File" , "Extra"))
}

exit 0