# Idea from http://stackoverflow.com/questions/7468707/deep-copy-a-dictionary-hashtable-in-powershell
# borrowed from http://stackoverflow.com/questions/8982782/does-anyone-have-a-dependency-graph-and-topological-sorting-code-snippet-for-pow
function Get-ClonedObject {
    param($DeepCopyObject)
    # BinaryFormatter was removed in .NET 7; use a recursive hashtable clone instead
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