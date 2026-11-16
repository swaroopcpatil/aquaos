-- Tenant isolation checks. Plain SQL, no pgTAP. Run as a superuser/postgres AFTER migrations (and, on plain
-- Postgres, after 00_plain_postgres_bootstrap.sql). Everything runs in one transaction and is rolled back.
-- Any failed assertion raises an exception and aborts the script (use psql -v ON_ERROR_STOP=1).
begin;

-- ---------- fixtures (as superuser) ----------
insert into auth.users (id, email) values
  ('a0000000-0000-4000-8000-00000000000a', 'owner-a@test.invalid'),
  ('a0000000-0000-4000-8000-00000000000b', 'owner-b@test.invalid'),
  ('a0000000-0000-4000-8000-00000000000c', 'admin-a@test.invalid'),
  ('a0000000-0000-4000-8000-00000000000d', 'tech-a@test.invalid'),
  ('a0000000-0000-4000-8000-00000000000e', 'farmer-a@test.invalid');
insert into public.profiles (id, full_name) values
  ('a0000000-0000-4000-8000-00000000000a', 'Owner A'), ('a0000000-0000-4000-8000-00000000000b', 'Owner B');
insert into public.organizations (id, name, slug) values
  ('b0000000-0000-4000-8000-00000000000a', 'Org A', 'org-a'), ('b0000000-0000-4000-8000-00000000000b', 'Org B', 'org-b');
insert into public.customers (id, organization_id, name) values
  ('c0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-00000000000a', 'A cust 1 (farmer)'),
  ('c0000000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-00000000000a', 'A cust 2'),
  ('c0000000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-00000000000b', 'B cust 1');
insert into public.memberships (organization_id, user_id, role, customer_id) values
  ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-00000000000a', 'owner', null),
  ('b0000000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-00000000000b', 'owner', null),
  ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-00000000000c', 'administrator', null),
  ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-00000000000d', 'technician', null),
  ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-00000000000e', 'farmer', 'c0000000-0000-4000-8000-0000000000a1');
insert into public.farms (id, organization_id, customer_id, name) values
  ('d0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a1', 'A farm 1'),
  ('d0000000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a2', 'A farm 2'),
  ('d0000000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-00000000000b', 'c0000000-0000-4000-8000-0000000000b1', 'B farm 1');
insert into public.service_tickets (id, organization_id, customer_id, assigned_to, title) values
  ('e0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-00000000000d', 'A ticket assigned to tech'),
  ('e0000000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a2', null, 'A ticket unassigned'),
  ('e0000000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-00000000000b', 'c0000000-0000-4000-8000-0000000000b1', null, 'B ticket');
insert into public.audit_logs (organization_id, action) values ('b0000000-0000-4000-8000-00000000000a', 'fixture');

-- =====================================================================
-- Owner of Org A
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
set local role authenticated;

do $$
declare n int;
begin
  select count(*) into n from public.customers where organization_id = 'b0000000-0000-4000-8000-00000000000b';
  assert n = 0, 'A must not read B customers';
  select count(*) into n from public.customers;
  assert n = 2, format('A should see exactly its 2 customers, saw %s', n);
  select count(*) into n from public.service_tickets where organization_id = 'b0000000-0000-4000-8000-00000000000b';
  assert n = 0, 'A must not read B tickets';
  select count(*) into n from public.organizations;
  assert n = 1, 'A sees only its own organization';
  select count(*) into n from public.profiles where id = 'a0000000-0000-4000-8000-00000000000b';
  assert n = 0, 'A must not read B profile';
  select count(*) into n from public.memberships where organization_id = 'b0000000-0000-4000-8000-00000000000b';
  assert n = 0, 'A must not read B memberships';

  -- cross-tenant UPDATE / DELETE touch zero rows
  update public.customers set name = 'hacked' where id = 'c0000000-0000-4000-8000-0000000000b1';
  get diagnostics n = row_count; assert n = 0, 'cross-tenant update must affect 0 rows';
  delete from public.customers where id = 'c0000000-0000-4000-8000-0000000000b1';
  get diagnostics n = row_count; assert n = 0, 'cross-tenant delete must affect 0 rows';
  update public.organizations set name = 'hacked' where id = 'b0000000-0000-4000-8000-00000000000b';
  get diagnostics n = row_count; assert n = 0, 'cross-tenant org update must affect 0 rows';

  -- in-tenant write works
  update public.customers set name = 'A cust 2 renamed' where id = 'c0000000-0000-4000-8000-0000000000a2';
  get diagnostics n = row_count; assert n = 1, 'in-tenant update should work';
  raise notice 'PASS owner A: reads/updates/deletes isolated';
