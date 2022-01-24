# Thanks to:
#   Many people on StackExchange for existing questions and their answers which assisted with the creation and optimization of this script
#   Microsoft Docs for PowerShell and .NET documentation, and Hey, Scripting Guy! blog on Microsoft TechNet
#   Various online RegEx Resources including Regular-Expressions.info

# example of extracting an H86 file from a RESX from the IFM Maintenance tool
# This example is fixed, to extract the data block whose name starts with 'R360Line_32_EEPROMData', and applies a correction where the
# Maintenance H86 generator failed to properly terminate the lines before being encoded in the RESX file.

([Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String(
                (([xml](Get-Content "7509 FRAM ID 14 2018-04-10.resx")).'root'.'data'.Where{
                        $_.'name' -match '^R360Line_32_EEPROMData(?:_|$)' }).'value'))
    ) -replace '(?=:)(?<!\n|^)', "`r`n" | Set-Content "7509 FRAM ID 14 2018-04-10.H86"

# in order to restrict to only FRAM, we have to find the data block who's name starts with 'R360Line_32_EEPROMData'

# sample of pulling in the resx file and attempting to repair the H86 subfiles so they have proper line endings, then writing out a new RESX file.
# if the H86 subfiles already have proper line endings, it will effectively have no change, but doesn't detect the situation and creates the 'Repaired' file anyway.
##################################################################################################################################################

# XMLWriter requires some special settings in order to keep the RESX format as original.
$xmlSettings = [Xml.XmlWriterSettings]@{
    Indent       = $true
    NewLineChars = "`r`n" # original RESX format had CRLF
    Encoding     = [Text.UTF8Encoding]::new($true) # Set an optional encoding, UTF-8 with BOM is the original RESX format
}


if ((Test-Path "7509 FRAM ID 14 2018-04-10 Repaired.md5") -and 
    (Get-FileHash '7509 FRAM ID 14 2018-04-10 Repaired.resx' -Algorithm MD5).Hash -ieq (Get-Content "7509 FRAM ID 14 2018-04-10 Repaired.md5")
) {
    [xml]$ifmresxfile = Get-Content "7509 FRAM ID 14 2018-04-10.resx" -Filter '*.resx' -Exclude "* Repaired.resx"

    # 32 bit IntelHex files DATA block names start with 'R360Line_32_', if none exist, skip this file
    if ($ifmresxfile.'root'.'data'.'name' -match '^R360Line_32_') {
        # not really sure why, but the CR0020 is considered 16 bit segmented, but DATA blocks still start with 'R360Line_32_', probably because they both use the same H86 format
        foreach ($datablock in $ifmresxfile.'root'.'data'.Where{ $_.'name' -match '^R360Line_32_' }) {
            "...Repairing block '$($datablock.'name')'"
            # convert result back to Base64String in the original RESX formatting
            $datablock.'value' = "$(([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(
                                    # convert from Base64String to a string
                                    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($datablock.'value')
                                        # add CRLF before ':' where missing
                                    ) -replace '(?=:)(?<!\n|^)', "`r`n")
                                # take the new Base64String and break it into 80 character lines formatted as assumed for the RESX file
                            ) -replace '.{1,80}', "`n        `$&"))`n"
        }

        # put the file back out with XMLWriter, as PowerShell seems to lack integral XML object output support.
        try {
            $xmlWriter = [Xml.XmlWriter]::Create("7509 FRAM ID 14 2018-04-10 Repaired.resx", $xmlSettings)
            $ifmResxFile.Save( $xmlWriter )
        }
        finally {
            if ($xmlWriter) {$xmlWriter.Dispose()}
        }

        # generate the hash file for the rebuilt RESX file
        (get-filehash "7509 FRAM ID 14 2018-04-10 Repaired.resx" -algorithm 'MD5').hash.ToLowerInvariant() |
            Set-Content "7509 FRAM ID 14 2018-04-10 Repaired.md5"
    }
} else {
    Write-Error "Source file '7509 FRAM ID 14 2018-04-10 Repaired.resx' failed integrity check! Checksum failed, or checksum file is missing!"
}
