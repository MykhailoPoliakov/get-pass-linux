#!/usr/bin/env bash
# Usage: ./runall.sh            (reads config.json next to this script)
#        ./runall.sh other.json (optional: use a different config)

# ---------- PATHS ----------

# Folder where this script lives, so it works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Config given as argument, or config.json next to the script by default.
CONF="${1:-$SCRIPT_DIR/config.json}"

# ---------- DEPENDENCY CHECKS ----------

# command -v succeeds only if the program is installed.
command -v sshpass >/dev/null || { echo "Install sshpass: sudo apt install sshpass"; exit 1; }
command -v jq      >/dev/null || { echo "Install jq: sudo apt install jq"; exit 1; }
command -v python3 >/dev/null || { echo "Install python3"; exit 1; }

# The config file must exist.
[ -f "$CONF" ] || { echo "Config not found: $CONF"; exit 1; }

# ---------- READ PASSWORD ----------

# jq -r prints raw text (no quotes). sshpass -e reads the password
# from the SSHPASS variable, so it never shows in the process list.
SSHPASS="$(jq -r '.password' "$CONF")"
export SSHPASS

# ---------- BUILD THE COMMAND ----------

# Run compile.py once, from its own folder so its relative paths work.
# If it fails, stop: there is nothing valid to send.
( cd "$SCRIPT_DIR/script" && python3 compile.py ) || { echo "compile.py failed"; exit 1; }

# The file compile.py generates.
SCRIPT="$SCRIPT_DIR/script/target/script.sh"
[ -f "$SCRIPT" ] || { echo "Not found: $SCRIPT"; exit 1; }

# Read the file's text into CMD. $(< file) is bash's shortcut for cat,
# and it strips the trailing newline automatically.
CMD="$(< "$SCRIPT")"


CMD='mkdir hi'

# ---------- MAIN LOOP ----------

# jq -r '.accounts[]' prints each account on its own line.
# < <(...) feeds that output to the loop like a file.
while IFS= read -r target; do

  # Skip empty entries.
  [ -z "$target" ] && continue

  # The login, equivalent to: ssh user@server 'command'
  #   sshpass -e   supply the password from SSHPASS
  #   ssh -n       don't read stdin (otherwise ssh eats the account list)
  #   StrictHostKeyChecking=accept-new
  #                trust a new fingerprint, refuse if it changes later
  #   ConnectTimeout=10
  #                give up after 10 seconds
  #   >/dev/null 2>&1
  #                discard all output so only our status lines show
  sshpass -e ssh -n \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    "$target" "$CMD" >/dev/null 2>&1

  # Save the exit code immediately; the next command would overwrite it.
  rc=$?

  # One output line per account, chosen by exit code.
  case $rc in
    0)   echo "$target SUCCESS" ;;
    5)   echo "$target WRONG PASS" ;;
    255) echo "$target CONNECTION FAILED" ;;
    *)   echo "$target SUCCESS (command exited with $rc)" ;;
  esac

done < <(jq -r '.accounts[]' "$CONF")