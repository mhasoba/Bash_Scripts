# WhisperX Transcription

This subproject contains two local transcription paths: OpenAI Whisper for straightforward transcripts in several output formats, and WhisperX for word alignment and speaker diarization. The WhisperX batch runner processes files sequentially.

## Choose a Transcriber

- **OpenAI Whisper** (`transcribe-audio.sh`): use for a single file and a plain TXT, SRT, VTT, JSON, or TSV transcript. It does not require a Hugging Face token. Install `openai-whisper` and `ffmpeg` separately.
- **WhisperX** (`transcribe-speakers-venv.sh`): use when you want word-level timestamps, speaker labels, or batch processing. Its `--transcription-only` mode skips diarization and does not require a Hugging Face token, but still runs alignment.

Example plain Whisper transcription from the repository root:

```bash
./transcription/transcribe-audio.sh recording.mp3 vtt medium
```

The output is written beside the input. Existing output files are not overwritten.

## Prerequisites

- Python 3 and `python3-venv`
- `ffmpeg`
- A Hugging Face Read token with access to [`pyannote/speaker-diarization-community-1`](https://huggingface.co/pyannote/speaker-diarization-community-1)
- Accept the model's user agreement in the same Hugging Face account that owns the token

The scripts read `HF_TOKEN` from the repository-root `.env` when it is not already exported. Add `HF_TOKEN=your_token` to that file and restrict its permissions with `chmod 600 .env`. Do not commit or share the token.

## Run One File

From the repository root:

```bash
./transcription/transcribe-speakers-venv.sh recording.m4a
./transcription/transcribe-speakers-venv.sh recording.m4a medium 2 --device cuda --batch-size 8
./transcription/transcribe-speakers-venv.sh recording.m4a --transcription-only
```

The first run creates `~/whisperx-env` and installs the package versions pinned in `whisperx-requirements.txt`. Existing environments are not upgraded automatically. Set `WHISPERX_VENV` to use a different virtualenv. The scripts require no activation; to activate it manually, use `source ~/whisperx-env/bin/activate`.

Options include `--device cpu|cuda|auto`, `--compute-type`, `--batch-size`, `--threads`, `--language`, and `--diarization-model`. Defaults are CPU, `int8`, batch size 16, and 4 CPU threads. CUDA defaults to `float16`. The direct wrapper `transcribe-with-speakers.sh` expects WhisperX to already be available to `WHISPERX_PYTHON`.

For a single file, outputs are written beside the input by default. `--transcription-only` skips diarization and writes `_transcript` outputs. Existing outputs are never overwritten.

## Batch a Directory

The batch wrapper searches recursively, processes one recording at a time, and continues after individual failures. It writes results to a `transcripts/` subdirectory beside each input. First preview the selected inputs and destination paths:

```bash
./transcription/transcribe-batch.sh ~/Desktop/NOMIS_Workshop_2026/recordings --dry-run
```

Then run the batch:

```bash
./transcription/transcribe-batch.sh ~/Desktop/NOMIS_Workshop_2026/recordings medium --device cuda --batch-size 8
```

For example, `recordings/subfolder/meeting.mp3` produces outputs in `recordings/subfolder/transcripts/`. Supported extensions include MP3, M4A, WAV, FLAC, OGG, OPUS, AAC, WMA, AIFF, MP4, M4V, MOV, MKV, WEBM, AVI, MPEG, and MPG. A complete existing output set is skipped; a partial set is reported as a failure and must be moved aside before retrying.

## Output Notes

WhisperX decodes input to mono 16 kHz audio, aligns transcribed words, then assigns speaker labels. Speaker IDs are anonymous labels, not names. Words without a diarization match are marked `UNKNOWN`; overlapping speech and attribution still warrant review. JSON retains aligned segments, word labels, speaker turns, language, run settings, and package versions.

## Planned Enhancements

- **AI-assisted speaker naming:** optionally suggest names for diarized IDs using a user-provided participant roster or context. Require the user to review and confirm or edit each mapping; keep unconfirmed speakers anonymous and preserve the original `SPEAKER_XX` IDs in JSON. Apply confirmed names to TXT/SRT exports. Any cloud-based analysis must be opt-in and clearly disclose audio sharing; do not claim identity from voice alone.

## Tests

From the repository root:

```bash
python3 -m unittest discover -s transcription -p 'test_*.py' -v
```
