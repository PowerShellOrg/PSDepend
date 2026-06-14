# cspell:ignore webclient
# Wrapped for pester mocking...
function Get-WebFile {
    param($URL, $Path)
    # We have the info, check for file, download it!
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $webclient = New-Object System.Net.WebClient
    $webclient.DownloadFile($URL, $Path)
    $webclient.Dispose()
}
