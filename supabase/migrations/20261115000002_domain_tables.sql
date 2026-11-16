-- AquaOS migration 2: domain tables.
-- Child rows reference parents with COMPOSITE FKs (organization_id, parent_id) so a row can never
-- point at a parent in another tenant, regardless of what a client supplies.

create table public.farms (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  customer_id uuid not null,
  name text not null,
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  area_acres numeric(10,2) check (area_acres > 0),
  crop text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, customer_id) references public.customers (organization_id, id) on delete cascade
);
create index farms_organization_id_idx on public.farms (organization_id);
create index farms_customer_id_idx on public.farms (customer_id);

create table public.borewells (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  farm_id uuid not null,
  name text not null,
  depth_m numeric(7,2) not null check (depth_m > 0),
  static_water_level_m numeric(7,2) check (static_water_level_m >= 0),
  pumping_water_level_m numeric(7,2),
  casing_diameter_mm numeric(7,1) check (casing_diameter_mm > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, farm_id) references public.farms (organization_id, id) on delete cascade,
  constraint borewells_static_lt_depth check (static_water_level_m < depth_m),
  constraint borewells_pumping_lt_depth check (pumping_water_level_m < depth_m),
  constraint borewells_pumping_ge_static check (pumping_water_level_m >= static_water_level_m)
);
create index borewells_organization_id_idx on public.borewells (organization_id);
create index borewells_farm_id_idx on public.borewells (farm_id);

-- Catalogue. Rows are 'unverified' until a human confirms them against a cited manufacturer source.
create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  category text not null default 'pump',
  manufacturer text,
  model text,
  specs jsonb not null default '{}'::jsonb,
  is_sample boolean not null default false,
  verification_status public.verification_status not null default 'unverified',
  source_type text,          -- e.g. 'manufacturer_catalogue', 'datasheet', 'manual_entry'
  source_reference text,     -- document title / catalogue id / page
  source_url text,
  verified_by uuid references auth.users (id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  -- sample data can never be marked verified; verified data must cite a source
  constraint products_verified_needs_source check (
    verification_status = 'unverified'
    or (not is_sample and source_reference is not null and verified_at is not null))
);
create index products_organization_id_idx on public.products (organization_id);
create index products_verified_by_idx on public.products (verified_by);

-- Validates [{flow_lpm, head_m, efficiency_pct?}, ...] with >= 2 points.
create function public.valid_curve_points(pts jsonb) returns boolean
language plpgsql immutable set search_path = '' as $$
declare p jsonb;
begin
  if jsonb_typeof(pts) is distinct from 'array' or jsonb_array_length(pts) < 2 then
    return false;
  end if;
  for p in select * from jsonb_array_elements(pts) loop
    if jsonb_typeof(p) is distinct from 'object'
       or jsonb_typeof(p -> 'flow_lpm') is distinct from 'number'
       or jsonb_typeof(p -> 'head_m') is distinct from 'number'
       or (p ->> 'flow_lpm')::numeric < 0 or (p ->> 'head_m')::numeric < 0 then
      return false;
    end if;
    if p ? 'efficiency_pct' and (
         jsonb_typeof(p -> 'efficiency_pct') is distinct from 'number'
         or (p ->> 'efficiency_pct')::numeric not between 0 and 100) then
      return false;
    end if;
  end loop;
  return true;
end $$;

create table public.pump_curves (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  product_id uuid not null,
  rpm integer check (rpm > 0),
  curve_points jsonb not null,
  is_sample boolean not null default false,
  verification_status public.verification_status not null default 'unverified',
  source_type text,
  source_reference text,
  source_url text,
  verified_by uuid references auth.users (id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, product_id) references public.products (organization_id, id) on delete cascade,
  constraint pump_curves_points_valid check (public.valid_curve_points(curve_points)),
  constraint pump_curves_verified_needs_source check (
    verification_status = 'unverified'
    or (not is_sample and source_reference is not null and verified_at is not null))
);
create index pump_curves_organization_id_idx on public.pump_curves (organization_id);
create index pump_curves_product_id_idx on public.pump_curves (product_id);
create index pump_curves_verified_by_idx on public.pump_curves (verified_by);

create table public.installations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  customer_id uuid not null,
  farm_id uuid,
  borewell_id uuid,
  product_id uuid,
  pump_curve_id uuid,
  installed_on date,
  installed_by uuid references auth.users (id) on delete set null,
  status text not null default 'active' check (status in ('planned', 'active', 'decommissioned')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, customer_id) references public.customers (organization_id, id) on delete restrict,
  foreign key (organization_id, farm_id) references public.farms (organization_id, id) on delete set null (farm_id),
  foreign key (organization_id, borewell_id) references public.borewells (organization_id, id) on delete set null (borewell_id),
  foreign key (organization_id, product_id) references public.products (organization_id, id) on delete set null (product_id),
  foreign key (organization_id, pump_curve_id) references public.pump_curves (organization_id, id) on delete set null (pump_curve_id)
);
create index installations_organization_id_idx on public.installations (organization_id);
create index installations_customer_id_idx on public.installations (customer_id);
create index installations_farm_id_idx on public.installations (farm_id);
create index installations_borewell_id_idx on public.installations (borewell_id);
create index installations_product_id_idx on public.installations (product_id);
create index installations_pump_curve_id_idx on public.installations (pump_curve_id);
create index installations_installed_by_idx on public.installations (installed_by);

create table public.service_tickets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  customer_id uuid not null,
  installation_id uuid,
  assigned_to uuid references auth.users (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  title text not null,
  description text,
  status public.ticket_status not null default 'open',
  priority public.ticket_priority not null default 'medium',
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, customer_id) references public.customers (organization_id, id) on delete restrict,
  foreign key (organization_id, installation_id) references public.installations (organization_id, id) on delete set null (installation_id)
);
create index service_tickets_organization_id_idx on public.service_tickets (organization_id);
create index service_tickets_customer_id_idx on public.service_tickets (customer_id);
create index service_tickets_installation_id_idx on public.service_tickets (installation_id);
create index service_tickets_assigned_to_idx on public.service_tickets (assigned_to);
create index service_tickets_created_by_idx on public.service_tickets (created_by);
