function Resolve-AC7Game([string]$GameDirectory){
    if($GameDirectory){
        $resolved=[IO.Path]::GetFullPath($GameDirectory)
        if(-not(Test-Path -LiteralPath (Join-Path $resolved 'Ace7Game.exe'))){throw 'Ace7Game.exe not found. Supply -GameDirectory with the AC7 game root.'}
        return $resolved
    }
    $roots=@()
    foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')){
        $entry=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if($entry.SteamPath){$roots+=,$entry.SteamPath}
        if($entry.InstallPath){$roots+=,$entry.InstallPath}
    }
    $libraries=@($roots)
    foreach($root in $roots){
        $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
        if(Test-Path -LiteralPath $vdf){
            foreach($match in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s*"([^"]+)"')){
                $libraries+=,$match.Groups[1].Value.Replace('\\','\')
            }
        }
    }
    $candidates=@($libraries | Select-Object -Unique | ForEach-Object {Join-Path $_ 'steamapps\common\ACE COMBAT 7'} | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'Ace7Game.exe')})
    if($candidates.Count -ne 1){throw 'Could not select one Steam AC7 installation. Supply -GameDirectory explicitly.'}
    return [IO.Path]::GetFullPath($candidates[0])
}
function Assert-AC7Closed([string]$GameDirectory){
    foreach($process in @(Get-Process Ace7Game -ErrorAction SilentlyContinue)){
        if(-not $GameDirectory -or -not $process.Path -or $process.Path -ieq (Join-Path $GameDirectory 'Ace7Game.exe')){
            throw 'Close AC7 before changing its files.'
        }
    }
}
function Remove-AC7TemporaryBackup([string]$Path){
    try{
        Remove-Item -LiteralPath $Path -Recurse -Force
        $parent=Split-Path -Parent $Path
        if(@(Get-ChildItem -LiteralPath $parent -Force).Count -eq 0){Remove-Item -LiteralPath $parent}
    }catch{Write-Warning "Operation succeeded, but temporary backup cleanup failed: $Path"}
}
function Get-AC7Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Write-AC7Utf8([string]$Path,[string]$Content){
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force | Out-Null}
    [IO.File]::WriteAllText($Path,$Content,(New-Object Text.UTF8Encoding($false)))
}
