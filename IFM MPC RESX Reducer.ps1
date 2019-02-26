<# 
.synopsis
    Reduce the size of IFM Maintenance RESX files on the MPC (Freescale PowerPC, BasicLine) platforms by filtering out S records which are 'empty'
.description
    Reduces the size of IFM Maintenance RESX files generated for the MPC platforms (Freescale PowerPC, BasicLine) for the datablocks which represent FLASH memory (BasicSystem|Bootloader|SISSystem|IECConfig|IECApplication) by removing S records which are entirely blank (all data bytes are 0xFF).
.parameter SearchPath
    Provides path(s) for which to search for files to reduce.  If the path is a folder, all RESX files in that folder will be reduced.  Only files of type '*.RESX' (not already named '* Reduced.RESX') will be reduced.
.parameter Recurse
    Recurses all specified paths (of which are directories, or result in matching directories) in the search for RESX files to reduce.
.parameter Depth
    Used with -Recurse, limits the depth of recursion.
.notes
    The IFM SREC reader is sensitive to file formatting, we had to be careful to not generate blank lines or extra spaces.
    Likewise, this script requires strict formatting in order to detect effectively empty S records.  The SREC file lines must be LF terminated, CR's are optional (for the SREC file).
    S1, S2 and S3 records are all supported, though S1 and S2 are unlikely to appear in the IFM RESX data blocks currently supported.
    The data blocks, when read in, are converted from CRLF to LF termination by XMLReader.  This is maintained until the XMLWriter restores the CRLF termination when it writes the file.

    Script assembled by:
        Carl Morris of Rosenbauer Aerials LLC, Fremont, Nebraska, USA

    Revisions:
        2018-08-02 CMM Released
        2018-08-09 CMM Added -file to Get-ChildItems file search.
        2018-08-10 CMM Added test for presence of MD5 file, gives revised checksum error if not present.  Added setting of XMLWriterSetting to insure output matches original known RESX format.  Changed to writing only LF terminations on the new Base64String formatting as thats how the original input blocks are formatted by the XMLReader.  The XMLWriter will now change them back to CRLF on output.
        2018-08-15 CMM Cleaned up unneeded overwrapped subexpression, code formatting corrections.
        2019-02-06 CMM Added a SearchPath parameter, and a Recurse switch parameter, and comment based help for the parameters.
        2019-02-13 CMM Added Depth parameter to limit recursion, added alias 'Path' to SearchPath parameter, parameter type was [string[]]

        *! PowerShell Core 6.1 or later is required due to '-Filter/-Exclude' issues with Get-ChildItem in Windows PowerShell 5.1 and earlier. !*

    Thanks to:
        Many people on StackExchange for existing questions and their answers which assisted with the creation and optimization of this script
        Microsoft Docs for PowerShell and .NET documentation, and Hey, Scripting Guy! blog on Microsoft TechNet
        Various online RegEx Resources including Regular-Expressions.info

    TODO:
        Could use Output-Progress to report on file reduction progress.
        Finish Comment Based Help.
#>
[CmdletBinding(PositionalBinding = $false)]
Param(
    # Specifies a path to one or more locations to search for ResX files. Wildcards are permitted.
    [Parameter(Mandatory = $false,
        Position = 0,
        ParameterSetName = 'Default',
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Path to one or more locations.')]
    #    [ValidateNotNullOrEmpty()]
    #    [SupportsWildcards()]
    [Alias('Path')]
    [object[]] $SearchPath = '.',

    # Recurse the path(s) to find files.
    [Parameter(HelpMessage = 'Recurses the path(s) when searching, if the paths are folders.')]
    [switch] $Recurse,

    # Depth of recursion allowed to find files.
    [Parameter(HelpMessage = 'Limits the depth of recursion.')]
    [uint32] $Depth
)

#this is the regex match to determine block names that possess SREC files stored in Flash
$srecBlockNameMatch = '(?:^BasicLine_|^)(?:BasicSystem|Bootloader|SISSystem|IECConfig|IECApplication)(?:_|$)'

# create a dictionary of parameters for the Get-ChildItem cmdlet that will search out the RESX files.
$gci_args = @{ 
    File    = $true
    Filter  = '*.resx'
    Exclude = '* Reduced.resx'
}

if ($Recurse.IsPresent) {
    $gci_args += @{Recurse = $true}
}
if ($PSBoundParameters.ContainsKey('Depth')) {
    $gci_args += @{Depth = $Depth}
}

$depth

# XMLWriter requires some special settings in order to keep the RESX format as original.
$xmlSettings = [Xml.XmlWriterSettings]::new()
$xmlSettings.Indent = $true
$xmlSettings.NewLineChars = "`r`n" # original RESX format had CRLF
#Set an optional encoding, UTF-8 with BOM is the original RESX format
$xmlSettings.Encoding = [Text.UTF8Encoding]::new($true)

# get a list of files to process, not already named 'reduced'
foreach ($resxFile in (get-item $(if ($SearchPath) {$SearchPath} else {'.'}) | Get-ChildItem @gci_args)) {
    # we should check the MD5 file to see if the hash matches before continuing to process the file.
    if ($(if (Test-Path "$($resxFile.DirectoryName)\$($resxFile.BaseName).md5") {(get-filehash $resxFile -algorithm "MD5").hash -ieq (get-content "$($resxFile.DirectoryName)\$($resxFile.BaseName).md5")} )) {
        # read the RESX file into an XML variable
        [xml]$ifmResxContent = Get-Content $resxFile

        # only process files that possess an SREC file
        if ($ifmResxContent.root.data.name -match $srecBlockNameMatch) {
            $resxFile.FullName # indicate the file we're processing

            # find each data block we believe we can process because it possesses an SREC file believed to be stored in Flash
            foreach ($datablock in ($ifmResxContent.root.data | Where-Object name -match $srecBlockNameMatch)) {
                $orgDataLength = $datablock.value.Length
                # convert reduced result back to Base64String
                $datablock.value = ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
                            # convert from Base64String
                            [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($datablock.value)
                                # remove effectively empty S3, S2, or S1 DATA records
                            ) -replace 'S(?:(?:3.{4})|(?:2..)|(?:1)).{6}(?:FF)+..\r*\n')
                        # take the new Base64String and break it into 80 character lines formatted as assumed for the RESX file
                    ) -replace '.{1,80}', "`n        `$&") + "`n"
                "...Reduced block '$($datablock.name)' by $($orgDataLength - $datablock.value.Length) bytes."
            }

            # put the file back out with XMLWriter, as PowerShell seems to lack integral XML object output support.
            $xmlWriter = [Xml.XmlWriter]::Create("$($resxFile.DirectoryName)\$($resxFile.BaseName) Reduced.resx", $xmlSettings)
            try {
                $ifmResxContent.Save($xmlWriter)
            }
            finally {
                $xmlWriter.Dispose()
            }
            # generate the hash file for the rebuilt RESX file
            Set-Content "$($resxFile.DirectoryName)\$($resxFile.BaseName) Reduced.md5" (get-filehash "$($resxFile.DirectoryName)\$($resxFile.BaseName) Reduced.resx" -algorithm "MD5").hash.ToLowerInvariant()
        }
    }
    else {
        Write-Error "Source file '$($resxFile.FullName)' failed integrity check! Checksum failed, or checksum file is missing!"
    }
}
