---
description: Analyze YouTube video(s) end-to-end — download, transcribe (WhisperX), frame-vision, German markdown report
---

Handle this request only through the video-analysis command:

$ARGUMENTS

1. Parse the arguments: one or more YouTube URLs, a playlist URL, a
   `@file.txt` with one URL per line, and any flags. Supported flags:

   ```
   /video-analysis <url> [@file.txt] [--out DIR] [--frames N] [--lang auto]
                   [--lang-report Deutsch] [--report-effort max] [--asr local|proxy]
                   [--no-video] [--keep-audio] [--diarize] [--whisper-model large-v2]
                   [--max-playlist 50]
   ```

   Defaults: output to `video-analysis/` in the current project, 1 fps frames
   (capped at 120 per video), report language Deutsch, report effort `max`
   (highest detail; `--report-effort low` or `high` cut synthesis time ~4x
   with slightly less depth — useful for large batches), local WhisperX with
   `large-v2`. `--diarize` needs an HF token for gated Pyannote models and
   fails without one; mention this when the user asks for diarization.
2. Run the setup script first if the tool environment is missing (no
   `~/.config/opencode/tools/video-analysis/.venv/bin/yt-dlp`):

   ```bash
   bash "$HOME/.config/opencode/commands/video-analysis-setup.sh"
   ```

   First runs after a container rebuild download the Whisper model (~3 GB)
   and the Silero VAD model into `~/.config/opencode/tools/video-analysis/models`
   and `~/.cache/torch/hub`; this is expected and happens once.
3. Run the pipeline with the venv Python in one Bash call. Long runs (model
   downloads, transcription, batches) belong in tmux or the background so
   tool timeouts cannot kill them:

   ```bash
   "$HOME/.config/opencode/tools/video-analysis/.venv/bin/python" \
     "$HOME/.config/opencode/commands/video-analysis.py" \
     '<url-or-@file>' --out '<output-dir>'
   ```

   Pass through the user's flags (`--no-video`, `--asr proxy`, `--keep-audio`,
   `--frames`, `--lang`, `--lang-report`, `--report-effort`, `--whisper-model`,
   `--max-playlist`).
   If YouTube blocks the download (bot detection), retry once after
   `uv pip install --upgrade yt-dlp --python
   "$HOME/.config/opencode/tools/video-analysis/.venv/bin/python"`, then
   report the failure instead of retrying endlessly.
4. Summarize the results from `report.md` per video (abstract and TL;DR are
   the core), mention the output folder, and point to `_index.md` for the
   batch overview. Do not silently swallow errors: a failed video is marked
   in `_index.md` and the script exits nonzero — report which videos failed
   and why. Never print or log the API key.
5. The script is resumable: re-running the same URL skips completed steps
   (per-video `pipeline-state.json`) and reuses the existing video folder.

The Bash script downloads videos (≤720p mp4), extracts frames (1 fps, capped
at 120 with uniform downsampling so the filename suffix equals the second),
transcribes with WhisperX (Silero VAD, float16, word-level alignment) or the
proxy whisper model, analyzes frames in 6–8-frame batches with the
multimodal chat model, and synthesizes a German markdown report (Abstract,
TL;DR, Inhalt with timestamps, Kernargumente, Visuelles, Zitate, Tags,
Ressourcen). Reports land in `video-analysis/<upload-date>_<slug>_<videoId>/`.
