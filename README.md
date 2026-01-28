NAME2PORT — Deterministic Name → Free Port Resolver
===============================================

A small CLI utility that converts a service name (string) into a deterministic TCP port,
checks if that port is already in use, shows what is listening on it, and keeps deriving
new ports until it finds a free one.

Designed for local dev environments, microservices, scripts, containers, and tooling
where you want stable-but-safe port assignment without manual tracking.


-----------------------------------
FEATURES
-----------------------------------

• Deterministic name → port mapping
• Automatic collision detection
• Shows what process is using a conflicting port
• Re-derives ports until a free one is found
• Uses psutil when available for best diagnostics
• Falls back to OS tools if psutil is missing
• Works on Linux, macOS, and Windows
• CLI-friendly (prints only the final port to stdout)


-----------------------------------
INSTALLATION (RECOMMENDED: PIP)
-----------------------------------

Install from PyPI:

    pip install name2port

Run:

    name2port bento-pdf


-----------------------------------
INSTALLATION (STANDALONE SCRIPT MODE)
-----------------------------------

If you want to run it without installing via pip, you can use the script directly.

1) Move the script somewhere permanent:

Linux / macOS (user):
    mkdir -p ~/bin
    mv name_to_free_port.py ~/bin/name2port

Linux / macOS (system-wide):
    sudo mv name_to_free_port.py /usr/local/bin/name2port

Windows:
    Put the file in a folder like:
        C:\tools\

2) Make executable (Linux/macOS):

    chmod +x ~/bin/name2port

3) Ensure folder is in PATH:

Bash:
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc

Zsh:
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc

4) Run it like a normal command:

    name2port my-service


-----------------------------------
EXAMPLE
-----------------------------------

$ name2port bento-pdf
24317

If a collision occurs:

[in use] name-to-port('bento-pdf', salt=0) -> 24317 is already in use.
Listener(s):
127.0.0.1:24317 pid=1234 name=node exe=/usr/bin/node

24389   ← next free port


-----------------------------------
PSUTIL (OPTIONAL BUT RECOMMENDED)
-----------------------------------

Without psutil, the tool still works but has limited process detection.

Install:

pip:
    python -m pip install psutil
    https://pypi.org/project/psutil/

Ubuntu/Debian:
    sudo apt install python3-psutil

Fedora:
    sudo dnf install python3-psutil

Arch:
    sudo pacman -S python-psutil


-----------------------------------
USAGE
-----------------------------------

name2port <name> [options]

Options:

--host           Interface to test binding against (default 127.0.0.1)
--min-port       Minimum port in range (default 20000)
--max-port       Maximum port in range (default 45000)
--max-attempts   Maximum re-derivation tries (default 2000)

Example:

name2port api-service --min-port 30000 --max-port 40000


-----------------------------------
WHY THIS EXISTS
-----------------------------------

Manually tracking service ports leads to:

• conflicts
• environment drift
• "works on my machine" problems
• brittle config files

This tool gives:

stable + collision-safe ports
no config files
works across teams and machines


-----------------------------------
NOTES / LIMITATIONS
-----------------------------------

• This tool does NOT reserve the port — it only checks availability.
  For race-safe reservation, bind your server to the returned port immediately,
  or implement a reservation mechanism in your runtime/tooling.
