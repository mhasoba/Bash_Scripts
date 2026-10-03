import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import shutil
import types
import unittest
from unittest.mock import Mock, patch


SPEC = importlib.util.spec_from_file_location("transcription", Path(__file__).with_name("transcribe-speakers.py"))
transcription = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transcription)


class TranscriptionTests(unittest.TestCase):
    def test_speaker_changes_preserve_punctuation(self):
        turns = transcription.speaker_turns([{
            "start": 0.0, "end": 2.0, "text": "Hello! Goodbye.", "speaker": "SPEAKER_00",
            "words": [{"start": 0.0, "end": 1.0, "word": "Hello!", "speaker": "SPEAKER_00"},
                      {"start": 1.0, "end": 2.0, "word": "Goodbye.", "speaker": "SPEAKER_01"}]}])
        self.assertEqual([turn["speaker"] for turn in turns], ["SPEAKER_00", "SPEAKER_01"])
        self.assertEqual([turn["text"] for turn in turns], ["Hello!", "Goodbye."])
        with tempfile.TemporaryDirectory() as directory:
            args = transcription.parse_args([str(Path(directory) / "recording.m4a")])
            paths = transcription.output_paths(args)
            transcription.publish_outputs(paths, {"speaker_turns": turns})
            for kind in ("txt", "srt"):
                self.assertIn("SPEAKER_01", paths[kind].read_text())

    def test_untimed_and_unlabelled_words_are_preserved(self):
        turns = transcription.speaker_turns([{
            "start": 0, "end": 3, "text": "Pay $13.60 now.",
            "words": [{"word": "Pay", "start": 0, "end": 1, "speaker": "SPEAKER_00"},
                      {"word": "$13.60"},
                      {"word": "now.", "start": 2, "end": 3, "speaker": "SPEAKER_00"}]}])
        self.assertEqual(" ".join(turn["text"] for turn in turns), "Pay $13.60 now.")
        self.assertEqual(turns[1]["speaker"], "UNKNOWN")
        self.assertEqual((turns[1]["start"], turns[1]["end"]), (1, 2))
        self.assertTrue(turns[1]["timing_estimated"])

    def test_unmatched_words_preserve_original_text_without_false_attribution(self):
        turns = transcription.speaker_turns([{"start": 0, "end": 1, "text": "Original!",
                                              "speaker": "SPEAKER_00", "words": [{"word": "different"}]}])
        self.assertEqual(turns[0]["text"], "Original!")
        self.assertEqual(turns[0]["speaker"], "UNKNOWN")

    def test_subtitle_rounding_carries_seconds(self):
        self.assertEqual(transcription.timestamp(59.9996, True), "00:01:00,000")

    def test_publication_failure_rolls_back_only_own_files(self):
        with tempfile.TemporaryDirectory() as directory:
            args = transcription.parse_args([str(Path(directory) / "recording.m4a")])
            paths = transcription.output_paths(args)
            paths["srt"].write_text("existing")
            with self.assertRaises(FileExistsError):
                transcription.publish_outputs(paths, {"speaker_turns": []})
            self.assertFalse(paths["txt"].exists())
            self.assertFalse(paths["json"].exists())
            self.assertEqual(paths["srt"].read_text(), "existing")
            self.assertEqual(list(Path(directory).glob(".transcription-*")), [])

    def test_staging_failure_leaves_no_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            args = transcription.parse_args([str(Path(directory) / "recording.m4a")])
            paths = transcription.output_paths(args)
            with patch.object(os, "fsync", side_effect=OSError("disk full")):
                with self.assertRaises(OSError):
                    transcription.publish_outputs(paths, {"speaker_turns": []})
            self.assertFalse(any(path.exists() for path in paths.values()))

    def test_missing_token_and_ffmpeg_fail_preflight(self):
        with tempfile.TemporaryDirectory() as directory:
            audio = Path(directory) / "audio.m4a"
            audio.touch()
            args = transcription.parse_args([str(audio)])
            with patch.dict(os.environ, {}, clear=True), patch.object(transcription.shutil, "which", return_value="ffmpeg"):
                with self.assertRaisesRegex(RuntimeError, "HF_TOKEN"):
                    transcription.preflight(args)
            with patch.object(transcription.shutil, "which", return_value=None):
                with self.assertRaisesRegex(RuntimeError, "ffmpeg"):
                    transcription.preflight(args)

    def test_transcription_only_has_distinct_outputs(self):
        args = transcription.parse_args(["audio.m4a", "--transcription-only"])
        self.assertEqual(transcription.output_paths(args)["txt"].name, "audio_transcript.txt")

    def test_output_dir_overrides_single_file_output_location(self):
        args = transcription.parse_args(["audio.m4a", "--output-dir", "transcripts"])
        paths = transcription.output_paths(args)
        self.assertEqual(paths["txt"], Path("transcripts/audio_speakers.txt"))

    def test_locked_output_is_rejected_before_inference(self):
        with tempfile.TemporaryDirectory() as directory:
            audio = Path(directory) / "audio.m4a"
            audio.touch()
            lock_path = Path(directory) / ".audio_transcript.lock"
            with lock_path.open("a") as lock, patch.object(transcription.shutil, "which", return_value="ffmpeg"):
                transcription.fcntl.flock(lock, transcription.fcntl.LOCK_EX | transcription.fcntl.LOCK_NB)
                with patch.object(transcription, "run_pipeline") as pipeline:
                    self.assertEqual(transcription.main([str(audio), "--transcription-only"]), 1)
                    pipeline.assert_not_called()

    def test_pipeline_orders_stages_and_records_settings(self):
        events = []
        segment = {"start": 0, "end": 1, "text": "Hello.",
                   "words": [{"start": 0, "end": 1, "word": "Hello.", "speaker": "SPEAKER_00"}]}
        torch = types.ModuleType("torch")
        torch.__version__ = "2.8.0"
        torch.set_num_threads = Mock()
        torch.cuda = types.SimpleNamespace(is_available=lambda: False)
        torchaudio = types.ModuleType("torchaudio")
        torchaudio.__version__ = "2.8.0"
        whisperx = types.ModuleType("whisperx")
        whisperx.load_audio = Mock(return_value=[0.1])
        model = types.SimpleNamespace(transcribe=lambda *args, **kwargs:
                                     events.append("transcribe") or {"language": "en", "segments": [segment]})
        load_model = Mock(return_value=model)
        whisperx.load_model = load_model
        whisperx.load_align_model = Mock(return_value=(object(), {}))
        whisperx.align = lambda *args, **kwargs: events.append("align") or {"segments": [segment]}
        whisperx.assign_word_speakers = lambda _, result: events.append("assign") or result
        diarize = types.ModuleType("whisperx.diarize")
        diarization_pipeline = Mock(return_value=lambda *args, **kwargs:
                       events.append("diarize") or ["speaker"])
        diarize.DiarizationPipeline = diarization_pipeline
        modules = {"torch": torch, "torchaudio": torchaudio, "whisperx": whisperx,
                   "whisperx.diarize": diarize}
        args = transcription.parse_args(["audio.m4a", "medium", "2", "--batch-size", "4"])
        with patch.dict(sys.modules, modules), patch.dict(os.environ, {"HF_TOKEN": "synthetic-secret"}), \
                patch.object(transcription.importlib.metadata, "version", return_value="test-version"), \
                patch.object(transcription, "release_memory") as release:
            result = transcription.run_pipeline(args)
            self.assertEqual(events, ["diarize", "transcribe", "align", "assign"])
            self.assertEqual(release.call_count, 3)
            self.assertEqual(result["language"], "en")
            self.assertEqual(result["run_metadata"]["batch_size"], 4)
            self.assertEqual(result["speaker_turns"][0]["speaker"], "SPEAKER_00")
            diarization_pipeline.side_effect = RuntimeError("Access denied: synthetic-secret")
            load_model.reset_mock()
            with self.assertRaisesRegex(RuntimeError, r"speaker diarization.*\[REDACTED\]") as raised:
                transcription.run_pipeline(args)
            self.assertNotIn("synthetic-secret", str(raised.exception))
            load_model.assert_not_called()

    def test_wrapper_rejects_bad_input_without_creating_venv(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = dict(os.environ, WHISPERX_VENV=str(Path(directory) / "venv"))
            wrapper = Path(__file__).with_name("transcribe-speakers-venv.sh")
            process = subprocess.run(["bash", str(wrapper), str(Path(directory) / "missing.m4a")],
                                     env=environment, capture_output=True, text=True, check=False)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("Input file not found", process.stderr)
            self.assertFalse((Path(directory) / "venv").exists())

    def test_batch_dry_run_handles_spaces_recursion_and_resume(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "recordings"
            nested = root / "sub folder"
            nested.mkdir(parents=True)
            pending = nested / "Session 2.MP3"
            pending.touch()
            duplicate_stem = root / "Session 2.wav"
            duplicate_stem.touch()
            ignored = root / "notes.txt"
            ignored.touch()
            completed = root / "already done.wav"
            completed.touch()
            completed_output = root / "transcripts"
            completed_output.mkdir()
            for extension in ("txt", "srt", "json"):
                (completed_output / f"already done_speakers.{extension}").touch()
            partial = root / "partial.m4a"
            partial.touch()
            (completed_output / "partial_speakers.txt").touch()
            wrapper = Path(__file__).with_name("transcribe-batch.sh")
            process = subprocess.run(["bash", str(wrapper), str(root), "medium", "--dry-run", "--device", "cuda"],
                                     capture_output=True, text=True, check=False)
            self.assertNotEqual(process.returncode, 0)
            nested_output = nested / "transcripts"
            self.assertIn(f"Would transcribe: {pending} -> {nested_output}", process.stdout)
            self.assertIn(f"Would transcribe: {duplicate_stem} -> {completed_output}", process.stdout)
            self.assertIn(f"Skip (outputs already complete): {completed} -> {completed_output}", process.stdout)
            self.assertIn(f"Would fail (partial output set exists): {partial} -> {completed_output}", process.stdout)
            self.assertNotIn(str(ignored), process.stdout)
            self.assertIn("discovered=4 planned=2 skipped=1 partial=1", process.stdout)
            self.assertFalse(nested_output.exists())

    def test_batch_transcription_only_uses_transcript_suffix(self):
        with tempfile.TemporaryDirectory() as directory:
            audio = Path(directory) / "audio.m4a"
            audio.touch()
            output_dir = Path(directory) / "transcripts"
            output_dir.mkdir()
            transcript = output_dir / "audio_transcript.txt"
            transcript.touch()
            wrapper = Path(__file__).with_name("transcribe-batch.sh")
            process = subprocess.run(["bash", str(wrapper), directory, "--dry-run", "--transcription-only"],
                                     capture_output=True, text=True, check=False)
            self.assertNotEqual(process.returncode, 0)
            self.assertIn("partial output set exists", process.stdout)
            self.assertIn("partial=1", process.stdout)
            self.assertIn(str(output_dir), process.stdout)

    def test_batch_writes_nested_outputs_under_transcripts_and_skips_on_rerun(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary_root = Path(directory)
            input_root = temporary_root / "recordings"
            (input_root / "room one").mkdir(parents=True)
            (input_root / "room two").mkdir()
            first_audio = input_root / "room one" / "meeting.mp3"
            second_audio = input_root / "room two" / "meeting.wav"
            first_audio.touch()
            second_audio.touch()

            utility_dir = temporary_root / "utilities"
            utility_dir.mkdir()
            wrapper = utility_dir / "transcribe-batch.sh"
            shutil.copy2(Path(__file__).with_name("transcribe-batch.sh"), wrapper)
            runner = utility_dir / "transcribe-speakers-venv.sh"
            runner.write_text("""#!/bin/bash
input_file="$1"
shift
output_dir=""
suffix="speakers"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --preflight-only) exit 0 ;;
        --output-dir) output_dir="$2"; shift 2 ;;
        --transcription-only) suffix="transcript"; shift ;;
        *) shift ;;
    esac
done
mkdir -p -- "$output_dir"
name="$(basename -- "$input_file")"
name="${name%.*}"
for extension in txt srt json; do
    printf 'mock output\\n' > "$output_dir/${name}_${suffix}.${extension}"
done
""")
            runner.chmod(0o755)

            first_run = subprocess.run(["bash", str(wrapper), str(input_root), "medium"],
                                       capture_output=True, text=True, check=False)
            self.assertEqual(first_run.returncode, 0, first_run.stderr)
            first_output = input_root / "room one" / "transcripts" / "meeting_speakers.txt"
            second_output = input_root / "room two" / "transcripts" / "meeting_speakers.txt"
            self.assertTrue(first_output.is_file())
            self.assertTrue(second_output.is_file())
            self.assertIn("completed=2 skipped=0 failed=0", first_run.stdout)

            second_run = subprocess.run(["bash", str(wrapper), str(input_root), "medium"],
                                        capture_output=True, text=True, check=False)
            self.assertEqual(second_run.returncode, 0, second_run.stderr)
            self.assertIn("completed=0 skipped=2 failed=0", second_run.stdout)

if __name__ == "__main__":
    unittest.main()