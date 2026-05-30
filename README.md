# Quicktionary

```bash
uv venv && source .venv/bin/activate
uv pip install -r requirements.txt
```
Terminal 1:
```bash
cd quicktionary/export && python -m http.server 8080
```
Terminal 2:
```bash
cd server && python server.py
```