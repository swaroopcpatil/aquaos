# AquaOS Security Policies (Row Level Security)

RLS is enabled on all 16 tables (51 policies). All policies are `TO authenticated`; `anon` has no privileges.
No policy mentions the service role. Privileged operations (creating organizations, writing audit logs and agent runs,
assistant messages) run server-side with a key that bypasses RLS and must never reach a client.

## Helper functions

All are `SECURITY DEFINER`, `STABLE`, `set search_path = ''` (fully schema-qualified), executable by `authenticated` only.
They read `memberships` without re-triggering its policies, which avoids recursive policy evaluation.

- `is_org_member(org uuid) -> boolean`
- `has_org_role(org uuid, roles org_role[]) -> boolean`
- `my_customer_id(org uuid) -> uuid`: customer linked to the caller's farmer membership, else null.

Other safeguards: composite FKs block cross-tenant references; `prevent_org_change` trigger makes `organization_id`
immutable; WITH CHECK clauses test the caller's role in the *row's* organization, so a client-supplied
`organization_id` is never trusted; table privileges are also revoked for `audit_logs`, `agent_runs` writes and
`organizations` insert/delete.

## Policy matrix

R = read, W = insert/update, D = delete. "own" = rows linked to the caller's customer record (farmer) or authored by caller.

| Table | owner | administrator | employee | technician | farmer |
|---|---|---|---|---|---|
| organizations | R, W(update) | R, W(update) | R | R | R |
| profiles | own R/W | own R/W | own R/W | own R/W | own R/W |
| memberships | R all, W/D all | R all, W/D except owner rows | own row R | own row R | own row R |
| customers | R W D | R W D | R W | R | R own |
| farms | R W D | R W D | R W | R | R own |
| borewells | R W D | R W D | R W | R | R own (via farm) |
| products | R W D | R W D | R | R | R |
| pump_curves | R W D | R W D | R | R | R |
| installations | R W D | R W D | R W | R | R own |
| service_tickets | R W D | R W D | R W | R; W only tickets assigned to them (cannot reassign) | R own; insert own, open, unassigned |
| diagnoses | R W D | R W D | R W | R; insert on assigned tickets, update own | R (on own tickets) |
| conversations | own R/W/D + R all | own R/W/D + R all | own R/W/D | own R/W/D | own R/W/D |
| messages | R all; insert own `user` msgs | same | own conversations R; insert own `user` msgs | same | same |
| recommendations | R W D | R W D | R W | R | R own |
| agent_runs | R | R | none | none | none |
| audit_logs | R | R | none | none | none |

No client insert/update/delete policy exists for `agent_runs`, `audit_logs`; `organizations` has no insert/delete policy.
Only an owner may create, modify or delete `owner` memberships.

## Known simplifications

- Farmer scope is by customer link only (customers, farms, borewells via farm, installations, tickets, diagnoses via ticket, recommendations by `customer_id`). Recommendations without a `customer_id` are invisible to farmers. Conversations are private to their author for every role.
- `memberships` read is own row or owner/administrator (not "all members"), so farmers and technicians cannot list colleagues. Cross-user names (profiles) are not readable; expose via a server endpoint or view if needed.
- Technician can read all customers/farms/tickets in the org, not only assigned ones.
- Products/pump_curves are managed by owner/administrator only; verification is not separately gated beyond that role and the CHECK constraints (no separate "verifier" role).
- Nothing prevents removing the last owner, or an owner demoting themselves; enforce server-side.
- Farmer ticket insert is allowed but status/assignment fields are only constrained at insert; later edits are staff-only.
- Organization bootstrap (create org + first owner membership + optional profile trigger on `auth.users`) is server-side and not defined here.
- `audit_logs` rows are cascaded when an organization is deleted.
- Tests: `supabase/tests/tenant_isolation.sql` (with `00_plain_postgres_bootstrap.sql` for non-Supabase Postgres only). Not covered: realtime, storage, views, and PostgREST-specific behaviour.
