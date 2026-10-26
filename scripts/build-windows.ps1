param([Parameter(Mandatory=$true)][string]$QtRoot)
$ErrorActionPreference = 'Stop'
# Run in Developer PowerShell for VS 2022. QtRoot example: C:\Qt\6.8.3\msvc2022_64
$root = Split-Path $PSScriptRoot -Parent
$build = Join-Path $root 'build'
$dist = Join-Path $root 'dist'
if (!(Test-Path "$QtRoot\lib\cmake\Qt6\Qt6Config.cmake")) { throw 'QtRoot must point to a Qt MSVC kit with Quick, QuickControls2, Concurrent and Svg.' }
& cmake -S $root -B $build -G 'Visual Studio 17 2022' -A x64 "-DCMAKE_PREFIX_PATH=$QtRoot"
if ($LASTEXITCODE -ne 0) { throw 'CMake configuration failed' }
& cmake --build $build --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
& cmake --install $build --config Release --prefix $dist
if ($LASTEXITCODE -ne 0) { throw 'Qt deployment failed' }
Copy-Item "$root\assets\KEYLINE-LICENSE.txt" $dist
Copy-Item "$root\README.md" $dist
Copy-Item "$root\QA.md" $dist
Copy-Item "$root\REFERENCES.md" $dist
Copy-Item "$root\examples" $dist -Recurse -Force
Copy-Item "$root\START-HERE.txt" $dist
Copy-Item "$root\licenses" $dist -Recurse -Force
Write-Host "Ready: $dist\CClicker.exe"
Write-Host 'Distribute the WHOLE dist folder, not only the executable. Test on a clean Windows account.'
