function Resolve-PathFromDictionary {
    param (
        [Parameter(Mandatory)] $Dictionary,
        [Parameter(Mandatory)] [string]$Path,
        [bool]$IgnoreInternalObjects = $true,
        [bool]$SkipFinalInternalUnwrap = $false
    )

    $signal = [Signal]::Start("Resolve-PathFromDictionary", $Dictionary) | Select-Object -Last 1

    function Unwrap-InternalObjects {
        param ([object]$obj)
        $current = $obj
        $check = $true
        while ($check) {
            $check = $false
            if ($current -is [Signal]) {
                $current = $current.GetResult()
                $check = $true
            } elseif ($current -is [Graph]) {
                $current = $current.Grid
                $check = $true
            }
        }
        return $current
    }

    function Expand-SymbolicPathSegments {
        param ([string[]]$RawSegments)

        #todo externalize in a jacket.
        $symbolMap = @{
            "%" = "Jacket"
            "*" = "Pointer"
            "@" = "Result"
            "$" = "Signal"
            "#" = "Grid"
        }
        $expanded = foreach ($segment in $RawSegments) {
            if ($symbolMap.ContainsKey($segment)) { $symbolMap[$segment] } else { $segment }
        }
        return $expanded
    }

    try {
        $rawSegments = $Path -split '\.'
        $parts = Expand-SymbolicPathSegments -RawSegments $rawSegments

        if ($rawSegments -ne $parts) {
            $IgnoreInternalObjects = $false
            $signal.LogVerbose("🧬 Symbolic path expansion detected — SkipFinalInternalUnwrap auto-enabled.")
        }

        if (-not $SkipFinalInternalUnwrap -and $parts[-1] -match '(?i)(Graph|Signal|Grid|Pointer)$') {
            $SkipFinalInternalUnwrap = $true
            $signal.LogVerbose("🧠 SkipFinalInternalUnwrap auto-enabled for path suffix match: '$Path'")
        }

        $current = $Dictionary

        foreach ($part in $parts) {
            if ($null -eq $current) {
                $signal.LogCritical("Current object is null while traversing path segment '$part'.")
                return $signal
            }

            if ($IgnoreInternalObjects) {
                $current = Unwrap-InternalObjects $current
            }

            if ($part -eq "*") {
                if ($current -is [Signal] -and $current.PSObject.Properties["Pointer"]) {
                    $current = $current.Pointer
                    $signal.LogVerbose("🔗 Dereferenced *Pointer in signal.")
                    continue
                } else {
                    $signal.LogCritical("❌ '*' used but no Pointer found in current object.")
                    return $signal
                }
            }

            $parsed = Parse-FilterSegment $part

            if ($parsed.IsFilter) {
                if ($current -is [System.Collections.IDictionary] -and $current.ContainsKey($parsed.ArrayKey)) {
                    $array = $current[$parsed.ArrayKey]
                } elseif ($current -is [pscustomobject] -and $current.PSObject.Properties.Name -contains $parsed.ArrayKey) {
                    $array = $current.$($parsed.ArrayKey)
                } else {
                    $signal.LogCritical("Missing array key '$($parsed.ArrayKey)' while applying filters.")
                    return $signal
                }

                $match = Resolve-FilteredArrayItem -Array $array -Filters $parsed.Filters -Signal $signal
                if ($null -eq $match) { return $signal }

                $current = $match
                continue
            }

            $partName = $parsed.Raw

            if ($current -is [System.Collections.IDictionary] -and $current.Contains($partName)) {
                $current = $current[$partName]
            } elseif ($current -is [hashtable] -and $current.Contains($partName)) {
                $current = $current[$partName]
            } elseif ($current -is [pscustomobject] -and $current.PSObject.Properties.Name -contains $partName) {
                $current = $current.$partName
            } elseif ($current -is [System.Collections.IEnumerable] -and -not ($current -is [string])) {
                $found = $null
                foreach ($item in $current) {
                    if (($item -is [pscustomobject] -or $item -is [hashtable]) -and ($item.Name -eq $partName)) {
                        $found = $item
                        break
                    }
                }
                if ($found) { $current = $found }
                else {
                    $signal.LogCritical("Array segment missing item with Name '$partName'.")
                    return $signal
                }
            } elseif ($current.GetType().IsClass -and $current.GetType().Namespace -ne "System") {
                $propInfo = $current.GetType().GetProperty($partName)
                if ($null -eq $propInfo) {
                    $signal.LogCritical("Class $($current.GetType().Name) does not have a property named '$partName'.")
                    return $signal
                }
                $next = $propInfo.GetValue($current, $null)
                if ($null -eq $next) {
                    $signal.LogCritical("Property '$partName' is null in class $($current.GetType().Name).")
                    return $signal
                }
                $current = $next
            } else {
                $signal.LogCritical("Unsupported object type encountered while traversing path '$Path'. Type: $($current.GetType().FullName)")
                return $signal
            }
        }

        if (-not $SkipFinalInternalUnwrap) {
            $current = Unwrap-InternalObjects $current
        }

        $signal.SetResult($current)
        $signal.LogInformation("Successfully resolved path '$Path'.")
    } catch {
        $signal.LogCritical("Critical failure during path resolution: $_")
    }

    return $signal
}
