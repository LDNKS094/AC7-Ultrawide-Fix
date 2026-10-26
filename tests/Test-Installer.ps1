$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
. (Join-Path $project 'scripts\Common.ps1')
function Add-Dependencies([string]$Folder){
    # Deliberately different contents: presence is required, external version hashes are not pinned.
    foreach($relative in @('dinput8.dll','dwmapi.dll','ue4ss\UE4SS.dll','ue4ss\UE4SS-settings.ini','ue4ss\Mods\shared\Types.lua','ue4ss\Mods\shared\UEHelpers\UEHelpers.lua')){
        Write-AC7Utf8 (Join-Path $Folder $relative) ('user-managed untested runtime '+$relative)
    }
}
function Check([bool]$Condition,[string]$Message){if(-not $Condition){throw "FAIL: $Message"}}
function Snapshot([string]$Folder){
    $parts=@(Get-ChildItem -LiteralPath $Folder -File -Recurse | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($Folder.Length+1)+' '+(Get-AC7Hash $_.FullName)
    })
    return $parts -join "`n"
}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('ac7-independent-install-'+[guid]::NewGuid().ToString('N'))
try{
    $package=Join-Path $fixture 'package'
    New-Item -ItemType Directory -Path $package -Force | Out-Null
    foreach($name in @('payload','mod','scripts')){Copy-Item -LiteralPath (Join-Path $project $name) -Destination $package -Recurse}
    if(Test-Path -LiteralPath (Join-Path $project 'MANIFEST.json')){Copy-Item -LiteralPath (Join-Path $project 'MANIFEST.json') -Destination $package}
    $install=Join-Path $package 'scripts\Install.ps1'
    $restore=Join-Path $package 'scripts\Uninstall.ps1'
    $game=Join-Path $fixture 'existing-game'
    Write-AC7Utf8 (Join-Path $game 'Ace7Game.exe') 'non-executable installation fixture'
    Add-Dependencies $game
    Write-AC7Utf8 (Join-Path $game 'Config\Input.ini') 'KEEP MOZA INPUT'
    Write-AC7Utf8 (Join-Path $game 'ue4ss\UE4SS-settings.ini') 'KEEP EXISTING SETTINGS'
    Write-AC7Utf8 (Join-Path $game 'ue4ss\Mods\AC7UIAspect\Scripts\main.lua') 'previous UI script'
    Write-AC7Utf8 (Join-Path $game 'ue4ss\Mods\mods.txt') "OtherMod : 1`r`nAC7FlightOnly : 1`r`nAC7UILayoutProbe : 1`r`n"
    Write-AC7Utf8 (Join-Path $game 'ue4ss\Mods\mods.json') '[{"mod_name":"OtherMod","mod_enabled":true},{"mod_name":"AC7FlightOnly","mod_enabled":true},{"mod_name":"AC7UILayoutProbe","mod_enabled":true}]'
    Write-AC7Utf8 (Join-Path $game 'ac7ultrawide.asi') 'previous legacy patch'
    $before=Snapshot $game
    $null=& $install -GameDirectory $game
    $relativeBackup=[IO.File]::ReadAllText((Join-Path $package '.local-state\latest-backup.txt')).Trim()
    Check (-not [IO.Path]::IsPathRooted($relativeBackup)) 'backup pointer is portable with the package'
    $backup=Join-Path $package $relativeBackup
    $manifest=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $backup 'manifest.json')))
    Check (@($manifest.files | Where-Object {$_.path -in @('dinput8.dll','dwmapi.dll','ue4ss\UE4SS.dll','ue4ss\UE4SS-settings.ini','ue4ss\Mods\shared\UEHelpers\UEHelpers.lua')}).Count -eq 0) 'external runtime absent from install/uninstall records'
    Check (([IO.File]::ReadAllText((Join-Path $game 'Config\Input.ini'))) -eq 'KEEP MOZA INPUT') 'input preserved'
    Check (([IO.File]::ReadAllText((Join-Path $game 'ue4ss\UE4SS-settings.ini'))) -eq 'KEEP EXISTING SETTINGS') 'settings preserved'
    Check (-not(Test-Path -LiteralPath (Join-Path $game 'ac7ultrawide.asi'))) 'legacy ASI parked in backup'
    $parsedMods=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $game 'ue4ss\Mods\mods.json')))
    $mods=@($parsedMods)
    Check (@($mods | Where-Object {$_.mod_name -eq 'OtherMod' -and $_.mod_enabled}).Count -eq 1) 'unrelated mod preserved'
    Check (@($mods | Where-Object {$_.mod_name -in @('AC7FlightOnly','AC7UILayoutProbe') -and $_.mod_enabled}).Count -eq 0) 'old diagnostics disabled'
    $scriptNames=@(Get-ChildItem -LiteralPath (Join-Path $game 'ue4ss\Mods\AC7UIAspect\Scripts') -File)
    Check ($scriptNames.Count -eq 3) 'only the three active Lua files installed'
    $patchPaths=@('AC7SceneProjection.asi','AC7HUDCenter.asi','ue4ss\Mods\AC7UIAspect\Scripts\main.lua','ue4ss\Mods\AC7UIAspect\Scripts\loading_geometry.lua','ue4ss\Mods\AC7UIAspect\Scripts\overlay_geometry.lua')
    $installedPatchHashes=@{}
    foreach($relative in $patchPaths){$installedPatchHashes[$relative]=Get-AC7Hash (Join-Path $game $relative)}
    $fixed=Snapshot $game
    $null=& $install -GameDirectory $game
    Check ((Snapshot $game) -eq $fixed) 'repeat installation idempotent, including mod-list newlines'
    $null=& $restore -BackupDirectory $backup
    Check ((Snapshot $game) -eq $before) 'restore returns exact pre-install files'

    $fresh=Join-Path $fixture 'fresh-game'
    Write-AC7Utf8 (Join-Path $fresh 'Ace7Game.exe') 'fresh fixture'
    Add-Dependencies $fresh
    Rename-Item -LiteralPath (Join-Path $fresh 'dinput8.dll') -NewName 'version.dll'
    Write-AC7Utf8 (Join-Path $fresh 'ue4ss\Mods\mods.json') '[{"mod_name":"OtherMod","mod_enabled":true}]'
    $freshBefore=Snapshot $fresh
    $null=& $install -GameDirectory $fresh
    $parsedMods=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $fresh 'ue4ss\Mods\mods.json')))
    $mods=@($parsedMods)
    Check ($mods.Count -eq 2) 'single-entry mod array retained when adding this mod'
    $nonAscii=[string][char]0x6E38+[char]0x620F
    $movedGame=Join-Path $fixture ($nonAscii+' relocated game')
    $movedPackage=Join-Path $fixture ('relocated tools '+$nonAscii)
    Move-Item -LiteralPath $fresh -Destination $movedGame
    Move-Item -LiteralPath $package -Destination $movedPackage
    $package=$movedPackage
    $install=Join-Path $package 'scripts\Install.ps1'
    $restore=Join-Path $package 'scripts\Uninstall.ps1'
    $rejected=$false
    try{$null=& $restore}catch{$rejected=$true}
    Check $rejected 'moved game requires an explicit replacement path, never a different Steam install'
    $null=& $restore -GameDirectory $movedGame
    Check ((Snapshot $movedGame) -eq $freshBefore) 'game and installer relocation with Unicode/spaces preserves exact uninstall'

    $missing=Join-Path $fixture 'missing-runtime'
    Write-AC7Utf8 (Join-Path $missing 'Ace7Game.exe') 'missing dependencies fixture'
    foreach($required in @('ue4ss\UE4SS.dll','ue4ss\Mods\shared\UEHelpers\UEHelpers.lua')){
        Add-Dependencies $missing
        Remove-Item -LiteralPath (Join-Path $missing $required)
        $missingBefore=Snapshot $missing
        $rejected=$false
        try{$null=& $install -GameDirectory $missing}catch{$rejected=$_.Exception.Message -match 'Missing dependency'}
        Check $rejected 'missing UE4SS/helper rejected with guidance'
        Check ((Snapshot $missing) -eq $missingBefore) 'missing dependency rejection leaves game untouched'
    }

    $broken=Join-Path $fixture 'rollback-game'
    Write-AC7Utf8 (Join-Path $broken 'Ace7Game.exe') 'rollback fixture'
    Add-Dependencies $broken
    Write-AC7Utf8 (Join-Path $broken 'ue4ss\Mods\AC7UIAspect') 'file blocks later script-directory creation'
    $brokenBefore=Snapshot $broken
    $rejected=$false
    try{$null=& $install -GameDirectory $broken}catch{$rejected=$true}
    Check $rejected 'commit-time failure exercised'
    Check ((Snapshot $broken) -eq $brokenBefore) 'partial installation rolled back'
    if(Test-Path -LiteralPath (Join-Path $package 'MANIFEST.json')){
        $corrupt=Join-Path $fixture 'corrupt-package-game'
        Write-AC7Utf8 (Join-Path $corrupt 'Ace7Game.exe') 'integrity fixture'
        $corruptBefore=Snapshot $corrupt
        $changedFile=Join-Path $package 'mod\AC7UIAspect\Scripts\loading_geometry.lua'
        Add-Content -LiteralPath $changedFile -Value '-- simulate a damaged package'
        $rejected=$false
        try{$null=& $install -GameDirectory $corrupt}catch{$rejected=$_.Exception.Message -match 'integrity'}
        Check $rejected 'damaged payload rejected by the package manifest'
        Check ((Snapshot $corrupt) -eq $corruptBefore) 'integrity rejection leaves game untouched'
        Copy-Item -LiteralPath (Join-Path $project 'mod\AC7UIAspect\Scripts\loading_geometry.lua') -Destination $changedFile -Force
    }
    $manual=Join-Path $fixture 'manual-install'
    Write-AC7Utf8 (Join-Path $manual 'Ace7Game.exe') 'manual fixture'
    Add-Dependencies $manual
    $manualBefore=Snapshot $manual
    foreach($name in @('AC7SceneProjection.asi','AC7HUDCenter.asi')){
        Copy-Item -LiteralPath (Join-Path $project ('payload\'+$name)) -Destination $manual
    }
    Copy-Item -LiteralPath (Join-Path $project 'mod\AC7UIAspect') -Destination (Join-Path $manual 'ue4ss\Mods') -Recurse
    Write-AC7Utf8 (Join-Path $manual 'ue4ss\Mods\mods.txt') "AC7UIAspect : 1`r`n"
    Write-AC7Utf8 (Join-Path $manual 'ue4ss\Mods\mods.json') '[{"mod_name":"AC7UIAspect","mod_enabled":true}]'
    foreach($relative in $patchPaths){Check ((Get-AC7Hash (Join-Path $manual $relative)) -eq $installedPatchHashes[$relative]) 'README manual copy produces the same five installed patch files'}
    $manualMods=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $manual 'ue4ss\Mods\mods.json')))
    Check ($manualMods[0].mod_name -eq 'AC7UIAspect' -and $manualMods[0].mod_enabled) 'README manual JSON enables the mod'
    foreach($relative in @('AC7SceneProjection.asi','AC7HUDCenter.asi','ue4ss\Mods\AC7UIAspect','ue4ss\Mods\mods.txt','ue4ss\Mods\mods.json')){
        Remove-Item -LiteralPath (Join-Path $manual $relative) -Recurse -Force
    }
    Check ((Snapshot $manual) -eq $manualBefore) 'manual removal preserves external dependencies'
    Write-Output 'PASS: patch-only install/merge/idempotence, unpinned external versions, dependency preservation, manual-copy equivalence, portable Unicode relocation, exact uninstall, missing-dependency/integrity rejection and rollback.'
}finally{
    if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
}
