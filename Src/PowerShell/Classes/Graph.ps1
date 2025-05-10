# =============================================================================
# 🧠 Graph (Working Memory using a Grid)
#  License: MIT License • Copyright (c) 2025 Silicon Dream Artists / BDDB
#  Authors: Shadow PhanTom ☠️🧁👾️/🤖 • Neural Alchemist ⚗️☣️🐲 • Last Generated: 05/02/2025
# =============================================================================
# The Graph object represents the live working memory during a conduction which can have an infiniate amount of internal conductions, so a user or ai may open a conduction with a graph and then perform a series of .
# The Graph is a ordered dictionary of Signals, which are the building blocks of the Graph. The Graph has a central Signal itself for tracking current state.
# The Signals in the grid have a Result which is a jacket for the hidden object in the Signal a _Memory which holds the memory of the signal and is transparently accessed with Resolve-PathFromDictionary and Add-PathToDictionary.
# The Result contains the settings for the signal in a dictionary, such as a physical file path, a VirtualPath that provides the wire hierarchy and anything else required, also easily accessible via Resolve-PathFromDictionary and Add-PathToDictionary.

class Graph {
    [object]$ReversePointer = $null
    [Signal]$Signal
    [ordered]$Grid

    Graph() {
        $this.Grid = [ordered]@{}
    }

    static [Signal] Start(
        [string]$name = "Graph",
        [object]$reversePointer = $null,
        [bool]$setPointer = $false
    ) {
        $opSignal = [Signal]::Start("Graph.Start:$name", $reversePointer) | Select-Object -Last 1

        $graph = [Graph]::new()
        $graph.ReversePointer = $reversePointer
        $graph.Signal = [Signal]::Start($name, $reversePointer).GetResult()
        $graph.Signal.LogVerbose("🧠 Graph '$name' initialized via Start().")

        $resultSignal = [Signal]::Start("Graph.Instance:$name", $graph.Signal) | Select-Object -Last 1
        if ($setPointer) {
            $resultSignal.Pointer = $graph
        } else {
            $resultSignal.SetResult($graph)
        }

        $opSignal.MergeSignal(@($resultSignal)) | Out-Null
        $opSignal.SetResult($graph)
        $opSignal.LogInformation("🧠 Graph created and returned from Start().")

        return $opSignal
    }

    [Signal] Finalize() {
        $opSignal = [Signal]::Start("Graph.Finalize", $this.Signal) | Select-Object -Last 1
        $opSignal.LogInformation("✅ Graph condensation finalized. Total registered signals: $($this.Grid.Count)")
        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] RegisterSignal([string]$Key, [Signal]$Signal) {
        $opSignal = [Signal]::Start("RegisterSignal:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Grid.Contains($Key)) {
            $opSignal.LogWarning("⚠️ Overwriting existing signal at key: $Key")
        }

        $this.Grid[$Key] = $Signal
        $opSignal.LogVerbose("🔗 Signal registered under key: $Key")

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] UnRegisterSignal([string]$Key) {
        $opSignal = [Signal]::Start("UnRegisterSignal:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Grid.Contains($Key)) {
            $this.Grid.Remove($Key)
            $opSignal.LogVerbose("🔓 Signal unregistered at key: $Key")
        } else {
            $opSignal.LogWarning("⚠️ Attempted to unregister missing signal at key: $Key")
        }

        $this.Signal.MergeSignal($opSignal)
        return $opSignal
    }

    [Signal] RegisterResultAsSignal([string]$Key, [object]$Result) {
        $opSignal = [Signal]::Start("RegisterResultAsSignal:$Key", $this.Signal) | Select-Object -Last 1
        $resultSignal = [Signal]::Start($Key, $this.Signal).GetResult()
        $resultSignal.SetResult($Result)
        $opSignal.MergeSignal($this.RegisterSignal($Key, $resultSignal))
        return $opSignal
    }

    [object[]] GetKeys() {
        return $this.Grid.Keys
    }

    [Signal] Resolve([string]$Key) {
        $opSignal = [Signal]::Start("Graph.Resolve:$Key", $this.Signal) | Select-Object -Last 1

        if ($this.Grid.Contains($Key)) {
            $resolved = $this.Grid[$Key]
            $opSignal.SetResult($resolved.GetResult())
            $opSignal.LogInformation("✅ Resolved signal at key '$Key'.")
        } else {
            $opSignal.LogWarning("⚠️ No signal registered at key '$Key'.")
        }

        return $opSignal
    }

    [string] ToJson([bool]$IgnoreInternalObjects = $false) {
        $opSignal = [Signal]::Start("Graph.ToJson", $this.Signal) | Select-Object -Last 1

        try {
            $jsonObjectSignal = Convert-GraphToJsonObject -Graph $this -IgnoreInternalObjects:$IgnoreInternalObjects | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($jsonObjectSignal)) {
                $opSignal.LogCritical("❌ Failed to convert Graph to JSON object.")
                return $null
            }

            $json = $jsonObjectSignal.GetResult() | ConvertTo-Json -Depth 25
            return $json
        }
        catch {
            $opSignal.LogCritical("🔥 Exception during Graph.ToJson(): $($_.Exception.Message)")
            return $null
        }
    }

    static [Signal] FromJson([string]$json, [bool]$IgnoreInternalObjects = $false) {
        $opSignal = [Signal]::Start("Graph.FromJson") | Select-Object -Last 1

        try {
            $jsonObject = $json | ConvertFrom-Json -Depth 25

            $conversionSignal = Convert-JsonObjectToGraph -JsonObject $jsonObject -IgnoreInternalObjects:$IgnoreInternalObjects | Select-Object -Last 1
            $opSignal.MergeSignal($conversionSignal)

            if ($conversionSignal.Failure()) {
                $opSignal.LogCritical("❌ Failed to reconstruct Graph from JSON.")
                $opSignal.IsTerminal = $true
                return $opSignal
            }

            $graph = $conversionSignal.GetResult()
            $opSignal.SetResult($graph)
            $opSignal.LogInformation("✅ Successfully reconstructed Graph from JSON.")
        }
        catch {
            $opSignal.LogCritical("🔥 Exception in Graph.FromJson: $($_.Exception.Message)")
            $opSignal.IsTerminal = $true
        }

        return $opSignal
    }
}
