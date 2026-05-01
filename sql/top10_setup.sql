-- =========================================================================
-- Top 10 Strengths setup
-- Run this in the Supabase SQL editor (project: eekefsuaefgpqmjdyniy).
-- Safe to re-run: uses "if not exists" / "on conflict do nothing".
-- =========================================================================

-- -----------------------------------------------------------------------
-- 1. Catalog of all 34 Gallup CliftonStrengths themes
-- -----------------------------------------------------------------------
create table if not exists public.strengths_catalog (
  id          serial primary key,
  name        text not null unique,
  domain      text not null check (domain in (
                'Executing',
                'Influencing',
                'Relationship Building',
                'Strategic Thinking'
              )),
  sort_order  int  not null default 0
);

alter table public.strengths_catalog enable row level security;

drop policy if exists "catalog readable by authenticated" on public.strengths_catalog;
create policy "catalog readable by authenticated"
  on public.strengths_catalog
  for select
  to authenticated
  using (true);

-- Seed the 34 themes (alphabetical)
insert into public.strengths_catalog (name, domain, sort_order) values
  ('Achiever',          'Executing',              1),
  ('Activator',         'Influencing',            2),
  ('Adaptability',      'Relationship Building',  3),
  ('Analytical',        'Strategic Thinking',     4),
  ('Arranger',          'Executing',              5),
  ('Belief',            'Executing',              6),
  ('Command',           'Influencing',            7),
  ('Communication',     'Influencing',            8),
  ('Competition',       'Influencing',            9),
  ('Connectedness',     'Relationship Building', 10),
  ('Consistency',       'Executing',             11),
  ('Context',           'Strategic Thinking',    12),
  ('Deliberative',      'Executing',             13),
  ('Developer',         'Relationship Building', 14),
  ('Discipline',        'Executing',             15),
  ('Empathy',           'Relationship Building', 16),
  ('Focus',             'Executing',             17),
  ('Futuristic',        'Strategic Thinking',    18),
  ('Harmony',           'Relationship Building', 19),
  ('Ideation',          'Strategic Thinking',    20),
  ('Includer',          'Relationship Building', 21),
  ('Individualization', 'Relationship Building', 22),
  ('Input',             'Strategic Thinking',    23),
  ('Intellection',      'Strategic Thinking',    24),
  ('Learner',           'Strategic Thinking',    25),
  ('Maximizer',         'Influencing',           26),
  ('Positivity',        'Relationship Building', 27),
  ('Relator',           'Relationship Building', 28),
  ('Responsibility',    'Executing',             29),
  ('Restorative',       'Executing',             30),
  ('Self-Assurance',    'Influencing',           31),
  ('Significance',      'Influencing',           32),
  ('Strategic',         'Strategic Thinking',    33),
  ('Woo',               'Influencing',           34)
on conflict (name) do nothing;


-- -----------------------------------------------------------------------
-- 2. A user's top 10 (one row per ranked strength, max 10 rows per user)
--    name_it / claim_it / aim_it hold the per-client coaching notes.
-- -----------------------------------------------------------------------
create table if not exists public.user_top_strengths (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  strength_id int  not null references public.strengths_catalog(id),
  rank        int  not null check (rank between 1 and 10),
  name_it     text,
  claim_it    text,
  aim_it      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, rank),
  unique (user_id, strength_id)
);

create index if not exists user_top_strengths_user_id_idx
  on public.user_top_strengths (user_id);

alter table public.user_top_strengths enable row level security;

drop policy if exists "users read own top strengths"   on public.user_top_strengths;
drop policy if exists "users insert own top strengths" on public.user_top_strengths;
drop policy if exists "users update own top strengths" on public.user_top_strengths;
drop policy if exists "users delete own top strengths" on public.user_top_strengths;

create policy "users read own top strengths"
  on public.user_top_strengths for select
  using (auth.uid() = user_id);

create policy "users insert own top strengths"
  on public.user_top_strengths for insert
  with check (auth.uid() = user_id);

create policy "users update own top strengths"
  on public.user_top_strengths for update
  using (auth.uid() = user_id);

create policy "users delete own top strengths"
  on public.user_top_strengths for delete
  using (auth.uid() = user_id);


-- -----------------------------------------------------------------------
-- 3. Convenience view: a user's top 10 joined to catalog name/domain
--    (RLS on the underlying table still applies — users only see their own)
-- -----------------------------------------------------------------------
create or replace view public.user_top_strengths_view as
  select
    uts.id,
    uts.user_id,
    uts.rank,
    uts.strength_id,
    sc.name   as strength_name,
    sc.domain as strength_domain,
    uts.name_it,
    uts.claim_it,
    uts.aim_it,
    uts.updated_at
  from public.user_top_strengths uts
  join public.strengths_catalog sc on sc.id = uts.strength_id;

grant select on public.user_top_strengths_view to authenticated;