end $$;

do $$ begin  -- cross-tenant INSERT blocked by RLS WITH CHECK
  begin
    insert into public.customers (organization_id, name) values ('b0000000-0000-4000-8000-00000000000b', 'evil');
    raise exception 'FAIL: cross-tenant insert succeeded';
  exception when insufficient_privilege then raise notice 'PASS cross-tenant customer insert blocked'; end;
  begin
    insert into public.memberships (organization_id, user_id, role)
      values ('b0000000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-00000000000a', 'owner');
    raise exception 'FAIL: self-granted membership in B succeeded';
  exception when insufficient_privilege then raise notice 'PASS cannot add self to org B'; end;
end $$;

do $$ begin  -- composite FK: own org id but another tenant's parent row
  begin
    insert into public.farms (organization_id, customer_id, name)
      values ('b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000b1', 'cross-ref');
    raise exception 'FAIL: farm referencing B customer succeeded';
  exception when foreign_key_violation then raise notice 'PASS cross-tenant FK reference rejected'; end;
end $$;

do $$ begin  -- moving a row into another tenant
  begin
    update public.customers set organization_id = 'b0000000-0000-4000-8000-00000000000b'
      where id = 'c0000000-0000-4000-8000-0000000000a2';
    raise exception 'FAIL: moved row to org B';
  exception when check_violation or insufficient_privilege then raise notice 'PASS organization_id immutable'; end;
end $$;

do $$ declare n int; begin  -- server-only tables
  begin
    insert into public.audit_logs (organization_id, action) values ('b0000000-0000-4000-8000-00000000000a', 'x');
    raise exception 'FAIL: client inserted audit log';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.agent_runs (organization_id, agent_name) values ('b0000000-0000-4000-8000-00000000000a', 'x');
    raise exception 'FAIL: client inserted agent run';
  exception when insufficient_privilege then null; end;
  begin
    delete from public.audit_logs;
    raise exception 'FAIL: client deleted audit logs';
  exception when insufficient_privilege then null; end;
  select count(*) into n from public.audit_logs;
  assert n = 1, 'owner can read own org audit logs';
  begin
    insert into public.organizations (name, slug) values ('new', 'new');
    raise exception 'FAIL: client created organization';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS audit_logs/agent_runs/organizations are server-side write only';
end $$;
reset role;

-- =====================================================================
-- Owner of Org B (symmetry)
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
set local role authenticated;
do $$ declare n int; begin
  select count(*) into n from public.customers; assert n = 1, 'B sees only its own customer';
  select count(*) into n from public.farms where organization_id = 'b0000000-0000-4000-8000-00000000000a';
  assert n = 0, 'B must not read A farms';
  select count(*) into n from public.audit_logs; assert n = 0, 'B must not read A audit logs';
  update public.service_tickets set title = 'hacked' where id = 'e0000000-0000-4000-8000-0000000000a1';
  get diagnostics n = row_count; assert n = 0, 'B cannot update A ticket';
  raise notice 'PASS owner B isolated from A';
end $$;
reset role;

-- =====================================================================
-- Administrator of Org A: cannot mint owners
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
set local role authenticated;
do $$ declare n int; begin
  begin
    insert into public.memberships (organization_id, user_id, role)
      values ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-00000000000b', 'owner');
    raise exception 'FAIL: admin created an owner membership';
  exception when insufficient_privilege then null; end;
  update public.memberships set role = 'administrator'
    where organization_id = 'b0000000-0000-4000-8000-00000000000a' and role = 'owner';
  get diagnostics n = row_count; assert n = 0, 'admin cannot modify owner membership';
  raise notice 'PASS administrator cannot escalate to/alter owner';
end $$;
reset role;

