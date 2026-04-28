# =============================================================================
# rife.vpy — VapourSynth RIFE 2x frame interpolation
# Target: NVIDIA RTX 3050 4 GB VRAM
# Model:   rife-v4.12-lite (model=37), gpu_thread=1
# =============================================================================
# Place this file in %APPDATA%\mpv\vapoursynth\ (Windows)
# or ~/.config/mpv/vapoursynth/ (Linux/macOS)
#
# Load via mpv:  --profile=rife-1080p
#          or:   --vf=vapoursynth="~~/vapoursynth/rife.vpy"
# =============================================================================

import vapoursynth as vs

core = vs.core

# ---------------------------------------------------------------------------
# Input — mpv passes the decoded video as the last filter output
# ---------------------------------------------------------------------------
src = video_in

# ---------------------------------------------------------------------------
# Colour conversion  YUV → RGB float32 (mandatory for RIFE)
# ---------------------------------------------------------------------------
rgb = core.resize.Bicubic(src, format=vs.RGBS, matrix_s="709", chromaloc_s="left")

# ---------------------------------------------------------------------------
# RIFE interpolation
#
# model       = 37   → rife-v4.12-lite (ensemble=False)
#                      Lightest v4-lite model; fits ~2 concurrent inferences
#                      in 4 GB VRAM at 1080p.
# gpu_id      = 1   → NVIDIA RTX 3050.  On dual-GPU laptops (Intel + NVIDIA)
#                      the iGPU is typically index 0 with zero compute queues;
#                      pass the correct index or omit for auto-detection.
#                      Use list_gpu=True in a test script to enumerate devices.
# gpu_thread  = 1    → One inference queue.  Saves ~500 MB VRAM vs default 2.
# sc          = True → Skip interpolation over scene changes (requires
#                      _SceneChangeNext frame property — see advanced variant
#                      for SCDetect integration).
# factor_num  = 2    → 2x frame rate (e.g. 24→48, 30→60, 60→120).
# factor_den  = 1
# ---------------------------------------------------------------------------
out = core.rife.RIFE(
    rgb,
    model=37,
    gpu_id=1,
    gpu_thread=1,
    sc=False,
    factor_num=2,
    factor_den=1,
)

# ---------------------------------------------------------------------------
# Colour conversion  RGB float32 → YUV (for mpv output)
# ---------------------------------------------------------------------------
out = core.resize.Bicubic(out, format=vs.YUV420P8, matrix_s="709", chromaloc="left")

# ---------------------------------------------------------------------------
# Output — mpv picks up the last clip that has set_output()
# ---------------------------------------------------------------------------
out.set_output()
