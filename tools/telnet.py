"""Send kOS commands to a CPU via telnet and stream output.

Connects to the kOS telnet server, selects a CPU, waits for
scrollback to finish, then sends commands one by one. Output
is streamed to stdout; command echo goes to stderr.

Uses raw sockets (no external dependencies). Designed for
iterative testing of kOS scripts without manual FIFO/socat
scripting.
"""

import argparse
import re
import socket
import sys
import time
from typing import TextIO, Tuple

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 5410
DEFAULT_CPU = 1
DEFAULT_DELAY = 2.0
DEFAULT_SCRIPT_TIMEOUT = 600.0
DEFAULT_SCROLLBACK_WAIT = 30.0
RECV_TIMEOUT = 0.1
CRLF = b"\r\n"

SCRIPT_RE = re.compile(
    r"^\s*(?:run\s+\w+|runPath\s*\(|runOncePath\s*\()",
    re.IGNORECASE,
)
SCRIPT_SENTINELS = ("Program ended.", "Program aborted.")
ERROR_RE = re.compile(r"At .+, line \d+")

# kOS terminal control characters (Unicode Private Use Area)
KOS_CLEAR = "\ue014"  # line/screen clear marker
KOS_RESET = "\ue002"  # terminal reset/home marker
KOS_POS_RE = re.compile(r"\ue006..", re.DOTALL)  # cursor position + 2 bytes

# Telnet IAC constants
IAC = 0xFF
WILL = 0xFB
WONT = 0xFC
DO = 0xFD
DONT = 0xFE
SB = 0xFA
SE = 0xF0


def strip_iac(data: bytes) -> bytes:
    """Strip telnet IAC negotiation sequences from raw bytes.

    Handles 3-byte sequences (WILL/WONT/DO/DONT), subnegotiation
    (SB...SE), 2-byte commands, and collapses IAC IAC to one 0xFF.
    """
    out = bytearray()
    i = 0
    n = len(data)
    while i < n:
        b = data[i]
        if b != IAC:
            out.append(b)
            i += 1
            continue
        # IAC at end of buffer — keep it (might be split)
        if i + 1 >= n:
            break
        cmd = data[i + 1]
        if cmd == IAC:
            out.append(IAC)
            i += 2
        elif cmd in (WILL, WONT, DO, DONT):
            i += 3  # skip IAC + cmd + option
        elif cmd == SB:
            # Skip until IAC SE
            j = i + 2
            while j < n - 1:
                if data[j] == IAC and data[j + 1] == SE:
                    j += 2
                    break
                j += 1
            else:
                j = n
            i = j
        else:
            i += 2  # other 2-byte IAC commands (GA, NOP, etc.)
    return bytes(out)


def clean_output(data: bytes) -> str:
    """Convert raw kOS telnet bytes to readable text.

    Strips telnet IAC sequences and kOS terminal control codes
    (U+E014 clear markers, U+E006 cursor positions), converts
    position markers to newlines, and removes stray control chars.
    """
    text = strip_iac(data).decode("utf-8", errors="replace")
    text = text.replace(KOS_CLEAR, "")
    text = text.replace(KOS_RESET, "")
    text = KOS_POS_RE.sub("\n", text)
    text = text.replace("\x00", "")
    text = text.replace("\r", "")
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def drain(
    sock: socket.socket,
    timeout: float,
    sentinel: Tuple[str, ...] = (),
    silence: float = 0,
) -> Tuple[bytes, bool]:
    """Read from socket until an exit condition is met.

    Exit conditions (whichever fires first):
      1. Any string in ``sentinel`` found in decoded output.
      2. kOS error pattern (``At <loc>, line N``) found without
         a prior sentinel match — drains 2 more seconds then exits.
      3. ``silence`` seconds of no new data (if > 0).
      4. ``timeout`` seconds elapsed total (hard cap).

    Returns (accumulated_bytes, sentinel_found).
    Raises ConnectionError if the remote side closes.
    """
    buf = bytearray()
    found = False
    finish_at = 0.0  # when > 0, we're in "finishing" mode
    start = time.monotonic()
    last_data = start
    sock.settimeout(RECV_TIMEOUT)

    while True:
        now = time.monotonic()
        elapsed = now - start

        if elapsed >= timeout:
            break
        if finish_at and now >= finish_at:
            break

        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            now = time.monotonic()
            if finish_at and now >= finish_at:
                break
            if silence > 0 and (now - last_data) >= silence:
                break
            if not sentinel and (now - last_data) >= timeout:
                break
            continue
        except OSError:
            break

        if not chunk:
            raise ConnectionError("kOS closed the connection.")

        buf.extend(chunk)
        last_data = time.monotonic()

        # Skip pattern matching during finishing drain
        if finish_at:
            continue

        decoded = strip_iac(bytes(buf)).decode("utf-8", errors="replace")

        for s in sentinel:
            if s in decoded:
                found = True
                finish_at = time.monotonic() + 1.0
                break

        if sentinel and not found and ERROR_RE.search(decoded):
            finish_at = time.monotonic() + 2.0

    return bytes(buf), found


def send(sock: socket.socket, text: str) -> None:
    """Send a line to the kOS terminal (appends CR+LF)."""
    sock.sendall(text.encode("utf-8") + CRLF)


