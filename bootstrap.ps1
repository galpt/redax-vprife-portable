<#
.SYNOPSIS
    Bootstrap portable mpv + VapourSynth + RIFE environment.
.DESCRIPTION
    Downloads and configures everything needed for RIFE 2x interpolation:
      - mpv (shinchiro portable build)
      - VapourSynth R74 (if not already installed)
      - RIFE plugin (styler00dollar/VapourSynth-RIFE-ncnn-Vulkan)
      - model files and configs
    Run once before using play.ps1.
.EXAMPLE
    .\bootstrap.ps1
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"  # faster downloads

$RepoRoot = Split-Path -Parent $PSCommandPath
$BinDir    = Join-Path $RepoRoot "bin"
$MpvDir    = Join-Path $BinDir "mpv"
$TempDir   = Join-Path $RepoRoot "_bootstrap"

# ── Helpers ──────────────────────────────────────────────────────────────────
function Section($t) { Write-Host "`n═" * 40; Write-Host "  $t" -ForegroundColor Cyan; Write-Host "═" * 40 }
function Ok($m)  { Write-Host "  ✔ $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  ⚠ $m" -ForegroundColor Yellow }
function Info($m){ Write-Host "    $m" }

# Clean up temp on exit
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue } | Out-Null

# ═══════════════════════════════════════════════════════════════════════════════
Section "1. Download cache"
# ═══════════════════════════════════════════════════════════════════════════════
if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
$null = New-Item -ItemType Directory -Path $TempDir -Force
$tmp = $TempDir
Ok "Temporary directory: $tmp"

# ═══════════════════════════════════════════════════════════════════════════════
Section "2. VapourSynth R74"
# ═══════════════════════════════════════════════════════════════════════════════
$vsInstalled = $false
try {
    $null = python -c "import vapoursynth; print(vapoursynth.__version__)" 2>&1 | Out-Null
    $vsInstalled = $true
} catch {}

if ($vsInstalled) {
    $ver = python -c "import vapoursynth; print(vapoursynth.__version__)"
    Ok "VapourSynth $ver already installed"
} else {
    Warn "VapourSynth not found — downloading R74..."
    $vsUrl = "https://github.com/vapoursynth/vapoursynth/releases/download/R74/VapourSynth64-74.exe"
    $vsExe = Join-Path $tmp "VapourSynth64-74.exe"
    Info "Downloading: $vsUrl"
    Invoke-WebRequest -Uri $vsUrl -OutFile $vsExe -UseBasicParsing
    Ok "Downloaded VapourSynth installer"

    Info "Running installer (silent mode)..."
    $proc = Start-Process -FilePath $vsExe -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru
    if ($proc.ExitCode -eq 0) {
        Ok "VapourSynth R74 installed"
    } else {
        throw "Installer exited with code $($proc.ExitCode)"
    }
}

# Find where VapourSynth plugins live
$vsPluginsDir = "$env:APPDATA\VapourSynth\plugins64"
if (-not (Test-Path $vsPluginsDir)) {
    $vsPluginsDir = "$env:ProgramFiles\VapourSynth\plugins64"
}
if (-not (Test-Path $vsPluginsDir)) {
    # Fallback: search common locations
    $candidates = @(
        "$env:APPDATA\VapourSynth\plugins64",
        "${env:ProgramFiles}\VapourSynth\plugins64",
        "${env:ProgramFiles(x86)}\VapourSynth\plugins64",
        "C:\Program Files\VapourSynth\plugins64",
        "C:\Program Files (x86)\VapourSynth\plugins64"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $vsPluginsDir = $c; break }
    }
}
Info "VapourSynth plugins directory: $vsPluginsDir"
$null = New-Item -ItemType Directory -Path $vsPluginsDir -Force

# ═══════════════════════════════════════════════════════════════════════════════
Section "3. RIFE plugin"
# ═══════════════════════════════════════════════════════════════════════════════

# Find latest release tag from GitHub API
try {
    $apiUrl = "https://api.github.com/repos/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $tag = $release.tag_name
    $zipUrl = "https://github.com/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan/archive/refs/tags/$tag.zip"
    Info "Latest RIFE plugin release: $tag"
} catch {
    # Fallback if API fails (rate limited etc.)
    $tag = "r9_mod_v33"
    $zipUrl = "https://github.com/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan/archive/refs/tags/$tag.zip"
    Warn "GitHub API unreachable — falling back to $tag"
}

# Download the release source/models (the repo includes models as submodules,
# so we download the pre-built release asset instead)
$relUrl = "https://github.com/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan/releases/download/$tag/vapoursynth64-plugins-rife-$tag.7z"
$rife7z = Join-Path $tmp "rife.7z"

try {
    Info "Downloading: $relUrl"
    Invoke-WebRequest -Uri $relUrl -OutFile $rife7z -UseBasicParsing -ErrorAction Stop
    Ok "Downloaded RIFE plugin ($tag)"
}
catch {
    # If the pre-built release fails, try the source archive and models submodule
    Warn "Pre-built release not available — will use source archive"
    Info "Downloading: $zipUrl"
    Invoke-WebRequest -Uri $zipUrl -OutFile (Join-Path $tmp "rife-src.zip") -UseBasicParsing
    # We need models which are a submodule — look for a models download separately
    throw "Source build not supported by bootstrap yet. Download manually from $relUrl"
}

