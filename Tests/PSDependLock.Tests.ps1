# cspell:ignore installignore nomatch
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    # A map that exposes the fake Resolve-capable type alongside Noop (which cannot Resolve)
    $fakeScript = (Resolve-Path (Join-Path $PSScriptRoot 'Shared/FakeResolver.ps1')).Path
    $script:MapPath = Join-Path $TestDrive 'Lock.PSDependMap.psd1'
    @"
@{
    FakeResolver = @{
        Script      = '$fakeScript'
        Description = 'Static graph for lock tests'
        Supports    = 'windows', 'core', 'macos', 'linux'
    }
    Noop = @{
        Script      = 'Noop.ps1'
        Description = 'Noop'
        Supports    = 'windows', 'core', 'macos', 'linux'
    }
}
"@ | Set-Content -Path $script:MapPath

    function Initialize-LockProject {
        param([string]$Name, [string]$Body)
        $dir = Join-Path $TestDrive $Name
        $null = New-Item -ItemType Directory -Path $dir -Force
        $file = Join-Path $dir 'requirements.psd1'
        Set-Content -Path $file -Value $Body
        $file
    }

    $script:AppBody = @'
@{
    App = @{
        DependencyType = 'FakeResolver'
        Version        = '[1.0,2.0)'
        Target         = '$DependencyFolder/target'
    }
    Plain = @{
        DependencyType = 'Noop'
        Version        = 'latest'
    }
}
'@

    $script:ResolvableBody = @'
@{
    App = @{
        DependencyType = 'FakeResolver'
        Version        = '[1.0,2.0)'
        Target         = '$DependencyFolder/target'
    }
}
'@
}

Describe 'Update-PSDependLock' {

    It 'Resolves the whole graph to one version per package, honouring constraints from every parent' {
        $file = Initialize-LockProject -Name 'graph' -Body $script:AppBody
        $lockPath = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath -PassThru

        $lockPath | Should -Be (Join-Path (Split-Path $file) 'requirements.lock.json')
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json

        $lock.lockfileVersion | Should -Be 1
        $lock.dependencies.App.requested | Should -Be '[1.0,2.0)'
        $lock.dependencies.App.resolved | Should -Be 'FakeResolver::App'
        $lock.packages.'FakeResolver::App'.version | Should -Be '1.1.0'
        # App 1.1.0 wants Lib [1.5,2.0); Util 2.0.0 wants Lib [1.0,1.6): only 1.5.0 satisfies both
        $lock.packages.'FakeResolver::Lib'.version | Should -Be '1.5.0'
        $lock.packages.'FakeResolver::Util'.version | Should -Be '2.0.0'
        $lock.packages.'FakeResolver::Core'.version | Should -Be '2.0.0'
        @($lock.packages.PSObject.Properties.Name).Count | Should -Be 4
    }

    It 'Writes byte-identical output when resolution has not changed' {
        $file = Initialize-LockProject -Name 'stable-output' -Body $script:AppBody
        $lockPath = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath -PassThru
        $first = Get-Content -LiteralPath $lockPath -Raw

        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath

        Get-Content -LiteralPath $lockPath -Raw | Should -BeExactly $first
    }

    It 'Does not write a lock with WhatIf' {
        $file = Initialize-LockProject -Name 'whatif' -Body $script:AppBody

        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath -WhatIf

        Test-Path (Join-Path (Split-Path $file) 'requirements.lock.json') | Should -BeFalse
    }

    It 'Records dependencies whose type cannot Resolve without a resolved package' {
        $file = Initialize-LockProject -Name 'unresolvable' -Body $script:AppBody
        $lockPath = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath -PassThru
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json

        $lock.dependencies.Plain.dependencyType | Should -Be 'Noop'
        $lock.dependencies.Plain.requested | Should -Be 'latest'
        $lock.dependencies.Plain.PSObject.Properties.Name | Should -Not -Contain 'resolved'
    }

    It 'Fails when two dependencies need incompatible versions of the same package' {
        $file = Initialize-LockProject -Name 'conflict' -Body @'
@{
    App  = @{ DependencyType = 'FakeResolver'; Version = '2.0.0' }
    Util = @{ DependencyType = 'FakeResolver'; Version = 'latest' }
}
'@
        { Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath } |
            Should -Throw -ExpectedMessage '*FakeResolver::Lib*requires*'
        Test-Path (Join-Path (Split-Path $file) 'requirements.lock.json') | Should -BeFalse
    }

    It 'Fails when no version satisfies a declared constraint' {
        $file = Initialize-LockProject -Name 'nomatch' -Body @'
@{
    App = @{ DependencyType = 'FakeResolver'; Version = '[5.0,)' }
}
'@
        { Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath } |
            Should -Throw -ExpectedMessage '*FakeResolver::App*constraint*'
    }

    It 'Rejects a dependency cycle before writing the lock' {
        $file = Initialize-LockProject -Name 'cycle' -Body @'
@{
    CycleA = @{ DependencyType = 'FakeResolver'; Version = '1.0.0' }
}
'@

        { Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath } |
            Should -Throw -ExpectedMessage '*dependency cycle*CycleA*CycleB*CycleA*'
        Test-Path (Join-Path (Split-Path $file) 'requirements.lock.json') | Should -BeFalse
    }
}


