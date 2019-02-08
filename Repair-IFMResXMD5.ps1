Param(
    # Specifies a path to one or more locations to search for ResX files. Wildcards are permitted.
    [Parameter(Mandatory = $true,
        Position = 0,
        ParameterSetName = "Default",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [string[]] $SearchPath,

    # Recurse the path(s) to find files.
    [Parameter(HelpMessage = "Recurses the path(s) when searching, if the paths are folders.")]
    [switch] $Recurse
)


foreach ($resxFileName in (get-item $SearchPath | Get-ChildItem -File -Filter '*.resx' -Recurse:$Recurse.IsPresent)) {
}

$Path | ForEach-Object {
    Get-Item $_ | ForEach-Object {
        Write-Progress $_
        Get-ChildItem $_ -Directory -Recurse | ForEach-Object {
            Write-Progress $_
            Get-ChildItem $_.FullName -File -Filter '*.resx' | ForEach-Object {
                Write-Progress $_
                Set-Content "$($_.DirectoryName)\$($_.BaseName).md5" (get-filehash $_ -Algorithm "MD5").hash.ToLowerInvariant()
            }
        }
    }
}

<# foreach ($aPath in $Path) {
    Write-Progress $aPath
    foreach ($folder in Get-ChildItem $aPath -Directory -Recurse) {
        Write-Progress $folder
        foreach ($item in Get-ChildItem $folder -File -Filter '*.resx') {
            Write-Progress $item
            Set-Content "$($item.DirectoryName)\$($item.BaseName) Reduced.md5" (get-filehash $item -Algorithm "MD5").hash.ToLowerInvariant()
            Write-Progress $folder
        }
        Write-Progress $aPath
    }
} #>