#!/usr/bin/env python3
"""YouTube video analysis pipeline for the /video-analysis OpenCode command.

Downloads one or more YouTube videos (or a text file with URLs), transcribes
them locally with WhisperX (large-v2, Silero VAD, float16) or via the proxy
whisper endpoint, extracts 1 fps frames (capped at 120 per video, uniformly
downsampled so the frame suffix stays equal to the second), describes frames
in batches of 6-8 with the multimodal chat model, synthesizes a German
markdown report, and maintains _index.md plus a per-video pipeline-state.json
manifest keyed by videoId.

Secrets are read from ~/.config/opencode/opencode.json (provider.litellm
options) or $LITELLM_API_KEY / $LITELLM_BASE_URL. Nothing is hardcoded.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

VIDEO_ID_RE = re.compile(r"[A-Za-z0-9_-]{11}")

YTDLP_COMMON_FLAGS = [
    "--write-info-json",
    "--write-thumbnail",
    "--convert-thumbnails",
    "jpg",
    "--write-auto-subs",
    "--sub-langs",
    "en.*",
    "--merge-output-format",
    "mp4",
    "-f",
    "bv*[height<=720]+ba/b[height<=720]",
    "--no-warnings",
    "--no-playlist",
    "--retries",
    "3",
    "--socket-timeout",
    "30",
]
YTDLP_AUDIO_FLAGS = [
    "-f",
    "ba[ext=m4a]/ba",
    "--extract-audio",
    "--audio-format",
    "wav",
]

FRAMES_DIR_NAME = "frames"
MANIFEST_NAME = "pipeline-state.json"
INDEX_NAME = "_index.md"

MODEL_ID = "local-inference-lab/GLM-5.3-Flash-NVFP4"
YTDLP_TIMEOUT = 1800
FFMPEG_TIMEOUT = 1800
VISION_TIMEOUT = 240
SYNTHESIS_TIMEOUT = 600
ASR_TIMEOUT = 3600
PROBE_TIMEOUT = 300

VENV_DIR = Path.home() / ".config/opencode/tools/video-analysis/.venv"
MODELS_DIR = Path.home() / ".config/opencode/tools/video-analysis/models"

MAX_PLAYLIST = 50
FRAME_CAP = 120
VISION_BATCH_MIN = 12
VISION_BATCH_MAX = 16
VISION_WORKERS = 8
VISION_IMAGE_MAX_BYTES = 3_000_000
MAX_TRANSCRIPT_CHARS = 400_000

STATE_ORDER = ["queued", "downloaded", "transcribed", "analyzed", "reported", "failed"]


class PipelineError(Exception):
    """A step failed; the message is safe to surface in _index.md."""


def log(msg: str) -> None:
    print(msg, flush=True)


def read_config() -> tuple[str, str]:
    config_path = Path.home() / ".config/opencode/opencode.json"
    api_key = os.environ.get("LITELLM_API_KEY", "").strip()
    base_url = os.environ.get("LITELLM_BASE_URL", "").strip()
    if config_path.exists():
        try:
            data = json.loads(config_path.read_text(encoding="utf-8"))
            options = data.get("provider", {}).get("litellm", {}).get("options", {})
            if not api_key:
                api_key = str(options.get("apiKey", "") or "").strip()
            if not base_url:
                base_url = str(options.get("baseURL", "") or "").strip()
        except (json.JSONDecodeError, OSError):
            pass
    if not api_key:
        raise PipelineError(
            "No API key found; set LITELLM_API_KEY or configure ~/.config/opencode/opencode.json"
        )
    if not base_url:
        raise PipelineError(
            "No base URL found; set LITELLM_BASE_URL or configure ~/.config/opencode/opencode.json"
        )
    return api_key, base_url.rstrip("/")


def chat_completion(
    messages: list[dict],
    api_key: str,
    base_url: str,
    timeout: int,
    max_tokens: int,
    transport_retries: int = 2,
    reasoning_effort: str | None = None,
) -> str:
    body = {"model": MODEL_ID, "messages": messages, "max_tokens": max_tokens}
    if reasoning_effort:
        body["reasoning_effort"] = reasoning_effort
    transport_attempts = transport_retries + 1
    budget_retried = False
    for attempt in range(max(transport_attempts, 2)):
        request = urllib.request.Request(
            f"{base_url}/chat/completions",
            data=json.dumps(body).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                data = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")[:500]
            raise PipelineError(f"Chat endpoint HTTP {exc.code}: {detail}") from exc
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            if attempt + 1 < transport_attempts:
                delay = 1.5 * (attempt + 1)
                log(f"  chat: transport error ({exc}); retrying in {delay:.1f}s")
                time.sleep(delay)
                continue
            raise PipelineError(f"Chat endpoint unreachable: {exc}") from exc
        try:
            choice = data["choices"][0]
            message = choice["message"]
            content = message.get("content")
            finish_reason = choice.get("finish_reason")
        except (KeyError, IndexError, TypeError) as exc:
            raise PipelineError(f"Unexpected chat response shape: {exc}") from exc
        if isinstance(content, str) and content.strip():
            return content
        if finish_reason == "length":
            if budget_retried:
                break
            budget_retried = True
            body["max_tokens"] = min(max_tokens * 4, 100_000)
            log(f"  chat: empty content (reasoning exhausted budget); retrying with {body['max_tokens']} tokens")
            continue
        raise PipelineError(
            "Chat response had empty content without truncation "
            f"(finish_reason={finish_reason!r}); a larger token budget would not help."
        )
    raise PipelineError(
        "Chat response had empty content even with increased token budget."
    )


def whisper_proxy_transcribe(
    audio_path: Path, api_key: str, base_url: str
) -> list[dict]:
    boundary = "----videoanalysisboundary7d9f2c"
    mime = mimetypes.guess_type(audio_path.name)[0] or "application/octet-stream"
    parts = [
        (
            f'--{boundary}\r\nContent-Disposition: form-data; name="model"\r\n\r\n'
            f"whisper-large-v3\r\n"
        ).encode("utf-8"),
        (
            f'--{boundary}\r\nContent-Disposition: form-data; name="response_format"\r\n\r\n'
            f"verbose_json\r\n"
        ).encode("utf-8"),
        (
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
            f'filename="{audio_path.name}"\r\nContent-Type: {mime}\r\n\r\n'
        ).encode("utf-8"),
        audio_path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode("utf-8"),
    ]
    request = urllib.request.Request(
        f"{base_url}/audio/transcriptions",
        data=b"".join(parts),
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=ASR_TIMEOUT) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:500]
        raise PipelineError(f"Proxy ASR HTTP {exc.code}: {detail}") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise PipelineError(f"Proxy ASR unreachable: {exc}") from exc
    segments: list[dict] = []
    raw_segments = data.get("segments") or []
    for seg in raw_segments:
        segments.append(
            {
                "start": float(seg.get("start", 0.0)),
                "end": float(seg.get("end", 0.0)),
                "text": str(seg.get("text", "")).strip(),
            }
        )
    if not segments and data.get("text"):
        segments = [{"start": 0.0, "end": 0.0, "text": str(data["text"]).strip()}]
    if not segments:
        raise PipelineError("Proxy ASR returned no segments and no text.")
    return segments


def parse_vtt(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8", errors="replace")
    segments: list[dict] = []
    blocks = re.split(r"\n\s*\n", text)
    for block in blocks:
        lines = [l for l in block.splitlines() if l.strip()]
        if not lines:
            continue
        timing_idx = next(
            (i for i, l in enumerate(lines) if "-->" in l), None
        )
        if timing_idx is None:
            continue
        m = re.search(
            r"(\d+):(\d+):(\d+)[.,](\d+)\s*-->\s*(\d+):(\d+):(\d+)[.,](\d+)",
            lines[timing_idx],
        )
        if not m:
            continue
        g = [int(x) for x in m.groups()]
        start = g[0] * 3600 + g[1] * 60 + g[2] + g[3] / 1000
        end = g[4] * 3600 + g[5] * 60 + g[6] + g[7] / 1000
        cue_text = " ".join(
            re.sub(r"<[^>]+>", "", l).strip()
            for l in lines[timing_idx + 1:]
        ).strip()
        if cue_text:
            segments.append({"start": start, "end": end, "text": cue_text})
    return segments


def run_ytdlp(url: str, out_dir: Path, audio_only: bool, yt_dlp: Path) -> dict:
    out_template = str(out_dir / "%(title).80B [%(id)s].%(ext)s")
    cmd = [str(yt_dlp)]
    flags = list(YTDLP_COMMON_FLAGS)
    if audio_only:
        flags = [
            f for f in flags
            if f not in ("--write-thumbnail", "--convert-thumbnails", "jpg")
        ]
        flags += YTDLP_AUDIO_FLAGS
    cmd += flags
    cmd += ["--paths", str(out_dir), "-o", out_template, url]
    log(f"  yt-dlp: downloading {url}")
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=YTDLP_TIMEOUT,
        env={**os.environ, "LC_ALL": "C.UTF-8"},
    )
    if proc.returncode != 0:
        error_text = (proc.stderr or proc.stdout or "unknown yt-dlp error").strip()
        # YouTube rate-limits subtitle downloads (HTTP 429); captions are only
        # fallback material, so retry once without them instead of failing.
        if "Unable to download video subtitles" in error_text:
            log("  yt-dlp: subtitle download failed (rate limit); retrying without subtitles")
            no_subs: list[str] = []
            i = 0
            while i < len(cmd):
                flag = cmd[i]
                if flag == "--write-auto-subs":
                    i += 3
                    continue
                no_subs.append(flag)
                i += 1
            proc = subprocess.run(
                no_subs, capture_output=True, text=True, timeout=YTDLP_TIMEOUT,
                env={**os.environ, "LC_ALL": "C.UTF-8"},
            )
            if proc.returncode != 0:
                error_text = (proc.stderr or proc.stdout or "unknown yt-dlp error").strip()
                raise PipelineError(error_text.splitlines()[-1][:300])
        else:
            raise PipelineError(error_text.splitlines()[-1][:300])
    json_files = sorted(out_dir.glob("*.info.json"), key=lambda p: p.stat().st_mtime)
    if not json_files:
        raise PipelineError("yt-dlp wrote no .info.json file.")
    try:
        info = json.loads(json_files[-1].read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise PipelineError(f"Corrupt info.json: {exc}") from exc
    return info


def find_media_file(out_dir: Path, video_id: str, audio_only: bool) -> Path | None:
    suffixes = (".wav", ".m4a", ".mp3", ".opus") if audio_only else (".mp4", ".mkv", ".webm")
    candidates = [
        p for p in out_dir.iterdir()
        if p.is_file() and p.suffix.lower() in suffixes
        and (audio_only or p.name != "audio.wav")
    ]
    if not candidates:
        return None

    def score(p: Path) -> int:
        return 0 if video_id in p.name else 1

    return sorted(candidates, key=score)[0]


def rename_media_files(folder: Path, video_id: str, audio_only: bool) -> None:
    if audio_only:
        wav = next(
            (p for p in folder.glob("*.wav") if p.name != "audio.wav"), None
        )
        if wav:
            wav.rename(folder / "audio.wav")
        return
    media = find_media_file(folder, video_id, False)
    if media:
        media.rename(folder / "video.mp4")


def extract_frames(
    video_path: Path, frames_dir: Path, duration_s: float, fps_wanted: float
) -> int:
    """Extract JPEG frames; cap total at FRAME_CAP by uniform fps reduction.

    The cap rule keeps filename == second: when duration * fps exceeds the
    cap, fps becomes Cap/duration so frame N still maps to second N.
    """
    frames_dir.mkdir(parents=True, exist_ok=True)
    fps = fps_wanted
    if duration_s > 0 and duration_s * fps_wanted > FRAME_CAP:
        fps = FRAME_CAP / duration_s
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(video_path),
        "-vf", f"fps={fps}",
        "-q:v", "2",
        str(frames_dir / "frame-%06d.jpg"),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=FFMPEG_TIMEOUT)
    if proc.returncode != 0:
        raise PipelineError(f"ffmpeg frame extraction failed: {(proc.stderr or '').strip()[-300:]}")
    frames = sorted(frames_dir.glob("frame-*.jpg"))
    # Rename in two phases: a direct rename can collide with an original name
    # still pending processing (e.g. frame-000002 -> frame-000004 overwrites
    # the not-yet-renamed frame-000004), destroying frames and misnumbering.
    tmp_suffix = ".renaming"
    staged = []
    for frame in frames:
        staged_path = frame.with_name(frame.name + tmp_suffix)
        frame.rename(staged_path)
        staged.append(staged_path)
    for idx, frame in enumerate(staged, start=1):
        second = int(round((idx - 1) / fps))
        frame.rename(frames_dir / f"frame-{second:06d}.jpg")
    return len(frames)


def extract_audio(video_path: Path, audio_path: Path) -> None:
    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(video_path), "-vn", "-acodec", "pcm_s16le", "-ar", "16000",
        "-ac", "1", str(audio_path),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=FFMPEG_TIMEOUT)
    if proc.returncode != 0:
        raise PipelineError(f"ffmpeg audio extraction failed: {(proc.stderr or '').strip()[-300:]}")


def run_whisperx(
    media_paths: list[Path],
    out_dir: Path,
    model: str,
    language: str,
    diarize: bool,
    whisperx_bin: Path,
) -> dict[str, Path]:
    """Transcribe one or more media files in a single WhisperX invocation.

    The CLI loads the whisper model once for all inputs and the alignment
    model once per language (verified: whisperx/transcribe.py loops over
    args["audio"] between the two load calls), so N videos cost one model
    load instead of N. Outputs are written to out_dir named after each
    input stem; returns a mapping input stem -> json path.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(whisperx_bin),
        "--model", model,
        "--model_dir", str(MODELS_DIR),
        "--vad_method", "silero",
        "--compute_type", "float16",
        "--output_format", "all",
        "--output_dir", str(out_dir),
    ]
    if language != "auto":
        cmd += ["--language", language]
    if diarize:
        cmd += ["--diarize"]
    cmd.extend(str(p) for p in media_paths)
    n = len(media_paths)
    log(f"  whisperx: transcribing + aligning {n} file(s) ({model}, silero, float16)")
    proc = subprocess.run(
        cmd, capture_output=True, text=True, timeout=ASR_TIMEOUT,
        env={**os.environ, "HF_HUB_DISABLE_TELEMETRY": "1"},
    )
    if proc.returncode != 0:
        raise PipelineError(
            (proc.stderr or proc.stdout or "unknown whisperx error").strip().splitlines()[-1][:400]
        )
    mapping: dict[str, Path] = {}
    for media in media_paths:
        expected = out_dir / f"{media.stem}.json"
        if not expected.exists():
            raise PipelineError(f"WhisperX produced no JSON output for {media.name}")
        mapping[media.stem] = expected
    return mapping