Describe 'Import-PSDependLock validation' {

    It 'Rejects malformed JSON' {
        $path = Join-Path $TestDrive 'malformed.lock.json'
        Set-Content -LiteralPath $path -Value '{'

        InModuleScope PSDepend -Parameters @{ Path = $path } {
            { Import-PSDependLock -Path $Path } | Should -Throw -ExpectedMessage '*not valid JSON*'
        }
    }

    It 'Rejects a JSON array instead of a lock object' {
        $path = Join-Path $TestDrive 'array.lock.json'
        Set-Content -LiteralPath $path -Value '[]'

        InModuleScope PSDepend -Parameters @{ Path = $path } {
            { Import-PSDependLock -Path $Path } | Should -Throw -ExpectedMessage '*not a PSDepend lock file*'
        }
    }

    It 'Rejects an unsupported lock format' {
        $path = Join-Path $TestDrive 'newer.lock.json'
        Set-Content -LiteralPath $path -Value '{"lockfileVersion":2,"dependencies":{},"packages":{}}'

        InModuleScope PSDepend -Parameters @{ Path = $path } {
            { Import-PSDependLock -Path $Path } | Should -Throw -ExpectedMessage '*supports lockfileVersion 1*'
        }
    }

    It 'Rejects a root that resolves to a different package' {
        $path = Join-Path $TestDrive 'redirect.lock.json'
        Set-Content -LiteralPath $path -Value @'
{
  "lockfileVersion": 1,
  "dependencies": {
    "App": { "dependencyType": "Npm", "name": "App", "requested": "latest", "resolved": "Npm::Injected" }
  },
  "packages": {
    "Npm::Injected": { "version": "1.0.0", "dependencies": {} }
  }
}
'@

        InModuleScope PSDepend -Parameters @{ Path = $path } {
            { Import-PSDependLock -Path $Path } | Should -Throw -ExpectedMessage '*resolved key*'
        }
    }

    It 'Rejects a locked version that is not an exact package version' {
        $path = Join-Path $TestDrive 'unsafe-version.lock.json'
        Set-Content -LiteralPath $path -Value @'
{
  "lockfileVersion": 1,
  "dependencies": {
    "App": { "dependencyType": "Npm", "name": "App", "requested": "latest", "resolved": "Npm::App" }
  },
  "packages": {
    "Npm::App": { "version": "https://example.invalid/package.tgz", "dependencies": {} }
  }
}
'@

        InModuleScope PSDepend -Parameters @{ Path = $path } {
            { Import-PSDependLock -Path $Path } | Should -Throw -ExpectedMessage '*exact version*'
        }
    }
}

