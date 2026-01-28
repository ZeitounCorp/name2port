#!/usr/bin/env python3
"""
name_to_free_port.py

Map a name (string) to a deterministic TCP port. If the derived port is in use,
explain that it's already in use, show what is listening on it, then re-derive
(with an incrementing salt) until a free port is found.

Extras:
- Uses psutil (if installed) for best PID/process reporting; otherwise falls back to OS tools.
- Optionally asks to copy the resulting port to clipboard (prompt can be bypassed).

CLI behavior:
- stdout: ONLY prints the final port number (safe for piping)
- stderr: prints diagnostics, prompts, and info messages

Usage:
  name2port bento-pdf
  name2port bento-pdf --copy
  name2port bento-pdf --no-copy
"""

from __future__ import annotations

import argparse
import hashlib
import platform
import socket
import subprocess
import sys
from dataclasses import dataclass
from typing import Optional, Tuple

# ---------------------------
# Color helpers
# ---------------------------
GREEN = "\033[92m"
ORANGE = "\033[38;5;208m"
RESET = "\033[0m"


def _run_cmd(cmd: list[str]) -> Tuple[int, str]:
    try:
        p = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        return p.returncode, (p.stdout or "").strip()
    except FileNotFoundError:
        return 127, f"(command not found: {cmd[0]})"
    except Exception as e:
        return 1, f"(failed to run {cmd!r}: {e})"


def _fallback_tools_for_os() -> str:
    system = platform.system().lower()
    if system in ("darwin", "linux"):
        return "lsof / ss"
    if system == "windows":
        return "netstat"
    return "OS networking tools"


def print_psutil_warning() -> None:
    fallback = _fallback_tools_for_os()
    msg = f"""{ORANGE}
⚠ psutil is NOT installed.
Falling back to: {fallback}

For best results, install psutil (better process + PID detection).

Install (pip):
  python -m pip install psutil
  Docs: https://pypi.org/project/psutil/

Ubuntu / Debian:
  sudo apt update && sudo apt install python3-psutil

Fedora:
  sudo dnf install python3-psutil

Arch Linux:
  sudo pacman -S python-psutil

macOS:
  python3 -m pip install psutil

Windows:
  py -m pip install psutil

{RESET}"""
    print(msg, file=sys.stderr)


# ---------------------------
# psutil availability check
# ---------------------------
try:
    import psutil  # type: ignore

    PSUTIL_AVAILABLE = True
    print(f"{GREEN}✔ psutil detected — enhanced port inspection enabled.{RESET}\n", file=sys.stderr)
except Exception:
    PSUTIL_AVAILABLE = False
    print_psutil_warning()


# ---------------------------
# Clipboard support
# ---------------------------

@dataclass(frozen=True)
class ClipboardResult:
    ok: bool
    method: str
    details: str = ""


def copy_to_clipboard(text: str) -> ClipboardResult:
    """
    Best-effort clipboard copy without extra dependencies.
    Tries OS-native commands.

    macOS: pbcopy
    Windows: clip (via cmd)
    Linux: wl-copy / xclip / xsel
    """
    system = platform.system().lower()
    data = (text + "\n").encode("utf-8")

    if system == "darwin":
        try:
            p = subprocess.run(["pbcopy"], input=data, check=False)
            return ClipboardResult(ok=(p.returncode == 0), method="pbcopy")
        except FileNotFoundError:
            return ClipboardResult(ok=False, method="pbcopy", details="pbcopy not found")

    if system == "windows":
        try:
            p = subprocess.run(["cmd.exe", "/c", "clip"], input=data, check=False)
            return ClipboardResult(ok=(p.returncode == 0), method="clip")
        except FileNotFoundError:
            return ClipboardResult(ok=False, method="clip", details="clip not found")

    # Linux / others
    # Wayland
    try:
        p = subprocess.run(["wl-copy"], input=data, check=False)
        if p.returncode == 0:
            return ClipboardResult(ok=True, method="wl-copy")
    except FileNotFoundError:
        pass

    # X11 (xclip)
    try:
        p = subprocess.run(["xclip", "-selection", "clipboard"], input=data, check=False)
        if p.returncode == 0:
            return ClipboardResult(ok=True, method="xclip")
    except FileNotFoundError:
        pass

    # X11 (xsel)
    try:
        p = subprocess.run(["xsel", "--clipboard", "--input"], input=data, check=False)
        if p.returncode == 0:
            return ClipboardResult(ok=True, method="xsel")
    except FileNotFoundError:
        pass

    return ClipboardResult(
        ok=False,
        method="none",
        details="No clipboard tool found (install wl-clipboard, xclip, or xsel on Linux).",
    )


def should_prompt_copy() -> bool:
    # Prompt only if interactive terminal
    return sys.stdin.isatty() and sys.stderr.isatty()


def prompt_yes_no(question: str, default: bool = False) -> bool:
    """
    Prompt on stderr (so stdout remains clean for piping).
    """
    suffix = " [Y/n] " if default else " [y/N] "
    while True:
        print(question + suffix, file=sys.stderr, end="")
        try:
            ans = input().strip().lower()
        except EOFError:
            return default

        if ans == "" and default is not None:
            return default
        if ans in ("y", "yes"):
            return True
        if ans in ("n", "no"):
            return False
        print("Please answer y or n.", file=sys.stderr)


# ---------------------------
# Port detection logic
# ---------------------------

@dataclass(frozen=True)
class ListenerInfo:
    text: str


