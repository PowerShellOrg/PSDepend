@{
    'jenkins' = @{
        DependencyType = 'PSGalleryNuget'
        Version = 'latest'
        Target = 'TestDrive:/PSDependPesterTest'
        Parameters = @{
            Force = $true
        }
        Credential = "imaginaryCreds"
    }
}