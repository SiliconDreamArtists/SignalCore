function Invoke-FormulaGraphCondenser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Signal]$Signal
    )

    $opSignal = [Signal]::Start("Invoke-FormulaGraphCondenser", $Signal) | Select-Object -Last 1

    # ░▒▓█ RESOLVE PLAN ARRAY █▓▒░
    $plansSignal = Resolve-PathFromDictionary -Dictionary $Signal -Path "%.GraphPlans" | Select-Object -Last 1
    if ($opSignal.MergeSignalAndVerifyFailure($plansSignal)) {
        $opSignal.LogCritical("❌ No GraphPlans defined in Signal jacket.")
        return $opSignal
    }

    $plans = $plansSignal.GetResult()
    $parentResult = $Signal.GetResult()

    foreach ($plan in $plans) {
        $planName = $plan.Name

        if ($plan.ForEachIn) {
            $itemArraySignal = Resolve-PathFromDictionary -Dictionary $parentResult -Path $plan.ForEachIn | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($itemArraySignal)) {
                $opSignal.LogWarning("⚠️ Could not resolve array path for ForEachIn: $($plan.ForEachIn)")
                continue
            }

            $itemArray = $itemArraySignal.GetResult()

            for ($i = 0; $i -lt $itemArray.Count; $i++) {
                $item = $itemArray[$i]
                $itemId = if ($item.PSObject.Properties["Identifier"]) { $item.Identifier } else { "Index_$i" }
                $subSignal = [Signal]::Start("GraphPlan:$($planName):$itemId", $Signal, $null, $item) | Select-Object -Last 1

                Add-PathToDictionary -Dictionary $subSignal -Path "$%.SourceWirePath" -Value $plan.SourceWirePath | Out-Null
                Add-PathToDictionary -Dictionary $subSignal -Path "$%.SourcesWirePath" -Value $plan.SourcesWirePath | Out-Null

                $graphSignal = Resolve-PathFormulaGraphForJsonArray -Signal $subSignal | Select-Object -Last 1
                if ($opSignal.MergeSignalAndVerifyFailure($graphSignal)) {
                    $opSignal.LogWarning("⚠️ Failed to resolve graph for item $itemId in plan: $planName")
                    continue
                }

                $graphResult = $graphSignal.GetResult()

                # Optional MatchKey/MatchAgainst cross-reference enrichment
                if ($plan.MatchKey -and $plan.MatchAgainst) {
                    $referenceArraySignal = Resolve-PathFromDictionary -Dictionary $parentResult -Path $plan.MatchAgainst | Select-Object -Last 1
                    if ($opSignal.MergeSignalAndVerifyFailure($referenceArraySignal)) {
                        $opSignal.LogWarning("⚠️ Could not resolve MatchAgainst path: $($plan.MatchAgainst)")
                    } else {
                        $referenceArray = $referenceArraySignal.GetResult()

                        foreach ($node in $graphResult.Grid.Values) {
                            $nodeKeySignal = Resolve-PathFromDictionary -Dictionary $node.Result -Path $plan.MatchKey | Select-Object -Last 1
                            if ($nodeKeySignal.Success()) {
                                $keyValue = $nodeKeySignal.GetResult()
                                $match = $referenceArray | Where-Object { $_.Name -eq $keyValue }
                                if ($match) {
                                    $node.SetPointer($match)
                                    $opSignal.LogInformation("🔗 Linked external reference for '$keyValue' into node '${node.Name}'")
                                }
                            }
                        }
                    }
                }

                if ($plan.TargetWirePath) {
                    Add-PathToDictionary -Dictionary $item -Path $plan.TargetWirePath -Value $graphResult | Out-Null
                    $opSignal.LogInformation("📍 Injected graph for item '$itemId' into '$($plan.TargetWirePath)'")
                }
            }
        }
        else {
            $subSignal = [Signal]::Start("GraphPlan:$planName", $Signal, $null, $parentResult) | Select-Object -Last 1

            Add-PathToDictionary -Dictionary $subSignal -Path "$%.SourceWirePath" -Value $plan.SourceWirePath | Out-Null
            Add-PathToDictionary -Dictionary $subSignal -Path "$%.SourcesWirePath" -Value $plan.SourcesWirePath | Out-Null

            $graphSignal = Resolve-PathFormulaGraphForJsonArray -Signal $subSignal | Select-Object -Last 1
            if ($opSignal.MergeSignalAndVerifyFailure($graphSignal)) {
                $opSignal.LogWarning("⚠️ Failed to resolve graph for plan: $planName")
                continue
            }

            if ($plan.TargetWirePath) {
                Add-PathToDictionary -Dictionary $parentResult -Path $plan.TargetWirePath -Value ($graphSignal.GetResult()) | Out-Null
                $opSignal.LogInformation("📍 Injected graph '$planName' into '$($plan.TargetWirePath)'")
            }
        }
    }

    $opSignal.SetResult($parentResult)
    $opSignal.LogInformation("✅ Completed all declared GraphPlans.")
    return $opSignal
}
<#
─────────────────────────────────────────────────────────────────────────────
🧠 SDA DOCTRINE FOOTER • function Invoke-FormulaGraphCondenser
─────────────────────────────────────────────────────────────────────────────

