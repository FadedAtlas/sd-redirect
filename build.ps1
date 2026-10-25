# Builds dist/sd-redirect-<version>.zip, flashable in APatch / KernelSU.
# With a JDK available (javac on PATH or JAVA_HOME), also builds the toast helper module/bin/sd-redirect-toast.dex.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$src = Join-Path $root 'module'
$stage = Join-Path $root 'build'
$dist = Join-Path $root 'dist'
$tools = Join-Path $root 'build-cache'
$R8_VERSION = '8.5.35'

function Find-JdkTool($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($jdk in $env:JAVA_HOME, [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User'), [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')) {
        if ($jdk -and (Test-Path "$jdk\bin\$name.exe")) { return "$jdk\bin\$name.exe" }
    }
    return $null
}

function Build-Toast {
    $javac = Find-JdkTool 'javac'
    $java = Find-JdkTool 'java'
    $dex = Join-Path $src 'bin\sd-redirect-toast.dex'
    $javaSrc = Join-Path $root 'toast\SdRedirectToast.java'
    if (-not $javac -or -not $java) {
        Write-Warning 'No JDK found: packaging without the toast helper (notification fallback only).'
        return
    }
    if ((Test-Path $dex) -and (Get-Item $dex).LastWriteTime -gt (Get-Item $javaSrc).LastWriteTime) { return }

    New-Item -ItemType Directory -Force $tools | Out-Null
    $r8 = Join-Path $tools "r8-$R8_VERSION.jar"
    if (-not (Test-Path $r8)) {
        Write-Host "Downloading r8 $R8_VERSION (D8 dexer)..."
        Invoke-WebRequest -UseBasicParsing -OutFile $r8 `
            "https://dl.google.com/dl/android/maven2/com/android/tools/r8/$R8_VERSION/r8-$R8_VERSION.jar"
    }

    $classes = Join-Path $tools 'classes'
    $dexOut = Join-Path $tools 'dex'
    foreach ($d in $classes, $dexOut) {
        if (Test-Path $d) { Remove-Item -Recurse -Force $d }
        New-Item -ItemType Directory $d | Out-Null
    }
    & $javac --release 8 -nowarn -d $classes $javaSrc
    if ($LASTEXITCODE) { throw 'javac failed' }
    & $java -cp $r8 com.android.tools.r8.D8 --release --min-api 30 --output $dexOut (Get-ChildItem -Recurse -Filter *.class $classes).FullName
    if ($LASTEXITCODE) { throw 'd8 failed' }
    New-Item -ItemType Directory -Force (Split-Path $dex) | Out-Null
    Copy-Item -Force (Join-Path $dexOut 'classes.dex') $dex
    Write-Host "Built $dex"
}

Build-Toast

$version = (Select-String -Path (Join-Path $src 'module.prop') -Pattern '^version=(.+)$').Matches[0].Groups[1].Value.Trim()

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
Copy-Item -Recurse $src $stage
Copy-Item (Join-Path $root 'LICENSE'), (Join-Path $root 'README.md') $stage
New-Item -ItemType Directory -Force $dist | Out-Null

# Shell scripts break on CRLF; normalize every text file to LF (binary files are left alone).
Get-ChildItem -Recurse -File $stage | Where-Object Extension -ne '.dex' | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    [IO.File]::WriteAllText($_.FullName, ($text -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
}

$zip = Join-Path $dist "sd-redirect-$version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
$items = Get-ChildItem -Name $stage
tar -a -c -f $zip -C $stage @items
if ($LASTEXITCODE) { throw "tar failed" }
Remove-Item -Recurse -Force $stage
Write-Host "Built $zip"
