-- AquaOS migration 4: updated_at / immutability triggers, grants, Row Level Security.
-- No policy references the service role: privileged work runs server-side with a key that bypasses RLS.

-- ---------- Triggers ----------
do $$
declare t text;
begin
  foreach t in array array['organizations','profiles','memberships','customers','farms','borewells','products',
    'pump_curves','installations','service_tickets','diagnoses','conversations','messages','recommendations','agent_runs']
  loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
  end loop;
  foreach t in array array['memberships','customers','farms','borewells','products','pump_curves','installations',
    'service_tickets','diagnoses','conversations','messages','recommendations','agent_runs','audit_logs']
  loop
    execute format('create trigger prevent_org_change before update on public.%I for each row execute function public.prevent_org_change()', t);
  end loop;
end $$;

-- ---------- Privileges (defence in depth on top of RLS) ----------
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke insert, update, delete on public.audit_logs, public.agent_runs from authenticated;
revoke insert, delete on public.organizations from authenticated;

-- ---------- Enable RLS on every table ----------
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.customers enable row level security;
alter table public.farms enable row level security;
alter table public.borewells enable row level security;
alter table public.products enable row level security;
alter table public.pump_curves enable row level security;
alter table public.installations enable row level security;
alter table public.service_tickets enable row level security;
alter table public.diagnoses enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.recommendations enable row level security;
alter table public.agent_runs enable row level security;
alter table public.audit_logs enable row level security;

-- Role sets used below:
--   admins = owner, administrator
--   managers = owner, administrator, employee
--   staff = owner, administrator, employee, technician

-- ---------- organizations (create/delete is server-side only) ----------
create policy organizations_select on public.organizations for select to authenticated
  using (public.is_org_member(id));
create policy organizations_update on public.organizations for update to authenticated
  using (public.has_org_role(id, array['owner','administrator']::public.org_role[]))
  with check (public.has_org_role(id, array['owner','administrator']::public.org_role[]));

-- ---------- profiles ----------
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_insert on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- ---------- memberships ----------
-- Read: own row, or owner/administrator sees the whole org roster.
-- Only an owner may create/modify/delete owner memberships (no admin self-escalation).
create policy memberships_select on public.memberships for select to authenticated
  using (user_id = (select auth.uid())
         or public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));
create policy memberships_insert on public.memberships for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[])
              and (role <> 'owner' or public.has_org_role(organization_id, array['owner']::public.org_role[])));
create policy memberships_update on public.memberships for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[])
         and (role <> 'owner' or public.has_org_role(organization_id, array['owner']::public.org_role[])))
  with check (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[])
              and (role <> 'owner' or public.has_org_role(organization_id, array['owner']::public.org_role[])));
create policy memberships_delete on public.memberships for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[])
         and (role <> 'owner' or public.has_org_role(organization_id, array['owner']::public.org_role[])));

-- ---------- customers ----------
create policy customers_select on public.customers for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or id = public.my_customer_id(organization_id));
create policy customers_insert on public.customers for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy customers_update on public.customers for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy customers_delete on public.customers for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- farms ----------
create policy farms_select on public.farms for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or customer_id = public.my_customer_id(organization_id));
create policy farms_insert on public.farms for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy farms_update on public.farms for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy farms_delete on public.farms for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- borewells (farmer access through the owning farm) ----------
create policy borewells_select on public.borewells for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or exists (select 1 from public.farms f
                    where f.id = farm_id and f.organization_id = borewells.organization_id
                      and f.customer_id = public.my_customer_id(borewells.organization_id)));
create policy borewells_insert on public.borewells for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy borewells_update on public.borewells for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy borewells_delete on public.borewells for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- products / pump_curves: org-wide catalogue, managed by owner/administrator ----------
create policy products_select on public.products for select to authenticated
  using (public.is_org_member(organization_id));
create policy products_write on public.products for all to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

create policy pump_curves_select on public.pump_curves for select to authenticated
  using (public.is_org_member(organization_id));