def normalize_transcript(whisperx_json_path: Path, out_dir: Path) -> dict:
    raw = json.loads(whisperx_json_path.read_text(encoding="utf-8"))
    segments: list[dict] = []
    for seg in raw.get("segments", []):
        entry = {
            "start": round(float(seg.get("start", 0.0)), 3),
            "end": round(float(seg.get("end", 0.0)), 3),
            "text": str(seg.get("text", "")).strip(),
        }
        words = seg.get("words") or []
        if words:
            entry["words"] = [
                {
                    "start": round(float(w["start"]), 3) if w.get("start") is not None else None,
                    "end": round(float(w["end"]), 3) if w.get("end") is not None else None,
                    "word": str(w.get("word", "")).strip(),
                }
                for w in words
            ]
        segments.append(entry)
    transcript = {"language": raw.get("language"), "segments": segments}
    write_transcript_files(transcript, out_dir)
    return transcript


def normalize_folder(folder: Path) -> None:
    """Bring the folder to the plan layout: poster.jpg + no raw WhisperX/
    yt-dlp sibling files. Runs for both ASR paths (local and proxy)."""
    canonical = {
        "metadata.json", MANIFEST_NAME, "transcript.json", "transcript.txt",
        "transcript.srt", "scenes.json", "report.md", "video.mp4", "poster.jpg",
        "audio.wav", "captions.vtt", FRAMES_DIR_NAME,
    }
    for thumbnail in list(folder.glob("*.jpg")) + list(folder.glob("*.webp")):
        if thumbnail.name != "poster.jpg":
            thumbnail.rename(folder / "poster.jpg")
            break
    for sibling in folder.iterdir():
        if sibling.name in canonical or sibling.is_dir():
            continue
        sibling.unlink()


