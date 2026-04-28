<#
.SYNOPSIS
    Play video with RIFE 2x interpolation.
.DESCRIPTION
    Launches mpv with the RIFE profile set up by bootstrap.ps1.
    All environment paths are configured automatically.
.PARAMETER File
    Path to the video file to play.
.PARAMETER Profile
    RIFE profile to use: rife-720p, rife-1080p, rife-anime (default: rife-720p).
.PARAMETER NoRife
    Play without RIFE interpolation (passthrough).
.PARAMETER ExtraArgs
    Additional mpv arguments passed through verbatim.
.EXAMPLE
    .\play.ps1 video.mkv
    .\play.ps1 video.mkv -Profile rife-anime
    .\play.ps1 video.mkv -NoRife
    .\play.ps1 video.mkv -ExtraArgs "--osd-level=3"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$File = "",
    [ValidateSet("rife-720p", "rife-1080p", "rife-anime")]
    [string]$Profile = "rife-720p",
    [switch]$NoRife = $false,
    [string]$ExtraArgs = ""
)

$RepoRoot = Split-Path -Parent $PSCommandPath
$MpvDir   = Join-Path $RepoRoot "bin" "mpv"
$MpvExe   = Join-Path $MpvDir "mpv.exe"

# ── Validate ─────────────────────────────────────────────────────────────────
if (-not (Test-Path $MpvExe)) {
    Write-Host "mpv not found at $MpvExe" -ForegroundColor Red
    Write-Host "Run bootstrap.ps1 first to download and extract mpv." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $File)) {
    Write-Host "File not found: $File" -ForegroundColor Red
    exit 1
}

# ── Build command line ──────────────────────────────────────────────────────
$argsList = @()

# Ensure mpv finds its bundled DLLs
$argsList += "--config-dir=$env:APPDATA\mpv"

if ($NoRife) {
    # No profile — plain mpv with our base settings (minus vapoursynth filter)
    Write-Host "Playing without RIFE (passthrough)" -ForegroundColor Yellow
} else {
    Write-Host "Profile: $Profile" -ForegroundColor Cyan
    $argsList += "--profile=$Profile"
}

# Extra user arguments
if ($ExtraArgs) {
    $argsList += $ExtraArgs
}

# The video file — always last
$argsList += "`"$File`""

# ── Launch ───────────────────────────────────────────────────────────────────
Write-Host "Launching: $MpvExe $($argsList -join ' ')" -ForegroundColor Gray
Write-Host ""

$proc = Start-Process -FilePath $MpvExe -ArgumentList $argsList -Wait -NoNewWindow

if ($proc.ExitCode -ne 0) {
    Write-Host "mpv exited with code $($proc.ExitCode)" -ForegroundColor Red
}
