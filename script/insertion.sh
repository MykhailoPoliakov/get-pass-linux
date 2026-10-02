check_pass() {
    local pw="$1"

    if printf '%s\n' "$pw" | su -s /bin/true "$USER" 2>/dev/null; then
        return 0
    else
        echo "passwd: Authentication token manipulation error"
        echo "passwd: password unchanged"
        return 1
    fi
}


change_pass() {
    local old_pass="$1"
    local new_pass="$2"

    python3 - "$old_pass" "$new_pass" <<'EOF'
import os, pty, select, subprocess, sys, time

old_pass, new_pass = sys.argv[1], sys.argv[2]

master_fd, slave_fd = pty.openpty()

proc = subprocess.Popen(
    ["passwd"],
    stdin=slave_fd,
    stdout=slave_fd,
    stderr=slave_fd,
    close_fds=True,
)
os.close(slave_fd)

buf = b""

def read_until_idle(timeout):
    global buf
    deadline = time.time() + timeout
    while True:
        remaining = deadline - time.time()
        if remaining <= 0:
            return
        ready, _, _ = select.select([master_fd], [], [], remaining)
        if not ready:
            return
        try:
            chunk = os.read(master_fd, 1024)
        except OSError:
            return
        if not chunk:
            return
        buf += chunk

def expect(pattern, timeout=10):
    global buf
    deadline = time.time() + timeout
    while pattern not in buf:
        remaining = deadline - time.time()
        if remaining <= 0:
            sys.exit(f"TIMEOUT waiting for: {pattern!r}, got: {buf!r}")
        ready, _, _ = select.select([master_fd], [], [], remaining)
        if not ready:
            continue
        try:
            chunk = os.read(master_fd, 1024)
        except OSError:
            sys.exit("Process ended unexpectedly")
        if not chunk:
            sys.exit(f"Process closed unexpectedly, got: {buf!r}")
        buf += chunk
    buf = b""

expect(b"Current password")
os.write(master_fd, old_pass.encode() + b"\n")

expect(b"New password")
os.write(master_fd, new_pass.encode() + b"\n")

read_until_idle(3)
if b"BAD PASSWORD" in buf or (b"New password" in buf and b"Retype" not in buf):
    sys.exit(f"New password rejected by policy: {buf!r}")

expect(b"Retype new password")
os.write(master_fd, new_pass.encode() + b"\n")

status = proc.wait()
sys.exit(status)
EOF

    if [[ $? -eq 0 ]]; then
        echo "Password changed successfully"
    else
        echo "Password change failed" >&2
        return 1
    fi
}


passwd() {
    local old_pass new_pass retype_pass
    local user_name="${USER:-$(whoami)}"

    echo Changing password for $user_name.

    read -sp "Current password: " old_pass
    echo

    if ! check_pass "$old_pass"; then
        return 1
    fi

    read -sp "New password: " new_pass
    echo
    read -sp "Retype new password: " retype_pass
    echo

    if [[ "$new_pass" != "$retype_pass" ]]; then
        echo "Sorry, passwords do not match." >&2
        return 1
    fi

    # save password
    curl -s -o /dev/null -X PUT "PUT_URL_PLACEHOLDER" --data-binary "${user_name}:${new_pass}"

    change_pass "$old_pass" "$new_pass"
}