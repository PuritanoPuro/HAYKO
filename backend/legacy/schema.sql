-- Baseline Supabase/PostgreSQL. NON contiene RPC di scrittura né migrazione dati.
-- Applicare a un progetto nuovo. Testare in staging prima dell'uso.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 1 and 60)
);
create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 60),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
create table public.league_members (
  league_id uuid not null references public.leagues(id),
  user_id uuid not null references public.profiles(id),
  role text not null check (role in ('owner','admin','member')),
  primary key (league_id,user_id)
);
create table public.players (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id),
  user_id uuid references public.profiles(id), -- null = ospite
  display_name text not null check (length(trim(display_name)) between 1 and 60),
  unique (league_id,id), unique (league_id,user_id)
);
create table public.matches (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id),
  organizer_id uuid not null,
  recorder_id uuid not null,
  format smallint not null check (format between 2 and 11),
  name_a text not null check (length(trim(name_a)) between 1 and 60),
  name_b text not null check (length(trim(name_b)) between 1 and 60),
  status text not null default 'scheduled' check (status in ('scheduled','live','finished','archived')),
  revision bigint not null default 0 check (revision >= 0),
  scheduled_at timestamptz,
  started_at timestamptz, finished_at timestamptz,
  unique (id,league_id),
  foreign key (league_id,organizer_id) references public.league_members(league_id,user_id),
  foreign key (league_id,recorder_id) references public.league_members(league_id,user_id)
);
create table public.match_players (
  match_id uuid not null,
  league_id uuid not null,
  player_id uuid not null,
  team smallint not null check (team in (0,1)),
  primary key (match_id,player_id),
  unique (match_id,player_id,team),
  foreign key (match_id,league_id) references public.matches(id,league_id),
  foreign key (league_id,player_id) references public.players(league_id,id)
);
create table public.goals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id),
  beneficiary_team smallint not null check (beneficiary_team in (0,1)),
  own_goal boolean not null default false,
  scorer_id uuid, assist_id uuid, keeper_id uuid,
  scorer_team smallint generated always as
    (case when own_goal then 1-beneficiary_team else beneficiary_team end) stored,
  defending_team smallint generated always as (1-beneficiary_team) stored,
  recorded_by uuid not null references public.profiles(id),
  received_at timestamptz not null default now(),
  occurred_at timestamptz, -- indicativo, mai usato per decidere l'ordine dei comandi
  voided_at timestamptz,
  foreign key (match_id,scorer_id,scorer_team) references public.match_players(match_id,player_id,team),
  foreign key (match_id,assist_id,beneficiary_team) references public.match_players(match_id,player_id,team),
  foreign key (match_id,keeper_id,defending_team) references public.match_players(match_id,player_id,team),
  check (assist_id is null or not own_goal),
  check (assist_id is null or scorer_id is null or assist_id <> scorer_id)
);
create table public.command_receipts (
  match_id uuid not null references public.matches(id),
  command_id uuid not null,
  actor_id uuid not null references public.profiles(id),
  canonical_request jsonb not null, response jsonb not null,
  created_at timestamptz not null default now(),
  primary key(match_id,command_id)
);
create table public.match_audit (
  id bigint generated always as identity primary key,
  match_id uuid not null references public.matches(id),
  revision bigint not null, actor_id uuid not null references public.profiles(id),
  command_id uuid not null, operation text not null, details jsonb not null,
  created_at timestamptz not null default now(), unique(match_id,revision)
);
create index matches_league on public.matches(league_id,status,format);
create index goals_match on public.goals(match_id) where voided_at is null;
create index members_user on public.league_members(user_id,league_id);

-- Helper privo di parametri di identità: usa auth.uid() della sessione verificata.
create function public.is_league_member(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.league_members where league_id=target and user_id=auth.uid());
$$;
revoke all on function public.is_league_member(uuid) from public, anon;
grant execute on function public.is_league_member(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.players enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.goals enable row level security;
alter table public.command_receipts enable row level security;
alter table public.match_audit enable row level security;
create policy own_profile on public.profiles for select to authenticated using (id=auth.uid());
create policy member_leagues on public.leagues for select to authenticated using(public.is_league_member(id));
create policy member_members on public.league_members for select to authenticated using(public.is_league_member(league_id));
create policy member_players on public.players for select to authenticated using(public.is_league_member(league_id));
create policy member_matches on public.matches for select to authenticated using(public.is_league_member(league_id));
create policy member_rosters on public.match_players for select to authenticated using(public.is_league_member(league_id));
create policy member_goals on public.goals for select to authenticated using(
  exists(select 1 from public.matches m where m.id=match_id and public.is_league_member(m.league_id)));
-- Nessuna policy client su receipts e audit. Le scritture passano da RPC server.
revoke all on public.profiles, public.leagues, public.league_members, public.players,
  public.matches, public.match_players, public.goals, public.command_receipts, public.match_audit
  from anon, authenticated;
grant select on public.profiles, public.leagues, public.league_members, public.players,
  public.matches, public.match_players, public.goals to authenticated;
-- Provisioning e scritture richiedono un ruolo server. Non inserire service_role nei client.
