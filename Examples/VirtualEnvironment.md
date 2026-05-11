# Creating a Virtual Environment

This walkthrough demonstrates a "virtual environment" scenario — pulling down dependencies into a project folder and importing them directly, independent of any other versions installed on the system.

## Set Up a Demo Project

```powershell
mkdir C:\ProjectX -Force
Set-Content C:\ProjectX\Requirements.psd1 -Value @'
@{
    PSDependOptions = @{
        Target = '$DependencyFolder' # Install all dependencies here
        AddToPath = $True            # Prepend project folder to $ENV:Path and $ENV:PSModulePath
    }

    # Gallery modules
    PSSlack     = 'latest'
    ImportExcel = 'latest'
    'Posh-SSH'  = 'latest'

    # Clone a git repo
    'PowerShellOrg/PSDepend' = 'master'

    # Download a file
    'RabbitMQ.Client.dll' = @{
        DependencyType = 'FileDownload'
        Source = 'https://github.com/PowerShellOrg/PSDepend/raw/master/PSDepend/PSDepend.psd1'
    }
}
'@
```

## Test and Install

```powershell
Import-Module PSDepend

# Check whether dependencies are already in place
Invoke-PSDepend -Path C:\ProjectX -Test | Select-Object Dependency*
<#
    DependencyFile                DependencyName           DependencyType  DependencyExists
    --------------                --------------           --------------  ----------------
    C:\ProjectX\Requirements.psd1 ImportExcel              PSGalleryModule            False
    C:\ProjectX\Requirements.psd1 Posh-SSH                 PSGalleryModule            False
    C:\ProjectX\Requirements.psd1 PSSlack                  PSGalleryModule            False
    C:\ProjectX\Requirements.psd1 PowerShellOrg/PSDepend   Git                        False
    C:\ProjectX\Requirements.psd1 RabbitMQ.Client.dll      FileDownload               False
#>

# Install all dependencies
Invoke-PSDepend -Path C:\ProjectX -Force

# Verify
Invoke-PSDepend -Path C:\ProjectX\Requirements.psd1 -Test -Quiet
# True

# Confirm files are present
Get-ChildItem C:\ProjectX
<#
    Mode                LastWriteTime         Length Name
    ----                -------------         ------ ----
    d-----        8/30/2016  10:48 AM                ImportExcel
    d-----        8/30/2016  10:48 AM                Posh-SSH
    d-----        8/30/2016  10:48 AM                PSDepend
    d-----        8/30/2016  10:48 AM                PSSlack
    -a----        8/30/2016  10:48 AM         248320 RabbitMQ.Client.dll
    -a----        8/30/2016  10:48 AM            627 Requirements.psd1
#>

# Import all dependencies
Invoke-PSDepend -Path C:\ProjectX\Requirements.psd1 -Import -Force

# Confirm modules loaded from the project folder
Get-Module PSSlack, ImportExcel, Posh-SSH | Select-Object Name, Path
<#
    Name        Path
    ----        ----
    ImportExcel C:\ProjectX\ImportExcel\2.2.7\ImportExcel.psm1
    Posh-SSH    C:\ProjectX\Posh-SSH\1.7.6\Posh-SSH.psd1
    PSSlack     C:\ProjectX\PSSlack\0.0.15\PSSlack.psm1
#>

# Confirm $env:Path and $env:PSModulePath were updated
$env:Path -split ';'
<#
    C:\ProjectX
    C:\Windows\system32
    ...
#>

$env:PSModulePath -split ';'
<#
    C:\ProjectX
    C:\Users\<username>\Documents\WindowsPowerShell\Modules
    ...
#>
```

This pattern lets you set up an isolated dependency folder for a project, with those paths taking precedence over system-wide installations for the current session.
