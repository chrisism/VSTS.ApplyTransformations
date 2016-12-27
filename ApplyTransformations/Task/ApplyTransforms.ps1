param(
    [string]$buildConfiguration,
    [string]$extension,
    [string]$dllFolder
)

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

            # write the project build file
            $BuildXml = @"
<Project ToolsVersion="4.0" DefaultTargets="TransformWebConfig" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <UsingTask TaskName="TransformXml"
             AssemblyFile="`$(MSBuildExtensionsPath)\Microsoft\VisualStudio\v14.0\Web\Microsoft.Web.Publishing.Tasks.dll"/>
  <Target Name="TransformWebConfig">
    <TransformXml Source="${SourceWork}"
                  Transform="${TransformWork}"
                  Destination="${OutputWork}"
                  StackTrace="true" />
  </Target>
</Project>
"@
            $BuildXmlWork = Join-Path $WorkDir "build.xml"
            $BuildXml | Out-File $BuildXmlWork

            # call msbuild
            & MSBuild.exe $BuildXmlWork

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