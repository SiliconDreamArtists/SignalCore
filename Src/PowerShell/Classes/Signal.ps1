# Globals for external use only.
$Global:SignalFeedbackLevel = @{
    Unspecified          = 0
    SensitiveInformation = 1
    Verbose              = 2
    Information          = 4
    Warning              = 8
    Retry                = 16
    Recovery             = 24
    Mute                 = 32
    Critical             = 48
}

$Global:SignalFeedbackNature = @{
    Unspecified = "Unspecified"
    Code        = "Code"
    Operations  = "Operations"
    Security    = "Security"
    Content     = "Content"
}

class Signal {
    [object]$Pointer = $null
    [object]$Jacket = $null
    [object]$Result = $null
    [string]$Name
    [string]$Level = 'Information'
    [System.Collections.Generic.List[SignalEntry]]$Entries = [System.Collections.Generic.List[SignalEntry]]::new()

    Signal() {}

    Signal([string]$name) {
        $this.Name = $name
        $this.LogVerbose("Signal '$($this.Name)' initialized.")
        $this.Result = $null
    }

    [SignalEntry] LogMessage([string]$level, [string]$message) {
        return $this.LogMessage($level, $message, "Unspecified", $null)
    }

    [SignalEntry] LogMessage([string]$level, [string]$message, [Exception]$exception = $null) {
        return $this.LogMessage($level, $message, "Unspecified", $exception)
    }

