#!/bin/bash

# Run the speaker transcription script with WhisperX in a virtual environment.
VENV_DIR="${WHISPERX_VENV:-$HOME/whisperx-env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
    WHISPERX_PYTHON=python3 exec "$SCRIPT_DIR/transcribe-with-speakers.sh" --help
fi
for argument in "$@"; do
    if [[ "$argument" == "--help" || "$argument" == "-h" ]]; then
        WHISPERX_PYTHON=python3 exec "$SCRIPT_DIR/transcribe-with-speakers.sh" "$@"
    fi
done
WHISPERX_PYTHON=python3 "$SCRIPT_DIR/transcribe-with-speakers.sh" "$@" --preflight-only || exit $?

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    echo "Setting up WhisperX in $VENV_DIR..."
    python3 -m venv "$VENV_DIR" || exit 1
fi
if ! "$VENV_DIR/bin/python" -c 'from importlib.metadata import version; version("whisperx")' 2>/dev/null; then
    "$VENV_DIR/bin/python" -m pip install -r "$SCRIPT_DIR/whisperx-requirements.txt" || exit 1
fi

WHISPERX_PYTHON="$VENV_DIR/bin/python" exec "$SCRIPT_DIR/transcribe-with-speakers.sh" "$@"