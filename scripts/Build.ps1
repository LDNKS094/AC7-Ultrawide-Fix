param([string]$Configuration='Release',[string]$CMake='cmake')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$build=Join-Path $projectRoot 'build'
& $CMake -S $projectRoot -B $build -G 'Visual Studio 17 2022' -A x64
if($LASTEXITCODE){throw 'CMake configure failed.'}
& $CMake --build $build --config $Configuration
if($LASTEXITCODE){throw 'Native build failed.'}
& $CMake -E chdir $build ctest -C $Configuration --output-on-failure
if($LASTEXITCODE){throw 'Native tests failed.'}
Write-Output "Build passed. Native outputs: $build\$Configuration"
Write-Output 'Building never installs files into the game; payload updates are an explicit packaging step.'
