function Add-Reference{
    # Calling convension:
    #   AddReference.PS1 "Mycsproj.csproj", 
    #                    "MyNewDllToReference.dll", 
    #                    "MyNewDllToReference"
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$dllRef, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$refName)

    $proj = [xml](Get-Content $path)
    [System.Console]::WriteLine("")
    [System.Console]::WriteLine("AddReference {0} on {1}", $refName, $path)

    # Create the following hierarchy
    #  <Reference Include='{0}'>
    #     <HintPath>{1}</HintPath>
    #  </Reference>
    # where (0) is $refName and {1} is $dllRef
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
    $xmlns = "http://schemas.microsoft.com/developer/msbuild/2003"
    #$itemGroup = $proj.CreateElement("ItemGroup", $xmlns);
    #$proj.Project.AppendChild($itemGroup);
    $nsmgr.AddNamespace("a", $xmlns)
    
    if ($proj.SelectNodes([string]::Format("//a:Reference[@Include='{0}']", $refName), $nsmgr).Count -eq 0 ){
        $nodes = $proj.SelectNodes("//a:Reference",$nsmgr)
    
        $referenceNode = $proj.CreateElement("Reference", $xmlns);
        $referenceNode.SetAttribute("Include", $refName);
        $nodes[0].ParentNode.AppendChild($referenceNode)

        $hintPath = $proj.CreateElement("HintPath", $xmlns);
        $hintPath.InnerXml = $dllRef
        $referenceNode.AppendChild($hintPath)

        $proj.Save($path)
    }
    #else do nothing because it's already there
}

function Remove-Reference{
    # Calling Convention
    #   RemoveReference.ps1 "MyCsProj.csproj" 
    #   "..\SomeDirectory\SomeProjectReferenceToRemove.dll"
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$Reference)

    $XPath = [string]::Format("//a:Reference[@Include='{0}']", $Reference)   

    [System.Console]::WriteLine("XPATH IS {0}", $XPath)    
    try{
    
        $proj = [xml](Get-Content $path)
        [System.Console]::WriteLine("Loaded project {0} into {1}", $path, $proj)
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
        $nsmgr.AddNamespace('a','http://schemas.microsoft.com/developer/msbuild/2003')
        $node = $proj.SelectSingleNode($XPath, $nsmgr)

        if (!$node)
        { 
            [System.Console]::WriteLine("");
            [System.Console]::WriteLine("Cannot find node with XPath {0}", $XPath) 
            [System.Console]::WriteLine("");
            #exit
        }

        [System.Console]::WriteLine("Removing node {0}", $node)
        $node.ParentNode.RemoveChild($node);

        $proj.Save($path)
    }
    catch{
        "An error has occured that could not be resolved"
    }
}

function Change-Reference{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$dllRef, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$refName)

    $XPath = [string]::Format("//a:Reference[@Include='{0}']", $refName)   

    #[System.Console]::WriteLine("XPATH IS {0}", $XPath)    
    try{
    
        $proj = [xml](Get-Content $path)
        #[System.Console]::WriteLine("Loaded project {0} into {1}", $path, $proj)
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
        $nsmgr.AddNamespace('a','http://schemas.microsoft.com/developer/msbuild/2003')
        $node = $proj.SelectSingleNode($XPath, $nsmgr)

        if ($node -and $node.HasChildNodes)
        { 
            $hintNode = $node.SelectSingleNode("a:HintPath",$nsmgr)
            if ($hintNode){
                $hintNode.InnerText = $dllRef
            }else{
                Write-Error "Didn't find a hint child element"
            }
            $proj.Save($path)
        }else{
            Write-Error "Did not find a matching reference"
        }
        
    }
    catch{
        "An error has occured that could not be resolved: "+ $_
    }
}

function Get-References{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path)

    $proj = GetBuildXML($path)
    $nsmgr = GetMSBuildNamespace($path)
    $NSQualifier = MSBuildNSQual
    $node = $proj.SelectNodes([String]::Format("//{0}:Reference", $NSQualifier), $nsmgr)
    
    $ourResult = New-Object PSObject
    $ourResult | Add-Member -type NoteProperty -Value $path -Name ProjectFile 
    $ourResult | Add-Member -type NoteProperty -Name References -Value @($($node |%{
                    $x = new-object psobject
                    $x | Add-Member -name ReferenceName -type NoteProperty -Value $_.Include
                    $x | Add-Member -name Hint -type NoteProperty -Value $_.HintPath
                    $x
                }))
    return $ourResult
}



function Get-PostBuildEvent{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path)

    $proj = GetBuildXML($path)
    $nsmgr = GetMSBuildNamespace($proj)
    $NSQualifier = MSBuildNSQual
    $xpath = [String]::Format("//{0}:PostBuildEvent", $NSQualifier)
    $node = $proj.SelectNodes($xpath, $nsmgr)
    if ($node.Count -gt 0){
    $node | %{
        $ourResult = New-Object psobject
        $ourResult | Add-Member -type NoteProperty -Value $path -Name ProjectFile
        $ourResult | Add-Member -type NoteProperty -Value $_.InnerXml -Name EventText
        $ourResult
        }
    }
}

function Set-PostBuildEvent{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$postBuildText)

    $proj = GetBuildXML($path)
    $nsmgr = GetMSBuildNamespace($proj)
    $NSQualifier = MSBuildNSQual
    $xpath = [String]::Format("//{0}:PostBuildEvent", $NSQualifier)
    $node = $proj.SelectNodes($xpath, $nsmgr)

    if ($node.Count -eq 1){
        $newNode = $proj.CreateElement("PostBuildEvent","http://schemas.microsoft.com/developer/msbuild/2003")
        # escape things so the xml will always be good
        $newNode.InnerXml =[System.Security.SecurityElement]::Escape($postBuildText)
        $parent = $node.ParentNode
        $parent.AppendChild($newNode)
        $parent.RemoveChild($node[0])

        $proj.Save($path)
    }
    else{
        Write-Error "Did not match a single node to replace. Matched $node.Count nodes"
    }

}


# private Functions (i.e. not exported)
function GetBuildXML{
    param([Parameter(Mandatory=$true)][string]$path)
    return $proj = [xml](Get-Content $path)
}

function MSBuildNSQual{
    return 'a'
}

function GetMSBuildNamespace{
    param([Parameter(Mandatory=$true)][System.Xml.XmlDocument]$proj)

    [System.Xml.XmlNamespaceManager] $nsmgr = $proj.NameTable
    $NSQualifier = MSBuildNSQual
    $nsmgr.AddNamespace($NSQualifier,'http://schemas.microsoft.com/developer/msbuild/2003')
    #without the comma PS will flatten to object[]
    return ,$nsmgr
}

