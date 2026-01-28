# NAME2PORT — Deterministic Name → Free Port Resolver

---

<div align="center">

[![PyPI version](https://img.shields.io/pypi/v/name2port.svg)](https://pypi.org/project/name2port/) [![Python versions](https://img.shields.io/pypi/pyversions/name2port.svg)](https://pypi.org/project/name2port/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE) [![Code style: PEP8](https://img.shields.io/badge/code%20style-PEP8-blue.svg)](https://peps.python.org/pep-0008/)

</div>

---

A small CLI utility that converts a service name (string) into a deterministic TCP port,
checks if that port is already in use, shows what is listening on it, and keeps deriving
new ports until it finds a free one.

Designed for local dev environments, microservices, scripts, containers, and tooling
where you want stable-but-safe port assignment without manual tracking.

---

## Features

• Deterministic name → port mapping
• Automatic collision detection
• Shows what process is using a conflicting port
• Re-derives ports until a free one is found
• Uses psutil when available for best diagnostics
• Falls back to OS tools if psutil is missing
• Works on Linux, macOS, and Windows
• CLI-friendly (prints only the final port to stdout)
• IPv4 and IPv6 host support

---

## Installation (recommended: pip)

**Fast path (recommended)**

- With PATH-managed shim: `pipx install "name2port[psutil]"`
- Minimal install: `pip install name2port`
- Enable richer listener info later: `pip install psutil`

**From source tree**

```bash
./install.sh                # macOS/Linux helper; supports --yes/--link flags
# or
pipx install .
# or
pip install ".[psutil]"
```

**One-liner (macOS/Linux)**

```bash
curl -fsSL https://raw.githubusercontent.com/ZeitounCorp/name2port/main/install.sh | bash
```

**Windows**

```powershell
pip install name2port
# add %USERPROFILE%\\.local\\bin to PATH if pip chooses that location
```

**Run it**

```bash
name2port bento-pdf
```

---

## Installation (standalone script mode)

If you prefer a single file, download `./name2port/cli.py`, make it executable,
and place it on your PATH:

```bash
mkdir -p ~/bin
cp cli.py ~/bin/name2port
chmod +x ~/bin/name2port
```

**System-wide on macOS/Linux:**

```bash
sudo cp cli.py /usr/local/bin/name2port && sudo chmod +x /usr/local/bin/name2port
```

**On Windows:**
Put `cli.py` in a directory on PATH (e.g., `C:\tools\`) and run `py cli.py <name>`.

---

## Psutil (optional but recommended)

Without psutil, the tool still works but has limited process detection.

**Install:**

**pip:**

```bash
python -m pip install psutil          # add psutil to existing install
python -m pip install "name2port[psutil]"  # fresh install with extra
```

**Ubuntu/Debian:**

```bash
sudo apt install python3-psutil
```

**Fedora:**

```bash
sudo dnf install python3-psutil
```

**Arch:**

```bash
sudo pacman -S python-psutil
```

---

## ＞ Usage

```bash
name2port <name> [options]
```

| Option           | Description                                             |
| ---------------- | ------------------------------------------------------- |
| `--host`         | Interface to test binding against (default `127.0.0.1`) |
| `--min-port`     | Minimum port in range (default `20000`)                 |
| `--max-port`     | Maximum port in range (default `45000`)                 |
| `--max-attempts` | Maximum re-derivation tries (default `2000`)            |
| `--copy`         | Copy port to clipboard without prompting                |
| `--no-copy`      | Disable clipboard and prompt                            |

**Example:**

__*Normal usage:*__

```bash
$ name2port bento-pdf
24317
```

__*Custom port range:*__

```bash
$ name2port api-service --min-port 30000 --max-port 40000
34567
```

__*If a collision occurs:*__

```bash
$ name2port bento-pdf
[in use] name-to-port('bento-pdf', salt=0) -> 24317 is already in use.
Listener(s):
127.0.0.1:24317 pid=1234 name=node exe=/usr/bin/node

24389   ← next free port
```

---

## 📋 Clipboard Support

By default, when run interactively, **name2port** will ask whether to copy the resulting port to your clipboard.

**Copy without prompting:**

```bash
name2port bento-pdf --copy
```

**Disable copy and disable prompt:**

```bash
name2port bento-pdf --no-copy
```

**Linux clipboard tools that may be required:**

```bash
sudo apt install wl-clipboard   # Wayland
sudo apt install xclip          # X11
```

---

## 🐳 Using the Port in Common Ecosystems

The command outputs a port number. Use it to bind servers or forward container ports.

### Docker

```bash
PORT=$(name2port bento-pdf --no-copy)
docker run --rm -p ${PORT}:3000 my-image
```

Host port → container port mapping (`${HOST_PORT}:${CONTAINER_PORT}`).

### Docker Compose

```yaml
services:
  app:
    image: my-image
    ports:
      - '${PORT}:${CONTAINER_PORT}'
```

```bash
export PORT=$(name2port bento-pdf --no-copy)
docker compose up
```

### Node.js (Express)

```bash
PORT=$(name2port bento-pdf --no-copy)
PORT=$PORT node server.js
```

```js
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (_req, res) => res.send('ok'));

app.listen(port, '0.0.0.0', () => {
  console.log(`Listening on ${port}`);
});
```

### Python (Flask)

```bash
PORT=$(name2port bento-pdf --no-copy)
flask --app app run --host 0.0.0.0 --port $PORT
```

```python
import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def home():
    return "ok"

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "3000"))
    app.run(host="0.0.0.0", port=port)
```

---

## Tips for PATH/bin

- `pipx` adds a shim in `~/.local/bin` (usually already on PATH after reloading your shell).
- For `pip install --user`, ensure `~/.local/bin` (Linux/macOS) or `%USERPROFILE%\.local\bin` (Windows) is on PATH.
- If you copied the standalone script manually, placing it at `~/bin/name2port` (user) or `/usr/local/bin/name2port` (system) makes it available everywhere.

---

## Why This Exists

**Manually tracking service ports leads to:**

- conflicts
- environment drift
- "works on my machine" problems
- brittle config files

**This tool gives:**

- stable + collision-safe ports
- no config files
- works across teams and machines

---

## Notes / Limitations

- This tool does NOT reserve the port — it only checks availability.
  For race-safe reservation, bind your server to the returned port immediately,
  or implement a reservation mechanism in your runtime/tooling.

---

## 📄 License

MIT License © ZeitounCorp
