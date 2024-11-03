Using Module "./FileOperation.psm1"
param (
    [Parameter(Mandatory = $true)]
    [string]$sourceDir,

    [Parameter(Mandatory = $true)]
    [string]$destinationDir,

    [Parameter(Mandatory = $false)]
    [int]$depth = 0
)

# Validate source directory
if (-Not (Test-Path -Path $sourceDir -PathType Container)) {
    Write-Error "Source directory '$sourceDir' does not exist."
    exit 1
}

# Validate destination directory
if (-Not (Test-Path -Path $destinationDir -PathType Container)) {
    Write-Error "Destination directory '$destinationDir' does not exist."
    exit 1
}

# convert to full path
$sourceDir = (Get-Item -Path $sourceDir).FullName
$destinationDir = (Get-Item -Path $destinationDir).FullName

# Check if the source and destination directories are the same
if ($sourceDir -eq $destinationDir) {
    Write-Error "Source and destination directories cannot be the same."
    exit 1
}

# Get the list of items in the source directory
$items = Get-ChildItem -Path $sourceDir -Recurse @($null, "-Depth $depth")[$depth -gt 0]

# Copy the directory structure and files
for ($i = 0; $i -lt $items.Count; $i++) {
    $item = $items[$i]

    # Check if source still exists 
    if (-Not (Test-Path -Path $item.FullName)) {
        Write-Output ([FileOperation]::new($item.FullName, $null, $item.PSIsContainer ? "Directory" : "File", "Deleted"))
        continue
    }

    # if it is a directory, create the directory in the destination
    if ($item.PSIsContainer) {
        # replace source directory with destination directory in the path
        $destinationDirPath = $item.FullName -replace [regex]::Escape($sourceDir), $destinationDir
        
        # create the directory in the destination if it does not exist
        if (-Not (Test-Path -Path $destinationDirPath -PathType Container)) {
            # Catch the exception if the directory cannot be created
            try {
                $null = New-Item -Path $destinationDirPath -ItemType Directory -Force
            }
            catch {
                Write-Output ([FileOperation]::new($item.FullName, $destinationDirPath, "Directory", "Failed"))
                Write-Error $_.Exception.Message
                continue
            }
            Write-Output ([FileOperation]::new($item.FullName, $destinationDirPath, "Directory", "Created"))           
            continue
        }
        Write-Output ([FileOperation]::new($item.FullName, $destinationDirPath, "Directory", "Skipped"))
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
        Write-Error $_.Exception.Message
        continue
    }
    Write-Output ([FileOperation]::new($item.FullName, $destinationFilePath, "File", $fileExists ? "Updated" : "Copied"))
}

exit 0