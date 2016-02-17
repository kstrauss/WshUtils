<#
.Synopsis
private Helper function to denote that it should exported as part of the module
#>
function export
{
  param ([parameter(mandatory=$true)] [validateset("function","variable")] $type,
  [parameter(mandatory=$true)] $name,
  [parameter(mandatory=$true)] $value)
  if ($type -eq "function")
   {
     Set-item "function:script:$name" $value
     Export-ModuleMember $name
   }
else
   {
     Set-Variable -scope Script $name $value
     Export-ModuleMember -variable $name
   }
}

<#
.Synopsis
Adds a dll as a reference to a project file

.Example add-DllReference mycsproj.csproj MyNewDll.dll myNewDll

.Notes
Potentially you might want to add a project reference instead of a DLL or assembly
#>
export function Add-DllReference{
    # Calling convension:
    #   AddReference.PS1 "Mycsproj.csproj", 
    #                    "MyNewDllToReference.dll", 
    #                    "MyNewDllToReference"
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$dllRef, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$refName)

    $proj = [xml](Get-Content $path)
    $srcPath = (dir $path).FullName # for writing it doesn't get the full path
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

        $proj.Save($srcPath)
    }
    #else do nothing because it's already there
}

export function Remove-Reference{
    # Calling Convention
    #   RemoveReference.ps1 "MyCsProj.csproj" 
    #   "..\SomeDirectory\SomeProjectReferenceToRemove.dll"
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$Reference)

    $XPath = [string]::Format("//a:Reference[@Include='{0}']", $Reference)   
    $srcPath = (dir $path).FullName # for writing it doesn't get the full path
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

        $proj.Save($srcPath)
    }
    catch{
        "An error has occured that could not be resolved"
    }
}

export function Edit-Reference{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$dllRef, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$refName)

    $XPath = [string]::Format("//a:Reference[@Include='{0}']", $refName)   
    $srcPath = (dir $path).FullName # for writing it doesn't get the full path
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
            $proj.Save($srcPath)
        }else{
            Write-Error "Did not find a matching reference"
        }
        
    }
    catch{
        "An error has occured that could not be resolved: "+ $_
    }
}

export function Get-References{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path)

    $proj = GetBuildXML($path)
    $nsmgr = GetMSBuildNamespace($proj)
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

export function Get-ProjectReference{
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][Alias('PSPath')][System.IO.FileInfo]$path
        )
	# for some reasons I don't under stand, sometimes this coeresion puts the path into the
	# current users document directory instead of the relative path, this tries to solve that
	if (-not $path.Exists){
		$path = dir $path
	}
	if ($path.Exists){
		$proj = GetBuildXML($path.FullName)
		$nsmgr = GetMSBuildNamespace($proj)
		$NSQualifier = MSBuildNSQual
		$node = $proj.SelectNodes([String]::Format("//{0}:ProjectReference", $NSQualifier), $nsmgr)

		$ourResult = New-Object PSObject
		$ourResult | Add-Member -type NoteProperty -Value $path -Name ProjectFile 
		$ourResult | Add-Member -type NoteProperty -Name ProjectReferences -Value @($($node |%{
						$x = new-object psobject
						$x | Add-Member -name Name -type NoteProperty -Value $_.Name
						$x | Add-Member -name ReferenedProjectPath -type NoteProperty -Value $_.Include
						$x | Add-Member -name ProjectGuid -type NoteProperty -Value $_.Project
						$x
					}))
		return $ourResult
	}
	else{
		write-error "$path does not exist"
	}
}