def write_transcript_files(transcript: dict, out_dir: Path) -> None:
    (out_dir / "transcript.json").write_text(
        json.dumps(transcript, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    lines = [seg["text"] for seg in transcript["segments"] if seg.get("text")]
    (out_dir / "transcript.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (out_dir / "transcript.srt").write_text(build_srt(transcript["segments"]), encoding="utf-8")


def build_srt(segments: list[dict]) -> str:
    def fmt(ts: float) -> str:
        ms = int(round(ts * 1000))
        h, rem = divmod(ms, 3600000)
        m, rem = divmod(rem, 60000)
        s, ms = divmod(rem, 1000)
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

    out = []
    for i, seg in enumerate(segments, 1):
        text = seg.get("text", "").strip()
        if not text:
            continue
        out.append(f"{i}\n{fmt(seg['start'])} --> {fmt(seg['end'])}\n{text}\n")
    return "\n".join(out)


def seconds_to_mmss(seconds: float) -> str:
    total = int(max(0, round(seconds)))
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{h:d}:{m:02d}:{s:02d}" if h else f"{m:02d}:{s:02d}"


def encode_image(path: Path) -> str:
    size = path.stat().st_size
    work_path = path
    tmp_dir: Path | None = None
    if size > VISION_IMAGE_MAX_BYTES:
        tmp_dir = Path(tempfile.mkdtemp(prefix="va-frame-"))
        work_path = tmp_dir / path.name
        proc = subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(path),
             "-vf", "scale='min(1024,iw)':-2", "-q:v", "4", str(work_path)],
            capture_output=True, text=True, timeout=120,
        )
        if proc.returncode != 0 or not work_path.exists():
            shutil.rmtree(tmp_dir, ignore_errors=True)
            raise PipelineError(f"Frame downscale failed for {path.name}")
    media_type = mimetypes.guess_type(work_path.name)[0] or "image/jpeg"
    b64 = base64.b64encode(work_path.read_bytes()).decode("ascii")
    if tmp_dir is not None:
        shutil.rmtree(tmp_dir, ignore_errors=True)
    return f"data:{media_type};base64,{b64}"


VISION_PROMPT = """You are analyzing frames sampled from a technical talk or tutorial video. For each frame, state concisely:
- what is visible (slide, code editor, terminal, diagram, demo UI, talking head, title card)
- any readable slide title or on-screen text (verbatim where short)
- if code is visible: language and what it roughly does
- scene changes between consecutive frames

Answer as a compact list, one entry per frame, prefixed with its second (e.g. "s012: ..."). Use English; keep each entry under 30 words."""


def analyze_frames(frames: list[Path], api_key: str, base_url: str) -> list[dict]:
    batches: list[list[Path]] = []
    for batch_start in range(0, len(frames), VISION_BATCH_MAX):
        batch = frames[batch_start:batch_start + VISION_BATCH_MAX]
        if len(batch) < VISION_BATCH_MIN and batch_start > 0:
            need = VISION_BATCH_MIN - len(batch)
            batch = frames[batch_start - need:batch_start + len(batch)]
        batches.append(batch)

    def frame_second(frame: Path) -> int:
        m = re.fullmatch(r"frame-(\d{6})\.jpg", frame.name)
        return int(m.group(1)) if m else 0

    def describe_batch(batch: list[Path]) -> dict:
        content: list[dict] = []
        for frame in batch:
            second = frame_second(frame)
            content.append({"type": "text", "text": f"Frame at second {second}:"})
            content.append({"type": "image_url", "image_url": {"url": encode_image(frame)}})
        content.append({"type": "text", "text": VISION_PROMPT})
        second_range = f"{frame_second(batch[0])}-{frame_second(batch[-1])}"
        try:
            answer = chat_completion(
                [{"role": "user", "content": content}],
                api_key, base_url, timeout=VISION_TIMEOUT, max_tokens=2000,
            )
        except PipelineError as exc:
            log(f"  vision: batch {second_range}s FAILED after retries: {str(exc)[:120]}")
            return {
                "batch_seconds": second_range,
                "frames": [{"second": frame_second(f), "file": f.name} for f in batch],
                "notes": None,
                "error": str(exc)[:300],
            }
        log(f"  vision: batch {second_range}s done ({len(batch)} frames)")
        return {
            "batch_seconds": second_range,
            "frames": [{"second": frame_second(f), "file": f.name} for f in batch],
            "notes": answer.strip(),
        }

    notes: list[dict] = []
    with ThreadPoolExecutor(max_workers=VISION_WORKERS) as pool:
        notes = list(pool.map(describe_batch, batches))
    return notes


def build_synthesis_prompt(
    info: dict, transcript: dict, scenes: list[dict], lang_report: str
) -> str:
    duration = info.get("duration") or 0
    chapters = info.get("chapters") or []
    chapter_lines = [
        f"- {seconds_to_mmss(c.get('start_time', 0))} {c.get('title', '')}" for c in chapters
    ]
    chapter_block = "\n".join(chapter_lines) if chapters else "(keine YouTube-Kapitel)"
    lines = [
        f"[{seconds_to_mmss(seg['start'])}] {seg['text']}"
        for seg in transcript.get("segments", [])
        if seg.get("text")
    ]
    transcript_text = "\n".join(lines)
    if len(transcript_text) > MAX_TRANSCRIPT_CHARS:
        step = max(1, len(lines) // max(1, MAX_TRANSCRIPT_CHARS // max(1, len(transcript_text) // len(lines))))
        sampled = lines[::step]
        transcript_text = (
            "(Transkript wegen Länge gleichmäßig ausgedünnt)\n" + "\n".join(sampled)
        )
    scene_text = "\n".join(
        f"[Batch {note['batch_seconds']}s]\n{note['notes']}" for note in scenes
    ) or "(keine Frame-Analyse verfügbar)"
    return SYNTHESIS_PROMPT.format(
        title=info.get("title", ""),
        channel=info.get("channel", ""),
        published=format_date(info.get("upload_date", "")),
        duration=seconds_to_mmss(duration),
        views=info.get("view_count") or 0,
        url=info.get("webpage_url", ""),
        chapters=chapter_block,
        scenes=scene_text,
        transcript=transcript_text,
        lang=lang_report,
    )


def format_date(raw: str) -> str:
    date = str(raw or "")
    return f"{date[0:4]}-{date[4:6]}-{date[6:8]}" if len(date) == 8 else date


SYNTHESIS_PROMPT = """Du erstellst aus den folgenden Quellen einen Video-Report. Antworte AUSSCHLIESSLICH mit dem Markdown-Dokument (kein Vorwort, keine Code-Fences um das Ganze).

Video: „{title}" — {channel}, veröffentlicht {published}, Dauer {duration}, {views:,} Aufrufe, {url}

YouTube-Kapitel:
{chapters}

Visuelle Frame-Notizen (aus Bildanalyse):
{scenes}

Transkript mit Timestamps [mm:ss]:
{transcript}

Erstelle den Report exakt nach dieser Struktur:

# {title}
> {channel} · {published} · {duration} · {views:,} Aufrufe · {url}

## Abstract
(3–5 Sätze, was das Video leistet und für wen)

## TL;DR
(5–7 Stichpunkte, je eine Zeile als Markdown-Liste)

## Inhalt
(Abschnitte entlang der Kapitel oder Themenblöcke; wenn keine Kapitel existieren, bilde thematische Blöcke über je ~5 Minuten; jede Aussage mit [mm:ss]-Timestamps aus dem Transkript belegen; im Zweifel MEHR Timestamps als weniger — jede Aussage soll einzeln prüfbar sein)

## Kernargumente
(3–6 Bullets mit dem substanziellsten Inhalt)

## Visuelles
(Slides/Demos/Diagramme aus den Frame-Notizen, mit Timestamps [mm:ss]; jedes visuelle Element bekommt einen eigenen Listenpunkt — keine Sammelzusammenfassung; ohne visuelle Notizen schreib „(nicht verfügbar)")

## Markante Zitate
(Exakt 3 wörtliche Zitate: kopiere die Sätze 1:1 aus dem Transkript, inklusive Füllwörter — keine Paraphrase, keine Kürzung; jeweils mit [mm:ss])

## Themen/Tags
(5–8 kurze Tags als Liste)

## Erwähnte Ressourcen
(Links, Paper, Tools, Bücher aus Transkript/Visuellem; sonst „(keine)")

Regeln: Antworte auf {lang}. Verwende nur Informationen aus den Quellen; erfinde nichts. Timestamps müssen aus dem Transkript oder den Frame-Notizen stammen. Wenn das Transkript mehrere Zeitangaben oder eine Reihenfolge von Ereignissen nennt, gib die Chronologie exakt wieder — keine zusammengefassten Zeitangaben."""


def sanitize_cell(text: str) -> str:
    return str(text or "").replace("|", "/").replace("\n", " ").strip()


def write_index_entry(
    index_path: Path,
    video_id: str,
    title: str,
    channel: str,
    duration: float,
    upload_date: str,
    folder_name: str,
    status: str,
    error: str = "",
) -> None:
    error_cell = f" — {sanitize_cell(error)[:120]}" if error else ""
    row = (
        f"| {sanitize_cell(title)[:80]} | {sanitize_cell(channel)[:40]} | "
        f"{seconds_to_mmss(duration)} | {status}{error_cell} | "
        f"{format_date(upload_date)} | `{sanitize_cell(folder_name)}` |"
    )
    header = "| Titel | Kanal | Dauer | Status | Datum | Ordner |\n|---|---|---|---|---|---|"
    if index_path.exists():
        lines = index_path.read_text(encoding="utf-8").splitlines()
    else:
        lines = ["# Video-Analysen", "", header]
    row_idx = next(
        (i for i, line in enumerate(lines) if video_id in line and line.startswith("|")),
        None,
    )
    if row_idx is not None:
        lines[row_idx] = row
    else:
        lines.append(row)
    index_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def load_manifest(folder: Path) -> dict:
    manifest_path = folder / MANIFEST_NAME
    if manifest_path.exists():
        try:
            return json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def save_manifest(folder: Path, manifest: dict) -> None:
    manifest["updated_at"] = datetime.now().isoformat(timespec="seconds")
    (folder / MANIFEST_NAME).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze YouTube video(s): download, transcribe, frame-vision, report."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        help="YouTube URL(s), playlist URL, or @file.txt with one URL per line",
    )
    parser.add_argument("--out", default="video-analysis", help="Output directory (default: video-analysis/)")
    parser.add_argument("--frames", type=float, default=1.0, help="Frames per second (default 1, cap 120)")
    parser.add_argument("--lang", default="auto", help="Audio language hint for WhisperX (default: auto)")
    parser.add_argument("--lang-report", default="Deutsch", help="Report language (default: Deutsch)")
    parser.add_argument(
        "--report-effort",
        choices=["low", "high", "max"],
        default="max",
        help="Reasoning effort for the synthesis call (default: max; low/high are ~4x faster with slightly less detail)",
    )
    parser.add_argument(
        "--asr", choices=["local", "proxy"], default="local",
        help="ASR backend: local WhisperX (default) or proxy whisper-large-v3",
    )
    parser.add_argument("--no-video", action="store_true", help="Audio-only download; no mp4/poster/frames")
    parser.add_argument("--keep-audio", action="store_true", help="Keep audio.wav in the video folder")
    parser.add_argument("--diarize", action="store_true", help="Speaker diarization (needs HF token; gated models)")
    parser.add_argument("--whisper-model", default="large-v2", help="WhisperX model (default: large-v2)")
    parser.add_argument("--max-playlist", type=int, default=MAX_PLAYLIST, help="Playlist cap (default 50)")
    return parser.parse_args()


def lenient_video_id(url: str) -> str | None:
    m = re.search(r"(?:v=|youtu\.be/|shorts/|embed/)([A-Za-z0-9_-]{11})", url)
    if m:
        return m.group(1)
    if VIDEO_ID_RE.fullmatch(url.strip()):
        return url.strip()
    return None


def is_playlist_url(url: str) -> bool:
    return "list=" in url and "watch?v=" not in url


def expand_playlist(url: str, yt_dlp: Path, cap: int) -> list[str]:
    proc = subprocess.run(
        [str(yt_dlp), "--no-warnings", "--flat-playlist", "--print", "%(id)s", url],
        capture_output=True, text=True, timeout=PROBE_TIMEOUT,
    )
    if proc.returncode != 0:
        raise PipelineError(
            (proc.stderr or "playlist expansion failed").strip().splitlines()[-1][:300]
        )
    ids = [
        line.strip()
        for line in proc.stdout.splitlines()
        if VIDEO_ID_RE.fullmatch(line.strip())
    ]
    if len(ids) > cap:
        log(f"Playlist has {len(ids)} entries; capping to {cap}.")
        ids = ids[:cap]
    return [f"https://www.youtube.com/watch?v={vid}" for vid in ids]


def probe_metadata(url: str, yt_dlp: Path) -> dict:
    proc = subprocess.run(
        [str(yt_dlp), "--no-warnings", "--skip-download", "--dump-json", url],
        capture_output=True, text=True, timeout=PROBE_TIMEOUT,
    )
    if proc.returncode != 0:
        raise PipelineError(
            (proc.stderr or "metadata probe failed").strip().splitlines()[-1][:300]
        )
    try:
        info = json.loads(proc.stdout.strip().splitlines()[0])
    except json.JSONDecodeError as exc:
        raise PipelineError(f"Unexpected metadata probe output: {exc}") from exc
    return {
        "id": info.get("id", ""),
        "upload_date": info.get("upload_date") or "",
        "duration": float(info.get("duration") or 0),
        "title": info.get("title", ""),
    }


def slugify(text: str) -> str:
    text = (text or "").strip()
    for src, dst in {"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss",
                     "Ä": "Ae", "Ö": "Oe", "Ü": "Ue"}.items():
        text = text.replace(src, dst)
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    text = re.sub(r"[\s_]+", "-", text).strip("-").lower()
    return text[:50] or "video"


def folder_name_for(info: dict) -> str:
    date_fmt = format_date(info.get("upload_date", "")) or "unknown-date"
    return f"{date_fmt}_{slugify(info.get('title', ''))}_{info.get('id', 'unknown')}"


def find_existing_folder(out_dir: Path, video_id: str) -> Path | None:
    for entry in sorted(out_dir.iterdir()):
        if entry.is_dir() and entry.name.endswith(f"_{video_id}"):
            return entry
    return None


def yt_dlp_path() -> Path:
    return VENV_DIR / "bin/yt-dlp"


def whisperx_bin_path() -> Path:
    return VENV_DIR / "bin/whisperx"


def prepare_video(
    args: argparse.Namespace,
    url: str,
    video_id: str,
    out_dir: Path,
) -> tuple[Path, dict]:
    folder = find_existing_folder(out_dir, video_id)
    if folder is None:
        info = probe_metadata(url, yt_dlp_path())
        folder = out_dir / folder_name_for(info)
        folder.mkdir(parents=True, exist_ok=True)
    manifest = load_manifest(folder)
    manifest.setdefault("video_id", video_id)
    manifest.setdefault("url", url)
    manifest.setdefault("state_order", STATE_ORDER)
    state = manifest.get("state", "queued")
    manifest["previous_state"] = state
    return folder, manifest


def record_failure(
    index_path: Path, video_id: str, folder: Path, manifest: dict
) -> None:
    failed_state = STATE_ORDER.index(manifest["state"]) if manifest.get("state") in STATE_ORDER else 0
    previous_state = STATE_ORDER.index(manifest["previous_state"]) if manifest.get("previous_state") in STATE_ORDER else 0
    if failed_state < previous_state:
        manifest["state"] = manifest["previous_state"]
    save_manifest(folder, manifest)
    metadata = read_metadata(folder)
    write_index_entry(
        index_path, video_id,
        metadata.get("title") or manifest.get("url", ""),
        metadata.get("channel", ""),
        metadata.get("duration") or 0,
        metadata.get("upload_date", ""),
        folder.name, "failed",
    )


def read_metadata(folder: Path) -> dict:
    info_path = folder / "metadata.json"
    if not info_path.exists():
        return {}
    try:
        return json.loads(info_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def ensure_downloaded(
    args: argparse.Namespace,
    url: str,
    video_id: str,
    folder: Path,
    manifest: dict,
) -> None:
    state = manifest.get("state", "queued")
    info_path = folder / "metadata.json"
    if state != "queued" and info_path.exists():
        return
    log(f"  download: yt-dlp into {folder.name}")
    info = run_ytdlp(url, folder, args.no_video, yt_dlp_path())
    wanted_keys = [
        "id", "title", "channel", "upload_date", "duration", "view_count",
        "webpage_url", "description", "chapters", "categories", "tags",
    ]
    metadata = {k: info.get(k) for k in wanted_keys}
    info_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    for stale in folder.glob("*.info.json"):
        stale.unlink()
    rename_media_files(folder, video_id, args.no_video)
    manifest["state"] = "downloaded"
    manifest["downloaded_at"] = datetime.now().isoformat(timespec="seconds")
    save_manifest(folder, manifest)


def finish_transcription(
    args: argparse.Namespace,
    video_id: str,
    folder: Path,
    manifest: dict,
    api_key: str,
    base_url: str,
) -> None:
    """Transcribe ONE video (already downloaded). Used for single-video runs,
    proxy ASR, and as fallback when the batched resident run fails."""
    state = manifest.get("state", "queued")
    if state in ("transcribed", "analyzed", "reported"):
        return
    media = find_media_file(folder, video_id, args.no_video)
    if media is None:
        raise PipelineError("no media file found after download")
    canonical = folder / ("audio.wav" if args.no_video else "video.mp4")
    if media != canonical:
        media.rename(canonical)
    try:
        if args.asr == "local":
            mapping = run_whisperx(
                [canonical], folder, args.whisper_model, args.lang, args.diarize,
                whisperx_bin_path(),
            )
            normalize_transcript(mapping[canonical.stem], folder)
        else:
            segments = whisper_proxy_transcribe(canonical, api_key, base_url)
            write_transcript_files({"language": None, "segments": segments}, folder)
    except PipelineError:
        captions = promote_captions(folder)
        if captions is None:
            raise
        log(f"  asr failed; using YouTube autocaptions as fallback: {captions.name}")
        segments = parse_vtt(captions)
        if not segments:
            raise
        write_transcript_files({"language": None, "segments": segments}, folder)
        manifest["asr_fallback"] = "captions"
    if args.no_video and not args.keep_audio:
        (folder / "audio.wav").unlink(missing_ok=True)
    normalize_folder(folder)
    manifest["state"] = "transcribed"
    save_manifest(folder, manifest)


def transcribe_batch(
    jobs: list[tuple[str, Path, dict]],
    args: argparse.Namespace,
    api_key: str,
    base_url: str,
    index_path: Path,
) -> list[str]:
    """Transcribe all pending videos with ONE WhisperX invocation (local ASR):
    one whisper-model load for the whole batch instead of one per video.
    Returns video_ids whose transcription failed (isolated, batch continues)."""
    failed: list[str] = []
    if not jobs:
        return failed
    if args.asr != "local":
        for video_id, folder, manifest in jobs:
            try:
                finish_transcription(args, video_id, folder, manifest, api_key, base_url)
            except PipelineError:
                failed.append(video_id)
        return failed
    staging = jobs[0][1].parent / "_transcribe-staging"
    staging.mkdir(parents=True, exist_ok=True)
    try:
        links: list[Path] = []
        for video_id, folder, _ in jobs:
            media = find_media_file(folder, video_id, args.no_video)
            if media is None:
                log(f"  whisperx: no media for {video_id}; deferring to fallback")
                failed.append(video_id)
                continue
            canonical = folder / ("audio.wav" if args.no_video else "video.mp4")
            if media != canonical:
                media.rename(canonical)
            link = staging / f"{video_id}{canonical.suffix}"
            if link.exists():
                link.unlink()
            os.link(canonical, link)
            links.append(link)
        mapping = run_whisperx(
            links, staging, args.whisper_model, args.lang, args.diarize,
            whisperx_bin_path(),
        )
        for video_id, folder, manifest in jobs:
            if video_id in failed:
                continue
            try:
                normalize_transcript(mapping[video_id], folder)
                if args.no_video and not args.keep_audio:
                    (folder / "audio.wav").unlink(missing_ok=True)
                normalize_folder(folder)
                manifest["state"] = "transcribed"
                save_manifest(folder, manifest)
            except (PipelineError, KeyError) as exc:
                log(f"  transcription output unusable for {video_id}: {str(exc)[:100]}")
                failed.append(video_id)
    except PipelineError:
        shutil.rmtree(staging, ignore_errors=True)
        return [vid for vid, _, _ in jobs]
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    return failed


def finish_video(
    args: argparse.Namespace,
    video_id: str,
    folder: Path,
    manifest: dict,
    api_key: str,
    base_url: str,
    index_path: Path,
) -> None:
    state = manifest.get("state", "queued")
    metadata = read_metadata(folder)

    transcript_json = folder / "transcript.json"
    if not transcript_json.exists() and state in ("queued", "downloaded"):
        finish_transcription(args, video_id, folder, manifest, api_key, base_url)
        state = manifest.get("state", "transcribed")
    scenes_path = folder / "scenes.json"
    if not args.no_video and state not in ("analyzed", "reported"):
        frames_dir = folder / FRAMES_DIR_NAME
        video_file = folder / "video.mp4"
        if not video_file.exists():
            media = find_media_file(folder, video_id, False)
            if media is None:
                raise PipelineError("no video file for frame extraction")
            media.rename(video_file)
        if not any(frames_dir.glob("frame-*.jpg")):
            n = extract_frames(
                video_file, frames_dir, float(metadata.get("duration") or 0), args.frames
            )
            log(f"  frames: {n} extracted")
        if args.keep_audio and not (folder / "audio.wav").exists():
            extract_audio(video_file, folder / "audio.wav")
        frame_files = sorted(frames_dir.glob("frame-*.jpg"))
        log(f"  vision: {len(frame_files)} frames")
        scenes = analyze_frames(frame_files, api_key, base_url)
        scenes_path.write_text(
            json.dumps(scenes, ensure_ascii=False, indent=1), encoding="utf-8"
        )
        manifest["state"] = "analyzed"
        save_manifest(folder, manifest)
        state = "analyzed"
    elif args.no_video and state == "transcribed":
        manifest["state"] = "analyzed"
        manifest["analysis_skipped"] = True
        save_manifest(folder, manifest)
        state = "analyzed"

    report_path = folder / "report.md"
    if state != "reported":
        transcript = json.loads(transcript_json.read_text(encoding="utf-8"))
        scenes = []
        if scenes_path.exists():
            scenes = json.loads(scenes_path.read_text(encoding="utf-8"))
        prompt = build_synthesis_prompt(metadata, transcript, scenes, args.lang_report)
        log(f"  synthesis: calling model for report (reasoning_effort={args.report_effort})")
        report_text = chat_completion(
            [{"role": "user", "content": prompt}],
            api_key, base_url, timeout=SYNTHESIS_TIMEOUT, max_tokens=24000,
            reasoning_effort=args.report_effort,
        )
        report_text = re.sub(r"^\s*```(?:markdown)?\s*\n", "", report_text.strip())
        report_text = re.sub(r"\n```\s*$", "", report_text)
        report_path.write_text(report_text + "\n", encoding="utf-8")
        manifest["state"] = "reported"
        save_manifest(folder, manifest)
        log(f"  report: {report_path}")


def promote_captions(folder: Path) -> Path | None:
    candidates = sorted(folder.glob("*.vtt"))
    if not candidates:
        return None
    target = folder / "captions.vtt"
    if not target.exists():
        shutil.copyfile(candidates[0], target)
    return target


def main() -> int:
    args = parse_args()
    yt_dlp = yt_dlp_path()
    if not yt_dlp.exists():
        raise PipelineError(f"yt-dlp not found at {yt_dlp}; run video-analysis-setup.sh")
    if args.asr == "local" and not whisperx_bin_path().exists():
        raise PipelineError(
            f"whisperx not found at {whisperx_bin_path()}; run video-analysis-setup.sh"
        )

    urls: list[str] = []
    for item in args.inputs:
        if item.startswith("@"):
            file_path = Path(item[1:]).expanduser()
            if not file_path.exists():
                raise PipelineError(f"@file not found: {file_path}")
            for line in file_path.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    urls.append(line)
        else:
            urls.append(item)
    if not urls:
        raise PipelineError("No URLs given.")

    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    index_path = out_dir / INDEX_NAME

    expanded: list[str] = []
    for url in urls:
        if is_playlist_url(url):
            log(f"Resolving playlist: {url}")
            expanded.extend(expand_playlist(url, yt_dlp, args.max_playlist))
        else:
            expanded.append(url)
    if len(expanded) > args.max_playlist:
        log(
            f"WARNING: {len(expanded)} URLs exceed the cap of {args.max_playlist}; "
            f"processing only the first {args.max_playlist}."
        )
        expanded = expanded[: args.max_playlist]

    api_key, base_url = read_config()
    exit_code = 0

    def fail_url(video_id: str | None, url: str, message: str) -> None:
        nonlocal exit_code
        log(f"ERROR: [{video_id or '?'}] {message}")
        write_index_entry(
            index_path, video_id or url, url, "", 0, "", "-", "failed", message
        )
        exit_code = 1

    # Phase 1: resolve folders and download all videos (sequential, yt-dlp).
    pending_transcribe: list[tuple[str, Path, dict]] = []
    finished: set[str] = set()
    for url in expanded:
        video_id = lenient_video_id(url)
        try:
            if video_id is None:
                raise PipelineError(f"Cannot extract video id from URL: {url}")
            log(f"Video {video_id}: starting")
            folder, manifest = prepare_video(args, url, video_id, out_dir)
            try:
                ensure_downloaded(args, url, video_id, folder, manifest)
            except PipelineError as exc:
                manifest["error"] = str(exc)[:300]
                record_failure(index_path, video_id, folder, manifest)
                fail_url(video_id, url, str(exc))
                continue
            state = manifest.get("state", "queued")
            if state in ("transcribed", "analyzed", "reported") or (folder / "transcript.json").exists():
                finished.add(video_id)
            else:
                pending_transcribe.append((video_id, folder, manifest))
        except PipelineError as exc:
            fail_url(video_id or "", url, str(exc))
        except subprocess.TimeoutExpired as exc:
            fail_url(video_id or "", url, f"timeout: {exc}")

    # Phase 2: transcribe all pending videos with one WhisperX invocation
    # (model loads once for the whole batch instead of once per video).
    if pending_transcribe:
        if len(pending_transcribe) > 1 and args.asr == "local":
            log(f"Transcribing {len(pending_transcribe)} video(s) in one batched run")
            failed_ids = transcribe_batch(pending_transcribe, args, api_key, base_url, index_path)
        else:
            failed_ids = []
            for video_id, folder, manifest in pending_transcribe:
                try:
                    finish_transcription(args, video_id, folder, manifest, api_key, base_url)
                except PipelineError as exc:
                    manifest["error"] = str(exc)[:300]
                    record_failure(index_path, video_id, folder, manifest)
                    failed_ids.append(video_id)
                    fail_url(video_id, manifest.get("url", ""), str(exc))
        for video_id, folder, manifest in pending_transcribe:
            if video_id in failed_ids:
                fail_url(video_id, manifest.get("url", ""), "transcription failed")
            else:
                finished.add(video_id)

    # Phase 3: vision + synthesis + index per finished video.
    for url in expanded:
        video_id = lenient_video_id(url)
        if video_id is None or video_id not in finished:
            continue
        try:
            folder, manifest = prepare_video(args, url, video_id, out_dir)
            if manifest.get("state") == "reported" and (folder / "report.md").exists():
                log(f"Video {video_id}: already done -> {folder.name}")
                continue
            finish_video(args, video_id, folder, manifest, api_key, base_url, index_path)
            metadata = read_metadata(folder)
            write_index_entry(
                index_path, video_id, metadata.get("title", ""), metadata.get("channel", ""),
                metadata.get("duration") or 0, metadata.get("upload_date", ""),
                folder.name, "reported",
            )
            log(f"Video {video_id}: done -> {folder.name}")
        except PipelineError as exc:
            fail_url(video_id, url, str(exc))
        except subprocess.TimeoutExpired as exc:
            fail_url(video_id, url, f"timeout: {exc}")
    return exit_code


if __name__ == "__main__":
    try:
        sys.exit(main())
    except PipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
