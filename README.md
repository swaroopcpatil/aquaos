# AquaOS

AquaOS is an AI Water Intelligence Platform for farmers, pump dealers, distributors and service technicians.

## Status

Early foundation (first slice). This is not production-ready.

Included in this slice:

- Monorepo foundation for the web app and the API
- PostgreSQL schema with Row Level Security (SQL only, not yet wired to the API)
- Deterministic hydraulic calculation engine with tests
- Hydraulic calculator page wired to the real API
- AI advisor explain endpoint, using the mock provider

Not built yet: authentication wired into the app, persistence of analyses, product catalogue UI, service management, real AI provider verification, Playwright end-to-end tests, deployment.

## What it does

The hydraulic calculator estimates total dynamic head, friction losses and pump power for a borewell and delivery pipe. The calculation is deterministic. The AI advisor explains a result in plain language for a farmer, dealer or technician, and it never changes the numbers.

Simplified calculations are not certified engineering designs.

## Layout

| Path | Contents |
| --- | --- |
| `apps/web` | Next.js App Router, TypeScript, Tailwind CSS, Recharts |
| `services/api` | Python FastAPI, Pydantic, pytest. `app/engineering` is the hydraulic engine; `app/ai` is the provider abstraction with a mock provider |
| `packages/shared-contracts` | Placeholder. The API contract currently lives in `docs/api/CONTRACT.md` |
| `supabase/migrations`, `supabase/seed.sql` | PostgreSQL schema with Row Level Security. Not yet wired to the API |
| `docs/` | Architecture, product, development notes and the API contract |
| `infra/docker` | Placeholder, currently empty |

## Quick start

Full steps for Windows PowerShell are in [docs/development/LOCAL_SETUP.md](docs/development/LOCAL_SETUP.md).

```powershell
# Backend (terminal 1)
cd services\api
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r requirements-dev.txt
uvicorn app.main:app --reload --port 8000

# Frontend (terminal 2)
cd apps\web
npm install
Copy-Item .env.example .env.local
npm run dev
```

The web app runs at http://localhost:3000. The API runs at http://localhost:8000. The API uses `AI_PROVIDER=mock` by default and needs no credentials.

## Tests and checks

```powershell
# Backend
cd services\api
python -m pytest
ruff check .

# Frontend
cd apps\web
npm run lint
npm run build
```

## Principles

- Hydraulic calculations are deterministic. AI never performs or overrides them.
- No fabricated manufacturer products or pump curves.
- Service-role credentials never reach the browser.
- Simplified calculations are not certified engineering designs.

## Documentation

- [API contract](docs/api/CONTRACT.md)
- [Architecture](docs/architecture/ARCHITECTURE.md)
- [Technical decisions](docs/architecture/TECH_DECISIONS.md)
- [Product requirements](docs/product/PRODUCT_REQUIREMENTS.md)
- [Local setup](docs/development/LOCAL_SETUP.md)

## Further reading

- [Hydraulic methodology](docs/architecture/HYDRAULIC_METHODOLOGY.md)
- [Database schema](docs/architecture/DATABASE.md) and [security policies](docs/architecture/SECURITY_POLICIES.md)
- [API contract](docs/api/CONTRACT.md)
