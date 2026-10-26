param([string]$Configuration='Release',[string]$CMake='cmake')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$build=Join-Path $projectRoot 'build'
& $CMake -S $projectRoot -B $build -G 'Visual Studio 17 2022' -A x64
if($LASTEXITCODE){throw 'CMake configure failed.'}
& $CMake --build $build --config $Configuration
if($LASTEXITCODE){throw 'Native build failed.'}
$output=if($Configuration -eq 'Release'){Join-Path $projectRoot 'payload'}else{Join-Path $build $Configuration}
Write-Output "Build passed. Native outputs: $output"
Write-Output 'Run scripts/Package.ps1 to regenerate the installation package and file manifest.'