export function Add-ProjectReference{
<#
.SYNOPSIS
Adds a project reference to an existing project

.DESCRIPTION
Adds a project reference to an existing project

.path Full path to the project file you are modifying to add this new project reference to
.referencedProjPath Full Path to the project file that is being referenced
.Relative A switch that says whether to use the full path or a relative path to the referencedProjPath

.EXAMPLE
Basic usage
Add-ProjectReference -csProjPath c:\projA\projA.csproj -referencedProjPath c:\projb\projb.csproj
#>

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$referencedProjPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$IncludeStr
    )
        $refProjPath = (Resolve-Path $referencedProjPath).Path
        $srcProjXml = [xml](gc $referencedProjPath)
        $projGuid = (Get-ProjectGuid -Path $refProjPath).keys[0]
        $XPath = "//a:ProjectReference"

        $srcPath = (dir $path).FullName # for writing it doesn't get the full path
        $proj = [xml](Get-Content $path)
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
        $ns = 'http://schemas.microsoft.com/developer/msbuild/2003'
        $nsmgr.AddNamespace('a',$ns)

        $parentNode = $proj.SelectNodes($XPath, $nsmgr)[0].ParentNode
        $newNode = $proj.CreateElement("ProjectReference", $ns)
        $newNode.SetAttribute("Include",  $IncludeStr)

        $projGuidElem = $proj.CreateElement("Project", $ns)
        $projGuidElem.InnerText=$projGuid
        $newNode.AppendChild($projGuidElem)

        $projName = $proj.CreateElement("Name",$ns)
        $projName.InnerText = $(dir $refProjPath).BaseName
        $newNode.AppendChild($projName)
        if ($parentNode.Count -eq 0){
            # there was no ItemGroup with project references so we make one
            $itemGroup = $proj.CreateElement("ItemGroup",$ns)
            $itemGroup.AppendChild($newNode)
            $proj.AppendChild( $itemGroup)
        }
        else{
            $parentNode.AppendChild($newNode)
        }
        
        $proj.Save($srcPath)     
}

export function Change-ProjectReference{
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$SearchProjGuid, # this is what we search by
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$SrcProjPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$NewProjGuid, 
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)][String]$Name
        )

    $XPath = [string]::Format("//a:ProjectReference[a:Project='{0}']", $SearchProjGuid)  
     
    try{
        $srcPath = (dir $path).FullName # for writing it doesn't get the full path
        $proj = [xml](Get-Content $path)
        #[System.Console]::WriteLine("Loaded project {0} into {1}", $path, $proj)
        $nsmgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
        $nsmgr.AddNamespace('a','http://schemas.microsoft.com/developer/msbuild/2003')
        $node = $proj.SelectSingleNode($XPath, $nsmgr)

        if ($node -and $node.HasChildNodes)
        {
            Write-Debug "Matched xpath $xpath"
            $x = $node.Attributes['Include'].Value
            write-Debug "$x"
            $node.Attributes['Include'].Value = $SrcProjPath
            $x = $node.Attributes['Include'].Value
            write-Debug "$x"
            #name
            $nameNode = $node.SelectSingleNode("a:Name",$nsmgr)
            if ($nameNode){
                $nameNode.InnerText = $Name
            }else{
                Write-Error "Didn't find a Name child element"
            }
            #guid
            $projNode = $node.SelectSingleNode("a:Project",$nsmgr)
            if ($projNode){
                $projNode.InnerText = $NewProjGuid
            }else{
                Write-Error "Didn't find a Name Project element"
            }
            Write-Debug "Writing changes to $path"
            $proj.Save($srcPath)
        }else{
            Write-Error "Did not find a matching reference"
        }
        
    }
    catch{
        "An error has occured that could not be resolved: "+ $_
    }
}

