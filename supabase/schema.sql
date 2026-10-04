-- MedVerse — Supabase schema (Postgres)
-- Run in Supabase SQL editor. All tables use RLS: a user sees only their own
-- account's data (and family members they manage).

create extension if not exists "pgcrypto";

-- ───────────── Accounts & family ─────────────
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  city text,
  language text not null default 'en' check (language in ('en','hi')),
  abha_number text,
  abha_linked_at timestamptz,
  asha_mode boolean not null default false,
  vault_pin_hash text,                -- bcrypt hash, verified in edge function
  created_at timestamptz not null default now()
);

create table family_members (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text not null,
  relation text not null,             -- Self, Mother, Father, Child, Other
  dob date,
  gender text check (gender in ('Female','Male','Other')),
  blood_group text,
  allergies text[] default '{}',
  conditions text[] default '{}',
  emergency_contact text,
  is_asha_patient boolean not null default false, -- managed in ASHA mode
  village text,
  created_at timestamptz not null default now()
);
create index on family_members(owner_id);

-- ───────────── Records ─────────────
create type record_type as enum ('report','prescription','scan','discharge');
create type record_status as enum ('uploaded','ocr_done','simplified','failed');

create table records (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  member_id uuid not null references family_members(id) on delete cascade,
  type record_type not null,
  title text,
  hospital text,
  doctor text,
  record_date date,
  storage_paths text[] not null,      -- files in bucket 'records'
  status record_status not null default 'uploaded',
  ocr_lines text[],                   -- raw OCR text, one entry per line
  summary_en text,
  summary_hi text,
  is_private boolean not null default false,
  tags text[] default '{}',
  has_critical boolean not null default false,
  created_at timestamptz not null default now()
);
create index on records(member_id, record_date desc);

-- One row per extracted lab value
create table lab_values (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references records(id) on delete cascade,
  member_id uuid not null references family_members(id) on delete cascade,
  test_code text not null,            -- normalised key e.g. 'HB', 'TSH', 'HBA1C'
  name text not null,
  value_text text not null,
  value_num numeric,
  unit text,
  value_norm numeric,                 -- converted to canonical unit for trends
  unit_norm text,
  ref_low numeric,
  ref_high numeric,
  status text check (status in ('normal','low','high','critical')),
  simple_en text,
  simple_hi text,
  source_line int,                    -- index into records.ocr_lines
  ocr_confidence real,
  measured_on date
);
create index on lab_values(member_id, test_code, measured_on);

-- Medicines extracted from prescriptions
create table medicines (
  id uuid primary key default gen_random_uuid(),
  record_id uuid references records(id) on delete set null,
  member_id uuid not null references family_members(id) on delete cascade,
  brand_name text not null,
  generic_name text,
  drug_class text,                    -- e.g. 'NSAID' — used for duplicate-class alerts
  dose text,
  schedule text[],                    -- ['08:00','20:00'] or ['SOS']
  food_relation text,
  purpose text,
  prescribed_by text,
  start_date date,
  end_date date,
  active boolean not null default true
);

create table dose_logs (
  id uuid primary key default gen_random_uuid(),
  medicine_id uuid not null references medicines(id) on delete cascade,
  scheduled_for timestamptz not null,
  taken_at timestamptz,
  unique (medicine_id, scheduled_for)
);

-- Tests ordered on a prescription (for duplicate-test detection)
create table ordered_tests (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null references records(id) on delete cascade,
  member_id uuid not null references family_members(id) on delete cascade,
  test_code text not null,
  name text not null,
  duplicate_of uuid references records(id),   -- filled by edge function
  created_at timestamptz not null default now()
);

-- ───────────── Opinion comparison ─────────────
create table opinion_cases (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  member_id uuid not null references family_members(id) on delete cascade,
  condition text not null,
  record_a uuid not null references records(id) on delete cascade,
  record_b uuid not null references records(id) on delete cascade,
  why_differ text[],
  created_at timestamptz not null default now()
);

create table diff_points (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references opinion_cases(id) on delete cascade,
  position int not null,
  topic text not null,
  tag text not null check (tag in ('agree','differs','only_a','only_b')),
  doctor_a text,
  doctor_b text,
  plain_en text,
  plain_hi text
);

create table visit_questions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid references opinion_cases(id) on delete cascade,
  member_id uuid not null references family_members(id) on delete cascade,
  question text not null,
  is_custom boolean not null default false,
  selected boolean not null default true,
  asked boolean not null default false
);

-- ───────────── Alerts, appointments, sharing ─────────────
create table alerts (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references family_members(id) on delete cascade,
  kind text not null check (kind in ('critical_value','duplicate_test','trend','drug_overlap','reminder')),
  title text not null,
  body text,
  record_id uuid references records(id) on delete cascade,
  dismissed boolean not null default false,
  created_at timestamptz not null default now()
);

create table appointments (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references family_members(id) on delete cascade,
  doctor text not null,
  speciality text,
  place text,
  starts_at timestamptz not null,
  purpose text
);

create table share_links (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references family_members(id) on delete cascade,
  token text not null unique default encode(gen_random_bytes(16),'hex'),
  scope text not null default 'health_card', -- or 'record'
  record_id uuid references records(id) on delete cascade,
  expires_at timestamptz not null default now() + interval '24 hours',
  created_at timestamptz not null default now()
);

create table cycle_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references family_members(id) on delete cascade,
  day date not null,
  flow text,
  symptoms text[],
  unique(member_id, day)
);

create table pregnancies (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references family_members(id) on delete cascade,
  lmp date not null,
  anc_done int[] default '{}',
  active boolean not null default true
);

-- ───────────── Row-level security ─────────────
alter table profiles enable row level security;
create policy "own profile" on profiles for all using (id = auth.uid()) with check (id = auth.uid());

create or replace function owns_member(m uuid) returns boolean
language sql security definer stable as $$
  select exists(select 1 from family_members where id = m and owner_id = auth.uid())
$$;

alter table family_members enable row level security;
create policy "own members" on family_members for all
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['records','lab_values','medicines','ordered_tests','opinion_cases',
    'visit_questions','alerts','appointments','share_links','cycle_logs','pregnancies']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('create policy "member owner" on %I for all using (owns_member(member_id)) with check (owns_member(member_id))', t);
  end loop;
end $$;

alter table diff_points enable row level security;
create policy "case owner" on diff_points for all using (
  exists(select 1 from opinion_cases c where c.id = case_id and c.owner_id = auth.uid()));

alter table dose_logs enable row level security;
create policy "med owner" on dose_logs for all using (
  exists(select 1 from medicines m where m.id = medicine_id and owns_member(m.member_id)));

-- Private-vault records are excluded from shared health cards in the
-- `health-card` edge function (service role), never exposed via share_links.

-- Storage: create a private bucket 'records'; objects stored as {owner_id}/{record_id}/{n}.jpg
-- policy: (storage.foldername(name))[1] = auth.uid()::text
