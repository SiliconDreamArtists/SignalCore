# Globals for external use only.
$Global:SignalFeedbackLevel = @{
    Unspecified           = 0
    SensitiveInformation  = 1
    VerboseInformation    = 2
    Verbose               = 3
    Information           = 4
    Warning               = 8
    Retry                 = 16
    Critical              = 32
}

$Global:SignalFeedbackNature = @{
    Unspecified = "Unspecified"
    Code        = "Code"
    Operations  = "Operations"
    Security    = "Security"
    Content     = "Content"
}

class Signal {
    [string]$Name
    [string]$Level = 'Information'
    [System.Collections.Generic.List[SignalEntry]]$Entries = [System.Collections.Generic.List[SignalEntry]]::new()

    Signal() {}

    Signal([string]$name) {
        $this.Name = $name
    }

    [SignalEntry] LogMessage([string]$level, [string]$message, [string]$nature = "Unspecified", [Exception]$exception = $null) {
        $exceptionMessage = if ($exception) { $exception.Message } else { $null }
        $entry = [SignalEntry]::new($level, $message, $nature, $exceptionMessage)
        $this.Entries.Add($entry)
        $this.UpdateLevel($level)
        return $entry
    }

    [SignalEntry] LogVerbose([string]$message) {
        return $this.LogMessage("Verbose", $message)
    }

    [SignalEntry] LogInformation([string]$message) {
        return $this.LogMessage("Information", $message)
    }

    [SignalEntry] LogWarning([string]$message) {
        return $this.LogMessage("Warning", $message)
    }

    [SignalEntry] LogRetry([string]$message) {
        return $this.LogMessage("Retry", $message)
    }

    [SignalEntry] LogCritical([string]$message) {
        return $this.LogMessage("Critical", $message)
    }

    [void] UpdateLevel([string]$newLevel) {
        $graph = @{
            "Unspecified"          = 0
            "SensitiveInformation" = 1
            "VerboseInformation"   = 2
            "Verbose"              = 3
            "Information"          = 4
            "Warning"              = 8
            "Retry"                = 16
            "Critical"             = 32
        }

        if ($graph[$newLevel] -ge $graph["Critical"]) {
            $this.Level = 'Critical'
        } elseif ($graph[$newLevel] -ge $graph["Warning"] -and $this.Level -ne 'Critical') {
            $this.Level = 'Warning'
        } elseif ($graph[$newLevel] -ge $graph["Information"] -and $this.Level -ne 'Warning' -and $this.Level -ne 'Critical') {
            $this.Level = 'Information'
        } elseif ($graph[$newLevel] -ge $graph["Verbose"] -and $this.Level -eq 'Unspecified') {
            $this.Level = 'Verbose'
        }
    }

    [bool] Failure() {
        return $this.Level -eq 'Critical'
    }

    [bool] Success() {
        return $this.Level -ne 'Critical'
    }

    [Signal] MergeSignal([Signal[]]$signals) {
        foreach ($sig in $signals) {
            if ($null -ne $sig) {
                foreach ($entry in $sig.Entries) {
                    $this.Entries.Add($entry)
                    $this.UpdateLevel($entry.Level)
                }
            }
        }
        return $this
    }

    [bool] MergeSignalAndVerifyFailure([Signal[]]$signals) {
        $this.MergeSignal($signals)
        return $this.Failure()
    }

    [bool] MergeSignalAndVerifySuccess([Signal[]]$signals) {
        $this.MergeSignal($signals)
        return $this.Success()
    }

    [string] ToJson() {
        return $this | ConvertTo-Json -Depth 20 -Compress
    }

    static [Signal] FromJson([string]$json) {
        return $json | ConvertFrom-Json -Depth 20
    }
}