export function Get-PostBuildEvent{
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

export function Set-PostBuildEvent{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$postBuildText)

    $proj = GetBuildXML($path)
    $nsmgr = GetMSBuildNamespace($proj)
    $NSQualifier = MSBuildNSQual
    $xpath = [String]::Format("//{0}:PostBuildEvent", $NSQualifier)
    $node = $proj.SelectNodes($xpath, $nsmgr)

    

    if ($node.Count -le 1){
        $newNode = $proj.CreateElement("PostBuildEvent","http://schemas.microsoft.com/developer/msbuild/2003")
        # escape things so the xml will always be good
        $newNode.InnerXml =[System.Security.SecurityElement]::Escape($postBuildText)
        if ($node.Count -eq 0){
            $PropGroupNode = $proj.CreateElement("PropertyGroup","http://schemas.microsoft.com/developer/msbuild/2003")
            $PropGroupNode.AppendChild($newNode)
            $proj.DocumentElement.AppendChild($PropGroupNode)
        }
        else{
            $parent = $node.ParentNode
            $parent.AppendChild($newNode)

            $parent.RemoveChild($node[0])
        }

        $proj.Save($path)
    }
    else{
        Write-Error "Did not match a single node to replace. Matched $node.Count nodes"
    }
}

# Start of thought to change NoneElements see: http://msdn.microsoft.com/en-us/library/bb629388.aspx
# so that we could modify them to copyToOutputDirectory
function Get-NoneElements{
    param([Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$path,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)][string]$postBuildText)

    $proj = GetBuildXML($path)
    $nsmgr = GetMSBuildNamespace($proj)

    $NSQualifier = MSBuildNSQual
    $xpath = [String]::Format("/{0}:ItemGroup/{0}:None", $NSQualifier)
    $node = $proj.SelectNodes($xpath, $nsmgr)
}

<#
.SYNOPSIS
Use SolutionDir variable for nuget references

.DESCRIPTION
Instead of using relative references for nuget references use the SolutionDir
variable. This way if the relative path to the solution file changes then things
should just all work

.PARAMETER path
a project file File Info

.EXAMPLE
dir -recurse -filter *.csproj | %{Update-NuGetReferencesToUseSolutionDir}
#>
export function Update-NuGetReferencesToUseSolutionDir{
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[Alias('PSPath')]
		[System.IO.FileInfo]
		$path
	)
	# if a build file
	$fullPath = $path.FullName
    $ref = $fullPath | Get-References
    
	# find those that need updating
    $needToUpdate = $ref.References | Where-Object {$_.Hint -match "(.*)\\packages\\"}
    
	#update those that need to be updated
    $needToUpdate | ForEach-Object {
        $newHint = $_.Hint -replace "(.*)\\packages\\", '$(SolutionDir)\packages\'
        Edit-Reference $fullPath -dllRef $newHint -refName $_.ReferenceName
        write-debug $_.ReferenceName, $newHint
        }
}

<#
.SYNOPSIS
Get HashTable of Project Guids to project file

.Description
It's sometimes useful to be able to associate what Project Guid to a particular
project file. Especially when you are moving things around and will need to
reset positions. So in many ways this is a helper function.

It will resolve the path to relative to where you run this file from, so run it
from the directory that you want to have as the "root"

.EXAMPLE
dir -recurse -filter *.csproj | Get-ProjectGuid
#>
export function Get-ProjectGuid{
	Param(
        
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Alias('PSPath')]
		[System.IO.FileInfo[]]
		$Path
	)
    begin{
	    $All = @{}
    }
    process{
	    $Path | ForEach-Object {
			    $projXml = [xml](Get-Content $_.FullName)
			    $projGuid = $projXml.Project.PropertyGroup.ProjectGuid[0].Trim()
			    #$projGuid | gm
			    $All[$projGuid] = $_.FullName
		    }
    }
    end{
    	return $All
    }
}


<#
.SYNOPSIS
Update a solution file that references a set of projects

.Description
Given the scenario that you have a solution file that references some number of
project files, but the project files have changed names or location, it will reset
the references to the new paths.

Warning: if you have the solution in source control, your bindings may be out of whack.
The best solution I know of is to delete the bindings manually (currently no cmdlet for that),
and delete the hidden suo binary file (in same directory as the solution file). Then
open in Visual studio and it should just "work"

