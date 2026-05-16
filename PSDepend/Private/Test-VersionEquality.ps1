function Test-VersionEquality {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$ReferenceVersion,
        [string]$DifferenceVersion
    )

    if ([string]::IsNullOrEmpty($ReferenceVersion) -or [string]::IsNullOrEmpty($DifferenceVersion)) {
        return $false
    }

    [System.Version]$parsedRef = $null
    [System.Version]$parsedDiff = $null

    if ([System.Version]::TryParse($ReferenceVersion, [ref]$parsedRef) -and
        [System.Version]::TryParse($DifferenceVersion, [ref]$parsedDiff)) {
        return (
            $parsedRef.Major -eq $parsedDiff.Major -and
            $parsedRef.Minor -eq $parsedDiff.Minor -and
            [Math]::Max($parsedRef.Build, 0) -eq [Math]::Max($parsedDiff.Build, 0) -and
            [Math]::Max($parsedRef.Revision, 0) -eq [Math]::Max($parsedDiff.Revision, 0)
        )
    }

    [System.Management.Automation.SemanticVersion]$parsedRefSemVer = $null
    [System.Management.Automation.SemanticVersion]$parsedDiffSemVer = $null

    if ([System.Management.Automation.SemanticVersion]::TryParse($ReferenceVersion, [ref]$parsedRefSemVer) -and
        [System.Management.Automation.SemanticVersion]::TryParse($DifferenceVersion, [ref]$parsedDiffSemVer)) {
        return $parsedRefSemVer -eq $parsedDiffSemVer
    }

    return $ReferenceVersion -eq $DifferenceVersion
}