-- =====================================================================
-- Technician of Org A
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
set local role authenticated;
do $$ declare n int; begin
  update public.service_tickets set status = 'in_progress' where id = 'e0000000-0000-4000-8000-0000000000a1';
  get diagnostics n = row_count; assert n = 1, 'technician updates assigned ticket';
  update public.service_tickets set status = 'in_progress' where id = 'e0000000-0000-4000-8000-0000000000a2';
  get diagnostics n = row_count; assert n = 0, 'technician cannot update unassigned ticket';
  begin
    update public.service_tickets set assigned_to = null where id = 'e0000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL: technician unassigned themselves';
  exception when insufficient_privilege then null; end;
  insert into public.diagnoses (organization_id, ticket_id, created_by, summary)
    values ('b0000000-0000-4000-8000-00000000000a', 'e0000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-00000000000d', 'ok');
  begin
    insert into public.diagnoses (organization_id, ticket_id, created_by, summary)
      values ('b0000000-0000-4000-8000-00000000000a', 'e0000000-0000-4000-8000-0000000000a2', 'a0000000-0000-4000-8000-00000000000d', 'not mine');
    raise exception 'FAIL: diagnosis on unassigned ticket';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.customers (organization_id, name) values ('b0000000-0000-4000-8000-00000000000a', 'x');
    raise exception 'FAIL: technician created a customer';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS technician limited to assigned tickets + own diagnoses';
end $$;
reset role;

-- =====================================================================
-- Farmer of Org A (linked to customer A1)
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
set local role authenticated;
do $$ declare n int; begin
  select count(*) into n from public.customers; assert n = 1, format('farmer sees only own customer, saw %s', n);
  select count(*) into n from public.farms; assert n = 1, 'farmer sees only own farm';
  select count(*) into n from public.service_tickets; assert n = 1, 'farmer sees only own tickets';
  select count(*) into n from public.diagnoses; assert n = 1, 'farmer sees diagnosis on own ticket';
  update public.customers set name = 'x' where id = 'c0000000-0000-4000-8000-0000000000a1';
  get diagnostics n = row_count; assert n = 0, 'farmer cannot update customers';
  begin
    insert into public.farms (organization_id, customer_id, name)
      values ('b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a1', 'x');
    raise exception 'FAIL: farmer created a farm';
  exception when insufficient_privilege then null; end;
  insert into public.service_tickets (organization_id, customer_id, created_by, title)
    values ('b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a1', 'a0000000-0000-4000-8000-00000000000e', 'my pump is slow');
  begin
    insert into public.service_tickets (organization_id, customer_id, created_by, title)
      values ('b0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-0000000000a2', 'a0000000-0000-4000-8000-00000000000e', 'for someone else');
    raise exception 'FAIL: farmer raised ticket for another customer';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS farmer scoped to own customer record';
end $$;
reset role;

-- =====================================================================
-- Data-integrity constraints (as superuser)
-- =====================================================================
do $$ begin
  begin
    insert into public.borewells (organization_id, farm_id, name, depth_m, static_water_level_m, pumping_water_level_m)
      values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1', 'bad', 100, 40, 30);
    raise exception 'FAIL: pumping < static accepted';
  exception when check_violation then null; end;
  begin
    insert into public.borewells (organization_id, farm_id, name, depth_m, static_water_level_m, pumping_water_level_m)
      values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1', 'bad', 100, 40, 120);
    raise exception 'FAIL: pumping >= depth accepted';
  exception when check_violation then null; end;
  insert into public.products (id, organization_id, name, is_sample)
    values ('f0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-00000000000a', 'SAMPLE test product', true);
  begin
    update public.products set verification_status = 'verified', source_reference = 'x', verified_at = now()
      where id = 'f0000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL: sample product marked verified';
  exception when check_violation then null; end;
  begin
    insert into public.pump_curves (organization_id, product_id, curve_points, is_sample)
      values ('b0000000-0000-4000-8000-00000000000a', 'f0000000-0000-4000-8000-0000000000a1', '[{"flow_lpm":1}]', true);
    raise exception 'FAIL: malformed curve accepted';
  exception when check_violation then null; end;
  insert into public.pump_curves (organization_id, product_id, curve_points, is_sample)
    values ('b0000000-0000-4000-8000-00000000000a', 'f0000000-0000-4000-8000-0000000000a1',
            '[{"flow_lpm":0,"head_m":1},{"flow_lpm":1,"head_m":0.5,"efficiency_pct":10}]', true);
  raise notice 'PASS borewell / verification / curve CHECK constraints';
end $$;

rollback;
