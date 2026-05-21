# Borrowed and tweaked from BuildHelpers.  TODO: Doc, commit back there
function Get-ProjectDetail {
    <#
    .SYNOPSIS
        Get the name for this project

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Get the name for this project

        Evaluates based on the following scenarios:
            * Subfolder with the same name as the current folder
            * Subfolder with a <subfolder-name>.psd1 file in it
            * Current folder with a <currentfolder-name>.psd1 file in it

    .PARAMETER Path
        Path to project root. Defaults to the current working path

    .NOTES
        We assume you are in the project root, for several of the fallback options

    .EXAMPLE
        Get-ProjectName

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        Get-BuildVariables

    .LINK
        Set-BuildEnvironment

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        $Path = $PWD.Path
    )

    Function Resolve-ProjectDetail {
        param(
            $Path = $Path,
            $RelativePath = '\',
            $Name
        )
        [PSCustomObject]@{
            Name = $Name
            Path = Resolve-Path (Join-Path $Path $RelativePath)
        }
    }

    $CurrentFolder = Split-Path $Path -Leaf
    $ExpectedPath = Join-Path -Path $Path -ChildPath $CurrentFolder
    $ExpectedPsd1 = Join-Path -Path $ExpectedPath -ChildPath "$CurrentFolder.psd1"
    if ((Test-Path $ExpectedPath) -and (Test-Path $ExpectedPsd1)) {
        Resolve-ProjectDetail -Path $Path -RelativePath $CurrentFolder -Name $CurrentFolder
    }
    else {
        # Look for properly organized modules
        $ProjectPaths = Get-ChildItem $Path -Directory |
            Where-Object {
                Test-Path $(Join-Path $_.FullName "$($_.name).psd1")
            } |
            Select-Object -ExpandProperty Fullname

        if ( @($ProjectPaths).Count -gt 1 ) {
            Write-Warning "Found more than one project path via subfolders with psd1 files: $(Split-Path $ProjectPaths -Leaf | Out-String)"
        }
        elseif ( @($ProjectPaths).Count -eq 1 ) {
            $Name = Split-Path $ProjectPaths -Leaf
            Resolve-ProjectDetail -Path $Path -RelativePath $Name -Name $Name
        }
        #PSD1 in root of project - ick, but happens.
        elseif ( Test-Path "$ExpectedPath.psd1" ) {
            Resolve-ProjectDetail -Path $Path -Name $CurrentFolder
        }
        else {
            Write-Verbose "Could not find a project from [$Path], using root"
            Resolve-ProjectDetail -Path $Path -Name $CurrentFolder
        }
    }
}