Describe 'Get-Dependency with a lock' {

    BeforeAll {
        $script:LockedFile = Initialize-LockProject -Name 'locked' -Body $script:AppBody
        $null = Update-PSDependLock -Path $script:LockedFile -PSDependTypePath $script:MapPath
    }

    It 'Pins the declared dependency to its locked version' {
        $deps = Get-Dependency -Path $script:LockedFile
        ($deps | Where-Object DependencyName -eq 'App').Version | Should -Be '1.1.0'
    }

    It 'Materializes locked transitive packages as dependencies that install before their parent' {
        $deps = @(Get-Dependency -Path $script:LockedFile)
        $names = $deps.DependencyName
        $names | Should -Contain 'Lib@1.5.0'
        $names | Should -Contain 'Util@2.0.0'
        $names | Should -Contain 'Core@2.0.0'
        $names.Count | Should -Be 5

        $names.IndexOf('Core@2.0.0') | Should -BeLessThan $names.IndexOf('Lib@1.5.0')
        $names.IndexOf('Lib@1.5.0') | Should -BeLessThan $names.IndexOf('Util@2.0.0')
        $names.IndexOf('Util@2.0.0') | Should -BeLessThan $names.IndexOf('App')

        $lib = $deps | Where-Object DependencyName -eq 'Lib@1.5.0'
        $lib.DependencyType | Should -Be 'FakeResolver'
        $lib.Name | Should -Be 'Lib'
        $lib.Version | Should -Be '1.5.0'
        $lib.Target | Should -Be ($deps | Where-Object DependencyName -eq 'App').Target
    }

    It 'Leaves dependencies of a type that cannot Resolve untouched' {
        $deps = Get-Dependency -Path $script:LockedFile
        ($deps | Where-Object DependencyName -eq 'Plain').Version | Should -Be 'latest'
    }

    It 'Returns the declared versions with -IgnoreLock' {
        $deps = @(Get-Dependency -Path $script:LockedFile -IgnoreLock)
        $deps.Count | Should -Be 2
        ($deps | Where-Object DependencyName -eq 'App').Version | Should -Be '[1.0,2.0)'
    }

    It 'Fails with an actionable error when the dependency file no longer matches the lock' {
        $file = Initialize-LockProject -Name 'stale' -Body $script:AppBody
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath
        Set-Content -Path $file -Value ($script:AppBody -replace "'\[1.0,2.0\)'", "'[1.0,3.0)'")

        { Get-Dependency -Path $file } | Should -Throw -ExpectedMessage '*out of date*Update-PSDependLock*'
        { Get-Dependency -Path $file -IgnoreLock } | Should -Not -Throw
    }

    It 'Fails when the dependency file gained a dependency the lock does not know' {
        $file = Initialize-LockProject -Name 'added' -Body $script:AppBody
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath
        Set-Content -Path $file -Value ($script:AppBody -replace 'Plain = @\{', "Extra = @{ DependencyType = 'Noop' }`n    Plain = @{")

        { Get-Dependency -Path $file } | Should -Throw -ExpectedMessage '*`[Extra`] is not in the lock*'
    }

    It 'Fails when the dependency file has removed every dependency in the lock' {
        $file = Initialize-LockProject -Name 'empty' -Body $script:AppBody
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath
        Set-Content -LiteralPath $file -Value '@{}'

        { Get-Dependency -Path $file } | Should -Throw -ExpectedMessage '*is in the lock but not in the DependencyFile*'
    }

    It 'Fails when the source used for resolution changes' {
        $body = $script:AppBody -replace "Target         = '", "Source         = 'feed-a'`n        Target         = '"
        $file = Initialize-LockProject -Name 'source' -Body $body
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath
        Set-Content -LiteralPath $file -Value ($body -replace "Source         = 'feed-a'", "Source         = 'feed-b'")

        { Get-Dependency -Path $file } | Should -Throw -ExpectedMessage '*resolution source or parameters changed*'
    }
}

Describe 'Invoke-PSDepend with a lock' {

    It 'Installs locked versions, children first' {
        $file = Initialize-LockProject -Name 'install' -Body $script:ResolvableBody
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath

        Invoke-PSDepend -Path $file -PSDependTypePath $script:MapPath -Force -WarningAction SilentlyContinue

        $log = Get-Content (Join-Path (Split-Path $file) 'target/installed.log')
        $log | Should -Be @('Core@2.0.0', 'Lib@1.5.0', 'Util@2.0.0', 'App@1.1.0')
    }

    It 'Installs a shared child into each root target' {
        $file = Initialize-LockProject -Name 'targets' -Body @'
@{
    App = @{
        DependencyType = 'FakeResolver'
        Version        = '1.0.0'
        Target         = '$DependencyFolder/app-target'
    }
    Util = @{
        DependencyType = 'FakeResolver'
        Version        = '1.0.0'
        Target         = '$DependencyFolder/util-target'
    }
}
'@
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath

        Invoke-PSDepend -Path $file -PSDependTypePath $script:MapPath -Force -WarningAction SilentlyContinue

        Get-Content (Join-Path (Split-Path $file) 'app-target/installed.log') | Should -Contain 'Lib@1.5.0'
        Get-Content (Join-Path (Split-Path $file) 'util-target/installed.log') | Should -Contain 'Lib@1.5.0'
    }

    It 'Passes the declared range through with -IgnoreLock' {
        $file = Initialize-LockProject -Name 'installignore' -Body $script:ResolvableBody
        $null = Update-PSDependLock -Path $file -PSDependTypePath $script:MapPath

        Invoke-PSDepend -Path $file -PSDependTypePath $script:MapPath -Force -IgnoreLock -WarningAction SilentlyContinue

        $log = Get-Content (Join-Path (Split-Path $file) 'target/installed.log')
        $log | Should -Be @('App@[1.0,2.0)')
    }
}
