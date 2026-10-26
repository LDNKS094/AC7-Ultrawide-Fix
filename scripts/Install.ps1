[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$GameDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$game=Resolve-AC7Game $GameDirectory
Assert-AC7Closed $game
$projectRoot=Split-Path -Parent $PSScriptRoot
$payload=Join-Path $projectRoot 'payload'
# Check required UI runtime paths, without pinning external versions or replacing their files.
foreach($relative in @('ue4ss\UE4SS.dll','ue4ss\Mods\shared\UEHelpers\UEHelpers.lua')){
    if(-not(Test-Path -LiteralPath (Join-Path $game $relative) -PathType Leaf)){
        throw "Missing dependency: $relative. Install UE4SS with UEHelpers first; see README.md. No game files changed."
    }
}
$files=[ordered]@{}
foreach($name in @('AC7SceneProjection.asi','AC7HUDCenter.asi')){$files[$name]=Join-Path $payload $name}
foreach($name in @('main.lua','loading_geometry.lua','overlay_geometry.lua')){
    $files['ue4ss\Mods\AC7UIAspect\Scripts\'+$name]=Join-Path $projectRoot ('mod\AC7UIAspect\Scripts\'+$name)
}
foreach($source in $files.Values){
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Missing package file: $source. No game files changed."}
}
$txtPath=Join-Path $game 'ue4ss\Mods\mods.txt'
$text=if(Test-Path -LiteralPath $txtPath){[IO.File]::ReadAllText($txtPath)}else{''}
foreach($name in @('AC7FlightOnly','AC7UILayoutProbe','AC7UIAspect')){
    $enabled=if($name -eq 'AC7UIAspect'){1}else{0}
    $pattern='(?m)^[ \t]*'+[regex]::Escape($name)+'[ \t]*:[ \t]*\d+[ \t]*(?=\r?$)'
    if($text -match $pattern){$text=[regex]::Replace($text,$pattern,"${name} : $enabled")}
    elseif($enabled){$text=$text.TrimEnd()+"`r`n${name} : 1`r`n"}
}
$jsonPath=Join-Path $game 'ue4ss\Mods\mods.json'
$entries=if(Test-Path -LiteralPath $jsonPath){@(ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($jsonPath)))}else{@()}
$entries=@($entries)
$found=$false
foreach($entry in $entries){
    if($entry.mod_name -in @('AC7FlightOnly','AC7UILayoutProbe')){$entry.mod_enabled=$false}
    if($entry.mod_name -eq 'AC7UIAspect'){$entry.mod_enabled=$true;$found=$true}
}
if(-not $found){$entries+=,[pscustomobject]@{mod_name='AC7UIAspect';mod_enabled=$true}}
$json=ConvertTo-Json -InputObject @($entries) -Depth 20
if(-not $PSCmdlet.ShouldProcess($game,'Back up and install the standalone ultrawide fix')){return}
$backup=Join-Path $projectRoot ('backups\'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Write-AC7Utf8 (Join-Path $backup 'staged\mods.txt') $text
Write-AC7Utf8 (Join-Path $backup 'staged\mods.json') $json
$files['ue4ss\Mods\mods.txt']=Join-Path $backup 'staged\mods.txt'
$files['ue4ss\Mods\mods.json']=Join-Path $backup 'staged\mods.json'
$records=@()
foreach($relative in $files.Keys){
    $source=$files[$relative]
    if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Missing package file: $relative"}
    $target=Join-Path $game $relative
    $existed=Test-Path -LiteralPath $target
    if($existed){
        $saved=Join-Path $backup ('original\'+$relative)
        New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
        Copy-Item -LiteralPath $target -Destination $saved
    }
    $records+=,[ordered]@{path=$relative;existed=[bool]$existed;action='write';installedSha256=Get-AC7Hash $source}
}
foreach($relative in @('ac7ultrawide.asi','ac7projectionprobe.asi')){
    $target=Join-Path $game $relative
    if(Test-Path -LiteralPath $target){
        New-Item -ItemType Directory -Path (Join-Path $backup 'original') -Force | Out-Null
        Copy-Item -LiteralPath $target -Destination (Join-Path $backup ('original\'+$relative))
        $records+=,[ordered]@{path=$relative;existed=$true;action='remove';installedSha256=$null}
    }
}
$exeHash=Get-AC7Hash (Join-Path $game 'Ace7Game.exe')
$done=@()
try{
    foreach($record in $records){
        $target=Join-Path $game $record.path
        # Include the current operation in rollback even if a copy fails partway through.
        $done+=,$record
        if($record.action -eq 'remove'){Remove-Item -LiteralPath $target}
        else{
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $files[$record.path] -Destination $target -Force
            if((Get-AC7Hash $target) -ne $record.installedSha256){throw "Copy verification failed: $($record.path)"}
        }
    }
    if((Get-AC7Hash (Join-Path $game 'Ace7Game.exe')) -ne $exeHash){throw 'Unexpected executable change.'}
}catch{
    $failure=$_
    for($index=$done.Count-1;$index -ge 0;$index--){
        $record=$done[$index];$target=Join-Path $game $record.path
        try{
            if($record.existed){
                $saved=Join-Path $backup ('original\'+$record.path)
                if((Test-Path -LiteralPath $target -PathType Leaf) -and (Get-AC7Hash $target) -eq (Get-AC7Hash $saved)){continue}
                Copy-Item -LiteralPath $saved -Destination $target -Force
            }elseif(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Force}
        }catch{Write-Warning "Could not restore $($record.path); its backup is in $backup"}
    }
    Write-Warning "Installation failed; recovery files retained at: $backup"
    throw $failure
}
Write-AC7Utf8 (Join-Path $projectRoot '.local-state\game-directory.txt') $game
Remove-AC7TemporaryBackup $backup
Write-Output "Installed latest package to: $game"
Write-Output 'External loaders, UE4SS, settings, input bindings and game assets were preserved.'