# Extract the 7z — need 7-Zip
$7z = Get-Command "7z" -ErrorAction SilentlyContinue
if (-not $7z) {
    $7z = Get-Command "7za" -ErrorAction SilentlyContinue
}
if (-not $7z) {
    # Check for 7z in Program Files
    $7zPaths = @(
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\7-Zip\7z.exe"
    )
    foreach ($p in $7zPaths) {
        if (Test-Path $p) { $7z = $p; break }
    }
}
if (-not $7z) {
    throw "7-Zip not found. Install 7-Zip from https://7-zip.org/ and re-run."
}
$7zExe = if ($7z -is [System.Management.Automation.CommandInfo]) { $7z.Source } else { $7z }

$rifeExtract = Join-Path $tmp "rife-extract"
$null = New-Item -ItemType Directory -Path $rifeExtract -Force
Info "Extracting RIFE plugin..."
$null = & $7zExe x "$rife7z" -o"$rifeExtract" -y 2>&1 | Out-Null
Ok "Extracted RIFE plugin"

# Find the models directory in the extraction
$modelsSrc = Get-ChildItem -Path $rifeExtract -Recurse -Directory -Filter "models" | Select-Object -First 1
if (-not $modelsSrc) {
    # Try broader search
    $modelsSrc = Get-ChildItem -Path $rifeExtract -Recurse -Directory | Where-Object { $_.Name -eq "models" } | Select-Object -First 1
}

if ($modelsSrc) {
    $modelsDst = Join-Path $vsPluginsDir "models"
    if (Test-Path $modelsDst) {
        Warn "Models directory already exists — backing up to models.bak"
        Remove-Item "${modelsDst}.bak" -Recurse -Force -ErrorAction SilentlyContinue
        Rename-Item $modelsDst "${modelsDst}.bak"
    }
    Copy-Item -Path $modelsSrc.FullName -Destination $modelsDst -Recurse -Force
    Ok "Models copied to $modelsDst"
} else {
    # Try to find the rife.dll and place it, then note models are needed
    $rifeDll = Get-ChildItem -Path $rifeExtract -Recurse -Filter "rife.dll" | Select-Object -First 1
    if ($rifeDll) {
        Copy-Item -Path $rifeDll.FullName -Destination (Join-Path $vsPluginsDir "rife.dll") -Force
        Ok "rife.dll placed in $vsPluginsDir"
    }
    Warn "Models directory not found in release — you may need to place models/ manually in $vsPluginsDir"
}

# ═══════════════════════════════════════════════════════════════════════════════
Section "4. mpv portable"
# ═══════════════════════════════════════════════════════════════════════════════

$mpvUrl = "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/20250331/mpv-x86_64-v3-20250331-8491870.7z"
$mpv7z  = Join-Path $tmp "mpv.7z"
$mpvExtract = Join-Path $tmp "mpv-extract"

if (Test-Path (Join-Path $MpvDir "mpv.exe")) {
    Ok "mpv already extracted at $MpvDir"
} else {
    Info "Downloading mpv portable ($mpvUrl)..."
    Invoke-WebRequest -Uri $mpvUrl -OutFile $mpv7z -UseBasicParsing

    $null = New-Item -ItemType Directory -Path $mpvExtract -Force
    Info "Extracting mpv..."
    $null = & $7zExe x "$mpv7z" -o"$mpvExtract" -y 2>&1 | Out-Null

    # Find mpv.exe in the extraction
    $mpvExe = Get-ChildItem -Path $mpvExtract -Recurse -Filter "mpv.exe" | Select-Object -First 1
    if ($mpvExe) {
        # Move the entire directory containing mpv.exe to bin\mpv\
        $srcMpvDir = $mpvExe.Directory.FullName
        if (Test-Path $MpvDir) { Remove-Item $MpvDir -Recurse -Force }
        Move-Item -Path $srcMpvDir -Destination $MpvDir -Force
        Ok "mpv extracted to $MpvDir"
    } else {
        throw "mpv.exe not found in downloaded archive"
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
Section "5. Configuration files"
# ═══════════════════════════════════════════════════════════════════════════════

$mpvCfgDir = "$env:APPDATA\mpv"
$mpvVSdir  = Join-Path $mpvCfgDir "vapoursynth"
$null = New-Item -ItemType Directory -Path $mpvCfgDir -Force
$null = New-Item -ItemType Directory -Path $mpvVSdir -Force

$srcCfgDir = Join-Path $RepoRoot "config"

# mpv.conf
$dstCfg = Join-Path $mpvCfgDir "mpv.conf"
if (Test-Path $dstCfg) {
    Warn "$dstCfg already exists — skipping (use -Force to overwrite with bootstrap)"
} else {
    Copy-Item -Path (Join-Path $srcCfgDir "mpv.conf") -Destination $dstCfg
    Ok "Copied mpv.conf"
}

# .vpy scripts
foreach ($name in @("rife", "rife-720p", "rife-anime")) {
    $src  = Join-Path $srcCfgDir "vapoursynth" "${name}.vpy"
    $dst  = Join-Path $mpvVSdir "${name}.vpy"
    Copy-Item -Path $src -Destination $dst -Force
}
Ok "Copied VapourSynth scripts to $mpvVSdir"

# ═══════════════════════════════════════════════════════════════════════════════
Section "Done!"
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  All components ready.  Play a video:" -ForegroundColor Green
Write-Host ""
Write-Host "    .\play.ps1 video.mkv" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Or check the installation:" -ForegroundColor Green
Write-Host ""
Write-Host "    .\scripts\diagnose.ps1" -ForegroundColor Cyan
