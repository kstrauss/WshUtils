$destDir = "~\Documents\WindowsPowerShell\Modules\VisualStudioProjectModifiers"
$filesToCopy = @("VisualStudioProjectModifiers.psm1","VisualStudioModifier.psd1")
$filesToCopy | %{
	copy $_ $destDir
}

if (get-command sign-script){
    $filesToCopy | %{
	    $codeToSign = Join-Path $destDir $_
        sign-script $codeToSign
    }
    else{
        Write-Warning "Did not sign module because Sign-Script command was not found"
    }
}