def _hash_to_port(name: str, salt: int, min_port: int, max_port: int) -> int:
    """
    Deterministically map (name, salt) into [min_port, max_port] using SHA-256.
    """
    if min_port < 1 or max_port > 65535 or min_port >= max_port:
        raise ValueError("Invalid port range. Must satisfy 1 <= min_port < max_port <= 65535.")

    data = f"{name}\0{salt}".encode("utf-8", errors="strict")
    digest = hashlib.sha256(data).digest()
    n = int.from_bytes(digest[:8], "big", signed=False)
    span = (max_port - min_port) + 1
    return min_port + (n % span)


def _is_port_free(host: str, port: int) -> bool:
    """
    Check if a TCP port is free on the given host by attempting to bind().
    """
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind((host, port))
        return True
    except OSError:
        return False
    finally:
        try:
            s.close()
        except Exception:
            pass


def _listener_via_psutil(port: int) -> Optional[ListenerInfo]:
    if not PSUTIL_AVAILABLE:
        return None

    try:
        conns = psutil.net_connections(kind="inet")
    except Exception as e:
        return ListenerInfo(text=f"(psutil present, but net_connections failed: {e})")

    listeners = []
    for c in conns:
        try:
            lport = c.laddr.port if hasattr(c.laddr, "port") else c.laddr[1]
        except Exception:
            continue

        if lport != port:
            continue

        if getattr(c, "status", "").upper() != "LISTEN":
            continue

        pid = getattr(c, "pid", None)
        proc_desc = "pid=?"
        if pid:
            try:
                p = psutil.Process(pid)
                proc_desc = f"pid={pid} name={p.name()} exe={p.exe()}"
            except Exception:
                proc_desc = f"pid={pid}"

        lip = ""
        try:
            lip = c.laddr.ip if hasattr(c.laddr, "ip") else c.laddr[0]
        except Exception:
            pass

        listeners.append(f"{lip}:{port} {proc_desc}")

    if not listeners:
        return ListenerInfo(text="(No LISTEN socket found via psutil; insufficient permissions or different socket type.)")

    return ListenerInfo(text="\n".join(listeners))


def _listener_via_os_tools(port: int) -> ListenerInfo:
    system = platform.system().lower()

    if system in ("darwin", "linux"):
        rc, out = _run_cmd(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"])
        if rc == 0 and out:
            return ListenerInfo(text=out)

        if system == "linux":
            _, out2 = _run_cmd(["ss", "-ltnp", f"sport = :{port}"])
            if out2:
                return ListenerInfo(text=out2)

        return ListenerInfo(text=out or "(could not determine listener; try installing psutil or lsof)")

    if system == "windows":
        cmd = ["cmd.exe", "/c", f'netstat -ano | findstr /R /C:":{port} "']
        _, out = _run_cmd(cmd)
        return ListenerInfo(text=out or "(could not determine listener; try installing psutil)")

    return ListenerInfo(text="(unsupported OS tools for listener detection; try installing psutil)")


def describe_listener(port: int) -> ListenerInfo:
    info = _listener_via_psutil(port)
    if info is not None:
        return info
    return _listener_via_os_tools(port)


def find_free_port_for_name(
    name: str,
    host: str,
    min_port: int,
    max_port: int,
    max_attempts: int,
) -> Tuple[int, int]:
    """
    Returns (free_port, salt_used).
    """
    for salt in range(max_attempts):
        port = _hash_to_port(name, salt, min_port, max_port)

        if _is_port_free(host, port):
            return port, salt

        listener = describe_listener(port)
        print(
            f"[in use] name-to-port({name!r}, salt={salt}) -> {port} is already in use.\n"
            f"Listener(s):\n{listener.text}\n",
            file=sys.stderr,
        )

    raise RuntimeError(f"Could not find a free port for {name!r} after {max_attempts} attempts.")


# ---------------------------
# CLI
# ---------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="Map a name to a deterministic free TCP port.")
    ap.add_argument("name", help='Name to map to a port (e.g. "bento-pdf").')
    ap.add_argument("--host", default="127.0.0.1", help="Host/interface to test binding against (default: 127.0.0.1).")
    ap.add_argument("--min-port", type=int, default=20000, help="Minimum port in mapping range (default: 20000).")
    ap.add_argument("--max-port", type=int, default=45000, help="Maximum port in mapping range (default: 45000).")
    ap.add_argument("--max-attempts", type=int, default=2000, help="Max re-derivation attempts (default: 2000).")

    copy_group = ap.add_mutually_exclusive_group()
    copy_group.add_argument(
        "--copy",
        action="store_true",
        help="Copy the resulting port to clipboard without prompting.",
    )
    copy_group.add_argument(
        "--no-copy",
        action="store_true",
        help="Do not copy and do not prompt.",
    )

    args = ap.parse_args()

    port, _salt = find_free_port_for_name(
        name=args.name,
        host=args.host,
        min_port=args.min_port,
        max_port=args.max_port,
        max_attempts=args.max_attempts,
    )

    # stdout: port only (pipe-friendly)
    print(port)

    # clipboard behavior (stderr only)
    do_copy: bool
    if args.copy:
        do_copy = True
    elif args.no_copy:
        do_copy = False
    else:
        do_copy = should_prompt_copy() and prompt_yes_no(f"Copy port {port} to clipboard?", default=True)

    if do_copy:
        res = copy_to_clipboard(str(port))
        if res.ok:
            print(f"{GREEN}✔ Copied {port} to clipboard ({res.method}).{RESET}", file=sys.stderr)
        else:
            print(
                f"{ORANGE}⚠ Could not copy to clipboard ({res.method}). {res.details}{RESET}",
                file=sys.stderr,
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
