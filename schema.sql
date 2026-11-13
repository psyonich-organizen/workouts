-- Exercise App — Supabase schema
-- Paste this whole file into Supabase: SQL Editor → New query → Run.
-- Safe to run once on a fresh project.
--
-- Two separate parts:
--   • Definitions (plans, plan_exercises): what you edit on the Workouts page.
--   • Day log (day_entries, completions): what was scheduled and done on each day.
--     The first time you interact with a workout on a day, its exercises are copied
--     into day_entries. The log has no links back to the definitions, so editing or
--     deleting a workout never changes days you've already logged.

-- ─────────────────────────────────────────────────────────────
-- Definitions
-- ─────────────────────────────────────────────────────────────

-- A scheduled item: either a workout (a group of exercises) or a single exercise.
create table public.plans (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind          text not null default 'workout' check (kind in ('workout', 'single')),
  title         text not null,
  start_date    date not null,
  repeat        text not null check (repeat in ('none', 'weekly', 'interval')),
  weekdays      smallint[] not null default '{}',          -- 0 = Sunday … 6 = Saturday (weekly only)
  interval_days integer check (interval_days is null or interval_days >= 1),  -- interval only
  end_date      date,                                        -- optional last day
  created_at    timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);

-- The exercises in a plan, in display order. A single-exercise plan has exactly one.
create table public.plan_exercises (
  id       uuid primary key default gen_random_uuid(),
  plan_id  uuid not null references public.plans (id) on delete cascade,
  user_id  uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name     text not null,
  sets     integer not null default 1 check (sets between 1 and 50),
  details  text not null default '',                         -- per set, e.g. "10 reps @ 40 lb"
  position integer not null default 0
);

-- ─────────────────────────────────────────────────────────────
-- Day log
-- ─────────────────────────────────────────────────────────────

-- One row per exercise on a specific day: a copy taken when the day was started,
-- or a one-off exercise added to that day. source_* are plain ids (not foreign keys)
-- so the log survives the definition being edited or deleted.
create table public.day_entries (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null default auth.uid() references auth.users (id) on delete cascade,
  date               date not null,
  source_plan_id     uuid,                                   -- null for one-off exercises
  source_exercise_id uuid,
  kind               text not null check (kind in ('workout', 'single', 'extra')),
  group_title        text not null default '',               -- workout name at the time
  name               text not null,
  details            text not null default '',
  planned_sets       integer not null check (planned_sets between 1 and 50),
  sets               integer not null check (sets between 1 and 50),  -- sets for this day
  position           integer not null default 0,
  removed            boolean not null default false,         -- removed from this day (can be restored)
  created_at         timestamptz not null default now()
);

-- One row per set checked off.
create table public.completions (
  entry_id     uuid not null references public.day_entries (id) on delete cascade,
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  date         date not null,
  set_no       integer not null check (set_no >= 1),
  completed_at timestamptz not null default now(),
  primary key (entry_id, set_no)
);

create index plan_exercises_plan_id_idx  on public.plan_exercises (plan_id);
create index day_entries_user_date_idx   on public.day_entries (user_id, date);
create index completions_user_date_idx   on public.completions (user_id, date);
-- A workout's exercise is copied into a given day only once (guards against two devices doing it at the same time).
create unique index day_entries_one_copy_idx
  on public.day_entries (user_id, date, source_exercise_id) where source_exercise_id is not null;

-- ─────────────────────────────────────────────────────────────
-- Security: Row Level Security
-- Every row is readable and writable only by the signed-in user who owns it.
-- The publishable key in the web page grants nothing beyond this.
-- ─────────────────────────────────────────────────────────────

alter table public.plans          enable row level security;
alter table public.plan_exercises enable row level security;
alter table public.day_entries    enable row level security;
alter table public.completions    enable row level security;

create policy "Owner can manage their plans"
  on public.plans for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Owner can manage their exercises"
  on public.plan_exercises for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.plans p
                where p.id = plan_id and p.user_id = (select auth.uid()))
  );

create policy "Owner can manage their day entries"
  on public.day_entries for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Owner can manage their completions"
  on public.completions for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.day_entries e
                where e.id = entry_id and e.user_id = (select auth.uid()))
  );

-- Signed-out visitors get no access at all; signed-in users go through the policies above.
revoke all on public.plans, public.plan_exercises, public.day_entries, public.completions from anon;
grant select, insert, update, delete
  on public.plans, public.plan_exercises, public.day_entries, public.completions to authenticated;
