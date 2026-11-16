-- AquaOS migration 3: AI / audit tables. agent_runs and audit_logs are written server-side only.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  customer_id uuid,
  ticket_id uuid,
  title text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, customer_id) references public.customers (organization_id, id) on delete set null (customer_id),
  foreign key (organization_id, ticket_id) references public.service_tickets (organization_id, id) on delete set null (ticket_id)
);
create index conversations_organization_id_idx on public.conversations (organization_id);
create index conversations_user_id_idx on public.conversations (user_id);
create index conversations_customer_id_idx on public.conversations (customer_id);
create index conversations_ticket_id_idx on public.conversations (ticket_id);

create table public.agent_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid references auth.users (id) on delete set null,
  conversation_id uuid,
  agent_name text not null,
  model text,
  status public.agent_run_status not null default 'running',
  input jsonb,
  output jsonb,
  input_tokens integer check (input_tokens >= 0),
  output_tokens integer check (output_tokens >= 0),
  error text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, id),
  foreign key (organization_id, conversation_id) references public.conversations (organization_id, id) on delete set null (conversation_id)
);
create index agent_runs_organization_id_idx on public.agent_runs (organization_id);
create index agent_runs_user_id_idx on public.agent_runs (user_id);
create index agent_runs_conversation_id_idx on public.agent_runs (conversation_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  conversation_id uuid not null,
  role public.message_role not null,
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  agent_run_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, conversation_id) references public.conversations (organization_id, id) on delete cascade,
  foreign key (organization_id, agent_run_id) references public.agent_runs (organization_id, id) on delete set null (agent_run_id)
);
create index messages_organization_id_idx on public.messages (organization_id);
create index messages_conversation_id_idx on public.messages (conversation_id);
create index messages_agent_run_id_idx on public.messages (agent_run_id);

create table public.diagnoses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  ticket_id uuid not null,
  created_by uuid references auth.users (id) on delete set null,
  agent_run_id uuid,
  summary text not null,
  findings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, ticket_id) references public.service_tickets (organization_id, id) on delete cascade,
  foreign key (organization_id, agent_run_id) references public.agent_runs (organization_id, id) on delete set null (agent_run_id)
);
create index diagnoses_organization_id_idx on public.diagnoses (organization_id);
create index diagnoses_ticket_id_idx on public.diagnoses (ticket_id);
create index diagnoses_created_by_idx on public.diagnoses (created_by);
create index diagnoses_agent_run_id_idx on public.diagnoses (agent_run_id);

create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  customer_id uuid,
  farm_id uuid,
  borewell_id uuid,
  product_id uuid,
  pump_curve_id uuid,
  conversation_id uuid,
  agent_run_id uuid,
  title text not null,
  rationale text,
  payload jsonb not null default '{}'::jsonb,
  status public.recommendation_status not null default 'draft',
  -- true when any input (product / curve) was sample or unverified; UI must surface this.
  uses_unverified_data boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (organization_id, customer_id) references public.customers (organization_id, id) on delete set null (customer_id),
  foreign key (organization_id, farm_id) references public.farms (organization_id, id) on delete set null (farm_id),
  foreign key (organization_id, borewell_id) references public.borewells (organization_id, id) on delete set null (borewell_id),
  foreign key (organization_id, product_id) references public.products (organization_id, id) on delete set null (product_id),
  foreign key (organization_id, pump_curve_id) references public.pump_curves (organization_id, id) on delete set null (pump_curve_id),
  foreign key (organization_id, conversation_id) references public.conversations (organization_id, id) on delete set null (conversation_id),
  foreign key (organization_id, agent_run_id) references public.agent_runs (organization_id, id) on delete set null (agent_run_id)
);
create index recommendations_organization_id_idx on public.recommendations (organization_id);
create index recommendations_customer_id_idx on public.recommendations (customer_id);
create index recommendations_farm_id_idx on public.recommendations (farm_id);
create index recommendations_borewell_id_idx on public.recommendations (borewell_id);
create index recommendations_product_id_idx on public.recommendations (product_id);
create index recommendations_pump_curve_id_idx on public.recommendations (pump_curve_id);
create index recommendations_conversation_id_idx on public.recommendations (conversation_id);
create index recommendations_agent_run_id_idx on public.recommendations (agent_run_id);
create index recommendations_created_by_idx on public.recommendations (created_by);

-- Append-only: no updated_at column and no update trigger by design.
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  actor_id uuid references auth.users (id) on delete set null,
  action text not null,
  table_name text,
  record_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_organization_id_idx on public.audit_logs (organization_id);
create index audit_logs_actor_id_idx on public.audit_logs (actor_id);
