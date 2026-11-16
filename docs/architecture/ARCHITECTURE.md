# Architecture

AquaOS is a monorepo with a Next.js web app, a FastAPI service and a PostgreSQL schema. The API contract is in [docs/api/CONTRACT.md](../api/CONTRACT.md).

## Overview

```
Browser (apps/web, Next.js)
    |  JSON over HTTP, base URL from NEXT_PUBLIC_API_BASE_URL
    v
API (services/api, FastAPI)
    |-- app/engineering   deterministic hydraulic engine (no AI)
    |-- app/ai            advisor; provider abstraction, mock provider by default
    |
    x  supabase/ PostgreSQL schema with RLS (defined, not yet used by the API)
```

## Components

- **Web (`apps/web`).** Next.js App Router with TypeScript, Tailwind CSS and Recharts. The hydraulic calculator page calls the real API.
- **API (`services/api`).** FastAPI with Pydantic models. Endpoints in this slice:
  - `GET /api/v1/health`
  - `POST /api/v1/hydraulics/calculate`
  - `POST /api/v1/advisor/explain`
- **Hydraulic engine (`services/api/app/engineering`).** Computes levels, total dynamic head, pipe conditions, flow conversions and pump power. Results carry `methodology_version` (currently `1.0.0`). The `tdh_breakdown` items sum to `total_dynamic_head_m`. The engine has no AI dependency.
- **AI advisor (`services/api/app/ai`).** Takes a calculation result and returns a plain-language explanation for a `farmer`, `dealer` or `technician`. It reads numbers and never changes them. The provider sits behind an abstraction; `AI_PROVIDER=mock` is the default. If the provider fails, the endpoint returns 503 and the calculator keeps working.
- **Database (`supabase/`).** Migrations define the PostgreSQL schema. Row Level Security policies restrict row access. `seed.sql` holds seed data. The API does not read from it yet.
- **Shared contracts (`packages/shared-contracts`).** Placeholder. The contract is currently maintained by hand in `docs/api/CONTRACT.md`.

## Calculator request flow

1. The user enters borewell, pipe and flow values in the web form.
2. The web app sends them to `POST /api/v1/hydraulics/calculate`.
3. The API validates the input against the contract rules and returns 200 with the result, or 422 with validation details.
4. The web app shows the result. The user may then request an explanation from `POST /api/v1/advisor/explain`.
5. An advisor failure (503) does not affect the displayed result.

## Security boundaries

- Service-role credentials stay on the server. They must never reach the browser.
- Row Level Security is part of the schema design. It is not yet exercised through the application.

## Not yet in place

Authentication wired into the app, persistence of analyses, product catalogue, service management, a real AI provider, Playwright end-to-end tests, and deployment.