create policy pump_curves_write on public.pump_curves for all to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- installations ----------
create policy installations_select on public.installations for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or customer_id = public.my_customer_id(organization_id));
create policy installations_insert on public.installations for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy installations_update on public.installations for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy installations_delete on public.installations for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- service_tickets ----------
create policy tickets_select on public.service_tickets for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or customer_id = public.my_customer_id(organization_id));
create policy tickets_insert_staff on public.service_tickets for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
-- A farmer may raise a ticket for their own customer record only, always unassigned and open.
create policy tickets_insert_farmer on public.service_tickets for insert to authenticated
  with check (public.has_org_role(organization_id, array['farmer']::public.org_role[])
              and customer_id = public.my_customer_id(organization_id)
              and created_by = (select auth.uid()) and assigned_to is null and status = 'open');
create policy tickets_update_staff on public.service_tickets for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy tickets_update_technician on public.service_tickets for update to authenticated
  using (public.has_org_role(organization_id, array['technician']::public.org_role[])
         and assigned_to = (select auth.uid()))
  with check (public.has_org_role(organization_id, array['technician']::public.org_role[])
              and assigned_to = (select auth.uid()));
create policy tickets_delete on public.service_tickets for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- diagnoses ----------
create policy diagnoses_select on public.diagnoses for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or exists (select 1 from public.service_tickets t
                    where t.id = ticket_id and t.organization_id = diagnoses.organization_id
                      and t.customer_id = public.my_customer_id(diagnoses.organization_id)));
create policy diagnoses_insert on public.diagnoses for insert to authenticated
  with check (created_by = (select auth.uid())
              and (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[])
                   or (public.has_org_role(organization_id, array['technician']::public.org_role[])
                       and exists (select 1 from public.service_tickets t
                                   where t.id = ticket_id and t.organization_id = diagnoses.organization_id
                                     and t.assigned_to = (select auth.uid())))));
create policy diagnoses_update on public.diagnoses for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[])
         or (public.has_org_role(organization_id, array['technician']::public.org_role[]) and created_by = (select auth.uid())))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[])
              or (public.has_org_role(organization_id, array['technician']::public.org_role[]) and created_by = (select auth.uid())));
create policy diagnoses_delete on public.diagnoses for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- conversations: private to their author; owner/administrator can read all ----------
create policy conversations_select on public.conversations for select to authenticated
  using (user_id = (select auth.uid()) and public.is_org_member(organization_id)
         or public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));
create policy conversations_insert on public.conversations for insert to authenticated
  with check (user_id = (select auth.uid()) and public.is_org_member(organization_id));
create policy conversations_update on public.conversations for update to authenticated
  using (user_id = (select auth.uid()) and public.is_org_member(organization_id))
  with check (user_id = (select auth.uid()) and public.is_org_member(organization_id));
create policy conversations_delete on public.conversations for delete to authenticated
  using (user_id = (select auth.uid()) and public.is_org_member(organization_id));

-- ---------- messages: clients insert only their own 'user' messages; assistant/tool rows are server-side ----------
create policy messages_select on public.messages for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[])
         or exists (select 1 from public.conversations c
                    where c.id = conversation_id and c.organization_id = messages.organization_id
                      and c.user_id = (select auth.uid())));
create policy messages_insert on public.messages for insert to authenticated
  with check (role = 'user' and agent_run_id is null and public.is_org_member(organization_id)
              and exists (select 1 from public.conversations c
                          where c.id = conversation_id and c.organization_id = messages.organization_id
                            and c.user_id = (select auth.uid())));

-- ---------- recommendations ----------
create policy recommendations_select on public.recommendations for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee','technician']::public.org_role[])
         or customer_id = public.my_customer_id(organization_id));
create policy recommendations_insert on public.recommendations for insert to authenticated
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy recommendations_update on public.recommendations for update to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]))
  with check (public.has_org_role(organization_id, array['owner','administrator','employee']::public.org_role[]));
create policy recommendations_delete on public.recommendations for delete to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));

-- ---------- agent_runs / audit_logs: read-only for owner/administrator; no client write policies exist ----------
create policy agent_runs_select on public.agent_runs for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));
create policy audit_logs_select on public.audit_logs for select to authenticated
  using (public.has_org_role(organization_id, array['owner','administrator']::public.org_role[]));