    [SignalEntry] LogMessage([string]$level, [string]$message, [string]$nature = "Unspecified", [Exception]$exception = $null) {
        $exceptionMessage = if ($exception) { $exception.Message } else { $null }
        $entry = [SignalEntry]::new($this, $level, $message, $nature, $exceptionMessage)
        $this.Entries.Add($entry)
        $this.UpdateLevel($level)

        # NEW: External logger support
        if ($Global:SignalLogger -ne $null) {
            try {
                & $Global:SignalLogger.Invoke($this, $entry)
            }
            catch {
                # Fail quietly so Signal Pointer isn't compromised
            }
        }

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

    [SignalEntry] LogRecovery([string]$message) {
        return $this.LogMessage("Recovery", $message)
    }

    [SignalEntry] LogMute([string]$message) {
        return $this.LogMessage("Mute", $message)
    }
        
    # =============================================================================
    # SovereignTrust Signal Escalation Ruleset (v1.1.1)
    # -----------------------------------------------------------------------------
    # - Signal.Level follows a linear severity graph unless explicitly downgraded.
    # - 'Recovery' and 'Mute' are privileged levels that may reduce severity
    #   from 'Critical' to 'Warning' under controlled circumstances.
    # - This allows for lineage-preserving resolution (Recovery) or diagnostic mute (Mute)
    # - All other levels escalate severity only when new > current.
    # =============================================================================
    [void] UpdateLevel([string]$newLevel) {
        $graph = @{
            "Unspecified"          = 0
            "SensitiveInformation" = 1
            "Verbose"              = 2
            "Information"          = 4
            "Warning"              = 8
            "Retry"                = 16
            "Recovery"             = 24
            "Mute"                 = 32
            "Critical"             = 48
        }

        $newValue = $graph[$newLevel]
        $currentValue = $graph[$this.Level]

        switch ($newLevel) {
            "Recovery" {
                if ($this.Level -eq "Critical") {
                    $this.Level = "Warning"
                }
            }
            "Mute" {
                if ($this.Level -eq "Critical") {
                    $this.Level = "Warning"
                }
            }
            default {
                if ($newValue -gt $currentValue) {
                    $this.Level = $newLevel
                }
            }
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
        return $this.MergeSignalAndVerifySuccess($signals, $false)
    }

    [bool] MergeSignalAndVerifySuccess([Signal[]]$signals, [bool]$MuteCritical = $false) {
        return $this.MergeSignalAndVerifySuccess($signals, $MuteCritical, $null)
    }

    [bool] MergeSignalAndVerifySuccess([Signal[]]$signals, [bool]$MuteCritical = $false, [string] $MuteMessage = $null) {
        $this.MergeSignal($signals)

        if ($this.Level -eq "Critical" -and $MuteCritical) {
            if ($null -ne $MuteMessage) {
                $this.LogMute($MuteMessage)
            }
            else {
                $this.LogMute("🔇 Critical signal merged with mute intent, local flow blocked — severity downgraded.")
            }

            # This returns a false so it fails the Verify Success even though it will be successful on the next level / success test.
            return $false
        }

        return $this.Success()
    }

    [string] ToJson() {
        return $this | ConvertTo-Json -Depth 20 -Compress
    }

    static [Signal] FromJson([string]$json) {
        return $json | ConvertFrom-Json -Depth 20
    }

    [void] SetResult([object]$value) {
        # Add or update the "Result" property using dictionary-like update

        # Don't wrap Signals in Signals, they can be passsed in directly so there's less interpretation needed, but we don't wrap a signal in a signal.
        while ($value -is [Signal]) {
            $value = $value.GetResult()
        }

        $this.Result = $value
    }

    [object] GetResult() {
        if ($null -ne $this.Result) {
            $this.LogInformation("✅ Retrieved result from signal.")
            return $this.Result
        }
        else {
            $this.LogCritical("❌ Attempted to retrieve result but no result is present in signal.")
            return $null
        }
    }

    [Signal] GetResultSignal() {
        $childSignal = [Signal]::new("GetResultSignal:$($this.Name)")
        if ($null -ne $this.Result) {
            $childSignal.SetResult($this.Result)
            $childSignal.LogInformation("✅ Result present and returned in new signal.")
        }
        else {
            $childSignal.LogCritical("❌ Result is missing in parent signal.")
        }
        return $childSignal
    }
    # ░▒▓█ Pointer MANAGEMENT █▓▒░

    [void] SetPointer([object]$value) {

        # Don't wrap Signals in Signals, they can be passsed in directly so there's less interpretation needed, but we don't wrap a signal in a signal.
        while ($value -is [Signal]) {
            $value = $value.GetResult()
        }
        
        $this.Pointer = $value
        $this.LogInformation("📦 Pointer content set for signal '$($this.Name)'.")
    }

    [object] GetPointer() {
        if ($null -ne $this.Pointer) {
            $this.LogInformation("✅ Retrieved Pointer from signal.")
            return $this.Pointer
        }
        else {
            $this.LogWarning("⚠️ No Pointer content present in signal.")
            return $null
        }
    }

    [Signal] GetPointerSignal() {
        $childSignal = [Signal]::new("GetPointerSignal:$($this.Name)")
        if ($null -ne $this.Pointer) {
            $childSignal.SetPointer($this.Pointer)
            $childSignal.LogInformation("✅ Pointer present and returned in new signal.")
        }
        else {
            $childSignal.LogCritical("❌ Pointer is missing in parent signal.")
        }
        return $childSignal
    }

    # ░▒▓█ JACKET MANAGEMENT █▓▒░
    [void] SetJacket([object]$value) {
        if ($null -eq $value) {
            $this.LogWarning("⚠️ Jacket value is null; skipping set.")
            return
        }

        # Don't wrap Signals in Signals, they can be passsed in directly so there's less interpretation needed, but we don't wrap a signal in a signal.
        while ($value -is [Signal]) {
            $value = $value.GetResult()
        }
        
        $this.Jacket = $value
        $this.LogInformation("🧥 Jacket set on signal '$($this.Name)'.")
    }

    [object] GetJacket() {
        if ($null -ne $this.Jacket) {
            $this.LogInformation("🧵 Retrieved Jacket from signal.")
            return $this.Jacket
        }
        else {
            $this.LogWarning("⚠️ No Jacket present on signal.")
            return $null
        }
    }

    [Signal] GetJacketSignal() {
        $childSignal = [Signal]::new("GetJacketSignal:$($this.Name)")
        if ($null -ne $this.Jacket) {
            $childSignal.SetResult($this.Jacket)
            $childSignal.LogInformation("✅ Jacket returned in new signal.")
        }
        else {
            $childSignal.LogCritical("❌ Jacket is missing in parent signal.")
        }
        return $childSignal
    }
}
