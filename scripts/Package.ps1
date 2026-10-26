param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Common.ps1')
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'releases'}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$release=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $root 'release.json')))
foreach($item in $release.referenceBinaries.PSObject.Properties){
    if((Get-AC7Hash (Join-Path $root ('payload\'+$item.Name))) -ne $item.Value){throw "Payload hash mismatch: $($item.Name)"}
}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('ac7-package-'+[guid]::NewGuid().ToString('N'))
try{
    foreach($kind in @('user','source')){
        $bundle=Join-Path $stage $kind
        New-Item -ItemType Directory -Path $bundle -Force | Out-Null
        foreach($name in @('README.md','Install.cmd','Uninstall.cmd','mod','licenses')){
            Copy-Item -LiteralPath (Join-Path $root $name) -Destination $bundle -Recurse
        }
        $tools=Join-Path $bundle 'scripts'
        New-Item -ItemType Directory -Path $tools -Force | Out-Null
        foreach($name in @('Common.ps1','Install.ps1','Uninstall.ps1')){
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $tools
        }
        $native=Join-Path $bundle 'payload'
        New-Item -ItemType Directory -Path $native -Force | Out-Null
        foreach($name in @('AC7SceneProjection.asi','AC7HUDCenter.asi')){
            Copy-Item -LiteralPath (Join-Path $root ('payload\'+$name)) -Destination $native
        }
        if($kind -eq 'source'){
            foreach($name in @('CMakeLists.txt','requirements-test.txt','release.json','.gitignore','src','third_party','tests')){
                Copy-Item -LiteralPath (Join-Path $root $name) -Destination $bundle -Recurse
            }
            foreach($name in @('Build.ps1','Package.ps1')){
                Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $tools
            }
        }
        $inventory=@(Get-ChildItem -LiteralPath $bundle -File -Recurse | Sort-Object FullName | ForEach-Object {
            [ordered]@{path=$_.FullName.Substring($bundle.Length+1).Replace('\','/');bytes=$_.Length;sha256=Get-AC7Hash $_.FullName}
        })
        $manifest=[ordered]@{format=1;package=$release.package;version=$release.version;files=$inventory}
        $json=ConvertTo-Json -InputObject $manifest -Depth 20
        Write-AC7Utf8 (Join-Path $bundle 'MANIFEST.json') $json
        if($kind -eq 'user'){Write-AC7Utf8 (Join-Path $root 'MANIFEST.json') $json}
        $archive=Join-Path $OutputDirectory ('AC7-Ultrawide-Fix-'+$release.version+'-'+$kind+'.zip')
        Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $archive -Force -CompressionLevel Optimal
        Write-AC7Utf8 ($archive+'.sha256') ((Get-AC7Hash $archive)+'  '+(Split-Path -Leaf $archive)+"`n")
        Write-Output "$kind package: $archive ($((Get-Item -LiteralPath $archive).Length) bytes, $($inventory.Count+1) files)"
    }
}finally{
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
