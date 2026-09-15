---
applyTo: "**/*.py"
description: "Conventions and practices for Python helper scripts and bridges in Lucid"
---

# Python Helpers & Bridge Scripts Guidelines

When modifying or adding Python scripts in Lucid:

## Output Format

- Python scripts invoked by Quickshell processes (`Process`, `ProcessView`) should output strict, clean JSON over stdout without extra stdout log noise.
- Direct debug or diagnostic logs to `sys.stderr`.

## Dependencies & Portability

- Maintain compatibility with standard Linux environments (Python 3.10+).
- Use standard library modules (`subprocess`, `json`, `sys`, `os`, `pathlib`, `re`, `argparse`) wherever possible.
- If using external dependencies (e.g. `PIL`, `numpy`, `fontTools`, `pytesseract` in `emoji-ocr.py` or `gi` / `GObject` / `Gio` in `kdeconnect-bridge.py`), fail gracefully or provide readable stderr diagnostics.

## Error Handling

- Handlers should handle subprocess failures (e.g., `nmcli`, `hyprctl`, `kdeconnect-cli`) cleanly without throwing unhandled exceptions that leave hanging processes.
