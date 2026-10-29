# cspell:ignore nomatch
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    # A map that exposes the fake Resolve-capable type alongside Noop (which cannot Resolve)
    $fakeScript = (Resolve-Path (Join-Path $PSScriptRoot 'Shared/FakeResolver.ps1')).Path
    $script:MapPath = Join-Path $TestDrive 'Add.PSDependMap.psd1'
    @"
@{
    FakeResolver = @{
        Script      = '$fakeScript'
        Description = 'Static graph for Add-PSDepend tests'
        Supports    = 'windows', 'core', 'macos', 'linux'
    }
    Noop = @{
        Script      = 'Noop.ps1'
        Description = 'Noop'
        Supports    = 'windows', 'core', 'macos', 'linux'
    }
}
"@ | Set-Content -Path $script:MapPath

    function Initialize-AddProject {
        param([string]$Name, [string]$Body)
        $dir = Join-Path $TestDrive $Name
        $null = New-Item -ItemType Directory -Path $dir -Force
        if ($PSBoundParameters.ContainsKey('Body')) {
            $file = Join-Path $dir 'requirements.psd1'
            Set-Content -Path $file -Value $Body -NoNewline
        }
        $dir
    }
}

Describe 'Add-PSDepend file discovery' {
    It 'Creates requirements.psd1 when none exists under Path' {
        $dir = Initialize-AddProject -Name 'new-file'

        $resultPath = Add-PSDepend -Path $dir -Name psake -Version latest -NoLock -PassThru

        $resultPath | Should -Be (Join-Path $dir 'requirements.psd1')
        Test-Path -LiteralPath $resultPath | Should -BeTrue
        (Get-Content -LiteralPath $resultPath -Raw) | Should -Match "'psake' = 'latest'"
    }

    It 'Uses the single existing DependencyFile under Path' {
        $dir = Initialize-AddProject -Name 'single-file' -Body "@{`r`n    Existing = 'latest'`r`n}`r`n"

        $resultPath = Add-PSDepend -Path $dir -Name psake -Version latest -NoLock -PassThru

        $resultPath | Should -Be (Join-Path $dir 'requirements.psd1')
    }

    It 'Throws when multiple DependencyFiles are found, asking for -Path' {
        $dir = Initialize-AddProject -Name 'ambiguous'
        Set-Content -Path (Join-Path $dir 'first.depend.psd1') -Value '@{}'
        Set-Content -Path (Join-Path $dir 'second.depend.psd1') -Value '@{}'

        { Add-PSDepend -Path $dir -Name psake -NoLock } | Should -Throw -ExpectedMessage '*Multiple DependencyFiles*-Path*'
    }

    It 'Writes directly to an explicit new file path with a .psd1 extension' {
        $dir = Initialize-AddProject -Name 'explicit-new'
        $target = Join-Path $dir 'custom.depend.psd1'

        $resultPath = Add-PSDepend -Path $target -Name psake -NoLock -PassThru

        $resultPath | Should -Be $target
        Test-Path -LiteralPath $target | Should -BeTrue
    }

    It 'Rejects an existing file that is not a .psd1' {
        $dir = Initialize-AddProject -Name 'wrong-extension'
        $target = Join-Path $dir 'requirements.json'
        Set-Content -Path $target -Value '{}'

        { Add-PSDepend -Path $target -Name psake -NoLock } | Should -Throw -ExpectedMessage '*not a .psd1 file*'
    }
}

