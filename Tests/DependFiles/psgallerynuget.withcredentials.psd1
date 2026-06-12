@{
    'jenkins' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '1.2.5'
        Target = 'TestDrive:/PSDependPesterTest'
        Parameters = @{
            Force = $true
        }
        Credential = 'imaginaryCreds'
    }
}