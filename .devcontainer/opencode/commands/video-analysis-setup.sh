#!/bin/bash
# Idempotent environment setup for the /video-analysis command.
# Installs ffmpeg (apt), creates the uv venv with Python 3.12, and installs
# yt-dlp (unpinned) plus whisperx==3.8.6 into the private tool venv.
# Model weights live in ~/.config/opencode/tools/video-analysis/models so they
# survive across pipeline runs (redownload only after a container rebuild).
set -euo pipefail
umask 077

VENV="$HOME/.config/opencode/tools/video-analysis/.venv"
MODELS="$HOME/.config/opencode/tools/video-analysis/models"

fail() {
    printf 'video-analysis-setup failed: %s\n' "$*" >&2
    exit 1
}

[[ -n "${SUDO_USER:-}" || "$(id -u)" -eq 0 ]] || fail 'Run as root or with sudo for apt.'
command -v uv >/dev/null || fail 'uv is required.'

# ffmpeg is needed by yt-dlp (muxing, thumbnails) and the frame extraction.
if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
    apt-get update -qq || fail 'apt-get update failed.'
    apt-get install -y -qq ffmpeg || fail 'apt-get install ffmpeg failed.'
else
    printf 'ffmpeg already installed: %s\n' "$(ffmpeg -version | head -1)"
fi

# WhisperX 3.8.6 requires Python >=3.10,<3.14; the uv default (3.14) is not
# usable, so request 3.12 explicitly (downloaded on demand if missing).
if [[ ! -x "$VENV/bin/python" ]]; then
    mkdir -p -- "$(dirname "$VENV")"
    uv venv "$VENV" --python 3.12 || fail 'uv venv creation failed.'
else
    printf 'venv already exists: %s\n' "$VENV"
fi

# yt-dlp stays unpinned so 'uv pip install --upgrade yt-dlp' can react to
# YouTube bot-detection changes. whisperx is pinned: it is the hinge package
# for torch~=2.8 (Blackwell sm_120-compatible cu128 stack).
VENV_PY="$VENV/bin/python"
NEED_INSTALL=0
"$VENV_PY" -c 'import yt_dlp' 2>/dev/null || NEED_INSTALL=1
"$VENV_PY" -c 'import whisperx' 2>/dev/null || NEED_INSTALL=1
if [[ "$NEED_INSTALL" -eq 1 ]]; then
    uv pip install --python "$VENV_PY" 'yt-dlp' 'whisperx==3.8.6' \
        || fail 'uv pip install failed.'
else
    printf 'yt-dlp and whisperx already installed in %s\n' "$VENV"
fi

mkdir -p -- "$MODELS"
printf 'video-analysis setup complete.\n'
printf 'Tools: %s/bin/yt-dlp, %s/bin/whisperx\n' "$VENV" "$VENV"
printf 'Whisper models: %s (large-v2 ~2.9 GB, downloaded on first run)\n' "$MODELS"
