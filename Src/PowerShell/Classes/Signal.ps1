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
    [object]$ReversePointer = $null
    [object]$Jacket = $null
    [object]$Result = $null
    [string]$Name
    [string]$Level = 'Information'
    [System.Collections.Generic.List[SignalEntry]]$Entries = [System.Collections.Generic.List[SignalEntry]]::new()

    Signal() {}

    static [Signal] Start(
        [string]$name
    ) {
        return [Signal]::Start($name, $null)
    }

    static [Signal] Start(
        [string]$name,
        [object]$reversePointer = $null
    ) {
        $opSignal = [Signal]::new()

        $signal = [Signal]::new()
        $signal.Name = $name
        $signal.LogVerbose("Signal '$name' initialized via Start().")

        if ($null -ne $reversePointer) {
            $signal.SetReversePointer($reversePointer) | Out-Null
            if ($reversePointer -is [Signal]) {
                $signal.MergeSignal(@($reversePointer)) | Out-Null
            }
        }

        $opSignal.SetResult($signal)
        $opSignal.LogInformation("✅ Signal created and returned from Start().")
        return $opSignal
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

        if ($Global:SignalLogger -ne $null) {
            try {
                & $Global:SignalLogger.Invoke($this, $entry)
            }
            catch {}
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
#Not done currently, waiting to look for the condition it's required before using it.
#        while ($value -is [Signal]) {
#            $value = $value.GetResult()
#        }

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
        $opSignal = [Signal]::Start("GetResultSignal:$($this.Name)")
        if ($null -ne $this.Result) {
            $opSignal.SetResult($this.Result)
            $opSignal.LogInformation("✅ Result present and returned in new signal.")
        }
        else {
            $opSignal.LogCritical("❌ Result is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal] SetReversePointer([object]$value) {
        $opSignal = [Signal]::Start("SetReversePointer:$($this.Name)")

#Not done currently, waiting to look for the condition it's required before using it.
#        while ($value -is [Signal]) {
#            $value = $value.GetResult()
#        }

        $this.ReversePointer = $value
        $opSignal.LogInformation("🔄 ReversePointer set on signal '$($this.Name)'.")
        $opSignal.SetResult($this)

        return $opSignal
    }

    [object] GetReversePointer() {
        if ($null -ne $this.ReversePointer) {
            $this.LogInformation("✅ Retrieved ReversePointer from signal.")
            return $this.ReversePointer
        }
        else {
            $this.LogWarning("⚠️ No ReversePointer content present in signal.")
            return $null
        }
    }

    [Signal] GetReversePointerSignal() {
        $opSignal = [Signal]::Start("GetReversePointerSignal:$($this.Name)")
        if ($null -ne $this.ReversePointer) {
            $opSignal.SetReversePointer($this.ReversePointer)
            $opSignal.LogInformation("✅ ReversePointer present and returned in new signal.")
        }
        else {
            $opSignal.LogCritical("❌ ReversePointer is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal] SetPointer([object]$value) {
        $opSignal = [Signal]::Start("SetPointer:$($this.Name)")

        while ($value -is [Signal]) {
            $value = $value.GetResult()
        }

        $this.Pointer = $value
        $opSignal.LogInformation("📦 Pointer content set on signal '$($this.Name)'.")
        $opSignal.SetResult($this)

        return $opSignal
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
        $opSignal = [Signal]::Start("GetPointerSignal:$($this.Name)")
        if ($null -ne $this.Pointer) {
            $opSignal.SetPointer($this.Pointer)
            $opSignal.LogInformation("✅ Pointer present and returned in new signal.")
        }
        else {
            $opSignal.LogCritical("❌ Pointer is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal] SetJacket([object]$value) {
        $opSignal = [Signal]::Start("SetJacket:$($this.Name)")

        if ($null -eq $value) {
            $opSignal.LogWarning("⚠️ Jacket value is null; skipping set.")
            $opSignal.SetResult($this)
            return $opSignal
        }

#        while ($value -is [Signal]) {
#            $value = $value.GetResult()
#        }

        $this.Jacket = $value
        $opSignal.LogInformation("🧥 Jacket set on signal '$($this.Name)'.")
        $opSignal.SetResult($this)

        return $opSignal
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
        $opSignal = [Signal]::Start("GetJacketSignal:$($this.Name)")
        if ($null -ne $this.Jacket) {
            $opSignal.SetResult($this.Jacket)
            $opSignal.LogInformation("✅ Jacket returned in new signal.")
        }
        else {
            $opSignal.LogCritical("❌ Jacket is missing in parent signal.")
        }
        return $opSignal
    }

    [Signal[]] GetLineage() {
        $lineage = @()

        if ($this.Pointer -is [Signal]) {
            $lineage += $this.Pointer
            $lineage += $this.Pointer.GetLineage()
        }
        elseif ($this.Pointer -is [System.Collections.IEnumerable]) {
            foreach ($parent in $this.Pointer) {
                if ($parent -is [Signal]) {
                    $lineage += $parent
                    $lineage += $parent.GetLineage()
                }
            }
        }

        return $lineage
    }
}
