-- DCDL initial database schema
-- Run in Supabase SQL Editor. This migration intentionally does not grant admin
-- based on a user-editable Geometry Dash username.

create extension if not exists pgcrypto;

create type public.profile_role as enum ('user', 'admin');
create type public.level_status as enum ('pending', 'voting', 'published', 'rejected');
create type public.review_status as enum ('pending', 'approved', 'rejected');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  gd_username text not null unique check (char_length(gd_username) between 1 and 24),
  country text not null,
  role public.profile_role not null default 'user',
  created_at timestamptz not null default now()
);

create table public.levels (
  id uuid primary key default gen_random_uuid(),
  gd_level_id text not null unique,
  name text not null,
  verifier text not null,
  creators text[] not null default '{}',
  video_url text,
  placement integer unique check (placement > 0),
  status public.level_status not null default 'pending',
  victor_count integer not null default 0 check (victor_count >= 0),
  created_at timestamptz not null default now(),
  published_at timestamptz
);

create table public.level_submissions (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid not null references public.profiles(id) on delete cascade,
  gd_level_id text not null,
  name text not null,
  verifier text not null,
  creators text[] not null default '{}',
  video_url text,
  video_storage_path text,
  status public.review_status not null default 'pending',
  admin_note text,
  created_at timestamptz not null default now()
);

create table public.level_tags (
  id uuid primary key default gen_random_uuid(),
  level_id uuid not null references public.levels(id) on delete cascade,
  tag text not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique(level_id, tag)
);

create table public.level_votes (
  id uuid primary key default gen_random_uuid(),
  level_id uuid not null references public.levels(id) on delete cascade,
  voter_id uuid not null references public.profiles(id) on delete cascade,
  estimated_placement integer not null check (estimated_placement > 0),
  updated_at timestamptz not null default now(),
  unique(level_id, voter_id)
);

create table public.completion_submissions (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  level_id uuid not null references public.levels(id) on delete cascade,
  attempts integer not null check (attempts > 0),
  screenshot_path text,
  video_url text,
  video_storage_path text,
  status public.review_status not null default 'pending',
  admin_note text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique(player_id, level_id, id)
);

create table public.point_settings (
  id boolean primary key default true check (id),
  points_per_completion integer not null default 1 check (points_per_completion >= 0),
  updated_at timestamptz not null default now()
);
insert into public.point_settings(id, points_per_completion) values (true, 1)
on conflict (id) do nothing;

create table public.point_ledger (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.profiles(id) on delete cascade,
  completion_id uuid references public.completion_submissions(id) on delete set null,
  points integer not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create table public.chat_channels (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null
);
insert into public.chat_channels(slug, name) values
  ('general', 'General'), ('verification', 'Verification'), ('voice', 'Voice')
on conflict (slug) do nothing;

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.chat_channels(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  check (sender_id <> recipient_id)
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, gd_username, country)
  values (
    new.id,
    trim(coalesce(new.raw_user_meta_data->>'gd_username', '')),
    trim(coalesce(new.raw_user_meta_data->>'country', ''))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.levels enable row level security;
alter table public.level_submissions enable row level security;
alter table public.level_tags enable row level security;
alter table public.level_votes enable row level security;
alter table public.completion_submissions enable row level security;
alter table public.point_settings enable row level security;
alter table public.point_ledger enable row level security;
alter table public.chat_channels enable row level security;
alter table public.chat_messages enable row level security;
alter table public.direct_messages enable row level security;

create policy "Authenticated users can view profiles"
on public.profiles for select to authenticated using (true);
create policy "Admins can manage profiles"
on public.profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Published levels are public to signed-in users"
on public.levels for select to authenticated using (status = 'published' or public.is_admin());
create policy "Admins manage levels"
on public.levels for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Users create own level submissions"
on public.level_submissions for insert to authenticated
with check (submitted_by = (select auth.uid()) and status = 'pending');
create policy "Users see own submissions and admins see all"
on public.level_submissions for select to authenticated
using (submitted_by = (select auth.uid()) or public.is_admin());
create policy "Admins review submissions"
on public.level_submissions for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "Tags visible for published levels"
on public.level_tags for select to authenticated
using (exists (select 1 from public.levels l where l.id = level_id and l.status = 'published') or public.is_admin());
create policy "Admins manage tags"
on public.level_tags for all to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "Votes visible to signed-in users"
on public.level_votes for select to authenticated using (true);
create policy "Users create their own vote"
on public.level_votes for insert to authenticated
with check (voter_id = (select auth.uid()) and exists (
  select 1 from public.levels l where l.id = level_id and l.status = 'voting'
));
create policy "Users update their own vote"
on public.level_votes for update to authenticated
using (voter_id = (select auth.uid()))
with check (voter_id = (select auth.uid()) and exists (
  select 1 from public.levels l where l.id = level_id and l.status = 'voting'
));

create policy "Players submit own completions"
on public.completion_submissions for insert to authenticated
with check (player_id = (select auth.uid()) and status = 'pending');
create policy "Players see own completions; admins see all"
on public.completion_submissions for select to authenticated
using (player_id = (select auth.uid()) or public.is_admin());
create policy "Admins review completions"
on public.completion_submissions for update to authenticated
using (public.is_admin()) with check (public.is_admin());

create policy "Signed-in users read point settings"
on public.point_settings for select to authenticated using (true);
create policy "Admins change point settings"
on public.point_settings for update to authenticated
using (public.is_admin()) with check (public.is_admin());
create policy "Players see own points; admins see all"
on public.point_ledger for select to authenticated
using (player_id = (select auth.uid()) or public.is_admin());
create policy "Admins award points"
on public.point_ledger for insert to authenticated
with check (public.is_admin());

create policy "Signed-in users see fixed channels"
on public.chat_channels for select to authenticated using (true);
create policy "Signed-in users read channel messages"
on public.chat_messages for select to authenticated using (true);
create policy "Users send own channel messages"
on public.chat_messages for insert to authenticated
with check (sender_id = (select auth.uid()));
create policy "Participants read direct messages"
on public.direct_messages for select to authenticated
using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));
create policy "Users send direct messages as themselves"
on public.direct_messages for insert to authenticated
with check (sender_id = (select auth.uid()));

create or replace view public.leaderboard
with (security_invoker = true) as
select p.id, p.gd_username, p.country, coalesce(sum(pl.points), 0)::bigint as points
from public.profiles p
left join public.point_ledger pl on pl.player_id = p.id
group by p.id, p.gd_username, p.country;

-- IMPORTANT: after the owner creates and verifies their own account, promote that
-- exact auth user UUID manually in the SQL editor. Do not promote by GD username.
-- update public.profiles set role = 'admin' where id = 'YOUR_AUTH_USER_UUID';
