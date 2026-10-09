-- ============================================================
-- Crash ERP - Supabase schema (run once in SQL Editor)
-- Multi-tenant: every row belongs to an organization (org_id)
-- ============================================================
create extension if not exists "pgcrypto";

-- ---------- Tenancy ----------
create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'My Company',
  tax_id text,
  logo_url text,
  currency text default 'EGP',
  created_at timestamptz default now()
);

create table if not exists public.org_members (
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin','cashier','accountant','storekeeper')),
  created_at timestamptz default now(),
  primary key (org_id, user_id)
);

create table if not exists public.subscriptions (
  org_id uuid primary key references public.organizations(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free','starter','business','enterprise')),
  expires_at timestamptz,
  gateway text check (gateway in ('paymob','fawry','stripe')),
  last_payment_ref text,
  updated_at timestamptz default now()
);

-- ---------- Helper functions ----------
create or replace function public.current_org_id() returns uuid
language sql stable security definer set search_path = public as $$
  select org_id from public.org_members where user_id = auth.uid() limit 1
$$;

create or replace function public.can_write(tbl text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.org_members m
    where m.user_id = auth.uid() and (
      m.role = 'admin'
      or (m.role = 'cashier'    and tbl in ('invoices','customers'))
      or (m.role = 'accountant' and tbl in ('expenses','journal_entries','invoices','customers','suppliers','purchase_orders'))
      or (m.role = 'storekeeper' and tbl in ('products','warehouses','stock_transfers','purchase_orders','suppliers','boms'))
    )
  )
$$;

-- effective plan (falls back to free when expired)
create or replace function public.org_plan(p_org uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce((
    select case when s.plan = 'free' or s.expires_at > now() then s.plan else 'free' end
    from public.subscriptions s where s.org_id = p_org
  ), 'free')
$$;

-- new user => new organization + admin membership + free plan
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  insert into public.organizations(name) values ('My Company') returning id into v_org;
  insert into public.org_members(org_id, user_id, role) values (v_org, new.id, 'admin');
  insert into public.subscriptions(org_id, plan) values (v_org, 'free');
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Business tables ----------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  name text not null, barcode text, sku text,
  price numeric(14,2) default 0, cost numeric(14,2) default 0,
  stock numeric(14,2) default 0, min_stock numeric(14,2) default 0,
  warehouse text, serial text,
  created_at timestamptz default now()
);

create table if not exists public.warehouses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  name text not null, location text,
  created_at timestamptz default now()
);

create table if not exists public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  product text, from_wh text, to_wh text, qty numeric(14,2) default 0, date date default current_date,
  created_at timestamptz default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  name text not null, phone text, email text,
  balance numeric(14,2) default 0, points numeric(14,2) default 0,
  created_at timestamptz default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  name text not null, phone text, balance numeric(14,2) default 0,
  created_at timestamptz default now()
);

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  supplier text, total numeric(14,2) default 0, status text default 'open', date date default current_date,
  created_at timestamptz default now()
);

create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  number text, customer text,
  total numeric(14,2) default 0, tax numeric(14,2) default 0, discount numeric(14,2) default 0,
  payment_method text default 'cash', kind text default 'sale' check (kind in ('sale','return')),
  date date default current_date, items jsonb default '[]'::jsonb,
  created_at timestamptz default now()
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  title text, amount numeric(14,2) default 0, kind text default 'expense' check (kind in ('expense','income')),
  account text, date date default current_date,
  created_at timestamptz default now()
);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  date date default current_date, description text,
  debit_account text, credit_account text, amount numeric(14,2) default 0,
  created_at timestamptz default now()
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  name text not null, job text, salary numeric(14,2) default 0, commission_pct numeric(6,2) default 0,
  created_at timestamptz default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  employee text, date date default current_date, check_in text, check_out text,
  created_at timestamptz default now()
);

create table if not exists public.boms (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null default public.current_org_id() references public.organizations(id) on delete cascade,
  product text, components text, cost numeric(14,2) default 0,
  created_at timestamptz default now()
);