Describe 'Add-PSDepend entry format' {
    It 'Writes the terse string form for Name+Version with the default PSGalleryModule type' {
        $dir = Initialize-AddProject -Name 'terse'

        $file = Add-PSDepend -Path $dir -Name psake -Version '4.9.1' -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "'psake' = '4\.9\.1'"
        $content | Should -Not -Match 'DependencyType'
    }

    It 'Writes the full hashtable form when an extra field is given' {
        $dir = Initialize-AddProject -Name 'hashtable-extra'

        $file = Add-PSDepend -Path $dir -Name Pester -Version '5.9.0' -Parameters @{ SkipPublisherCheck = $true } -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "'Pester' = @\{"
        $content | Should -Match "DependencyType = 'PSGalleryModule'"
        $content | Should -Match "'SkipPublisherCheck' = \`$true"
    }

    It 'Writes the full hashtable form when the effective DependencyType is not PSGalleryModule' {
        $dir = Initialize-AddProject -Name 'hashtable-type'

        $file = Add-PSDepend -Path $dir -Name App -DependencyType FakeResolver -PSDependTypePath $script:MapPath -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "'App' = @\{"
        $content | Should -Match "DependencyType = 'FakeResolver'"
    }

    It 'Quotes a Parameters key that is not a valid bareword identifier' {
        $dir = Initialize-AddProject -Name 'hashtable-key-quoting'

        $file = Add-PSDepend -Path $dir -Name Pester -Parameters @{ 'Display Name' = 'x' } -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "'Display Name' = 'x'"
    }

    It 'Serializes an empty Tags array as an empty array literal, not blank' {
        $dir = Initialize-AddProject -Name 'empty-array'

        $file = Add-PSDepend -Path $dir -Name Pester -Tags @() -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match 'Tags\s*=\s*@\(\)'

        # and the result must still be valid, parseable PowerShell data
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Add-PSDepend DependencyType default resolution' {
    It 'Infers GitHub from an owner/repo-shaped Name' {
        $dir = Initialize-AddProject -Name 'infer-github'

        $file = Add-PSDepend -Path $dir -Name 'RamblingCookieMonster/PowerShell' -Version main -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "DependencyType = 'GitHub'"
    }

    It 'Infers Git from a multi-segment path-shaped Name' {
        $dir = Initialize-AddProject -Name 'infer-git'

        $file = Add-PSDepend -Path $dir -Name 'gitlab.example.com/org/some' -Version main -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "DependencyType = 'Git'"
    }

    It "Falls back to the target file's PSDependOptions.DependencyType" {
        $dir = Initialize-AddProject -Name 'psdependoptions-default' -Body @'
@{
    PSDependOptions = @{
        DependencyType = 'FakeResolver'
    }
}
'@

        $file = Add-PSDepend -Path $dir -Name App -PSDependTypePath $script:MapPath -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "'App' = @\{"
        $content | Should -Match "DependencyType = 'FakeResolver'"
    }

    It 'An explicit -DependencyType overrides PSDependOptions and name-pattern inference' {
        $dir = Initialize-AddProject -Name 'explicit-wins' -Body @'
@{
    PSDependOptions = @{
        DependencyType = 'FakeResolver'
    }
}
'@

        $file = Add-PSDepend -Path $dir -Name 'owner/repo' -DependencyType Noop -PSDependTypePath $script:MapPath -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "DependencyType = 'Noop'"
    }
}

Describe 'Add-PSDepend collisions' {
    It 'Throws when the dependency already exists, without -Force' {
        $dir = Initialize-AddProject -Name 'collision' -Body "@{`r`n    psake = 'latest'`r`n}`r`n"

        { Add-PSDepend -Path $dir -Name psake -Version '4.9.1' -NoLock } |
            Should -Throw -ExpectedMessage "*'psake' already exists*-Force*"
    }

    It 'Fully replaces the existing entry with -Force, dropping fields not given again' {
        $dir = Initialize-AddProject -Name 'force-replace' -Body @'
@{
    Pester = @{
        DependencyType = 'PSGalleryModule'
        Version        = '4.0.0'
        Target         = 'CurrentUser'
    }
}
'@

        $file = Add-PSDepend -Path $dir -Name Pester -Version '5.9.0' -Force -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "'Pester' = '5\.9\.0'"
        $content | Should -Not -Match 'Target'
        $content | Should -Not -Match '4\.0\.0'
    }

    It "Treats 'PSDependOptions' as a reserved name" {
        $dir = Initialize-AddProject -Name 'reserved'

        { Add-PSDepend -Path $dir -Name PSDependOptions -NoLock } | Should -Throw -ExpectedMessage '*reserved*'
    }
}

Describe 'Add-PSDepend preserves existing content' {
    It 'Leaves comments and other entries untouched when appending' {
        $dir = Initialize-AddProject -Name 'preserve' -Body @'
@{
    # Keep this comment
    psake = 'latest' # inline comment
}
'@

        $file = Add-PSDepend -Path $dir -Name Pester -Version '5.9.0' -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match '# Keep this comment'
        $content | Should -Match "psake = 'latest' # inline comment"
        $content | Should -Match "'Pester' = '5\.9\.0'"
    }

    It 'Preserves a blank line before the closing brace instead of trimming it' {
        $dir = Initialize-AddProject -Name 'blank-line' -Body "@{`r`n    psake = 'latest'`r`n`r`n}`r`n"

        $file = Add-PSDepend -Path $dir -Name Pester -Version '5.9.0' -NoLock -PassThru
        $content = Get-Content -LiteralPath $file -Raw

        $content | Should -Match "psake = 'latest'`r`n`r`n    'Pester'"
    }

    It 'Preserves LF-only line endings instead of introducing CRLF' {
        $dir = Initialize-AddProject -Name 'lf-only'
        $target = Join-Path $dir 'requirements.psd1'
        [System.IO.File]::WriteAllText($target, "@{`n    psake = 'latest'`n}`n", [System.Text.UTF8Encoding]::new($false))

        $null = Add-PSDepend -Path $target -Name Pester -Version '5.9.0' -NoLock
        $content = [System.IO.File]::ReadAllText($target)

        $content | Should -Not -Match "`r`n"
        $content | Should -Match "'Pester' = '5\.9\.0'`n"
    }

    It 'Preserves an existing UTF-8 BOM' {
        $dir = Initialize-AddProject -Name 'utf8-bom'
        $target = Join-Path $dir 'requirements.psd1'
        [System.IO.File]::WriteAllText($target, "@{`r`n}`r`n", [System.Text.UTF8Encoding]::new($true))

        $null = Add-PSDepend -Path $target -Name psake -NoLock
        $bytes = [System.IO.File]::ReadAllBytes($target)

        , $bytes[0..2] | Should -Be @(, @(0xEF, 0xBB, 0xBF))
    }

    It 'Writes brand-new DependencyFiles without a BOM' {
        $dir = Initialize-AddProject -Name 'no-bom'

        $file = Add-PSDepend -Path $dir -Name psake -NoLock -PassThru
        $bytes = [System.IO.File]::ReadAllBytes($file)

        , $bytes[0..2] | Should -Not -Be @(, @(0xEF, 0xBB, 0xBF))
    }
}

Describe 'Add-PSDepend lock interaction' {
    It 'Updates requirements.lock.json after a successful add' {
        $dir = Initialize-AddProject -Name 'lock-success'

        $null = Add-PSDepend -Path $dir -Name App -DependencyType FakeResolver -PSDependTypePath $script:MapPath -PassThru
        $lockPath = Join-Path $dir 'requirements.lock.json'

        Test-Path -LiteralPath $lockPath | Should -BeTrue
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $lock.packages.'FakeResolver::App'.version | Should -Not -BeNullOrEmpty
    }

    It 'Does not touch the lock with -NoLock' {
        $dir = Initialize-AddProject -Name 'lock-skip'

        $null = Add-PSDepend -Path $dir -Name App -DependencyType FakeResolver -PSDependTypePath $script:MapPath -NoLock

        Test-Path -LiteralPath (Join-Path $dir 'requirements.lock.json') | Should -BeFalse
    }

    It 'Rolls back the edit to an existing file when the lock step fails' {
        $dir = Initialize-AddProject -Name 'lock-fail-existing' -Body "@{`r`n    psake = 'latest'`r`n}`r`n"
        $file = Join-Path $dir 'requirements.psd1'
        $before = Get-Content -LiteralPath $file -Raw

        { Add-PSDepend -Path $dir -Name DoesNotExist -DependencyType FakeResolver -PSDependTypePath $script:MapPath } |
            Should -Throw -ExpectedMessage '*rolled back*'

        (Get-Content -LiteralPath $file -Raw) | Should -BeExactly $before
        Test-Path -LiteralPath (Join-Path $dir 'requirements.lock.json') | Should -BeFalse
    }

    It 'Removes a brand-new file entirely when the lock step fails' {
        $dir = Initialize-AddProject -Name 'lock-fail-new'
        $file = Join-Path $dir 'requirements.psd1'

        { Add-PSDepend -Path $dir -Name DoesNotExist -DependencyType FakeResolver -PSDependTypePath $script:MapPath } |
            Should -Throw -ExpectedMessage '*rolled back*'

        Test-Path -LiteralPath $file | Should -BeFalse
    }
}

Describe 'Add-PSDepend WhatIf and PassThru' {
    It 'Makes no changes with -WhatIf' {
        $dir = Initialize-AddProject -Name 'whatif'

        $null = Add-PSDepend -Path $dir -Name psake -WhatIf

        Test-Path -LiteralPath (Join-Path $dir 'requirements.psd1') | Should -BeFalse
    }

    It 'Returns nothing without -PassThru' {
        $dir = Initialize-AddProject -Name 'no-passthru'

        $result = Add-PSDepend -Path $dir -Name psake -NoLock

        $result | Should -BeNullOrEmpty
    }
}

Describe 'Add-PSDepend unknown DependencyType' {
    It 'Throws a helpful error listing known types' {
        $dir = Initialize-AddProject -Name 'unknown-type'

        { Add-PSDepend -Path $dir -Name psake -DependencyType NoSuchType -PSDependTypePath $script:MapPath -NoLock } |
            Should -Throw -ExpectedMessage '*NoSuchType*not defined*FakeResolver*'
    }
}