📘 AI TRAINER: HOW TO USE

This function enables a signal to construct one or more sovereign `[Graph]` structures
based on a declared array of `GraphPlans[]`.

Each `GraphPlan` may operate in two modes:

1. 🔁 **Global Mode** — Executes once, building a graph from `.Result` based on:
   - `SourceWirePath`: path to array within `.Result`
   - `SourcesWirePath`: linking reference inside each item
   - `TargetWirePath`: path in `.Result` where final graph is stored

2. 🔄 **Per-Item Mode (`ForEachIn`)** — Iterates over an array (e.g., agents), and for each item:
   - Executes a subgraph build using inner data (e.g., `.Roles`)
   - Stores the resulting graph back into the individual item using `TargetWirePath`

➕ Optionally, each node in the resulting graph can be **linked to external references** using:

- `MatchKey`: property path to extract from the graph node (e.g., `"Name"`)
- `MatchAgainst`: array path in `.Result` for lookup (e.g., `"$.SharedAdapters[*].Name"`)

If a match is found, it is set as the node’s `.Pointer`.

─────────────────────────────────────────────────────────────────────────────
✅ EXAMPLE USAGE:

$signal = [Signal]::Start("GraphOrchestration", $null, $null, $yourJsonData)

Add-PathToDictionary -Dictionary $signal -Path "$.%.GraphPlans" -Value @(
    @{
        Name = "AgentGraph"
        SourceWirePath = "$.Agents"
        SourcesWirePath = "Roles[*].Adapters[*].Name"
        TargetWirePath = "$.Graphs.Agents"
    },
    @{
        Name = "RoleGraph"
        SourceWirePath = "$.Agents[*].Roles"
        SourcesWirePath = "Dependencies"
        TargetWirePath = "$.Graphs.Roles"
    },
    @{
        Name = "PerAgentRoleGraph"
        ForEachIn = "$.Agents"
        SourceWirePath = "$.Roles"
        SourcesWirePath = "Dependencies"
        TargetWirePath = "$.RoleGraph"
    },
    @{
        Name = "AdapterReference"
        ForEachIn = "$.Agents"
        SourceWirePath = "$.Roles[*].Adapters"
        SourcesWirePath = "Name"
        MatchKey = "Name"
        MatchAgainst = "$.SharedAdapters[*].Name"
        TargetWirePath = "$.ResolvedAdapters"
    }
)

$finalSignal = function Invoke-FormulaGraphCondenser -Signal $signal

$finalResult = $finalSignal.GetResult()
# Now contains:
# $finalResult.Graphs.Agents
# $finalResult.Graphs.Roles
# $finalResult.Agents[*].RoleGraph
# $finalResult.Agents[*].ResolvedAdapters

─────────────────────────────────────────────────────────────────────────────
📦 SDA SIGNATURE
Function: function Invoke-FormulaGraphCondenser
Slot: FormulaAdapter
Kind: Graph Construction Layer
Designed by: Shadow PhanTom • SDA Co-Chair 🤖/☠️🧁👾️
Architect: Neural Alchemist ⚗️☣️🐲
─────────────────────────────────────────────────────────────────────────────
#>
