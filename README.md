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

```bash
pip install name2port
```

Run:

```bash
name2port bento-pdf
```


-----------------------------------
INSTALLATION (STANDALONE SCRIPT MODE)
-----------------------------------

If you want to run it without installing via pip, you can use the script directly.

Move the script somewhere permanent:

Linux / macOS (user):

```bash
mkdir -p ~/bin
mv name_to_free_port.py ~/bin/name2port
```

Linux / macOS (system-wide):

```bash
sudo mv name_to_free_port.py /usr/local/bin/name2port
```

Windows:

```txt
Put the file in a folder like:
C:\tools\
```

Make executable (Linux/macOS):

```bash
chmod +x ~/bin/name2port
```

Ensure folder is in PATH:

Bash:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Zsh:

```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Run it like a normal command:

```bash
name2port my-service
```


-----------------------------------
EXAMPLE
-----------------------------------

```bash
$ name2port bento-pdf
24317
```

If a collision occurs:

```txt
[in use] name-to-port('bento-pdf', salt=0) -> 24317 is already in use.
Listener(s):
127.0.0.1:24317 pid=1234 name=node exe=/usr/bin/node

24389   ← next free port
```


-----------------------------------
PSUTIL (OPTIONAL BUT RECOMMENDED)
-----------------------------------

Without psutil, the tool still works but has limited process detection.

Install:

pip:

```bash
python -m pip install psutil
```

Ubuntu/Debian:

```bash
sudo apt install python3-psutil
```

Fedora:

```bash
sudo dnf install python3-psutil
```

Arch:

```bash
sudo pacman -S python-psutil
```


-----------------------------------
USAGE
-----------------------------------

```bash
name2port <name> [options]
```

Options:

```txt
--host           Interface to test binding against (default 127.0.0.1)
--min-port       Minimum port in range (default 20000)
--max-port       Maximum port in range (default 45000)
--max-attempts   Maximum re-derivation tries (default 2000)
```

Example:

```bash
name2port api-service --min-port 30000 --max-port 40000
```


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
