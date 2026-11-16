# Technical decisions

Short ADR-style log. Status is `Accepted` unless noted.

## ADR-001: Monorepo with separate web and API apps

- **Context:** The web app and API need to evolve together, with one place for docs and schema.
- **Decision:** Keep `apps/web`, `services/api`, `supabase/`, `docs/` and `infra/` in one repository.
- **Consequences:** Cross-cutting changes land in one commit. There is no shared build tooling beyond each app's own.

## ADR-002: Next.js App Router with TypeScript, Tailwind CSS and Recharts for the web app

- **Context:** The web app needs forms, result display and charts.
- **Decision:** Use Next.js App Router, TypeScript, Tailwind CSS and Recharts.
- **Consequences:** Build and lint run through `npm run build` and `npm run lint`.

## ADR-003: Python FastAPI with Pydantic for the API

- **Context:** The API runs numerical code and must validate inputs strictly.
- **Decision:** Use FastAPI with Pydantic models, pytest for tests and ruff for linting.
- **Consequences:** Validation failures use FastAPI's 422 shape, as defined in the API contract.

## ADR-004: Deterministic hydraulic engine, separate from AI

- **Context:** Pump sizing outputs must be reproducible and explainable.
- **Decision:** `app/engineering` is pure calculation. `app/ai` only explains results. AI never computes or overrides a number.
- **Consequences:** Results carry `methodology_version`. Calculations work without AI.

## ADR-005: Provider abstraction for AI, with a mock provider as default

- **Context:** No AI provider credentials are available in development, and provider output must be validated before use.
- **Decision:** Hide providers behind an abstraction. Default to `AI_PROVIDER=mock`.
- **Consequences:** The advisor endpoint runs without credentials. Real provider behaviour is not yet verified. Invalid provider output returns 503.

## ADR-006: PostgreSQL schema with Row Level Security via Supabase

- **Context:** Data will be shared across users and roles, and access must be enforced in the database.
- **Decision:** Define the schema and RLS policies as SQL in `supabase/migrations`, with sample data in `supabase/seed.sql`.
- **Consequences:** The schema is not yet connected to the API. Persistence is a later slice.

## ADR-007: API contract documented in `docs/api/CONTRACT.md`

- **Context:** There is no generated shared types package yet.
- **Decision:** Keep the contract as a Markdown document. `packages/shared-contracts` is reserved for shared types.
- **Consequences:** Web and API must be kept in step by hand until shared types exist.

## ADR-008: No fabricated products or pump curves

- **Context:** Invented manufacturer data would mislead users about real equipment.
- **Decision:** The engine uses user-entered values and stated assumptions only. No catalogue data is included in this slice.
- **Consequences:** Product selection is out of scope until verified data sources exist.

## ADR-009: Service-role credentials are server-side only

- **Context:** Browser code can be read by anyone who opens the page.
- **Decision:** Service-role keys stay in server-side configuration and are never exposed to the browser.
- **Consequences:** Browser code uses only public configuration such as `NEXT_PUBLIC_API_BASE_URL`.
