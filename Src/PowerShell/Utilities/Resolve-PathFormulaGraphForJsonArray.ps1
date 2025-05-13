function Resolve-PathFormulaGraphForJsonArray {
    param (
        [Parameter(Mandatory)]
        [Signal]$ConductionSignal
    )

    $opSignal = [Signal]::Start("Resolve-PathFormulaGraphForJsonArray", $ConductionSignal) | Select-Object -Last 1

    # ░▒▓█ RESOLVE SOURCE CONFIG PATHS █▓▒░
    $sourcePathSignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.SourceWirePath" | Select-Object -Last 1
    $sourcesKeySignal = Resolve-PathFromDictionary -Dictionary $ConductionSignal -Path "%.SourcesWirePath" | Select-Object -Last 1
    $opSignal.MergeSignal(@($sourcePathSignal, $sourcesKeySignal)) | Out-Null

    if ($opSignal.MergeSignalAndVerifyFailure(@($sourcePathSignal, $sourcesKeySignal))) {
        $opSignal.LogCritical("❌ Missing SourceWirePath or SourcesWirePath in Jacket.")
        return $opSignal
    }

    $sourcePath = $sourcePathSignal.GetResult()
    $sourcesKey = $sourcesKeySignal.GetResult()

    # ░▒▓█ GET ROOT ARRAY FROM CONDUCTION SIGNAL RESULT █▓▒░
    $arraySignal = Resolve-PathFromDictionary -Dictionary ($ConductionSignal.GetResult()) -Path $sourcePath | Select-Object -Last 1
    $opSignal.MergeSignal(@($arraySignal)) | Out-Null

    if ($opSignal.MergeSignalAndVerifyFailure($arraySignal)) {
        $opSignal.LogCritical("❌ Failed to resolve object array at SourceWirePath '$sourcePath'.")
        return $opSignal
    }

    $flatArray = $arraySignal.GetResult()

    # ░▒▓█ CREATE GRAPH SIGNAL MESH █▓▒░
    $graphSignal = [Graph]::Start("GSG:ResolvedGraph", $opSignal, $true) | Select-Object -Last 1
    $graph = $graphSignal.Pointer
    $opSignal.MergeSignal($graphSignal) | Out-Null

    # ░▒▓█ BUILD SIGNALS AND REGISTER TO GRAPH █▓▒░
    $signalMap = @{}
    foreach ($item in $flatArray) {
        $id = $item.ID
        $signal = [Signal]::Start("Node:$id", $opSignal, $null, $item) | Select-Object -Last 1
        $signalMap[$id] = $signal.GetResult()
    }

    foreach ($signal in $signalMap.Values) {
        $jacket = $signal.Jacket
        $sources = @()

        if ($jacket.ContainsKey($sourcesKey)) {
            foreach ($srcId in $jacket[$sourcesKey]) {
                if ($signalMap.ContainsKey($srcId)) {
                    $sources += $signalMap[$srcId]
                } else {
                    $opSignal.LogWarning("⚠️ Source ID '$srcId' not found in signal map.")
                }
            }
        }

        if ($sources.Count -eq 1) {
            $signal.SetPointer($sources[0])
        } elseif ($sources.Count -gt 1) {
            $signal.SetPointer($sources)
        }

        $graph.RegisterSignal($signal.Name, $signal) | Out-Null
    }

    $graph.Finalize()
    $opSignal.SetResult($graph)
    $opSignal.LogInformation("✅ Signal graph constructed from JSON array.")
    return $opSignal
}
