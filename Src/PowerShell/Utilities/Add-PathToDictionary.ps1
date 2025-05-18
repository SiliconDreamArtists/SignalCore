function Add-PathToDictionary {
    param (
        [Parameter(Mandatory)] $Signal,
        [Parameter(Mandatory)] [string]$Path,
        [Parameter()] $Value
    )

    $opSignal = [Signal]::Start("Add-PathToDictionary", $Signal) | Select-Object -Last 1

    $symbolMap = @{
        "%" = "Jacket"
        "*" = "Pointer"
        "@" = "Result"
        "$" = "Signal"
        "#" = "Grid"
    }

    function Expand-Symbols {
        param ([string[]]$segments)
        return $segments | ForEach-Object {
            if ($symbolMap.ContainsKey($_)) { $symbolMap[$_] } else { $_ }
        }
    }

    try {
        $rawSegments = $Path -split '\.'
        $segments = Expand-Symbols -segments $rawSegments

        if ($segments.Count -lt 1) {
            $opSignal.LogCritical("❌ Path too short or empty.")
            return $opSignal
        }

        $current = $Signal

        for ($i = 0; $i -lt $segments.Count; $i++) {
            $key = $segments[$i]
            $isFinal = ($i -eq $segments.Count - 1)

            if ($null -eq $current) {
                $opSignal.LogCritical("❌ Null encountered at segment '$key'")
                return $opSignal
            }

            # Auto-unwrap Signal/Graph
            #if ($current -is [Signal]) { $current = $current.GetResult() }
            #if ($current -is [Graph])  { $current = $current.Grid }

            $processed = $false

            # ░▒▓█ SYMBOLIC STRUCTURE STEPS █▓▒░
            switch ($key) {
                "Jacket" {
                    if ($current -is [Signal]) {
                        $current = $current.GetJacket()
                        $processed = $true
                        continue
                    } else {
                        $opSignal.LogCritical("❌ 'Jacket' expected Signal, got $($current.GetType().Name)")
                        return $opSignal
                    }
                }
                "Pointer" {
                    if ($current -is [Signal]) {
                        if (-not $current.Pointer) {
                            $current.Pointer = [Graph]::Start("AutoCreated")
                        }
                        $current = $current.GetPointer()
                        $processed = $true
                        continue
                    } else {
                        $opSignal.LogCritical("❌ 'Pointer' expected Signal, got $($current.GetType().Name)")
                        return $opSignal
                    }
                }
                "Result" {
                    if ($current -is [Signal]) {
                        if (-not $current.GetResult()) {
                            $current.SetResult(@{})
                        }
                        $current = $current.GetResult()
                        $processed = $true
                        continue
                    }
                    elseif ($current -is [Graph]) {
                        if (-not $current.Grid) {
                            $current.Grid = [Signal]::Start("AutoCreated")
                        }
                        $current = $current.Grid
                        $processed = $true
                        continue
                    } else {
                        $opSignal.LogCritical("❌ 'Result' segment unsupported on $($current.GetType().Name)")
                        return $opSignal
                    }
                }
                "Grid" {
                    if ($current -is [Graph]) {
                        if (-not $current.Grid) {
                            $current.Grid = @{}
                        }
                        $current = $current.Grid
                        $processed = $true
                        continue
                    } else {
                        $graph = [Graph]::Start("AutoCreated")
                        if ($current -is [System.Collections.IDictionary]) {
                            $current["Grid"] = $graph.Grid
                            $current = $graph.Grid
                            continue
                        } else {
                            $opSignal.LogCritical("❌ 'Grid' requires Graph or dictionary host.")
                            return $opSignal
                        }
                    }
                }
                "Signal" {
                    if ($current -is [System.Collections.IDictionary]) {
                        if (-not $current.Contains("Signal")) {
                            $current["Signal"] = [Signal]::Start("AutoCreated")
                        }
                        $current = $current["Signal"]
                        $processed = $true
                        continue
                    } else {
                        $opSignal.LogCritical("❌ 'Signal' key requires dictionary host.")
                        return $opSignal
                    }
                }
            }


            # ░▒▓█ FINAL WRITE █▓▒░
            if ($isFinal) {
                if ($current -is [System.Collections.IDictionary]) {
                    $current[$key] = $Value
                }
                elseif ($current -is [PSCustomObject] -or $current -is [System.Management.Automation.PSObject]) {
                    if (-not $current.PSObject.Properties[$key]) {
                        Add-Member -InputObject $current -MemberType NoteProperty -Name $key -Value $Value
                    } else {
                        $current.$key = $Value
                    }
                }
                elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                    $prop = $current.GetType().GetProperty($key)
                    if ($null -eq $prop -or -not $prop.CanWrite) {
                        $opSignal.LogCritical("❌ Cannot write '$key' on class '$($current.GetType().Name)'")
                        return $opSignal
                    }
                    $prop.SetValue($current, $Value)
                }
                else {
                    $opSignal.LogCritical("❌ Unsupported type at final write: $($current.GetType().FullName)")
                    return $opSignal
                }

                $opSignal.LogInformation("📥 Wrote '$key' → $($Value.GetType().Name)")
                $opSignal.SetResult($Signal)
                return $opSignal
            }

            if ($processed) {
                continue
            }

            # ░▒▓█ INTERMEDIATE OBJECTS █▓▒░
            if ($current -is [System.Collections.IDictionary]) {
                if (-not $current.Contains($key)) {
                    $current[$key] = @{}
                }
                $current = $current[$key]
            }
            elseif ($current -is [PSCustomObject] -or $current -is [System.Management.Automation.PSObject]) {
                if (-not $current.PSObject.Properties[$key]) {
                    Add-Member -InputObject $current -MemberType NoteProperty -Name $key -Value (@{})
                }
                $current = $current.$key
            }
            elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                $prop = $current.GetType().GetProperty($key)
                if ($null -eq $prop) {
                    $opSignal.LogCritical("❌ Class '$($current.GetType().Name)' missing property '$key'")
                    return $opSignal
                }
                $next = $prop.GetValue($current)
                if ($null -eq $next) {
                    $next = New-Object -TypeName $prop.PropertyType
                    $prop.SetValue($current, $next)
                }
                $current = $next
            }
            else {
                $opSignal.LogCritical("❌ Unsupported type at '$key': $($current.GetType().FullName)")
                return $opSignal
            }
        }
    }
    catch {
        $opSignal.LogCritical("❌ Exception during Add-PathToDictionary: $_")
        return $opSignal
    }
}
