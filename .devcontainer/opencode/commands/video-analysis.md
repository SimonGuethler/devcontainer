---
description: Analyze YouTube video(s) end-to-end — download, transcribe (WhisperX), frame-vision, German markdown report
---

Handle this request only through the video-analysis command:

$ARGUMENTS

1. Parse the arguments: one or more YouTube URLs, a playlist URL, a
   `@file.txt` with one URL per line, and any flags. Supported flags:

   ```
   /video-analysis <url> [@file.txt] [--out DIR] [--frames N] [--lang auto]
                   [--lang-report Deutsch] [--report-effort high] [--asr local|proxy]
                   [--no-video] [--keep-audio] [--diarize] [--whisper-model large-v2]
                   [--max-playlist 50] [--frame-cap 120]
   ```

   Defaults: output to `video-analysis/` in the current project, 1 fps frames
   (capped at 120 per video; `--frame-cap` raises the cap for fast-cut long
   videos — vision is parallel and cheap relative to synthesis), report
   language Deutsch, report effort `high`
   (statement-level timestamp density; `--report-effort max` adds ~10–40%
   more timestamps at 3–10× cost and can exhaust the reasoning budget — use
   for single videos you specifically care about; `low` summarizes blocks
   with time ranges instead of per-statement timestamps),
   local WhisperX with `large-v2`. `--diarize` needs an HF token for gated Pyannote models and
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
   `--frames`, `--frame-cap`, `--lang`, `--lang-report`, `--report-effort`,
   `--whisper-model`, `--max-playlist`).
   Note: `--whisper-model` and `--diarize` only affect local WhisperX; in
   `--asr proxy` mode the script warns and uses the proxy's `whisper-large-v3`
   (a non-auto `--lang` is forwarded to the proxy).
   If YouTube blocks the download (bot detection), retry once after
   `uv pip install --upgrade yt-dlp --python
   "$HOME/.config/opencode/tools/video-analysis/.venv/bin/python"`, then
   report the failure instead of retrying endlessly.
4. Summarize the results from `report.md` per video (abstract and TL;DR are
   the core), mention the output folder, and point to `_index.md` for the
   batch overview and `summary.json` for per-video status and wall times.
   Do not silently swallow errors: a failed video is marked in `_index.md`
   and the script exits nonzero — report which videos failed and why. URLs
   beyond `--max-playlist` in an `@file` batch are written to the index as
   `skipped (cap)` and to `skipped-urls.txt` (exit code nonzero); a playlist
   URL over the cap fails hard. Never print or log the API key.
5. The script is resumable: re-running the same URL skips completed steps
   (per-video `pipeline-state.json`) and reuses the existing video folder.

The Bash script downloads videos (≤720p mp4), extracts frames (1 fps, capped
at `--frame-cap` (default 120) with uniform downsampling so the filename
suffix equals the second),
transcribes with WhisperX (Silero VAD, float16, word-level alignment) or the
proxy whisper model, analyzes frames in 12–16-frame batches with the
multimodal chat model, and synthesizes a German markdown report (Abstract,
TL;DR, Inhalt with timestamps, Kernargumente, Visuelles, Zitate, Tags,
Ressourcen). Synthesis is preceded by a cheap `reasoning_effort=low`
extraction pre-pass (cached in `extraction.json`) that mines keypoints, quote
candidates, visual elements, and resources; chat calls retry HTTP 429/5xx and
transport errors with exponential backoff, the synthesis socket timeout scales
with effort (600/1200/1800 s), and a failing `max` synthesis falls back to one
`high` retry (marked `effort_degraded` in `pipeline-state.json`). Batches
exceeding `--max-playlist` list the overflow as `skipped (cap)` rows in
`_index.md`, append the URLs to `skipped-urls.txt`, and exit nonzero; playlist
URLs hitting the cap hard-error instead. Each run also writes a machine-readable
`summary.json` (status, folder, wall-clock seconds per video) next to
`_index.md`. Reports land
in `video-analysis/<upload-date>_<slug>_<videoId>/`.
