[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$GameDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$projectRoot=Split-Path -Parent $PSScriptRoot
$location=Join-Path $projectRoot '.local-state\game-directory.txt'
if(-not $GameDirectory -and (Test-Path -LiteralPath $location)){$GameDirectory=[IO.File]::ReadAllText($location).Trim()}
$game=Resolve-AC7Game $GameDirectory
Assert-AC7Closed $game
$modNames=@('AC7UIAspect','AC7FlightOnly','AC7UILayoutProbe')
$updates=[ordered]@{}
$txtPath=Join-Path $game 'ue4ss\Mods\mods.txt'
if(Test-Path -LiteralPath $txtPath){
    $text=[IO.File]::ReadAllText($txtPath)
    $clean=[regex]::Replace($text,'(?m)^[ \t]*(?:AC7UIAspect|AC7FlightOnly|AC7UILayoutProbe)[ \t]*:[^\r\n]*(?:\r?\n|$)','')
    if($clean -cne $text){$updates['ue4ss\Mods\mods.txt']=$clean}
}
$jsonPath=Join-Path $game 'ue4ss\Mods\mods.json'
if(Test-Path -LiteralPath $jsonPath){
    $parsed=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($jsonPath))
    if(@($parsed | Where-Object {$_.mod_name -in $modNames}).Count){
        $entries=@($parsed | Where-Object {$null -ne $_ -and $_.mod_name -notin $modNames})
        $updates['ue4ss\Mods\mods.json']=ConvertTo-Json -InputObject $entries -Depth 20
    }
}
# Remove only this patch's files and known earlier implementations, never shared loaders/runtime.
$owned=@('AC7SceneProjection.asi','AC7HUDCenter.asi','AC7SceneProjection.log','AC7HUDCenter.log',
    'ac7ultrawide.asi','ac7projectionprobe.asi','ac7ultrawide.ini','ac7ultrawide.log','AC7ProjectionProbe.bin','AC7ProjectionProbe.log')
foreach($name in $modNames){$owned+=,('ue4ss\Mods\'+$name)}
foreach($index in 1..8){$owned+=,"AC7HUDCenter-shader-$index.txt"}
$remove=@($owned | Where-Object {Test-Path -LiteralPath (Join-Path $game $_)})
if(-not $remove.Count -and -not $updates.Count){Write-Output 'No patch files or enabled entries remain.';return}
foreach($relative in $remove){
    $item=Get-Item -LiteralPath (Join-Path $game $relative)
    if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Patch path is a link; review before removing: $relative"}
    if($item.PSIsContainer -and @(Get-ChildItem -LiteralPath $item.FullName -Recurse -Force | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count){
        throw "Patch directory contains links; review before removing: $relative"
    }
}
if(-not $PSCmdlet.ShouldProcess($game,'Remove this patch and its mod-list entries')){return}
$backup=Join-Path $projectRoot ('backups\uninstall-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$changed=@($remove)+@($updates.Keys)
foreach($relative in $changed){
    $saved=Join-Path $backup $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $game $relative) -Destination $saved -Recurse -Force
}
try{
    foreach($relative in $updates.Keys){Write-AC7Utf8 (Join-Path $game $relative) $updates[$relative]}
    foreach($relative in $remove){Remove-Item -LiteralPath (Join-Path $game $relative) -Recurse -Force}
}catch{
    $failure=$_
    foreach($relative in $changed){
        try{
            $target=Join-Path $game $relative
            $saved=Join-Path $backup $relative
            if((Test-Path -LiteralPath $target -PathType Leaf) -and (Test-Path -LiteralPath $saved -PathType Leaf) -and (Get-AC7Hash $target) -eq (Get-AC7Hash $saved)){continue}
            if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Recurse -Force}
            Copy-Item -LiteralPath $saved -Destination $target -Recurse -Force
        }catch{Write-Warning "Could not restore $relative; its backup is in $backup"}
    }
    throw $failure
}
Write-Output "Uninstalled patch from: $game"
Write-Output 'Patch files and mod-list entries removed. Previous patch versions were not restored.'
Write-Output 'External dependencies, other mods, game assets, saves and input bindings were preserved.'
