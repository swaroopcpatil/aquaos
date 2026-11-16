# AquaOS Database

Supabase PostgreSQL 15+, Supabase Auth, Row Level Security on every table. Migrations live in `supabase/migrations/`
(1 enums + core tenancy, 2 domain tables, 3 AI tables, 4 triggers + RLS). `supabase/seed.sql` holds SAMPLE-only data.

Conventions: UUID primary keys (`gen_random_uuid()`); `created_at`/`updated_at` with a `set_updated_at` trigger
(`audit_logs` is append-only and has no `updated_at`); every tenant-owned table has `organization_id NOT NULL`
referencing `organizations ON DELETE CASCADE`, and an index on it. Child rows reference parents through composite
foreign keys `(organization_id, parent_id)`, so a row can never point at a parent in another tenant. Optional links use
`ON DELETE SET NULL (column)`. `organization_id` is immutable (trigger). Every FK column is indexed.

## Relationships

```
organizations 1─* memberships *─1 auth.users 1─1 profiles
organizations 1─* customers 1─* farms 1─* borewells
organizations 1─* products 1─* pump_curves
customers 1─* installations (→ farm, borewell, product, pump_curve optional)
customers 1─* service_tickets 1─* diagnoses
conversations 1─* messages ; agent_runs ← messages / diagnoses / recommendations
audit_logs (append-only, per organization)
```

## Tables

- **organizations**: a tenant (dealer, distributor or service company). Holds name, unique slug, settings jsonb. Created and deleted server-side only.
- **profiles**: 1:1 with `auth.users` (same id, cascade delete). Per-user data (name, phone, locale); not tenant-owned.
- **memberships**: links a user to an organization with a role (`owner`, `administrator`, `employee`, `technician`, `farmer`); unique per (org, user). Farmer memberships carry `customer_id` pointing at the customer record they represent.
- **customers**: the people/businesses an organization serves (farmers, dealers' clients). Parent of farms, installations and tickets.
- **farms**: a customer's land; optional coordinates, area, crop.
- **borewells**: belong to a farm. Depth, static and pumping water level, casing diameter, with CHECKs: pumping >= static, both levels < depth, positive dimensions.
- **products**: per-organization catalogue entries. `is_sample` plus `verification_status` (`unverified`/`verified`) and source columns (`source_type`, `source_reference`, `source_url`, `verified_by`, `verified_at`). A CHECK forbids `verified` on sample rows and requires a source reference and timestamp for verified rows.
- **pump_curves**: curve for a product, stored as `curve_points jsonb` array of `{flow_lpm, head_m, efficiency_pct?}` (at least 2 points, validated by `valid_curve_points` in a CHECK). Same sample/verification/source columns and CHECK as products.
- **installations**: a pump installed for a customer, optionally linked to farm, borewell, product and curve. Deleting a customer is restricted while installations exist.
- **service_tickets**: service requests with status, priority, optional installation and `assigned_to` technician.
- **diagnoses**: findings recorded against a ticket by a human or an agent run (`agent_run_id`).
- **conversations**: a user's AI chat thread, optionally tied to a customer or ticket.
- **messages**: turns in a conversation (`user`, `assistant`, `system`, `tool`), append-style, with metadata jsonb.
- **recommendations**: advice (e.g. pump selection) for a customer/farm/borewell, optionally citing product and curve. `uses_unverified_data` (default true) flags output built on sample or unverified data.
- **agent_runs**: one record per AI agent execution: model, status, input/output, token counts, error. Server-written.
- **audit_logs**: append-only log of security-relevant actions (actor, action, table, record). Server-written.

## Sample vs verified data

Nothing is trusted as manufacturer data unless `verification_status = 'verified'` and `is_sample = false` with a cited
source. The seed contains only rows named `SAMPLE ...` with `is_sample = true`, and deliberately no pump curves.
