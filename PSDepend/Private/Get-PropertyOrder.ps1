#function to extract properties
function Get-PropertyOrder {
    <#
    .SYNOPSIS
        Gets property order for specified object

    .DESCRIPTION
        Gets property order for specified object

    .PARAMETER InputObject
        A single object to convert to an array of property value pairs.

    .PARAMETER MemberType
        MemberTypes to include

    .PARAMETER ExcludeProperty
        Specific properties to exclude

    .FUNCTIONALITY
        PowerShell Language
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromRemainingArguments = $false)]
        [PSObject]$InputObject,

        [ValidateSet("AliasProperty", "CodeProperty", "Property", "NoteProperty", "ScriptProperty",
            "Properties", "PropertySet", "Method", "CodeMethod", "ScriptMethod", "Methods",
            "ParameterizedProperty", "MemberSet", "Event", "Dynamic", "All")]
        [string[]]$MemberType = @( "NoteProperty", "Property", "ScriptProperty" ),

        [string[]]$ExcludeProperty = $null
    )

    begin {

        if ($PSBoundParameters.ContainsKey('inputObject')) {
            $firstObject = $InputObject[0]
        }
    }
    process {

        #we only care about one object...
        $firstObject = $InputObject
    }
    end {

        #Get properties that meet specified parameters
        $firstObject.PSObject.properties |
            Where-Object { $MemberType -contains $_.MemberType } |
            Select-Object -ExpandProperty Name |
            Where-Object { -not $excludeProperty -or $excludeProperty -notcontains $_ }
    }
} #Get-PropertyOrder
