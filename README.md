# Devil-In AI

> Run any GGUF language model locally on Windows — no Python, no Docker, no cloud, no install headaches.
> Works from a USB drive. One click to set up, one click to run. Premium red & gold theme.

---

## What is this?

Devil-In AI wraps [llama.cpp](https://github.com/ggml-org/llama.cpp)'s `llama-server` into a zero-dependency portable package for **Windows x64**. Plug in a USB drive (or clone the repo), drop in a model, and run a single script. A premium-styled local web UI opens in your browser — fully offline, fully private.

No Python environment. No package managers. No GPU required.

---

## Features

- **Windows-only** — optimized for Windows 10/11 x64 (CPU)
- **Truly portable** — runs from a USB stick on any Windows machine
- **Auto-installer** — fetches the latest `llama-server` release for Windows straight from GitHub, downloading only the files actually needed to run the server
- **Model picker** — prompts you to choose when multiple `.gguf` models are present
- **CPU-only** — works on any modern Windows machine without a GPU
- **100% offline** after setup — no data leaves your machine
- **Premium Web UI** — custom red & gold themed chat interface with your logo
- **LAN sharing** — accessible from any device on the same network at `http://<your-ip>:8080`

---

## Directory Layout

```
Devil-In AI/
├── .gitignore
├── install.bat          ← Windows installer (downloads llama.cpp Windows binary)
├── start.bat             ← Windows launcher (starts server + opens premium UI)
├── models/                ← Drop your .gguf model files here (not tracked in git)
├── ui/                     ← Custom premium web UI (red & gold theme)
│   ├── index.html          ← Premium themed chat interface
│   └── logo.png             ← UI logo
└── bin/
    └── windows/               ← Created by install.bat (not tracked in git)
        ├── llama-server-win.exe
        └── *.dll                ← only the DLLs actually required to run the server
```

---

## Quick Start

### Step 1 — Install binaries

Double-click `install.bat`. It will:
- Check for the Visual C++ Redistributable (required)
- Query GitHub for the latest llama.cpp release
- Download the Windows x64 CPU build
- Extract it to a temp folder, then copy only the files the server actually needs into `bin\windows\` (server exe, core DLLs, and every CPU-arch `ggml-cpu-*.dll` variant)
- Rename the server executable to `llama-server-win.exe`

### Step 2 — Get a model

Download any `.gguf` model and place it in the `models\` folder.

> Search [huggingface.co](https://huggingface.co) for any model — filter by `GGUF` format and pick a `Q4_K_M` quantization for the best balance of size and quality.

### Step 3 — Start the server

Double-click `start.bat`. The browser opens automatically at **http://127.0.0.1:8080** with the premium red & gold UI.

If you have multiple models in `models\`, you'll be asked to choose one:

```
 [?] Multiple models found - select one:
     ------------------------------------
     [1] mistral-7b-instruct-v0.2.Q4_K_M.gguf     3.8G
     [2] llama-3.2-3b-instruct-q4_k_m.gguf         1.9G

 Enter number [1-2]:
```

---

## Requirements

### Runtime
| Platform | Requirement |
|---|---|
| Windows | Windows 10 (build 17063+), [Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe) |

### For install.bat
| Tool | Notes |
|---|---|
| `curl` | Included in Windows 10 17063+ |
| `tar` / PowerShell | Included in Windows 10 17063+ (used for extraction) |

### Hardware (minimum)
| RAM | Recommended model size |
|---|---|
| 4 GB | 1B–3B models (Q4_K_M) |
| 8 GB | 7B models (Q4_K_M) |
| 16 GB | 13B models (Q4_K_M) |
| 32 GB | 30B+ models (Q4_K_M) |

---

## How It Works

```
install.bat
        │
        ├── Queries GitHub API for the latest llama.cpp release
        ├── Downloads the win-cpu-x64 asset
        ├── Extracts all files to a temp folder
        ├── Resolves symlinks for portability
        ├── Copies only the required server files into bin\windows\
        │       (llama-server.exe, core DLLs, all ggml-cpu-*.dll variants)
        └── Renames llama-server.exe -> llama-server-win.exe

start.bat
        │
        ├── Scans models\ for .gguf files
        ├── Prompts for selection if more than one model is found
        ├── Prepends bin\windows\ to PATH (so its DLLs win over any on the system)
        ├── Opens the browser once the server responds on port 8080
        └── Launches llama-server-win.exe with --path ui\
```

> **Why copy DLLs at all instead of just the exe?**
> `llama-server` dynamically links against `llama.dll`, `ggml.dll`, `ggml-base.dll`, and several `ggml-cpu-*.dll` variants (the server auto-detects your CPU at runtime and loads the matching one). Copying only the executable would crash with "DLL not found." The installer filters the release down to just these required files — it does **not** copy the full archive, so unrelated tools (CLI chat, benchmarking, quantization, TTS, RPC server, etc.) are skipped.

---

## Configuration

The server starts with sensible defaults. To customize, edit the launch command at the bottom of `start.bat`:

```bat
"%BIN%" ^
    -m "%MODEL%" ^
    -c 4096 ^
    -t %THREADS% ^
    --port 8080 ^
    --host 0.0.0.0 ^
    --path "%~dp0ui"
```

Common tweaks:

| Flag | Example | Effect |
|---|---|---|
| `-c` | `-c 8192` | Larger context (needs more RAM) |
| `-t` | `-t 4` | Fixed thread count |
| `--port` | `--port 9090` | Change the port |
| `--host` | `--host 127.0.0.1` | Localhost only (disable LAN) |
| `-ngl` | `-ngl 35` | Offload layers to GPU (if available) |

Full flag reference: `bin\windows\llama-server-win.exe --help`

---

## Accessing from Other Devices

While the server is running, any device on the same network can access the UI:

1. Find your machine's local IP: `ipconfig` (look for IPv4 Address)
2. Open `http://192.168.x.x:8080` on the other device

---

## Troubleshooting

**`VCRUNTIME140_1.dll` not found**
Install the [Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe) and re-run `start.bat`.

**Binary not found / install.bat stops after printing the release tag**
GitHub API rate-limited the request (60 requests/hour for unauthenticated IPs). Wait a few minutes and try again.

**Model loads but responses are very slow**
Use a smaller or more quantized model (e.g., `Q2_K` instead of `Q8_0`). Reduce context with `-c 2048`.

**Port 8080 already in use**
Change `--port 8080` to another port (e.g. `--port 9090`) in `start.bat`.

**Logo not showing**
Confirm `ui\logo.png` exists. Replace it with your own PNG (128×128px+, transparency recommended) to rebrand.

---

## Updating llama.cpp

Just re-run the installer — it always fetches the **latest** release from GitHub:

```
Double-click install.bat
```

---

## Premium UI Customization

The custom UI lives in `ui/`:
- `index.html` — the complete chat interface, red/gold theme
- `logo.png` — the UI logo (replace with your own to rebrand)

The UI includes:
- Dark theme with gold/red accents
- Animated status indicators
- Styled message bubbles (user = gold, assistant = red)
- Code syntax highlighting
- Responsive design for mobile/desktop
- Custom scrollbars matching the theme

---

## Credits

- **[llama.cpp](https://github.com/ggml-org/llama.cpp)** by ggml-org — the inference engine powering everything
- Models from **[Hugging Face](https://huggingface.co)** — community-converted GGUF weights

---

## License

MIT License — feel free to use, modify, and distribute.
