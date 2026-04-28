# =============================================================================
# rife-anime.vpy — RIFE 2x for anime / cel-shaded content
# Target: NVIDIA RTX 3050 4 GB VRAM
# Model:   rife-anime (model=3), gpu_thread=1
# =============================================================================
# The "rife-anime" model (model=3) was specifically trained on anime frames
# and is significantly lighter than general-purpose models.  It performs well
# even at native 1080p on 4 GB VRAM.
#
# Place this file in %APPDATA%\mpv\vapoursynth\ (Windows)
# or ~/.config/mpv/vapoursynth/ (Linux/macOS)
#
# Load via mpv:  --profile=rife-anime
#          or:   --vf=vapoursynth="~~/vapoursynth/rife-anime.vpy"
# =============================================================================

import vapoursynth as vs

core = vs.core

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
src = video_in

# ---------------------------------------------------------------------------
# Colour conversion  YUV → RGB float32
# ---------------------------------------------------------------------------
rgb = core.resize.Bicubic(src, format=vs.RGBS, matrix_s="709", chromaloc_s="left")

# ---------------------------------------------------------------------------
# RIFE interpolation
#
# model      = 3    → rife-anime
#                     Specifically tuned for flat-colour / cel-shaded frames.
#                     Very low VRAM footprint — runs comfortably at 1080p
#                     on 4 GB VRAM even with gpu_thread=2.
# gpu_id     = 1   → NVIDIA RTX 3050 (see rife.vpy header for dual-GPU notes).
# gpu_thread = 2    → Two concurrent inference queues; safe on this model.
# factor_num = 2    → 2x frame rate.
# ---------------------------------------------------------------------------
out = core.rife.RIFE(
    rgb,
    model=3,
    gpu_id=1,
    gpu_thread=2,
    sc=False,
    factor_num=2,
    factor_den=1,
)

# ---------------------------------------------------------------------------
# Colour conversion back to YUV
# ---------------------------------------------------------------------------
out = core.resize.Bicubic(out, format=vs.YUV420P8, matrix_s="709", chromaloc="left")

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
out.set_output()
