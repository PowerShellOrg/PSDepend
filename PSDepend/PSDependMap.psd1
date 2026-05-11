# This defines dependencies. Feel free to create your own
# Top level node is the dependency name
#   Script is the script to run. These are stored in \PSDepend\PSDependScripts
#   Description is a quick description of the dependency script
#   Supports is a way to filter supported platforms:  core, windows, macos, linux

# In some cases, it may be beneficial to include 'aliases'.  Just add nodes for these.
@{
    Chocolatey = @{
        Script = 'Chocolatey.ps1'
        Description = 'Install a Chocolatey package from a Chocolatey feed'
        Supports = 'windows'
    }
    
    Command = @{
        Script = 'Command.ps1'
        Description = 'Invoke a command in PowerShell'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    DotnetSdk = @{
        Script = 'DotnetSdk.ps1'
        Description = "Installs the .NET Core SDK"
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    FileDownload = @{
        Script = 'FileDownload.ps1'
        Description = 'Download a file'
        Supports = 'windows'
    }

    FileSystem = @{
        Script = 'FileSystem.ps1'
        Description = 'Copy a file or folder'
        Supports = 'windows'
    }

    Git = @{
        Script = 'Git.ps1'
        Description = 'Clone a git repository'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    GitHub = @{
        Script = 'GitHub.ps1'
        Description = 'Download and extract a GitHub repo'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    Npm = @{
        Script = 'Npm.ps1'
        Description = 'Install a node package'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    Noop = @{
        Script = 'Noop.ps1'
        Description = 'Display parameters that a depends script would receive. Use for testing and validation'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    Nuget = @{
        Script = 'Nuget.ps1'
        Description = 'Install a Nuget package from a Nuget feed'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    Package = @{
        Script = 'Package.ps1'
        Description = 'EXPERIMENTAL: Install a package via PackageManagement Install-Package'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    PSGalleryModule = @{
        Script= 'PSGalleryModule.ps1'
        Description = 'Install a PowerShell module from the PowerShell Gallery'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    PSGalleryNuget = @{
        Script = 'PSGalleryNuget.ps1'
        Description = 'Install a PowerShell module from the PowerShell Gallery without the PowerShellGet dependency'
        Supports = 'windows', 'core', 'macos', 'linux'
    }

    Task = @{
        Script = 'Task.ps1'
        Description = 'Support dependencies by handling simple tasks'
        Supports = 'windows', 'core', 'macos', 'linux'
    }
}
