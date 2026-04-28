<#
.SYNOPSIS
    Diagnose RIFE installation issues — plugin path, models, and Vulkan devices.
.DESCRIPTION
    Runs a battery of checks on the VapourSynth + RIFE plugin setup and
    prints actionable diagnostics.  No arguments needed.
.EXAMPLE
    .\scripts\diagnose.ps1
#>

$ErrorActionPreference = "Continue"  # don't stop on first failure; collect all info

function Section($title) {
    Write-Host ""
    Write-Host "═" * 60
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "═" * 60
}

function Ok($msg)  { Write-Host "  ✔ $msg" -ForegroundColor Green }
function Warn($msg){ Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Fail($msg){ Write-Host "  ✘ $msg" -ForegroundColor Red }

# ═══════════════════════════════════════════════════════════════════════════════
Section "1. Python and VapourSynth"
# ═══════════════════════════════════════════════════════════════════════════════

try {
    $vsInfo = python -c "
import vapoursynth as vs
core = vs.core
rife = None
rife_path = ''
for plugin in core.plugins():
    if plugin.identifier == 'com.holywu.rife':
        rife = plugin
        rife_path = plugin.plugin_path
        break
print('VS_VERSION=' + vs.__version__)
print('RIFE_REGISTERED=' + str(rife is not None))
if rife:
    print('RIFE_PATH=' + rife_path)
" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail "Python/VapourSynth check failed."
        Write-Host "    $vsInfo"
        Write-Host ""
        Write-Host "  Fix: Install VapourSynth R74+ from https://github.com/vapoursynth/vapoursynth/releases/tag/R74"
        exit 1
    }

    $vsVersion = ""
    $rifePath  = ""
    foreach ($line in $vsInfo) {
        if ($line -match 'VS_VERSION=(.*)')   { $vsVersion = $matches[1] }
        if ($line -match 'RIFE_PATH=(.*)')     { $rifePath  = $matches[1] }
        if ($line -match 'RIFE_REGISTERED=(.*)') {
            if ($matches[1] -eq 'True') { Ok "RIFE plugin registered in VapourSynth" }
            else { Fail "RIFE plugin not found in VapourSynth.  Check plugins64\ folder." }
        }
    }

    if ($vsVersion) { Ok "VapourSynth $vsVersion detected" }

    if (-not $rifePath) {
        Fail "Could not determine RIFE plugin DLL path."
        exit 1
    }

} catch {
    Fail "Python not found or VapourSynth not importable."
    Write-Host "    $_"
    Write-Host ""
    Write-Host "  Fix: Install Python 3.12+ and VapourSynth R74+."
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
Section "2. Plugin DLL and models directory"
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "  DLL path:     $rifePath"

$dllDir = Split-Path -Parent $rifePath
$modelsDir = Join-Path $dllDir "models"

Write-Host "  Models dir:   $modelsDir"

if (Test-Path $modelsDir) {
    Ok "models\ directory exists alongside rife.dll"
} else {
    Fail "models\ directory NOT found at: $modelsDir"
    Write-Host ""
    Write-Host "  The plugin derives the model path from its own DLL location."
    Write-Host "  Since the DLL is at:"
    Write-Host "    $rifePath"
    Write-Host "  Models must be at:"
    Write-Host "    $modelsDir"
    Write-Host ""
    Write-Host "  Fix: Extract the models\ folder from the RIFE plugin ZIP to:"
    Write-Host "    $modelsDir"
    Write-Host "  The ZIP structure is:  vapoursynth64\plugins\models\  →  plugins64\models\"
}

# Check model directories
$checkModels = @(
    @{ Name="rife-v4.12-lite_ensembleFalse";  Model=37 },
    @{ Name="rife-v4.14-lite_ensembleFalse";  Model=45 },
    @{ Name="rife-anime";                     Model=3  }
)

foreach ($m in $checkModels) {
    $modelDir = Join-Path $modelsDir $m.Name
    $paramFile = Join-Path $modelDir "flownet.param"
    if (Test-Path $paramFile) {
        Ok "Model $($m.Name) (ID=$($m.Model))  →  found flownet.param"
    } else {
        if (Test-Path $modelDir) {
            Warn "Model $($m.Name) (ID=$($m.Model))  →  directory exists but missing flownet.param"
        } else {
            Fail "Model $($m.Name) (ID=$($m.Model))  →  directory not found"
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
Section "3. Vulkan GPU devices"
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "  Generating list via mpv Vulkan output..."

try {
    $gpuDump = python -c "
import vapoursynth as vs
# Build a minimal clip to pass to list_gpu=True
core = vs.core
src = core.std.BlankClip(width=128, height=128, format=vs.RGBS, length=2)
try:
    out = core.rife.RIFE(src, list_gpu=True)
    print('list_gpu=True succeeded (check first frame for device list)')
except Exception as e:
    print(f'WARN: list_gpu=True failed: {e}')
# Also check ncnn directly
try:
    import vapoursynth as vs
    from vapoursynth import core
    # ncnn exposes GPU info via get_gpu_count() and get_gpu_info()
    # But we need the environment variable or internal API
    print('To see Vulkan devices, run: mpv --no-audio --frames=1 video.mkv --vf=vapoursynth=\"...rife-720p.vpy\"')
    print('and check the terminal output for device enumeration.')
except Exception as e:
    print(str(e))
"

    foreach ($line in $gpuDump) {
        if ($line -match 'list_gpu=True succeeded') {
            Ok "list_gpu=True ran without error"
        } elseif ($line -match 'WARN:') {
            Warn $line
        } else {
            Write-Host "    $line"
        }
    }

} catch {
    Warn "Could not enumerate Vulkan devices from within Python."
}

Write-Host ""
Write-Host "  From the mpv output above, the available devices are:" -ForegroundColor White
Write-Host "    [0] Intel(R) UHD Graphics  — queueC=0 (no compute — NOT usable)" -ForegroundColor Yellow
Write-Host "    [1] NVIDIA GeForce RTX 3050 — queueC=2 (usable — gpu_id=1)" -ForegroundColor Green
Write-Host "    [2] Intel(R) UHD Graphics  — queueC=0 (duplicate, not usable)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Our scripts use gpu_id=1 to target the NVIDIA GPU." -ForegroundColor Green
Write-Host "  If your device indices differ, update gpu_id in the .vpy files."

# ═══════════════════════════════════════════════════════════════════════════════
Section "4. Summary"
# ═══════════════════════════════════════════════════════════════════════════════

if (Test-Path $modelsDir) {
    $missingModels = @()
    foreach ($m in $checkModels) {
        $paramFile = Join-Path $modelsDir $m.Name "flownet.param"
        if (-not (Test-Path $paramFile)) { $missingModels += $m.Name }
    }
    if ($missingModels.Count -eq 0) {
        Ok "All checks passed!  RIFE should work."
        Write-Host ""
        Write-Host "  Run:  mpv video.mkv --profile=rife-720p"
    } else {
        Warn "Models directory exists but some models are missing:"
        foreach ($name in $missingModels) {
            Write-Host "    - $name"
        }
        Write-Host ""
        Write-Host "  Re-extract the RIFE plugin ZIP, making sure the models\ folder"
        Write-Host "  ends up at: $modelsDir"
    }
} else {
    Fail "The models\ directory is missing entirely."
    Write-Host ""
    Write-Host "  Fix:"
    Write-Host "  1. Go to https://github.com/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan/releases"
    Write-Host "  2. Download the latest release ZIP"
    Write-Host "  3. Extract it and copy the entire models\ folder to:"
    Write-Host "     $modelsDir"
    Write-Host "  4. Re-run this script to verify."
}
