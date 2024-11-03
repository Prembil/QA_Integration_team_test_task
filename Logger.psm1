<#
# Links:
    https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings#the-round-trip-o-o-format-specifier
#>

enum MessageType {
    Info
    Warning
    Error
}

class Logger : IDisposable {
    [string]$LogFilePath
    [System.IO.StreamWriter]$StreamWriter

    Logger([string]$logFilePath) {
        $this.LogFilePath = $logFilePath
        # Ensure the log file exists
        if (-Not (Test-Path -Path $this.LogFilePath -PathType Leaf)) {
            New-Item -Path $this.LogFilePath -ItemType File -Force | Out-Null
        }
        # Open the StreamWriter
        $this.StreamWriter = [System.IO.StreamWriter]::new($this.LogFilePath, $true)
    }

    static [string] FormatLogEntry([string]$message, [MessageType]$messageType) {
        # ISO 8601
        $timestamp = Get-Date -Format "o"
        return "$timestamp [$messageType] - $message"
    }
    

    static [void] WriteConsole([string]$message) {
        [Logger]::WriteConsole($message, [MessageType]::Info)
    }
    static [void] WriteConsole([string]$message, [MessageType]$messageType) {
        switch ($messageType) {
            Info {
                Write-Host $message
            }
            Warning {
                Write-Warning $message
            }
            Error {
                Write-Error $message
            }
            default {
                Write-Host "[Unknown type] $message"
            }
        }
    }
    
    [void] AppendLog([string]$message) {
        $this.AppendLog($message, [MessageType]::Info)
    }
    [void] AppendLog([string]$message, [MessageType]$messageType) {
        $logEntry = [Logger]::FormatLogEntry($message, $messageType)
        $this.StreamWriter.WriteLine($logEntry)
        [Logger]::WriteConsole($message, $messageType)
    }

    [void] Dispose() {
        $this.StreamWriter.Close()
        $this.StreamWriter.Dispose()
        Write-Host "Logger disposed."
    }

    static [void] SAppendLog([string]$logFilePath, [string]$message) {
        [Logger]::SAppendLog($logFilePath, $message, [MessageType]::Info)
    }
    static [void] SAppendLog([string]$logFilePath, [string]$message, [MessageType]$messageType) {
        # Ensure the log file exists
        if (-Not (Test-Path -Path $logFilePath -PathType Leaf)) {
            New-Item -Path $logFilePath -ItemType File -Force | Out-Null
        }
        $logEntry = [Logger]::FormatLogEntry($message, $messageType)
        Add-Content -Path $logFilePath -Value $logEntry
        [Logger]::WriteConsole($message, $messageType)
    }
}

# function GetNewLoggerClass([string]$logFilePath) {
#     return [Logger]::new($logFilePath)
# }

# function SAppendLog([string]$logFilePath, [string]$message, [MessageType]$messageType = [MessageType]::Info) {
#     return [Logger]::SAppendLog($logFilePath, $message, $messageType)
# }

# # Export the function, which can generate a new instance of the class
# Export-ModuleMember -Function GetNewLoggerClass, SAppendLog, MessageType, Logger