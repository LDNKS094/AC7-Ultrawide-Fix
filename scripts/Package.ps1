param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Common.ps1')
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'releases'}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$release=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $root 'release.json')))
$stage=Join-Path ([IO.Path]::GetTempPath()) ('ac7-package-'+[guid]::NewGuid().ToString('N'))
try{
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    # Installation files only.
    foreach($name in @('README.md','README_zh.md','Install.cmd','Uninstall.cmd','mod','licenses')){
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage -Recurse
    }
    $tools=Join-Path $stage 'scripts'
    New-Item -ItemType Directory -Path $tools -Force | Out-Null
    foreach($name in @('Common.ps1','Install.ps1','Uninstall.ps1')){
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $tools
    }
    $native=Join-Path $stage 'payload'
    New-Item -ItemType Directory -Path $native -Force | Out-Null
    foreach($name in @('AC7SceneProjection.asi','AC7HUDCenter.asi')){
        Copy-Item -LiteralPath (Join-Path $root ('payload\'+$name)) -Destination $native
    }
    $inventory=@(Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{path=$_.FullName.Substring($stage.Length+1).Replace('\','/');bytes=$_.Length;sha256=Get-AC7Hash $_.FullName}
    })
    $manifest=[ordered]@{format=1;package=$release.package;version=$release.version;files=$inventory}
    $json=ConvertTo-Json -InputObject $manifest -Depth 20
    Write-AC7Utf8 (Join-Path $stage 'MANIFEST.json') $json
    Write-AC7Utf8 (Join-Path $root 'MANIFEST.json') $json
    $archive=Join-Path $OutputDirectory ($release.package+'-'+$release.version+'.zip')
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -Force -CompressionLevel Optimal
    Write-AC7Utf8 ($archive+'.sha256') ((Get-AC7Hash $archive)+'  '+(Split-Path -Leaf $archive)+"`n")
    Write-Output "Package: $archive ($((Get-Item -LiteralPath $archive).Length) bytes, $($inventory.Count+1) files)"
}finally{
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
