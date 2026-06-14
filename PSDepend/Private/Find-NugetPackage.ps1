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

    #Ugly way to do this.  Prefer islatest, otherwise look for version, otherwise grab all matching modules
    if ($IsLatest) {
        Write-Verbose "Searching for latest [$name] module"
        $URI = "${PackageSourceUrl}Packages?`$filter=Id eq '$name' and IsLatestVersion"
    }
    elseif ($PSBoundParameters.ContainsKey('Version')) {
        Write-Verbose "Searching for version [$version] of [$name]"
        $URI = "${PackageSourceUrl}Packages?`$filter=Id eq '$name' and Version eq '$Version'"
    }
    else {
        Write-Verbose "Searching for all versions of [$name] module"
        $URI = "${PackageSourceUrl}Packages?`$filter=Id eq '$name'"
    }

    $headers = @{}
    if ($null -ne $Credential) {
        $basicAuthToken = [Convert]::ToBase64String(":$($Credential.GetNetworkCredential().Password)")

        $headers["X-NuGet-ApiKey"] = $Credential.UserName
        $headers["Authentication"] = "Basic $basicAuthToken"
    }

    Invoke-RestMethod $URI -Headers $headers |
        Select-Object @{n = 'Name'; ex = { $_.title.('#text') } },
        @{n = 'Author'; ex = { $_.author.name } },
        @{n = 'Version'; ex = { $_.properties.NormalizedVersion } },
        @{n = 'Uri'; ex = { $_.Content.src } },
        @{n = 'Description'; ex = { $_.properties.Description } },
        @{n = 'Properties'; ex = { $_.properties } }
}
