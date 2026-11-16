# Local setup (Windows, PowerShell)

These steps assume Windows with PowerShell, Python 3 with pip, and Node.js with npm installed. Run commands from the repository root unless a step says otherwise.

## 1. Backend (terminal 1)

```powershell
cd services\api
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r requirements-dev.txt
uvicorn app.main:app --reload --port 8000
```

Check that the API responds at http://localhost:8000/api/v1/health. It should return `{"status": "ok", ...}`.

If activation is blocked by execution policy, run this once in the same user account and open a new terminal:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 2. Environment files

- Root `.env.example` points to the per-app examples.
- `services/api`: the default is `AI_PROVIDER=mock`. No credentials are needed.
- `apps/web`: copy the example to `.env.local` and confirm that `NEXT_PUBLIC_API_BASE_URL=http://localhost:8000`.

```powershell
cd apps\web
Copy-Item .env.example .env.local
```

## 3. Frontend (terminal 2)

```powershell
cd apps\web
npm install
npm run dev
```

Open http://localhost:3000 and use the hydraulic calculator. Restart `npm run dev` after changing `.env.local`, because Next.js reads it at startup.

## 4. Checks

```powershell
# Backend (from services\api, with the venv active)
python -m pytest
ruff check .

# Frontend (from apps\web)
npm run lint
npm run build
```

## Troubleshooting

- **Port 8000 or 3000 is in use.** Start the API on another port, for example `--port 8001`, and update `NEXT_PUBLIC_API_BASE_URL` to match. For the web app, stop the other process or let Next.js choose another port.
- **The calculator cannot reach the API.** Check that uvicorn is running, that `NEXT_PUBLIC_API_BASE_URL` is correct, and that the dev server was restarted after the change.
- **The advisor returns 503.** The AI provider failed or returned invalid output. The calculation result should still display.
- **`pip install` fails.** Make sure the venv is active. Run `where.exe python` to check which interpreter is in use.
