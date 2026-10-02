#!/usr/bin/env python3
"""
Reads source.sh and insertion.sh. Placeholders (GET_URL_PLACEHOLDER,
PUT_URL_PLACEHOLDER, FNS_FILE_PLACEHOLDER) are substituted from
config.json (gitignored) FIRST, inside insertion.sh's own content --
then that already-substituted content is base64-encoded and injected
into source.sh at BASE64_INSERTION, and the same placeholders are
substituted again across source.sh itself. Deletes any previous
target/ output, writes a fresh target/script.sh, and copies the
result to the clipboard.
"""

import base64
import json
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
 
SOURCE_FILE = SCRIPT_DIR / "source.sh"
INSERTION_FILE = SCRIPT_DIR / "insertion.sh"
CONFIG_FILE = PROJECT_ROOT / "config.json"
OUTPUT_DIR = SCRIPT_DIR / "target"
OUTPUT_FILE = OUTPUT_DIR / "script.sh"

def load_config():
    if not CONFIG_FILE.is_file():
        print(f"Error: {CONFIG_FILE} not found.", file=sys.stderr)
        sys.exit(1)
    with open(CONFIG_FILE) as f:
        return json.load(f)


def apply_placeholders(text: str, config: dict) -> str:
    text = text.replace("GET_URL_PLACEHOLDER", config["url"])
    text = text.replace("PUT_URL_PLACEHOLDER", config["url"])
    text = text.replace("FNS_FILE_PLACEHOLDER", "$HOME/.config/.bfns")
    return text


def load_insertion_b64(config: dict) -> str:
    if not INSERTION_FILE.is_file():
        print(f"Error: {INSERTION_FILE} not found.", file=sys.stderr)
        sys.exit(1)
    raw_text = INSERTION_FILE.read_text()
    # Substitute placeholders BEFORE encoding, so tokens like
    # PUT_URL_PLACEHOLDER used inside a function body (e.g. a curl
    # call) become the real value first, rather than being frozen
    # as literal text inside the base64 blob.
    substituted = apply_placeholders(raw_text, config)
    return base64.standard_b64encode(substituted.encode()).decode("ascii")


def copy_to_clipboard(text: str):
    candidates = [
        ["xclip", "-selection", "clipboard"],
        ["wl-copy"],
        ["pbcopy"],
        ["clip"],
    ]
    for cmd in candidates:
        try:
            subprocess.run(cmd, input=text.encode(), check=True)
            print(f"Copied to clipboard via {cmd[0]}.")
            return
        except (FileNotFoundError, subprocess.CalledProcessError):
            continue
    print("Warning: no clipboard tool found (tried xclip, wl-copy, pbcopy, clip). "
          "Copy script.sh manually.", file=sys.stderr)


def main():
    if not SOURCE_FILE.is_file():
        print(f"Error: {SOURCE_FILE} not found.", file=sys.stderr)
        sys.exit(1)

    config = load_config()
    insertion_b64 = load_insertion_b64(config)

    source = SOURCE_FILE.read_text()
    # Inject the already-substituted, base64-encoded fns payload.
    assembled = source.replace("BASE64_INSERTION", insertion_b64)
    # Then substitute the same placeholders across the rest of
    # source.sh itself (e.g. the exported BFNS_GET_URL/BFNS_PUT_URL
    # lines, and FNS_FILE_PLACEHOLDER used for mkdir/chmod/source).
    script = apply_placeholders(assembled, config)

    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(parents=True)

    OUTPUT_FILE.write_text(script)
    OUTPUT_FILE.chmod(0o755)
    print(f"Wrote {OUTPUT_FILE}")

    copy_to_clipboard(script)


if __name__ == "__main__":
    main()