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
The OpenAI Whisper wrapper defaults to `large-v3` and full-precision inference. The CLI selects CUDA automatically when its own Python environment can use it; otherwise it uses the CPU. Pass a model name as the third argument to choose a smaller model.

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
./transcription/transcribe-speakers-venv.sh recording.m4a --num-speakers 2 --chunk-size 15
./transcription/transcribe-speakers-venv.sh recording.m4a --transcription-only
```

The first run creates `~/whisperx-env` and installs the package versions pinned in `whisperx-requirements.txt`. Existing environments are not upgraded automatically. Set `WHISPERX_VENV` to use a different virtualenv. The scripts require no activation; to activate it manually, use `source ~/whisperx-env/bin/activate`.

TorchCodec 0.7 requires FFmpeg 4-7 shared libraries. If the system has a newer FFmpeg, the wrapper also checks for optional FFmpeg 7 libraries in `~/whisperx-env/ffmpeg7/av.libs` (or the equivalent under `WHISPERX_VENV`). These libraries are not installed automatically. A TorchCodec warning about missing libraries does not by itself stop this pipeline: WhisperX decodes the audio first and passes the waveform to diarization.

The default model is `large-v3`, with automatic CUDA selection when available, `float32` inference, batch size 4, and 4 CPU threads. The model is downloaded on first use and requires substantial disk space and memory; CPU runs may be slow. Options include `--device cpu|cuda|auto`, `--compute-type`, `--batch-size`, `--threads`, `--language`, and `--diarization-model`. For a faster CUDA run, for example, use `medium --device cuda --compute-type float16 --batch-size 8`. The direct wrapper `transcribe-with-speakers.sh` expects WhisperX to already be available to `WHISPERX_PYTHON`.

`--chunk-size` sets the maximum transcription chunk length from 1 to 30 seconds; the default is 30. Shorter chunks can recover words in some recordings but can also lose context or introduce errors, so compare a representative passage with the audio. The chosen value is recorded in JSON. Use `--num-speakers` only when the exact number is known; forcing the wrong count can misattribute speech. The positional speaker-count argument remains supported.

The voice-activity detector defaults to sensitive thresholds, `--vad-onset 0.005 --vad-offset 0.002`, to reduce missed quiet speech. These values may also classify noise or silence as speech, causing hallucinated text; compare the result with the recording. The offset must not exceed the onset, and both must be greater than 0 and less than 1. The previous, less sensitive defaults can be restored with `--vad-onset 0.5 --vad-offset 0.363`. The selected thresholds are recorded in the JSON output.

Diarization, transcription and alignment show separate progress bars when callbacks are available. Model loading and decoding show elapsed-time updates instead. When output is redirected, progress is written as periodic lines to standard error. These are stage-specific updates, not an estimate of total time remaining.

For a single file, outputs are written beside the input by default. `--transcription-only` skips diarization and writes `_transcript` outputs. Existing outputs are never overwritten.

## Batch a Directory

The batch wrapper searches recursively, processes one recording at a time, displays each file's position among the discovered recordings, and continues after individual failures. It writes results to a `transcripts/` subdirectory beside each input. First preview the selected inputs and destination paths:

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
