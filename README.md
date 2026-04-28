# redax-vprife-portable

**Self-bootstrapping mpv + VapourSynth + RIFE for RTX 3050 4 GB.**

One command. Everything automagically downloaded, extracted, and configured.
No manual install steps, no registry edits, no guessing where models go.

```powershell
.\bootstrap.ps1      # one-time setup
.\play.ps1 video.mkv # play with RIFE 720p
```

## How it works

`bootstrap.ps1` does all of this automatically:

1. **Downloads mpv** (shinchiro's portable build) — extracts it to `bin\mpv\`
2. **Checks VapourSynth** — if not installed, downloads and runs the R74
   installer silently (`/VERYSILENT`)
3. **Downloads the RIFE plugin** — extracts the `models\` folder to the
   correct location alongside your existing `rife.dll`
4. **Copies all configs** — `mpv.conf` and VapourSynth scripts to
   `%APPDATA%\mpv\`

After bootstrap, run `play.ps1` to launch mpv with RIFE 2x interpolation
on any video file.

## Prerequisites

- Windows 10/11
- NVIDIA RTX 3050 (4 GB VRAM)
- Internet connection for the first bootstrap run
- PowerShell 5.1+ (ships with Windows)

## Commands

| Command | What it does |
|---------|-------------|
| `.\bootstrap.ps1` | Full setup — downloads everything, runs installers |
| `.\play.ps1 video.mkv` | Play video with RIFE 720p profile |
| `.\play.ps1 video.mkv -Profile rife-anime` | Play with anime profile |
| `.\play.ps1 video.mkv -NoRife` | Play without RIFE (passthrough) |
| `.\scripts\diagnose.ps1` | Check installation health |

## Files

```
redax-vprife-portable/
├── README.md
├── bootstrap.ps1       One-time setup: downloads mpv, VapourSynth, RIFE plugin
├── play.ps1            Launch mpv with RIFE
├── config/
│   ├── mpv.conf        Optimised mpv configuration
│   └── vapoursynth/    VapourSynth RIFE scripts
└── scripts/
    └── diagnose.ps1    Installation health check
```

## Acknowledgements

Same as [redax-vprife](https://github.com/galpt/redax-vprife) — all credit
to the RIFE, ncnn, VapourSynth, and mpv teams.
