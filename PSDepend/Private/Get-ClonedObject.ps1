function Get-ClonedObject {
    <#
    .SYNOPSIS
    Clones
    
    .DESCRIPTION
    Creates a deep copy of the provided object. This is useful for cloning
    dependency objects before passing them to dependency scripts, allowing
    modifications to the clone without affecting the original object.
    
    .PARAMETER DeepCopyObject
    The source object to copy from.
    
    .EXAMPLE
    Get-ClonedObject $MyObject

    Get a deep copy of $MyObject.  This is used to clone dependency objects
    before passing them to dependency scripts, so that we can modify the object
    without affecting the original.
    
    .NOTES
    Idea from https://stackoverflow.com/a/7475744
    borrowed from https://stackoverflow.com/q/8982782

    BinaryFormatter was removed in .NET 7; use a recursive hashtable clone
    instead
    #>
    param($DeepCopyObject)
    $clone = @{}
    foreach ($key in $DeepCopyObject.Keys) {
        $val = $DeepCopyObject[$key]
        if ($val -is [hashtable]) {
            $clone[$key] = Get-ClonedObject $val
        } elseif ($val -is [array]) {
            $clone[$key] = $val.Clone()
        } else {
            $clone[$key] = $val
        }
    }
    $clone
}