﻿<# 
.synopsis
    Reduce the size of IFM Maintenance RESX files on the MPC (Freescale PowerPC, BasicLine) platforms by filtering out S records which are 'empty'
.description
    Reduces the size of IFM Maintenance RESX files generated for the MPC platforms (Freescale PowerPC, BasicLine) for the datablocks which represent FLASH memory (BasicSystem|Bootloader|SISSystem|IECConfig|IECApplication) by removing S records which are entirely blank (all data bytes are 0xFF).
.parameter SearchPath
    Provides path(s) for which to search for files to reduce.  If the path is a folder, all RESX files in that folder will be reduced.  Only files of type '*.RESX' (not already named '* Reduced.RESX') will be reduced.
.parameter Recurse
    Recurses all specified paths (of which are directories, or result in matching directories) in the search for RESX files to reduce.
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

        *! PowerShell Core 6.1 or later is required due to '-Filter/-Exclude' issues with Get-ChildItem in Windows PowerShell 5.1 and earlier. !*

    Thanks to:
        Many people on StackExchange for existing questions and their answers which assisted with the creation and optimization of this script
        Microsoft Docs for PowerShell and .NET documentation, and Hey, Scripting Guy! blog on Microsoft TechNet
        Various online RegEx Resources including Regular-Expressions.info

    TODO:
        Could use Output-Progress to report on file reduction progress.
        Finish Comment Based Help.
#>

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

#this is the regex match to determine block names that possess SREC files stored in Flash
$srecBlockNameMatch = '(?:^BasicLine_|^)(?:BasicSystem|Bootloader|SISSystem|IECConfig|IECApplication)(?:_|$)'

# XMLWriter requires some special settings in order to keep the RESX format as original.
$xmlSettings = [Xml.XmlWriterSettings]::new()
$xmlSettings.Indent = $true
$xmlSettings.NewLineChars = "`r`n" # original RESX format had CRLF
#Set an optional encoding, UTF-8 with BOM is the original RESX format
$xmlSettings.Encoding = [Text.UTF8Encoding]::new($true)

# get a list of files to process, not already named 'reduced'
foreach ($resxFileName in (get-item $SearchPath | Get-ChildItem -File -Filter '*.resx' -Exclude '* Reduced.resx' -Recurse:$Recurse.IsPresent)) {
    # we should check the MD5 file to see if the hash matches before continuing to process the file.
    if ($(if (Test-Path "$($resxFileName.DirectoryName)\$($resxFileName.BaseName).md5") {(get-filehash $resxFileName -algorithm "MD5").hash -ieq (get-content "$($resxFileName.DirectoryName)\$($resxFileName.BaseName).md5")} )) {
        # read the RESX file into an XML variable
        [xml]$ifmResxFile = Get-Content $resxFileName

        # only process files that possess an SREC file
        if ($ifmResxFile.root.data.name -match $srecBlockNameMatch) {
            $resxFileName.FullName # indicate the file we're processing

            # find each data block we believe we can process because it is believed to contain an SREC file
            foreach ($datablock in ($ifmResxFile.root.data | Where-Object name -match $srecBlockNameMatch)) {
                #(([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($datablock.value)) -split "`r`n") -match "S3.{10}(FF)+..$").count

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

            # put the file back out with XMLWriter, as PowerShell seems to lack that support.
            $xmlWriter = [Xml.XmlWriter]::Create("$($resxFileName.DirectoryName)\$($resxFileName.BaseName) Reduced.resx", $xmlSettings)
            try {
                $ifmResxFile.Save($xmlWriter)
            }
            finally {
                $xmlWriter.Dispose()
            }
            # generate the hash file for the rebuilt RESX file
            Set-Content "$($resxFileName.DirectoryName)\$($resxFileName.BaseName) Reduced.md5" (get-filehash "$($resxFileName.DirectoryName)\$($resxFileName.BaseName) Reduced.resx" -algorithm "MD5").hash.ToLowerInvariant()
        }
    }
    else {
        Write-Error "Source file '$($resxFileName.FullName)' failed integrity check! Checksum failed, or checksum file is missing!"
    }
}

<# ))) |  ##  The -replace operator (-replace '.{1,80}', "`r`n        `$&") is much more effective than the below code loop was.   ##
# reformat the newly generated Base64String to match the RESX formatting, note the use of ForEach-Object even though there is only one object at this point, a Base64String
ForEach-Object -Begin {$datablock.value = "`r`n"} {
    for ( $i = 0; $i -lt $_.length; $i += 80 ) {
        $datablock.value += "        $(if (($i + 80) -lt $_.length) {$_.substring($i, 80)} else {$_.substring($i)})`r`n"
    }
} #>
