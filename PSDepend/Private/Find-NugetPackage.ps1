# All credit and major props to Joel Bennett for this simplified solution that doesn't depend on PowerShellGet
# https://gist.github.com/Jaykul/1caf0d6d26380509b04cf4ecef807355
function Find-NugetPackage {
    [CmdletBinding()]
    param(
        # The name of a package to find
        [Parameter(Mandatory)]
        $Name,
        # The repository api URL -- like https://www.powershellgallery.com/api/v2/ or https://www.nuget.org/api/v2/
        $PackageSourceUrl = 'https://www.powershellgallery.com/api/v2/',

        #If specified takes precedence over version
        [switch]$IsLatest,

        [string]$Version,

        # If specified, gets passed during the Nuget source call
        [PSCredential]$Credential = $null
    )


    $escapedName = ([string]$Name).Replace("'", "''")
    $escapedVersion = ([string]$Version).Replace("'", "''")
    #Ugly way to do this.  Prefer islatest, otherwise look for version, otherwise grab all matching modules
    if ($IsLatest) {
        Write-Verbose "Searching for latest [$name] module"
        $URI = "${PackageSourceUrl}Packages?`$filter=Id eq '$escapedName' and IsLatestVersion"
    }
    elseif ($PSBoundParameters.ContainsKey('Version')) {
        Write-Verbose "Searching for version [$version] of [$name]"
        $URI = "${PackageSourceUrl}Packages?`$filter=Id eq '$escapedName' and Version eq '$escapedVersion'"
    }
    else {
        Write-Verbose "Searching for all versions of [$name] module"
        $URI = "${PackageSourceUrl}Packages?`$filter=Id eq '$escapedName'"
    }

    $headers = @{}
    if ($null -ne $Credential) {
        $basicAuthToken = [Convert]::ToBase64String(":$($Credential.GetNetworkCredential().Password)")

        $headers["X-NuGet-ApiKey"] = $Credential.UserName
        $headers["Authentication"] = "Basic $basicAuthToken"
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    if (-not $IsLatest -and -not $PSBoundParameters.ContainsKey('Version')) {
        $pageSize = 100
        $skip = 0
        do {
            $page = @(Invoke-RestMethod "$URI&`$top=$pageSize&`$skip=$skip" -Headers $headers)
            foreach ($entry in $page) {
                $entries.Add($entry)
            }
            $skip += $page.Count
        } while ($page.Count -gt 0)
    }
    else {
        foreach ($entry in @(Invoke-RestMethod $URI -Headers $headers)) {
            $entries.Add($entry)
        }
    }

    $entries | Select-Object @{n = 'Name'; ex = { $_.title.('#text') } },
    @{n = 'Author'; ex = { $_.author.name } },
    @{n = 'Version'; ex = { $_.properties.NormalizedVersion } },
    @{n = 'Uri'; ex = { $_.Content.src } },
    @{n = 'Description'; ex = { $_.properties.Description } },
    @{n = 'Properties'; ex = { $_.properties } }
}
