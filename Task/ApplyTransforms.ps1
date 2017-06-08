param(
    [string]$buildConfiguration,
    [string]$extension,
    [string]$dllFolder
)


if ($dllFolder -eq $null -OR $dllFolder -eq "") {

    # Resolve path to VS
    $vswScript = "$PSScriptRoot\vswhere.exe"
    $vsVersion = & $vswScript  @("-format", "json") | ConvertFrom-Json

    
    Write-Host "Found Visual Studio $vsVersion.installationVersion at $vsVersion.installationPath"

    if ($vsVersion.installationVersion.StartsWith("15")) {
        $dllFolder = Join-Path $vsVersion.installationPath "MSBuild\Microsoft\VisualStudio\v15.0\Web\"
    }
    
    if ($vsVersion.installationVersion.StartsWith("14")) {
        $dllFolder = Join-Path $vsVersion.installationPath "MSBuild\Microsoft\VisualStudio\v14.0\Web\"
    }

    Write-Host "DLL Path for Microsoft.Web.XmlTransform.dll is $dllFolder"
}


$dllFullPath = Join-Path $dllFolder "Microsoft.Web.XmlTransform.dll"
Add-Type -Path $dllFullPath

$sourcesDirectory = $Env:BUILD_SOURCESDIRECTORY

Write-Host "Applying $buildConfiguration transforms to all config files in $sourcesDirectory"

# Apply the version to the assembly property files
$files = gci $sourcesDirectory -recurse | 
    ?{ $_.PSIsContainer } | 
    foreach { gci -Path $_.FullName -Recurse -include *.$extension }

if($files)
{
    Write-Verbose "Found $($files.count) config files."

    foreach ($file in $files) 
    {
        if ($file.FullName.ToLower().EndsWith(".$buildConfiguration.$extension"))
        {
            Write-Verbose "Found $file"
            $org = $file.FullName -replace ".$buildConfiguration",""
            $trs = $file.FullName
            Write-Verbose "Corresponding original file: $org"
            
            # set up output filenames
            $WorkDir = Join-Path ${env:temp} "work-${PID}"
            $SourceWork = Join-Path $WorkDir (Split-Path $org -Leaf)
            $TransformWork = Join-Path $WorkDir (Split-Path $trs -Leaf)
            $OutputWork = Join-Path $WorkDir (Split-Path $org -Leaf)
            
            # create a working directory and copy files into place
            New-Item -Path ${WorkDir} -Type Directory
            Copy-Item $org $WorkDir
            Copy-Item $trs $WorkDir

            $xmldoc = New-Object Microsoft.Web.XmlTransform.XmlTransformableDocument;
            $xmldoc.PreserveWhitespace = $true
            $xmldoc.Load($SourceWork);
            $transf = New-Object Microsoft.Web.XmlTransform.XmlTransformation($TransformWork);

            if ($transf.Apply($xmldoc) -eq $false)
            {
                throw "Transformation failed."
            }
            $xmldoc.Save($OutputWork);

            # copy the output to the desired location
            Copy-Item $OutputWork $org

            # clean up
            Remove-Item $WorkDir -Recurse -Force
        }
    }
    
    foreach ($file in $files) 
    {
        if ($file.FullName.ToLower().EndsWith(".release.$extension") -or $file.FullName.ToLower().EndsWith(".debug.$extension"))
        {
            if (Test-Path $file.FullName) 
            {
                Remove-Item $file.FullName
            }
        }
    }
}
else
{
    Write-Host "Found no files."
}