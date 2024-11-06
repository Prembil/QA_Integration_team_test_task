
class FileOperation {
    [string]$Source
    [string]$Destination
    [string]$Type
    [string]$Status

    FileOperation([string]$source, [string]$destination, [string]$type, [string]$status) {
        $this.Source = $source
        $this.Destination = $destination
        $this.Type = $type
        $this.Status = $status
    }

    [string] ToString() {
        return "Source: '$($this.Source)', Destination: '$($this.Destination)', Type: $($this.Type), Status: $($this.Status)"
    }
}