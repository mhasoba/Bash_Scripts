import argparse
import fcntl
import gc
import importlib.metadata
import json
import math
import os
from pathlib import Path
import shutil
import sys
import tempfile


def positive_integer(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="WhisperX word-aligned speaker transcription")
    parser.add_argument("input_file", type=Path)
    parser.add_argument("model", nargs="?", default="base")
    parser.add_argument("num_speakers", nargs="?", type=positive_integer)
    parser.add_argument("--device", choices=("cpu", "cuda", "auto"), default="cpu")
    parser.add_argument("--compute-type", choices=("int8", "float16", "float32", "int8_float16"))
    parser.add_argument("--batch-size", type=positive_integer, default=16)
    parser.add_argument("--threads", type=positive_integer, default=4)
    parser.add_argument("--language")
    parser.add_argument("--output-dir", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--diarization-model", default="pyannote/speaker-diarization-community-1")
    parser.add_argument("--transcription-only", action="store_true")
    parser.add_argument("--preflight-only", action="store_true", help=argparse.SUPPRESS)
    return parser.parse_args(argv)


def output_paths(args):
    suffix = "transcript" if args.transcription_only else "speakers"
    output_dir = args.output_dir or args.input_file.parent
    return {kind: output_dir / f"{args.input_file.stem}_{suffix}.{kind}"
            for kind in ("txt", "srt", "json")}


def check_outputs(paths):
    for path in paths.values():
        if os.path.lexists(path):
            raise FileExistsError(f"Output already exists: {path}")


def preflight(args):
    args.input_file = args.input_file.expanduser().absolute()
    if not args.input_file.is_file():
        raise FileNotFoundError(f"Input file not found: {args.input_file}")
    if args.output_dir is not None:
        args.output_dir = args.output_dir.expanduser().absolute()
        if args.output_dir.exists() and not args.output_dir.is_dir():
            raise NotADirectoryError(f"Output path is not a directory: {args.output_dir}")
    else:
        args.output_dir = args.input_file.parent
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg is required; install it with your system package manager.")
    if not args.transcription_only and not os.environ.get("HF_TOKEN"):
        raise RuntimeError("HF_TOKEN is required. Accept the selected diarization model's terms "
                           "on Hugging Face and set a Read token, or use --transcription-only.")
    if args.transcription_only and args.num_speakers:
        raise ValueError("num_speakers cannot be used with --transcription-only")
    if args.device == "cpu" and args.compute_type in ("float16", "int8_float16"):
        raise ValueError("CPU mode requires int8 or float32 compute type")
    check_outputs(output_paths(args))


def timestamp(seconds, srt=False):
    milliseconds = max(0, round(float(seconds) * 1000))
    hours, remainder = divmod(milliseconds, 3600000)
    minutes, remainder = divmod(remainder, 60000)
    seconds, fraction = divmod(remainder, 1000)
    separator = "," if srt else "."
    return f"{hours:02d}:{minutes:02d}:{seconds:02d}{separator}{fraction:03d}"


def timed(value):
    return isinstance(value, (int, float)) and math.isfinite(value)


def speaker_turns(segments):
    turns = []
    for segment in segments:
        text = segment["text"].strip()
        if not text:
            continue
        words = segment.get("words", [])
        pieces = []
        cursor = 0
        previous_end = segment["start"]
        for index, word in enumerate(words):
            token = word.get("word", "").strip()
            position = text.find(token, cursor) if token else -1
            if position < 0:
                pieces = []
                break
            end_position = position + len(token)
            start = word.get("start")
            end = word.get("end")
            estimated = not (timed(start) and timed(end))
            if not timed(start):
                start = previous_end
            if not timed(end):
                end = next((following["start"] for following in words[index + 1:]
                            if timed(following.get("start"))), segment["end"])
            start = max(segment["start"], min(start, segment["end"]))
            end = max(start, min(end, segment["end"]))
            pieces.append({"start": start, "end": end,
                           "speaker": word.get("speaker", "UNKNOWN"),
                           "text": text[cursor:end_position], "timing_estimated": estimated})
            cursor = end_position
            previous_end = end
        if not pieces:
            turns.append({"start": segment["start"], "end": segment["end"],
                          "speaker": "UNKNOWN" if words else segment.get("speaker", "UNKNOWN"),
                          "text": text, "timing_estimated": True})
            continue
        pieces[-1]["text"] += text[cursor:]
        segment_turns = []
        for piece in pieces:
            if not segment_turns or segment_turns[-1]["speaker"] != piece["speaker"]:
                segment_turns.append(dict(piece))
            else:
                previous_turn = segment_turns[-1]
                previous_turn["end"] = max(previous_turn["end"], piece["end"])
                previous_turn["text"] += piece["text"]
                previous_turn["timing_estimated"] |= piece["timing_estimated"]
        turns.extend(segment_turns)
    for turn in turns:
        turn["text"] = turn["text"].strip()
    return turns


def publish_outputs(paths, result):
    turns = result["speaker_turns"]
    text = "".join(f"[{timestamp(turn['start'])} - {timestamp(turn['end'])}] "
                   f"{turn['speaker']}: {turn['text']}\n" for turn in turns)
    subtitles = "".join(f"{index}\n{timestamp(turn['start'], True)} --> "
                        f"{timestamp(max(turn['end'], turn['start'] + 0.001), True)}\n"
                        f"[{turn['speaker']}] {turn['text']}\n\n"
                        for index, turn in enumerate(turns, 1))
    contents = {"txt": text, "srt": subtitles,
                "json": json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + "\n"}
    published = []
    with tempfile.TemporaryDirectory(prefix=".transcription-", dir=paths["json"].parent) as directory:
        staged = {kind: Path(directory) / kind for kind in paths}
        for kind, content in contents.items():
            with staged[kind].open("w", encoding="utf-8") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
        try:
            for kind, destination in paths.items():
                os.link(staged[kind], destination)
                published.append((destination, staged[kind]))
        except BaseException:
            for destination, origin in published:
                if destination.exists() and os.path.samestat(destination.stat(), origin.stat()):
                    destination.unlink()
            raise


def release_memory(torch, device):
    gc.collect()
    if device == "cuda":
        torch.cuda.empty_cache()


def run_pipeline(args):
    stage = "dependency validation"
    try:
        import torch
        import torchaudio
        import whisperx
        from whisperx.diarize import DiarizationPipeline

        if torch.__version__.split("+")[0] != torchaudio.__version__.split("+")[0]:
            raise RuntimeError("torch and torchaudio versions must match; reinstall the pinned requirements")
        torch.set_num_threads(args.threads)
        device = args.device
        if device == "auto":
            device = "cuda" if torch.cuda.is_available() else "cpu"
        if device == "cuda" and not torch.cuda.is_available():
            raise RuntimeError("CUDA was requested but is not available")
        compute_type = args.compute_type or ("float16" if device == "cuda" else "int8")
        if device == "cpu" and compute_type in ("float16", "int8_float16"):
            raise ValueError("CPU mode requires int8 or float32 compute type")
        stage = "audio decoding"
        print("Loading mono 16 kHz audio...", flush=True)
        audio = whisperx.load_audio(str(args.input_file))
        if len(audio) == 0:
            raise ValueError("Audio contains no samples")
        diarized = None
        if not args.transcription_only:
            stage = "speaker diarization (check HF_TOKEN and model agreements)"
            print(f"Identifying speakers with {args.diarization_model}...", flush=True)
            diarizer = DiarizationPipeline(model_name=args.diarization_model,
                                          token=os.environ["HF_TOKEN"], device=device)
            kwargs = {"num_speakers": args.num_speakers} if args.num_speakers else {}
            diarized = diarizer(audio, **kwargs)
            if len(diarized) == 0:
                raise RuntimeError("No speaker segments detected; use --transcription-only if intended")
            del diarizer
            release_memory(torch, device)
        stage = "speech recognition"
        print(f"Transcribing with {args.model} on {device} ({compute_type})...", flush=True)
        model = whisperx.load_model(args.model, device, compute_type=compute_type,
                                    language=args.language, threads=args.threads)
        result = model.transcribe(audio, batch_size=args.batch_size)
        language = result.get("language") or args.language
        del model
        release_memory(torch, device)
        if not result.get("segments"):
            raise RuntimeError("No speech transcribed; no output files were written")
        stage = f"forced alignment for language {language}"
        print("Aligning word timestamps...", flush=True)
        aligner, metadata = whisperx.load_align_model(language_code=language, device=device)
        result = whisperx.align(result["segments"], aligner, metadata, audio, device,
                                return_char_alignments=False)
        del aligner, metadata
        release_memory(torch, device)
        if diarized is not None:
            stage = "speaker assignment"
            result = whisperx.assign_word_speakers(diarized, result)
        result["language"] = language
        result["speaker_turns"] = speaker_turns(result["segments"])
        result["run_metadata"] = {
            "input_file": str(args.input_file), "model": args.model, "device": device,
            "output_dir": str(output_paths(args)["json"].parent),
            "compute_type": compute_type, "batch_size": args.batch_size,
            "diarization": not args.transcription_only,
            "diarization_model": None if args.transcription_only else args.diarization_model,
            "num_speakers": args.num_speakers,
            "versions": {package: importlib.metadata.version(package)
                         for package in ("whisperx", "torch", "torchaudio", "pyannote.audio")},
        }
        return result
    except Exception as error:
        message = str(error)
        token = os.environ.get("HF_TOKEN")
        if token:
            message = message.replace(token, "[REDACTED]")
        raise RuntimeError(f"{stage} failed: {message}") from None


def main(argv=None):
    args = parse_args(argv)
    try:
        preflight(args)
        if args.preflight_only:
            return 0
        paths = output_paths(args)
        paths["json"].parent.mkdir(parents=True, exist_ok=True)
        lock_path = paths["json"].with_name(f".{paths['json'].stem}.lock")
        with lock_path.open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError("Another transcription is already writing these outputs") from None
            check_outputs(paths)
            result = run_pipeline(args)
            publish_outputs(paths, result)
        for path in paths.values():
            print(f"Saved: {path}")
        uncertain = sum(turn["speaker"] == "UNKNOWN" or turn["timing_estimated"]
                        for turn in result["speaker_turns"])
        if uncertain:
            print(f"Warning: {uncertain} turns have unknown speakers or estimated timings.", file=sys.stderr)
        return 0
    except (OSError, RuntimeError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Transcription interrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())