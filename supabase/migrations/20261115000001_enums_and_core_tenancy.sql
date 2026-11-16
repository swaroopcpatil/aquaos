-- AquaOS migration 1: enums, shared trigger functions, core tenancy tables, RLS helper functions.
-- Targets Supabase PostgreSQL 15+ (composite FK ON DELETE SET NULL (cols) needs 15+).

-- ---------- Enums ----------
create type public.org_role as enum ('owner', 'administrator', 'employee', 'technician', 'farmer');
create type public.verification_status as enum ('unverified', 'verified');
create type public.ticket_status as enum ('open', 'assigned', 'in_progress', 'resolved', 'closed');
create type public.ticket_priority as enum ('low', 'medium', 'high', 'urgent');
create type public.message_role as enum ('user', 'assistant', 'system', 'tool');
create type public.recommendation_status as enum ('draft', 'proposed', 'accepted', 'rejected');
create type public.agent_run_status as enum ('running', 'succeeded', 'failed');

-- ---------- Shared trigger functions ----------
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- A row can never be moved to another tenant by an UPDATE.
create function public.prevent_org_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.organization_id is distinct from old.organization_id then
    raise exception 'organization_id is immutable' using errcode = '23514';
  end if;
  return new;
end $$;

-- ---------- Core tenancy ----------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) > 0),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]*$'),
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  locale text not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  phone text,
  email text,
  village text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id)  -- target for composite tenant-safe foreign keys
);
create index customers_organization_id_idx on public.customers (organization_id);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.org_role not null,
  -- For role 'farmer': the customer record this login represents.
  customer_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id),
  foreign key (organization_id, customer_id) references public.customers (organization_id, id)
    on delete set null (customer_id),
  check (customer_id is null or role = 'farmer')
);
create index memberships_organization_id_idx on public.memberships (organization_id);
create index memberships_user_id_idx on public.memberships (user_id);
create index memberships_customer_id_idx on public.memberships (customer_id);

-- ---------- RLS helper functions ----------
-- SECURITY DEFINER so they read memberships without re-entering memberships' own RLS (no recursion).
-- search_path is empty: every reference is schema-qualified.
create function public.is_org_member(org uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = org and m.user_id = (select auth.uid())
  );
$$;

create function public.has_org_role(org uuid, roles public.org_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.memberships m
    where m.organization_id = org and m.user_id = (select auth.uid()) and m.role = any (roles)
  );
$$;

-- Customer record linked to the calling farmer in this org (null for non-farmers).
create function public.my_customer_id(org uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select m.customer_id from public.memberships m
  where m.organization_id = org and m.user_id = (select auth.uid()) and m.role = 'farmer'
  limit 1;
$$;

revoke all on function public.is_org_member(uuid), public.has_org_role(uuid, public.org_role[]),
  public.my_customer_id(uuid) from public, anon;
grant execute on function public.is_org_member(uuid), public.has_org_role(uuid, public.org_role[]),
  public.my_customer_id(uuid) to authenticated;