-- ---------- Indexes ----------
create index if not exists idx_invoices_org_date on public.invoices(org_id, date);
create index if not exists idx_products_org_barcode on public.products(org_id, barcode);
create index if not exists idx_expenses_org_date on public.expenses(org_id, date);
create index if not exists idx_journal_org_date on public.journal_entries(org_id, date);

-- ---------- Plan limits enforced on the server ----------
create or replace function public.enforce_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_plan text; v_limit int; v_count int; v_exists boolean;
begin
  v_plan := public.org_plan(new.org_id);
  if tg_table_name = 'invoices' then
    select exists(select 1 from public.invoices where id = new.id) into v_exists;
    if v_exists then return new; end if;
    v_limit := case v_plan when 'free' then 100 when 'starter' then 1000 else -1 end;
    select count(*) into v_count from public.invoices where org_id = new.org_id;
  elsif tg_table_name = 'warehouses' then
    select exists(select 1 from public.warehouses where id = new.id) into v_exists;
    if v_exists then return new; end if;
    v_limit := case v_plan when 'free' then 1 when 'starter' then 2 else -1 end;
    select count(*) into v_count from public.warehouses where org_id = new.org_id;
  elsif tg_table_name = 'org_members' then
    v_limit := case v_plan when 'free' then 1 when 'starter' then 3 when 'business' then 10 else -1 end;
    select count(*) into v_count from public.org_members where org_id = new.org_id;
  end if;
  if v_limit >= 0 and v_count >= v_limit then
    raise exception 'PLAN_LIMIT_REACHED: upgrade your plan';
  end if;
  return new;
end $$;

drop trigger if exists trg_limit_invoices on public.invoices;
create trigger trg_limit_invoices before insert on public.invoices
  for each row execute function public.enforce_limit();
drop trigger if exists trg_limit_warehouses on public.warehouses;
create trigger trg_limit_warehouses before insert on public.warehouses
  for each row execute function public.enforce_limit();
drop trigger if exists trg_limit_members on public.org_members;
create trigger trg_limit_members before insert on public.org_members
  for each row execute function public.enforce_limit();

-- ---------- Row Level Security ----------
alter table public.organizations enable row level security;
alter table public.org_members   enable row level security;
alter table public.subscriptions enable row level security;

drop policy if exists org_select on public.organizations;
create policy org_select on public.organizations for select using (id = public.current_org_id());
drop policy if exists org_update on public.organizations;
create policy org_update on public.organizations for update
  using (id = public.current_org_id() and public.can_write('organizations'));

drop policy if exists members_select on public.org_members;
create policy members_select on public.org_members for select using (org_id = public.current_org_id());
drop policy if exists members_admin on public.org_members;
create policy members_admin on public.org_members for all
  using (org_id = public.current_org_id() and exists (
    select 1 from public.org_members m where m.user_id = auth.uid() and m.role = 'admin' and m.org_id = org_members.org_id))
  with check (org_id = public.current_org_id());

-- subscriptions: read-only for clients; written only by the payment webhook (service role)
drop policy if exists sub_select on public.subscriptions;
create policy sub_select on public.subscriptions for select using (org_id = public.current_org_id());

do $$
declare t text;
begin
  foreach t in array array['products','warehouses','stock_transfers','customers','suppliers',
    'purchase_orders','invoices','expenses','journal_entries','employees','attendance','boms']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%1$s_select" on public.%1$I', t);
    execute format('drop policy if exists "%1$s_write" on public.%1$I', t);
    execute format('create policy "%1$s_select" on public.%1$I for select using (org_id = public.current_org_id())', t);
    execute format('create policy "%1$s_write" on public.%1$I for all
      using (org_id = public.current_org_id() and public.can_write(%1$L))
      with check (org_id = public.current_org_id() and public.can_write(%1$L))', t);
  end loop;
end $$;

-- ---------- Realtime (optional) ----------
-- alter publication supabase_realtime add table public.invoices, public.products;