def is_script_command(cmd: str) -> bool:
    """Check if a command runs a script file."""
    return bool(SCRIPT_RE.match(cmd))


def parse_commands(source: TextIO) -> list:
    """Read commands from a file or stream.

    Skips blank/whitespace-only lines (empty CR+LF can trigger
    kOS telnet detach). Everything else is sent verbatim — kOS
    handles its own comments.
    """
    commands = []
    for line in source:
        stripped = line.strip()
        if stripped:
            commands.append(stripped)
    return commands


def connect(
    host: str,
    port: int,
    cpu: int,
    scrollback_wait: float,
    dismiss_prompt: bool,
    delay: float,
) -> socket.socket:
    """Connect to kOS telnet, select CPU, and drain scrollback.

    Returns a socket ready for commands.
    """
    try:
        sock = socket.create_connection((host, port), timeout=10)
    except (ConnectionRefusedError, TimeoutError, OSError) as e:
        print(
            "Cannot connect to {}:{}: {}. "
            "Is KSP running with telnet enabled?".format(host, port, e),
            file=sys.stderr,
        )
        sys.exit(1)

    # Wait for CPU menu to fully appear before selecting
    print("Connected. Selecting CPU {}...".format(cpu), file=sys.stderr)
    drain(sock, 10.0, sentinel=("selection number",), silence=2.0)

    # Select CPU; drain response + scrollback in one pass
    send(sock, str(cpu))
    data, _ = drain(sock, scrollback_wait, silence=2.0)
    text = clean_output(data)
    if "Garbled" in text or "No such number" in text:
        print(
            "CPU {} not found. Server response:\n{}".format(
                cpu, clean_output(data)
            ),
            file=sys.stderr,
        )
        sock.close()
        sys.exit(1)

    if dismiss_prompt:
        print("Dismissing boot prompt...", file=sys.stderr)
        send(sock, ".")
        drain(sock, delay)

    print("Ready.", file=sys.stderr)
    return sock


def run_commands(
    sock: socket.socket,
    commands: list,
    delay: float,
    script_timeout: float,
) -> None:
    """Send commands sequentially and stream output."""
    for cmd in commands:
        print(">>> {}".format(cmd), file=sys.stderr)
        send(sock, cmd)

        if is_script_command(cmd):
            data, found = drain(
                sock,
                script_timeout,
                sentinel=SCRIPT_SENTINELS,
                silence=10,
            )
            if not found:
                print(
                    "Warning: script ended without " "'Program ended.'",
                    file=sys.stderr,
                )
        else:
            data, _ = drain(sock, delay)

        text = clean_output(data)
        if text:
            sys.stdout.write(text + "\n")
            sys.stdout.flush()

    # Final drain for any trailing output
    data, _ = drain(sock, 2.0)
    if data:
        text = clean_output(data)
        if text:
            sys.stdout.write(text + "\n")
            sys.stdout.flush()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Send kOS commands to a CPU via telnet.",
    )
    parser.add_argument(
        "file",
        nargs="?",
        help="File with commands to send (one per line)",
    )
    parser.add_argument(
        "-c",
        "--command",
        action="append",
        default=[],
        help="Command to send (repeatable)",
    )
    parser.add_argument(
        "--cpu",
        type=int,
        default=DEFAULT_CPU,
        help="CPU number (default: %(default)s)",
    )
    parser.add_argument(
        "--host",
        default=DEFAULT_HOST,
        help="Telnet host (default: %(default)s)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_PORT,
        help="Telnet port (default: %(default)s)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=DEFAULT_DELAY,
        help=(
            "Silence timeout for non-script commands "
            "(default: %(default)ss)"
        ),
    )
    parser.add_argument(
        "--script-timeout",
        type=float,
        default=DEFAULT_SCRIPT_TIMEOUT,
        help=("Max wait for script commands " "(default: %(default)ss)"),
    )
    parser.add_argument(
        "--scrollback-wait",
        type=float,
        default=DEFAULT_SCROLLBACK_WAIT,
        help=("Seconds to wait for scrollback " "(default: %(default)ss)"),
    )
    parser.add_argument(
        "--dismiss-prompt",
        action="store_true",
        help="Send throwaway command first (post-reboot)",
    )

    args = parser.parse_args()

    # Resolve command source
    if args.command:
        commands = args.command
    elif args.file:
        try:
            with open(args.file, encoding="utf-8") as f:
                commands = parse_commands(f)
        except FileNotFoundError:
            print(
                "File not found: {}".format(args.file),
                file=sys.stderr,
            )
            sys.exit(1)
    elif not sys.stdin.isatty():
        commands = parse_commands(sys.stdin)
    else:
        parser.error(
            "No commands provided. "
            "Use -c, a file argument, or pipe to stdin."
        )

    if not commands:
        print("No commands to send.", file=sys.stderr)
        sys.exit(0)

    sock = connect(
        args.host,
        args.port,
        args.cpu,
        args.scrollback_wait,
        args.dismiss_prompt,
        args.delay,
    )

    try:
        run_commands(sock, commands, args.delay, args.script_timeout)
    except ConnectionError as e:
        print("Connection lost: {}".format(e), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
    finally:
        sock.close()


if __name__ == "__main__":
    main()
