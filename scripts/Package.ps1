param([string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Common.ps1')
if(-not $OutputDirectory){$OutputDirectory=Join-Path $root 'releases'}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$cmake=[IO.File]::ReadAllText((Join-Path $root 'CMakeLists.txt'))
if($cmake -notmatch '(?im)^\s*project\(AC7UltrawideFix\s+VERSION\s+(\d+\.\d+\.\d+(?:\.\d+)?)\s'){
    throw 'Could not find the AC7UltrawideFix version in CMakeLists.txt.'
}
$version=$Matches[1]
$stage=Join-Path ([IO.Path]::GetTempPath()) ('ac7-package-'+[guid]::NewGuid().ToString('N'))
try{
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    # Installation files only.
    foreach($name in @('LICENSE','README.md','README_zh.md','Install.cmd','Uninstall.cmd','mod','licenses')){
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
    $archive=Join-Path $OutputDirectory ('AC7-Ultrawide-Fix-'+$version+'.zip')
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive -Force -CompressionLevel Optimal
    Write-AC7Utf8 ($archive+'.sha256') ((Get-AC7Hash $archive)+'  '+(Split-Path -Leaf $archive)+"`n")
    Write-Output "Package: $archive ($((Get-Item -LiteralPath $archive).Length) bytes)"
}finally{
    if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
}