.EXAMPLE
Rejig-SolutionWithMovedProjects -ProjectFiles (dir -recurse -filter *.csproj) -SolutionFile x.sln
#>
export function Rejig-SolutionWithMovedProjects{
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[System.IO.FileInfo[]]
		$ProjectFiles,
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[String]
		$SolutionFile)
    $All = $ProjectFiles | Get-ProjectGuid
    
    $sf = dir $SolutionFile
    if ($sf.Exists){
        $x = Get-Content $sf
        $All.Keys | %{
            # expect a line like:
            #Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "NicorReceivedConsumptIntegrationSvc", ".\Partner\Nicor\NicorReceivedConsumptIntegrationSvc\NicorReceivedConsumptIntegrationSvc.csproj", "{CA06E9CA-4FEB-414F-84D5-C3072E1CDA2A}"
    
            $t = $_
            $pattern = "Project\(""(?<unknownGuid>.*)""\) = ""(?<ProjName>.*)"", ""(?<Path>.*)"", ""(?<ProjGuid>$t)"""
            $r = $x  | Select-string $pattern
            $matches = ($x | ?{$_ -match $pattern} | %{$matches})
            $unknownGuid = $matches['unknownGuid']
            $projName = $matches['ProjName']
            $path = $All[$t] | Resolve-Path -Relative
            $newString = "Project(""$unknownGuid"") = ""$projName"", ""$path"", ""$t"""
            #echo $newString
            ReplaceText-InFile -inputFile $sf -searchPatter $pattern -replaceText $newString
        }
    }
    else{
        Write-Error "$sf does not exist"
    }
}

<#
.SYNOPSIS
Updates projects and their related project references

.Description
updates a set of project files that has project references to their new
location

.EXAMPLE
Edit-ProjectReference -ProjectFiles (dir -recurse -filter *.csproj)
#>
export function Edit-ProjectReference{
    [cmdletbinding(SupportsShouldProcess=$true)]
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[System.IO.FileInfo[]]
		$ProjectFiles
		)
    begin{
        Write-Debug "there are $($ProjectFiles.Count) files in begin"
        $myVar = @()
    }
    process{
	    # do nothing here because we don't have all the entries from the pipeline (if any)
        #Write-Debug "there are $($ProjectFiles.Count) files in process, will add to accumulator"
        $myVar+=$ProjectFiles
    }
    end{
        $All = $myVar | Get-ProjectGuid

        Write-Debug "Got $($myVar.Count) project files "
	    $ProjectFiles | ForEach-Object {
		    $projFile = $_.FullName
		    $projDir = $_.DirectoryName
		    $relativePath = $_ | Resolve-Path -Relative
		    $x = (Get-ProjectReference $projFile).ProjectReferences
		    # foreach reference
		    $x | ForEach-Object {
			    if ($All[$_.ProjectGuid]){
				    pushd $projDir
				    $r=$All[$_.ProjectGuid] | Resolve-Path -Relative
				    popd
				    if ($r -ne $_.ReferencedProjectPath){
					    Write-Debug "Need to update $r"
					    Change-ProjectReference -path $projFile -SearchProjGuid $_.ProjectGuid -NewProjGuid $_.ProjectGuid -SrcProjPath $r -Name $_.Name
				    }
			    }else{
				    write-error "Did not know where project file for Guid: $($_.ProjectGuid) that used to reference $($_.ReferenedProjectPath) lives. This was in $projFile"
			    }
		    }
	    }
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

Function ReplaceText-InFile
{
    Param(
    [parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [System.IO.FileInfo] $inputFile,
    [Parameter(Mandatory=$true)]
    [String] $searchPattern,
    [Parameter(Mandatory=$true)]
    [String] $replaceText
    )
    Begin{}
    Process{
       $x=gc $inputFile.FullName;
       $y=$x -replace $searchPattern, $replaceText;
       #only replace those that there actually were changes
       if (Compare-Object $x $y)
       {
        $y | Out-File -Encoding UTF8 -FilePath $inputFile.FullName
       }
     }
     End{}
}