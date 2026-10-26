[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$BackupDirectory,[string]$GameDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$projectRoot=Split-Path -Parent $PSScriptRoot
if(-not $BackupDirectory){
    $latest=Join-Path $projectRoot '.local-state\latest-backup.txt'
    if(-not(Test-Path -LiteralPath $latest)){throw 'Supply -BackupDirectory with an installation backup folder.'}
    $BackupDirectory=[IO.File]::ReadAllText($latest).Trim()
    if(-not [IO.Path]::IsPathRooted($BackupDirectory)){$BackupDirectory=Join-Path $projectRoot $BackupDirectory}
}
$backup=[IO.Path]::GetFullPath($BackupDirectory)
$manifest=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $backup 'manifest.json')))
if($manifest.format -ne 1){throw 'Unsupported backup manifest.'}
if(-not $GameDirectory){$GameDirectory=$manifest.game}
$game=Resolve-AC7Game $GameDirectory
Assert-AC7Closed $game
foreach($record in $manifest.files){
    if([IO.Path]::IsPathRooted($record.path) -or ($record.path -split '[\\/]') -contains '..' -or $record.action -notin @('write','remove')){throw 'Invalid file path or action in backup manifest.'}
    $target=Join-Path $game $record.path
    if($record.action -eq 'write'){
        if(-not(Test-Path -LiteralPath $target) -or (Get-AC7Hash $target) -ne $record.installedSha256){
            throw "File changed after installation: $($record.path). Review later changes before uninstalling."
        }
    }elseif(Test-Path -LiteralPath $target){throw "Previously removed legacy plugin has reappeared: $($record.path)"}
    if($record.existed -and -not(Test-Path -LiteralPath (Join-Path $backup ('original\'+$record.path)))){throw "Backup file missing: $($record.path)"}
}
if(-not $PSCmdlet.ShouldProcess($game,'Restore the exact pre-install files from this backup')){return}
foreach($record in $manifest.files){
    $target=Join-Path $game $record.path
    if($record.existed){
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $backup ('original\'+$record.path)) -Destination $target -Force
    }elseif(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target}
}
Write-Output "Restored pre-install files: $game"
Write-Output 'An install over an existing fixed setup restores that pre-install setup.'
