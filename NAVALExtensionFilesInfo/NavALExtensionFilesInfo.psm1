Function Get-ALExtensionFilesInfo{
<#
    .SYNOPSIS
        This function allows you to get information about Nav(Business Central) AL Extension files.

    .DESCRIPTION
        In AL VS Code Extensions V2, if you try to create an extension and the ID or Name are already used, you get an error.
        If you don't have the IDs of the files in the file name it is difficult to know what ID each extension has. 
        This function will show for each extension file the ID, the name of the object that it extends and the extension type.
        You can also check what Ids are not used.
        
    .PARAMETER ALExtensionFiles
        This is a mandatory parameter and it should be an array of FileInfo objects (Use function Get-ChildItem to Get array of FileInfo objects with
        the folders where you have your extension files.

    .PARAMETER GetIDFromExtensionName
        You can use this switch in case you have the ID of the extension in the extension name.

    .PARAMETER GetObjectNameFromFileName
        You can use this switch in case you have the name of the object that the extension extends in the file name.

    .PARAMETER GetFreeIds
        Use this switch in case you want the function to return only the free Ids. For example if you have two page extensions with IDs 50251 and 50254, the function can show you
        that Ids 50252 and 50253 are not used.
    
    .EXAMPLE
        PS> Get-RandomPassword -PasswordLength 10 -NoOfPasswords 30 -PercentLowerCaseLetters 0.5 -PercentNumbers 0.5 -OpenInTextFile

        This example generates 30 passwords of 10 characters composed 50% of Lowercase letters and 50% numbers each. It will also create and open a temporary text file with the passwords.
     
    .EXAMPLE
        PS> $Folder = 'C:\ALExtensionIdsSample\Folder 1'
            $Folder2 = 'C:\ALExtensionIdsSample\Folder 2'
            $Files = Get-ChildItem $Folder -Filter '*.al'
            $Files += Get-ChildItem $Folder2 -Filter '*.al'

            #get the info from extension files
            $ExtensionInfo = Get-ALExtensionFilesInfo -ALExtensionFiles $Files
            $ExtensionInfo

        This example gives you information about the extension files:
        ObjectName                  ExtensionNumber FileName                                                               ExtensionType 
        ----------                  --------------- --------                                                               ------------- 
        Posted Purchase Invoices    50292           C:\ALExtensionIdsSample\Folder 1\PEX - Posted Purchase Invoices.al     pageextension 
        Workflow                    50295           C:\ALExtensionIdsSample\Folder 1\PEX - Workflow.al                     pageextension 
    
    .EXAMPLE
        PS> Get-ALExtensionFilesInfo -ALExtensionFiles $Files -GetFreeIds

        This example generates a list with Ids that are not used:
        ExtensionNumber ExtensionType 
        --------------- ------------- 
                50293  pageextension 
                50294  pageextension

    .EXAMPLE
        PS> $MaxMinNo = $ExtensionInfo | 
            Where-Object{$_.ExtensionType -like 'pageextension'} | 
            Measure-Object -Property ExtensionNumber -Maximum -Minimum
            $ExtensionInfo | Where-Object {($_.ExtensionNumber -eq $MaxMinNo.Maximum) -and 
                                           ($_.ExtensionType -like 'pageextension')}

        This example gives you the maximum used id for page extensions

    .EXAMPLE
        PS> $ExtensionInfo | Where-Object{($_.ObjectName -like 'Transfer Order') -and 
                                          ($_.ExtensionType -like 'pageextension')}

        This example gives you the id of the extension that extends page Transfer Order.

    .EXAMPLE
        PS> $ExtensionInfo | Where-Object{($_.ExtensionNumber -eq 50292) -and
                              ($_.ExtensionType -like 'pageextension')} | 
                           Select-Object -Property ObjectName

        This example gives you the Nav object name that extension with Id 50292 extends
        
    .INPUTS
        None.

    .OUTPUTS
        The return Type is an Array of PSCustomObjects.

    .LINK
        http://andreilungu.com/nav-al-extension-files-info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][array]$ALExtensionFiles,
        [switch]$GetIDFromExtensionName,
        [switch]$GetObjectNameFromFileName,
        [switch]$GetFreeIds
        )
    
    If(($ALExtensionFiles | Get-Member | Where-Object{$_.Name -eq "PSIsContainer"}).Count -eq 0) {
        throw 'You must provide an array of FileInfo objects for parameter ALExtensionFiles(Use function Get-ChildItem to Get files from folders where you have extension files). '
    }

    If($GetIDFromExtensionName) {
        [regex]$Regex = '[a-zA-Z]+(?<num>\d+)'
    } else {
        [regex]$Regex = '(?<num>\b\d+)'
    }

    $ExtensionNumbers = @()
    foreach($File in $ALExtensionFiles)
    {
        If([IO.Path]::GetExtension($File.FullName) -ne '.al') {continue}
        $ExtHash = @{}
        $stringfirstline = (Select-String -InputObject $file -Pattern $RegEx | select-object -First 1).Line
        $m = $Regex.Matches($stringfirstline)
        $number = ($m[0].Groups["num"].Value) * 1
        $ExtHash.Add("FileName",$File.FullName)

        If(!$GetObjectNameFromFileName) {
            #match the object name from the first line (after word 'extends'): 
            $ExtHash.Add("ObjectName",(([regex]::Match($stringfirstline,'(?<=extends ).*').Value) -replace '"','').TrimEnd())
        } else {
            $ExtHash.Add("ObjectName",[regex]::Match($File.Name,'(?<=\w+(?:\d+)? - ).*').Value)
        }
        
        $ExtHash.Add("ExtensionNumber",$number)
        $ExtHash.Add("ExtensionType",[regex]::Match($stringfirstline,'^\b\w+'))
        $PsObject = New-Object PSObject -property $ExtHash
        $ExtensionNumbers += $PsObject
    }
    
    If($GetFreeIds){
        return Get-FreeExtensionIds -ALExtensionFiles ($ExtensionNumbers | Sort-Object -Property ExtensionType,ExtensionNumber)
    } else {
        return $ExtensionNumbers | Sort-Object -Property ExtensionType,ExtensionNumber
    }
}

Function Get-FreeExtensionIds{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][array]$ALExtensionFiles
    )

    $FreeIds = @()
    [int]$PreviousId = 0
    [string]$PreviousType = ''

    foreach($item in $ALExtensionFiles) {
        If(($PreviousId -eq 0) -or ($PreviousType -ne $item.ExtensionType)) {
            $PreviousId = $item.ExtensionNumber;$PreviousType = $item.ExtensionType;continue
        }

        If(($item.ExtensionNumber - $PreviousId) -ne 1) {
            for($i=0; $i -lt ($item.ExtensionNumber - $PreviousId - 1); $i++) {
                $FreeIdsHash = @{}
                $FreeIdsHash.Add("ExtensionNumber",$PreviousId + $i + 1)
                $FreeIdsHash.Add("ExtensionType",$item.ExtensionType)
                $PsObject = New-Object PSObject -property $FreeIdsHash
                $FreeIds += $PsObject
            }
        }

       $PreviousId = $item.ExtensionNumber;$PreviousType = $item.ExtensionType
    }
    return $FreeIds
}