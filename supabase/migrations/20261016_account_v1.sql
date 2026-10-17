-- HAYKO account v1 - progetto nuovo, eseguire una sola volta nel SQL Editor.
-- Tutte le istruzioni sono in una singola transazione.
begin;
do $$ begin
 if to_regclass('public.bc_leagues') is not null or to_regclass('public.hayko_profiles') is not null then
  raise exception 'HAYKO_ALREADY_INSTALLED: interrompo senza modifiche. Invia questo messaggio.';
 end if;
end $$;
grant usage on schema public to authenticated;

-- BASE COMPATIBILE: social_v02.sql
-- MVP social autonomo Supabase: non richiede schema.sql v0.1.
-- Snapshot di lega JSON + lock/revisione: percorso MVP, non database analitico finale.
create schema if not exists extensions;
-- SHA-256 nativo PostgreSQL: non richiede estensioni aggiuntive.
create table public.bc_leagues (
  id text primary key, state jsonb not null,
  president uuid not null references auth.users(id), revision bigint not null default 0,
  created_at timestamptz not null default now()
);
create table public.bc_members (
  league_id text not null references public.bc_leagues(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('president','admin','member')),
  player_id text,
  primary key(league_id,user_id), unique(league_id,player_id)
);
create table public.bc_invites (
  token_hash text primary key, league_id text not null references public.bc_leagues(id),
  expires_at timestamptz not null, revoked boolean not null default false,
  uses integer not null default 0, max_uses integer not null default 100,
  created_by uuid not null references auth.users(id)
);
create table public.bc_audit (
  id bigint generated always as identity primary key,
  league_id text not null references public.bc_leagues(id), actor uuid not null references auth.users(id),
  action text not null, revision bigint not null, occurred_at timestamptz not null default now()
);
alter table public.bc_leagues enable row level security;
alter table public.bc_members enable row level security;
alter table public.bc_invites enable row level security;
alter table public.bc_audit enable row level security;
-- Solo RPC, nessuna operazione diretta sul documento o sui ruoli.
revoke all on public.bc_leagues, public.bc_members, public.bc_invites, public.bc_audit from anon, authenticated;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare m jsonb; g jsonb; k jsonb; team jsonb; all_players jsonb; n int; t int; sid text; aid text; kid text;
begin
  if jsonb_typeof(s) <> 'object' or jsonb_typeof(s->'id') is distinct from 'string' or jsonb_typeof(s->'name') is distinct from 'string' or length(s->>'id') not between 1 and 128
    or length(trim(s->>'name')) not between 1 and 60
    or jsonb_typeof(s->'players') is distinct from 'array' or jsonb_typeof(s->'matches') is distinct from 'array'
    or pg_column_size(s) > 5242880 or jsonb_array_length(s->'players') > 200 or jsonb_array_length(s->'matches') > 1000
    or (s - array['id','name','players','matches']) <> '{}'::jsonb then
    raise exception 'INVALID_LEAGUE';
  end if;
  if exists(select 1 from jsonb_array_elements(s->'players') p where
    jsonb_typeof(p) <> 'object' or jsonb_typeof(p->'id') is distinct from 'string' or jsonb_typeof(p->'name') is distinct from 'string' or p->>'id' is null or length(p->>'id') not between 1 and 128 or
    p->>'name' is null or length(trim(p->>'name')) not between 1 and 60 or (p-array['id','name']) <> '{}'::jsonb)
    or (select count(*) <> count(distinct p->>'id') from jsonb_array_elements(s->'players') p)
    or (select count(*) <> count(distinct x->>'id') from jsonb_array_elements(s->'matches') x) then
    raise exception 'INVALID_IDS';
  end if;
  select coalesce(jsonb_agg(p->'id'), '[]'::jsonb) into all_players from jsonb_array_elements(s->'players') p;
  for m in select value from jsonb_array_elements(s->'matches') loop
    if jsonb_typeof(m->'id') is distinct from 'string' or jsonb_typeof(m->'creatorId') is distinct from 'string' or m->>'id' is null or length(m->>'id') not between 1 and 128 or m->>'creatorId' is null
      or (m-array['id','format','names','teams','status','startedAt','finishedAt','goals','keepers','creatorId']) <> '{}'::jsonb
      or m->>'status' not in ('scheduled','live','finished') or m->>'status' is null
      or jsonb_typeof(m->'format') <> 'number' or (m->>'format') !~ '^[0-9]+$'
      or jsonb_typeof(m->'names') is distinct from 'array' or jsonb_typeof(m->'teams') is distinct from 'array'
      or jsonb_typeof(m->'goals') is distinct from 'array' or jsonb_typeof(m->'keepers') is distinct from 'array' then
      raise exception 'INVALID_MATCH';
    end if;
    n := (m->>'format')::int;
    if n not between 2 and 11 or jsonb_array_length(m->'names') <> 2 or jsonb_array_length(m->'teams') <> 2
      or jsonb_array_length(m->'keepers') <> 2
      or exists(select 1 from jsonb_array_elements(m->'names') name where jsonb_typeof(name) <> 'string' or length(trim(name #>> '{}')) not between 1 and 60)
      or jsonb_typeof(m->'teams'->0) is distinct from 'array' or jsonb_typeof(m->'teams'->1) is distinct from 'array'
      or jsonb_array_length(m->'goals') > 1000 then raise exception 'INVALID_ROSTER'; end if;
    if (select count(*) <> count(distinct p) from jsonb_array_elements_text((m->'teams'->0)||(m->'teams'->1)) p)
      or (select count(*) <> count(distinct x->>'id') from jsonb_array_elements(m->'goals') x) then raise exception 'DUPLICATE_ID'; end if;
    for t in 0..1 loop
      team := m->'teams'->t; k := m->'keepers'->t;
      if jsonb_array_length(team) <> n or not all_players @> team then raise exception 'INVALID_ROSTER'; end if;
      if jsonb_typeof(k->'mode') is distinct from 'string' or (k-array['mode','fixed','order','minutes','sound','vibration']) <> '{}'::jsonb or (k ? 'sound' and jsonb_typeof(k->'sound') <> 'boolean') or (k ? 'vibration' and jsonb_typeof(k->'vibration') <> 'boolean') or k->>'mode' is null or k->>'mode' not in ('manual','fixed','rotation') then raise exception 'INVALID_KEEPER'; end if;
      if k->>'mode' = 'fixed' and (jsonb_typeof(k->'fixed') is distinct from 'string' or k->>'fixed' is null or not team ? (k->>'fixed')) then raise exception 'INVALID_KEEPER'; end if;
      if k ? 'order' and jsonb_typeof(k->'order') is distinct from 'array' then raise exception 'INVALID_ROTATION'; end if;
      if k->>'mode' = 'rotation' then
        if jsonb_typeof(k->'order') is distinct from 'array' or (k->>'minutes') !~ '^[0-9]+$'
          or k->>'minutes' is null then raise exception 'INVALID_ROTATION'; end if;
        if (k->>'minutes')::int not between 1 and 60 or jsonb_array_length(k->'order') <> n
          or not (k->'order' @> team and team @> k->'order')
          or (select count(*) <> count(distinct p) from jsonb_array_elements_text(k->'order') p) then raise exception 'INVALID_ROTATION'; end if;
      end if;
    end loop;
    if m->>'status' = 'scheduled' and (jsonb_array_length(m->'goals') <> 0 or m->>'startedAt' is not null or m->>'finishedAt' is not null) then raise exception 'INVALID_STATE'; end if;
    if m->>'status' in ('live','finished') and m->>'startedAt' is null then raise exception 'INVALID_STATE'; end if;
    if m->>'status' = 'finished' and (m->>'finishedAt' is null or (m->>'finishedAt')::timestamptz < (m->>'startedAt')::timestamptz) then raise exception 'INVALID_STATE'; end if;
    if m->>'status' = 'live' and m->>'finishedAt' is not null then raise exception 'INVALID_STATE'; end if;
    if m->>'startedAt' is not null then
      if jsonb_typeof(m->'startedAt') <> 'string' then raise exception 'INVALID_TIME'; end if;
      perform (m->>'startedAt')::timestamptz;
    end if;
    if m->>'finishedAt' is not null then
      if jsonb_typeof(m->'finishedAt') <> 'string' then raise exception 'INVALID_TIME'; end if;
      perform (m->>'finishedAt')::timestamptz;
    end if;
    for g in select value from jsonb_array_elements(m->'goals') loop
      if jsonb_typeof(g->'id') is distinct from 'string' or jsonb_typeof(g->'time') is distinct from 'string' or jsonb_typeof(g->'team') is distinct from 'number' or g->>'id' is null or g->>'time' is null or g->>'team' not in ('0','1') or g->>'team' is null
        or jsonb_typeof(g->'ownGoal') is distinct from 'boolean' or jsonb_typeof(g->'voided') is distinct from 'boolean'
        or (g-array['id','team','scorer','assist','keeper','ownGoal','time','voided']) <> '{}'::jsonb then raise exception 'INVALID_GOAL'; end if;
      if jsonb_typeof(g->'scorer') is null or jsonb_typeof(g->'scorer') not in ('string','null')
        or jsonb_typeof(g->'assist') is null or jsonb_typeof(g->'assist') not in ('string','null')
        or jsonb_typeof(g->'keeper') is null or jsonb_typeof(g->'keeper') not in ('string','null') then raise exception 'INVALID_GOAL'; end if;
      perform (g->>'time')::timestamptz;
      t := (g->>'team')::int; sid := g->>'scorer'; aid := g->>'assist'; kid := g->>'keeper';
      if sid is not null and not (m->'teams'->(case when (g->>'ownGoal')::boolean then 1-t else t end)) ? sid then raise exception 'INVALID_SCORER'; end if;
      if aid is not null and ((g->>'ownGoal')::boolean or not (m->'teams'->t) ? aid or aid = sid) then raise exception 'INVALID_ASSIST'; end if;
      if kid is not null and not (m->'teams'->(1-t)) ? kid then raise exception 'INVALID_KEEPER'; end if;
      if m->'keepers'->(1-t)->>'mode' = 'fixed' and kid is distinct from (m->'keepers'->(1-t)->>'fixed') then raise exception 'INVALID_KEEPER'; end if;
    end loop;
  end loop;
end;
$$;

create or replace function public.bc_get(p_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me public.bc_members; l public.bc_leagues; members jsonb;
begin
  select * into me from public.bc_members where league_id=p_id and user_id=auth.uid();
  if not found then raise exception 'FORBIDDEN'; end if;
  select * into l from public.bc_leagues where id=p_id;
  select coalesce(jsonb_agg(jsonb_build_object('player_id',player_id,'role',role)), '[]'::jsonb)
    into members from public.bc_members where league_id=p_id;
  return jsonb_build_object('state',l.state,'revision',l.revision,'role',me.role,'player_id',me.player_id,'members',members);
end; $$;
create or replace function public.bc_list() returns jsonb
language sql security definer set search_path = '' as $$
  select coalesce(jsonb_agg(public.bc_get(league_id)), '[]'::jsonb) from public.bc_members where user_id=auth.uid();
$$;
create or replace function public.bc_create(p_state jsonb) returns text
language plpgsql security definer set search_path = '' as $$
declare id text := p_state->>'id';
begin
  if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
  perform public.bc_validate(p_state);
  if jsonb_array_length(p_state->'matches') <> 0 then raise exception 'CREATE_EMPTY_LEAGUE'; end if;
  insert into public.bc_leagues(id,state,president) values(id,p_state,auth.uid());
  insert into public.bc_members(league_id,user_id,role) values(id,auth.uid(),'president');
  insert into public.bc_audit(league_id,actor,action,revision) values(id,auth.uid(),'create',0);
  return id;
end; $$;

create or replace function public.bc_save(p_id text, p_revision bigint, p_state jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare l public.bc_leagues; role text; old jsonb; m jsonb; oldm jsonb; g jsonb; oldg jsonb; idx int;
begin
  select * into l from public.bc_leagues where id=p_id for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  select bc_members.role into role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if role is null then raise exception 'FORBIDDEN'; end if;
  if p_state = l.state then return l.revision; end if; -- retry identico non genera un secondo risultato
  if p_revision is null or p_revision <> l.revision then raise exception 'REVISION_CONFLICT: aggiorna la lega prima di riprovare'; end if;
  perform public.bc_validate(p_state);
  if p_state->>'id' <> p_id then raise exception 'INVALID_ID'; end if;
  old := l.state;
  if role = 'member' and (p_state-array['matches']) <> (old-array['matches']) then raise exception 'ADMIN_REQUIRED'; end if;
  if exists(select 1 from jsonb_array_elements(old->'players') p where not exists(
    select 1 from jsonb_array_elements(p_state->'players') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_PLAYER'; end if;
  if exists(select 1 from jsonb_array_elements(old->'matches') p where not exists(
    select 1 from jsonb_array_elements(p_state->'matches') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_MATCH'; end if;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    select value into oldm from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id';
    if oldm is null then
      if role not in ('president','admin') or m->>'creatorId' <> auth.uid()::text or m->>'status' <> 'scheduled' then raise exception 'ADMIN_REQUIRED'; end if;
    elsif m <> oldm then
      if oldm->>'creatorId' <> auth.uid()::text or m->>'creatorId' <> oldm->>'creatorId' then raise exception 'ONLY_EVENT_CREATOR'; end if;
      if oldm->>'status' = 'finished' then raise exception 'MATCH_FINISHED'; end if;
      if oldm->>'status' = 'scheduled' and m->>'status' not in ('scheduled','live') then raise exception 'INVALID_TRANSITION'; end if;
      if oldm->>'status' = 'live' then
        if m->>'status' not in ('live','finished') or (m-array['status','finishedAt','goals']) <> (oldm-array['status','finishedAt','goals']) then raise exception 'ROSTER_FROZEN'; end if;
      end if;
      if jsonb_array_length(m->'goals') < jsonb_array_length(oldm->'goals') then raise exception 'CANNOT_DELETE_GOAL'; end if;
      idx := 0;
      for oldg in select value from jsonb_array_elements(oldm->'goals') loop
        g := m->'goals'->idx;
        if (g-'voided') <> (oldg-'voided') or ((oldg->>'voided')::boolean and not (g->>'voided')::boolean) then raise exception 'GOAL_IMMUTABLE'; end if;
        idx := idx + 1;
      end loop;
      while idx < jsonb_array_length(m->'goals') loop
        if (m->'goals'->idx->>'voided')::boolean then raise exception 'INVALID_NEW_GOAL'; end if;
        idx := idx + 1;
      end loop;
      -- Non consentire gol nel medesimo aggiornamento che avvia o chiude l'evento.
      if oldm->>'status' <> m->>'status' and m->'goals' <> oldm->'goals' then raise exception 'STATE_AND_GOAL_SEPARATE'; end if;
    end if;
  end loop;
  update public.bc_leagues set state=p_state,revision=revision+1 where id=p_id returning revision into p_revision;
  insert into public.bc_audit(league_id,actor,action,revision) values(p_id,auth.uid(),'save',p_revision);
  return p_revision;
end; $$;

create or replace function public.bc_invite(p_id text) returns text
language plpgsql security definer set search_path = '' as $$
declare token text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
begin
  perform 1 from public.bc_leagues where id=p_id for update;
  if not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED'; end if;
  insert into public.bc_invites(token_hash,league_id,expires_at,created_by)
    values(encode(sha256(convert_to(token,'UTF8')),'hex'),p_id,now()+interval '7 days',auth.uid());
  return token;
end; $$;
create or replace function public.bc_join(p_token text) returns text
language plpgsql security definer set search_path = '' as $$
declare i public.bc_invites;
begin
  if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
  if length(p_token) <> 64 then raise exception 'INVALID_INVITE'; end if;
  select * into i from public.bc_invites where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  if not found then raise exception 'INVALID_INVITE'; end if;
  -- Lock ordine coerente: lega poi invito; evita deadlock con revoca.
  perform 1 from public.bc_leagues where id=i.league_id for update;
  select * into i from public.bc_invites where token_hash=i.token_hash for update;
  if i.revoked or i.expires_at <= now() or i.uses >= i.max_uses then raise exception 'INVITE_EXPIRED_OR_REVOKED'; end if;
  if not exists(select 1 from public.bc_members where league_id=i.league_id and user_id=auth.uid()) then
    insert into public.bc_members(league_id,user_id,role) values(i.league_id,auth.uid(),'member');
    update public.bc_invites set uses=uses+1 where token_hash=i.token_hash;
  end if;
  return i.league_id;
end; $$;
create or replace function public.bc_revoke_invites(p_id text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.bc_leagues where id=p_id for update;
  if not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED'; end if;
  update public.bc_invites set revoked=true where league_id=p_id;
end; $$;
create or replace function public.bc_claim(p_id text, p_player text default null, p_name text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare l public.bc_leagues; existing text; id text := p_player; s jsonb;
begin
  select * into l from public.bc_leagues where bc_leagues.id=p_id for update;
  select player_id into existing from public.bc_members where league_id=p_id and user_id=auth.uid();
  if not found then raise exception 'FORBIDDEN'; end if;
  if existing is not null then raise exception 'ALREADY_ASSOCIATED'; end if;
  s := l.state;
  if id is null then
    if p_name is null or length(trim(p_name)) not between 1 and 60 then raise exception 'INVALID_NAME'; end if;
    id := replace(gen_random_uuid()::text,'-','');
    s := jsonb_set(s,'{players}',(s->'players')||jsonb_build_array(jsonb_build_object('id',id,'name',trim(p_name))));
  elsif not exists(select 1 from jsonb_array_elements(s->'players') p where p->>'id'=id) then raise exception 'INVALID_PLAYER'; end if;
  if exists(select 1 from public.bc_members where league_id=p_id and player_id=id) then raise exception 'PLAYER_ALREADY_ASSOCIATED'; end if;
  perform public.bc_validate(s);
  update public.bc_members set player_id=id where league_id=p_id and user_id=auth.uid();
  update public.bc_leagues set state=s,revision=revision+1 where bc_leagues.id=p_id;
  insert into public.bc_audit(league_id,actor,action,revision) values(p_id,auth.uid(),'claim',l.revision+1);
end; $$;
create or replace function public.bc_role(p_id text, p_player text, p_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare l public.bc_leagues;
begin
  select * into l from public.bc_leagues where id=p_id for update;
  if l.president is distinct from auth.uid() or p_role not in ('admin','member') or p_role is null then raise exception 'PRESIDENT_REQUIRED'; end if;
  update public.bc_members set role=p_role where league_id=p_id and player_id=p_player and role <> 'president';
  if not found then raise exception 'INVALID_MEMBER'; end if;
  update public.bc_leagues set revision=revision+1 where id=p_id;
  insert into public.bc_audit(league_id,actor,action,revision) values(p_id,auth.uid(),'role',l.revision+1);
end; $$;

revoke all on function public.bc_validate(jsonb), public.bc_get(text), public.bc_list(), public.bc_create(jsonb),
  public.bc_save(text,bigint,jsonb), public.bc_invite(text), public.bc_join(text), public.bc_revoke_invites(text),
  public.bc_claim(text,text,text), public.bc_role(text,text,text) from public, anon, authenticated;
grant execute on function public.bc_get(text), public.bc_list(), public.bc_create(jsonb),
  public.bc_save(text,bigint,jsonb), public.bc_invite(text), public.bc_join(text), public.bc_revoke_invites(text),
  public.bc_claim(text,text,text), public.bc_role(text,text,text) to authenticated;

-- BASE COMPATIBILE: social_v03.sql
-- Dopo social_v02.sql, una sola volta su Supabase di TEST. Migrazione transazionale.
alter function public.bc_validate(jsonb) rename to bc_validate_base_v02;
create or replace function public.bc_valid_color(v jsonb) returns boolean language sql set search_path='' as $$
  select case when v is null then true when jsonb_typeof(v)='number' then
    (v #>> '{}') ~ '^[0-9]+$' and (v #>> '{}')::numeric between 4278190080 and 4294967295 else false end;
$$;
create or replace function public.bc_validate(s jsonb) returns void language plpgsql set search_path='' as $$
declare base jsonb; p jsonb; c jsonb; m jsonb; raw jsonb; players jsonb; presets jsonb; comps jsonb;
  ids jsonb; teams jsonb; pair jsonb; checked jsonb; winners jsonb; r int; i int; n int; found_count int;
  complete boolean; gf0 int; gf1 int; winner text;
begin
  if pg_column_size(s)>5242880 or not public.bc_valid_color(s->'primaryColor') or not public.bc_valid_color(s->'secondaryColor') then raise exception 'INVALID_LEAGUE_COLOR'; end if;
  presets:=coalesce(s->'presets','[]'::jsonb);comps:=coalesce(s->'competitions','[]'::jsonb);
  if jsonb_typeof(presets)<>'array' or jsonb_typeof(comps)<>'array' then raise exception 'INVALID_COMPETITIONS'; end if;
  if jsonb_array_length(presets)>200 or jsonb_array_length(comps)>200 then raise exception 'TOO_MANY_TEAMS'; end if;
  base:=s-array['primaryColor','secondaryColor','presets','competitions'];
  select coalesce(jsonb_agg(x-'color'),'[]'::jsonb) into players from jsonb_array_elements(s->'players') x;
  base:=jsonb_set(base,'{players}',players);
  select coalesce(jsonb_agg(x-array['scheduledAt','venue','teamColors','presetIds','competitionId','knockoutRound','qualifiedTeamId']),'[]'::jsonb)
    into raw from jsonb_array_elements(s->'matches') x;
  perform public.bc_validate_base_v02(jsonb_set(base,'{matches}',raw));
  if exists(select 1 from jsonb_array_elements(s->'players') x where not public.bc_valid_color(x->'color')) then raise exception 'INVALID_PLAYER_COLOR'; end if;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(s->'players') x;
  if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(presets) x) or
    (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(comps) x) then raise exception 'DUPLICATE_TEAM_ID'; end if;
  for p in select value from jsonb_array_elements(presets) loop
    if jsonb_typeof(p->'id') is distinct from 'string' or jsonb_typeof(p->'name') is distinct from 'string'
      or length(p->>'id') not between 1 and 128 or length(trim(p->>'name')) not between 1 and 60
      or not public.bc_valid_color(p->'color') or jsonb_typeof(p->'players') is distinct from 'array'
      or (p-array['id','name','players','color'])<>'{}'::jsonb then raise exception 'INVALID_PRESET'; end if;
    if jsonb_array_length(p->'players') not between 2 and 11 or not ids @> p->'players'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(p->'players') x) then raise exception 'INVALID_PRESET_ROSTER'; end if;
  end loop;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(presets) x;
  for c in select value from jsonb_array_elements(comps) loop
    if jsonb_typeof(c->'id') is distinct from 'string' or jsonb_typeof(c->'name') is distinct from 'string'
      or length(c->>'id') not between 1 and 128 or length(trim(c->>'name')) not between 1 and 60
      or c->>'kind' is null or c->>'kind' not in ('league','knockout') or jsonb_typeof(c->'format') is distinct from 'number'
      or (c->>'format') !~ '^[0-9]+$' or jsonb_typeof(c->'teamIds') is distinct from 'array'
      or (c-array['id','name','kind','format','teamIds'])<>'{}'::jsonb then raise exception 'INVALID_COMPETITION'; end if;
    if (c->>'format')::int not between 2 and 11 or jsonb_array_length(c->'teamIds')<2 or not ids @> c->'teamIds'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(c->'teamIds') x)
      or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds') not in (2,4,8,16)) then raise exception 'INVALID_COMPETITION_TEAMS'; end if;
    if exists(select 1 from jsonb_array_elements(presets) x where c->'teamIds' ? (x->>'id') and jsonb_array_length(x->'players')<>(c->>'format')::int) then raise exception 'COMPETITION_FORMAT'; end if;
  end loop;
  for m in select value from jsonb_array_elements(s->'matches') loop
    if m->>'scheduledAt' is not null then
      if jsonb_typeof(m->'scheduledAt')<>'string' then raise exception 'INVALID_DATE'; end if;
      perform (m->>'scheduledAt')::timestamptz;
    end if;
    if m ? 'venue' and (jsonb_typeof(m->'venue')<>'string' or length(m->>'venue')>120) then raise exception 'INVALID_VENUE'; end if;
    if m ? 'teamColors' then
      if jsonb_typeof(m->'teamColors')<>'array' or jsonb_array_length(m->'teamColors')<>2 then raise exception 'INVALID_TEAM_COLOR'; end if;
      if exists(select 1 from jsonb_array_elements(m->'teamColors') v where not public.bc_valid_color(v)) then raise exception 'INVALID_TEAM_COLOR'; end if;
    end if;
    if m ? 'presetIds' then
      if jsonb_typeof(m->'presetIds')<>'array' or jsonb_array_length(m->'presetIds')<>2 then raise exception 'INVALID_TEAM_ID'; end if;
      if exists(select 1 from jsonb_array_elements(m->'presetIds') v where jsonb_typeof(v) not in ('string','null')) or exists(select 1 from jsonb_array_elements_text(m->'presetIds') v where v is not null and not ids ? v) then raise exception 'INVALID_TEAM_ID'; end if;
    end if;
    if m->>'competitionId' is not null then
      select value into c from jsonb_array_elements(comps) x where x->>'id'=m->>'competitionId';
      if c is null or m->>'format'<>c->>'format' or m->'presetIds'->>0 is null or m->'presetIds'->>1 is null
        or m->'presetIds'->>0=m->'presetIds'->>1 or not c->'teamIds' @> m->'presetIds' then raise exception 'INVALID_MATCH_COMPETITION'; end if;
      if c->>'kind'='knockout' then
        if jsonb_typeof(m->'knockoutRound') is distinct from 'number' or (m->>'knockoutRound') !~ '^[1-4]$' then raise exception 'INVALID_ROUND'; end if;
        if m->>'status'='finished' then
          if m->>'qualifiedTeamId' is null or not m->'presetIds' ? (m->>'qualifiedTeamId') then raise exception 'QUALIFIER_REQUIRED'; end if;
          select count(*) filter(where x->>'team'='0'),count(*) filter(where x->>'team'='1') into gf0,gf1
            from jsonb_array_elements(m->'goals') x where not (x->>'voided')::boolean;
          if gf0<>gf1 and m->>'qualifiedTeamId' is distinct from (m->'presetIds'->>(case when gf0>gf1 then 0 else 1 end)) then raise exception 'WRONG_QUALIFIER'; end if;
        elsif m->>'qualifiedTeamId' is not null then raise exception 'INVALID_QUALIFIER'; end if;
      elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'INVALID_ROUND'; end if;
    elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'COMPETITION_REQUIRED'; end if;
  end loop;
  -- Valida il tabellone: un incontro per coppia, turni futuri solo dopo tutti i risultati.
  for c in select value from jsonb_array_elements(comps) x where x->>'kind'='knockout' loop
    teams:=c->'teamIds';r:=1;checked:='[]'::jsonb;
    while jsonb_array_length(teams)>=2 loop
      winners:='[]'::jsonb;complete:=true;n:=jsonb_array_length(teams);
      for i in 0..(n/2-1) loop
        pair:=jsonb_build_array(teams->(i*2),teams->(i*2+1));
        select count(*) into found_count from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id'
          and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        if found_count>1 then raise exception 'DUPLICATE_FIXTURE'; end if;
        if found_count=0 then complete:=false;continue;end if;
        select value into m from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        checked:=checked||jsonb_build_array(m->'id');winner:=m->>'qualifiedTeamId';
        if m->>'status'='finished' and winner is not null then winners:=winners||jsonb_build_array(winner);else complete:=false;end if;
      end loop;
      exit when not complete;teams:=winners;r:=r+1;
    end loop;
    if exists(select 1 from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and not checked ? (x->>'id')) then raise exception 'ROUND_NOT_AVAILABLE'; end if;
  end loop;
end; $$;

create or replace function public.bc_save_core_v03(p_id text, p_revision bigint, p_state jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare l public.bc_leagues; role text; old jsonb; m jsonb; oldm jsonb; g jsonb; oldg jsonb; idx int;
begin
  select * into l from public.bc_leagues where id=p_id for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  select bc_members.role into role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if role is null then raise exception 'FORBIDDEN'; end if;
  if p_state = l.state then return l.revision; end if; -- retry identico non genera un secondo risultato
  if p_revision is null or p_revision <> l.revision then raise exception 'REVISION_CONFLICT: aggiorna la lega prima di riprovare'; end if;
  perform public.bc_validate(p_state);
  if p_state->>'id' <> p_id then raise exception 'INVALID_ID'; end if;
  old := l.state;
  if role = 'member' and (p_state-array['matches']) <> (old-array['matches']) then raise exception 'ADMIN_REQUIRED'; end if;
  if exists(select 1 from jsonb_array_elements(old->'players') p where not exists(
    select 1 from jsonb_array_elements(p_state->'players') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_PLAYER'; end if;
  if exists(select 1 from jsonb_array_elements(old->'matches') p where not exists(
    select 1 from jsonb_array_elements(p_state->'matches') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_MATCH'; end if;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    select value into oldm from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id';
    if oldm is null then
      if role not in ('president','admin') or m->>'creatorId' <> auth.uid()::text or m->>'status' <> 'scheduled' then raise exception 'ADMIN_REQUIRED'; end if;
    elsif m <> oldm then
      if oldm->>'creatorId' <> auth.uid()::text or m->>'creatorId' <> oldm->>'creatorId' then raise exception 'ONLY_EVENT_CREATOR'; end if;
      if oldm->>'status' = 'finished' then raise exception 'MATCH_FINISHED'; end if;
      if oldm->>'status' = 'scheduled' and m->>'status' not in ('scheduled','live') then raise exception 'INVALID_TRANSITION'; end if;
      if oldm->>'status' = 'live' then
        if m->>'status' not in ('live','finished') or (m-array['status','finishedAt','goals','qualifiedTeamId']) <> (oldm-array['status','finishedAt','goals','qualifiedTeamId']) then raise exception 'ROSTER_FROZEN'; end if;
      end if;
      if jsonb_array_length(m->'goals') < jsonb_array_length(oldm->'goals') then raise exception 'CANNOT_DELETE_GOAL'; end if;
      idx := 0;
      for oldg in select value from jsonb_array_elements(oldm->'goals') loop
        g := m->'goals'->idx;
        if (g-'voided') <> (oldg-'voided') or ((oldg->>'voided')::boolean and not (g->>'voided')::boolean) then raise exception 'GOAL_IMMUTABLE'; end if;
        idx := idx + 1;
      end loop;
      while idx < jsonb_array_length(m->'goals') loop
        if (m->'goals'->idx->>'voided')::boolean then raise exception 'INVALID_NEW_GOAL'; end if;
        idx := idx + 1;
      end loop;
      -- Non consentire gol nel medesimo aggiornamento che avvia o chiude l'evento.
      if oldm->>'status' <> m->>'status' and m->'goals' <> oldm->'goals' then raise exception 'STATE_AND_GOAL_SEPARATE'; end if;
    end if;
  end loop;
  update public.bc_leagues set state=p_state,revision=revision+1 where id=p_id returning revision into p_revision;
  insert into public.bc_audit(league_id,actor,action,revision) values(p_id,auth.uid(),'save',p_revision);
  return p_revision;
end; $$;


create or replace function public.bc_save(p_id text,p_revision bigint,p_state jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare old jsonb; member_role text; m jsonb; p jsonb; c jsonb;
begin
  select state into old from public.bc_leagues where id=p_id for update;
  select role into member_role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if old is null or member_role is null then raise exception 'FORBIDDEN'; end if;
  if member_role<>'president' and (p_state->'name' is distinct from old->'name' or p_state->'primaryColor' is distinct from old->'primaryColor' or p_state->'secondaryColor' is distinct from old->'secondaryColor') then raise exception 'PRESIDENT_REQUIRED'; end if;
  for p in select value from jsonb_array_elements(coalesce(old->'presets','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'presets','[]'::jsonb)) x where x->>'id'=p->>'id' and x->'players'=p->'players') then raise exception 'PRESET_ROSTER_FROZEN'; end if;
  end loop;
  for c in select value from jsonb_array_elements(coalesce(old->'competitions','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'competitions','[]'::jsonb)) x where x->>'id'=c->>'id') then raise exception 'CANNOT_REMOVE_COMPETITION'; end if;
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'competitionId'=c->>'id') and
      not exists(select 1 from jsonb_array_elements(p_state->'competitions') x where x=c) then raise exception 'COMPETITION_FROZEN'; end if;
  end loop;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id' and
      (x->'competitionId' is distinct from m->'competitionId' or x->'presetIds' is distinct from m->'presetIds' or x->'knockoutRound' is distinct from m->'knockoutRound')) then raise exception 'EVENT_IDENTITY_FROZEN'; end if;
    if not exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id') and
      (m->>'scheduledAt' is null or length(trim(coalesce(m->>'venue',''))) not between 1 and 120) then raise exception 'EVENT_DETAILS_REQUIRED'; end if;
  end loop;
  return public.bc_save_core_v03(p_id,p_revision,p_state);
end; $$;

create or replace function public.bc_delete(p_id text,p_name text) returns void
language plpgsql security definer set search_path='' as $$
declare l public.bc_leagues;
begin
  select * into l from public.bc_leagues where id=p_id for update;
  if l.president is distinct from auth.uid() or auth.uid() is null then raise exception 'PRESIDENT_REQUIRED'; end if;
  if l.state->>'name' is distinct from p_name then raise exception 'NAME_CHANGED_RELOAD'; end if;
  delete from public.bc_invites where league_id=p_id;
  delete from public.bc_audit where league_id=p_id;
  delete from public.bc_members where league_id=p_id;
  delete from public.bc_leagues where id=p_id;
end; $$;


alter function public.bc_claim(text,text,text) rename to bc_claim_core_v02;
create or replace function public.bc_claim(p_id text,p_player text default null,p_name text default null) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform public.bc_claim_core_v02(p_id,p_player,p_name);
 update public.bc_leagues set state=jsonb_set(state,'{players}',(select jsonb_agg(x||jsonb_build_object('color',coalesce(x->'color','4290508136'::jsonb))) from jsonb_array_elements(state->'players') x)) where id=p_id;
end; $$;
revoke all on function public.bc_claim_core_v02(text,text,text),public.bc_claim(text,text,text) from public,anon,authenticated;
grant execute on function public.bc_claim(text,text,text) to authenticated;

-- Dati v0.2: aggiunge solo default, senza date inventate o competizioni retroattive.
do $$
declare l record; s jsonb; players jsonb; matches jsonb;
begin
 for l in select id,state from public.bc_leagues for update loop
  s:=l.state||jsonb_build_object('primaryColor',coalesce(l.state->'primaryColor','4290508136'::jsonb),'secondaryColor',coalesce(l.state->'secondaryColor','4287544575'::jsonb),'presets',coalesce(l.state->'presets','[]'::jsonb),'competitions',coalesce(l.state->'competitions','[]'::jsonb));
  select coalesce(jsonb_agg(x||jsonb_build_object('color',coalesce(x->'color','4290508136'::jsonb))),'[]'::jsonb) into players from jsonb_array_elements(s->'players') x;
  select coalesce(jsonb_agg(x||jsonb_build_object('scheduledAt',coalesce(x->'scheduledAt','null'::jsonb),'venue',coalesce(x->'venue','""'::jsonb),
   'teamColors',coalesce(x->'teamColors','[4287544575,4294945636]'::jsonb),'presetIds',coalesce(x->'presetIds','[null,null]'::jsonb),
   'competitionId',coalesce(x->'competitionId','null'::jsonb),'knockoutRound',coalesce(x->'knockoutRound','null'::jsonb),'qualifiedTeamId',coalesce(x->'qualifiedTeamId','null'::jsonb))),'[]'::jsonb)
   into matches from jsonb_array_elements(s->'matches') x;
  s:=jsonb_set(jsonb_set(s,'{players}',players),'{matches}',matches);
  perform public.bc_validate(s);
  if s<>l.state then update public.bc_leagues set state=s,revision=revision+1 where id=l.id;end if;
 end loop;
end; $$;
revoke all on function public.bc_valid_color(jsonb),public.bc_validate(jsonb),public.bc_validate_base_v02(jsonb),public.bc_save_core_v03(text,bigint,jsonb),public.bc_delete(text,text) from public,anon,authenticated;
grant execute on function public.bc_delete(text,text) to authenticated;

-- BASE COMPATIBILE: social_v04.sql
-- Dopo social_v02.sql e social_v03.sql, una sola volta su Supabase di TEST.
-- Questa migrazione non e stata eseguita nel workspace.
create or replace function public.bc_validate(s jsonb) returns void language plpgsql set search_path='' as $$
declare base jsonb; p jsonb; c jsonb; m jsonb; raw jsonb; players jsonb; presets jsonb; comps jsonb;
  ids jsonb; teams jsonb; pair jsonb; checked jsonb; winners jsonb; r int; i int; n int; found_count int;
  complete boolean; gf0 int; gf1 int; winner text;
begin
  if coalesce(s->>'type','amateur') not in ('amateur','competition') then raise exception 'INVALID_LEAGUE_TYPE'; end if;
  if pg_column_size(s)>5242880 or not public.bc_valid_color(s->'primaryColor') or not public.bc_valid_color(s->'secondaryColor') then raise exception 'INVALID_LEAGUE_COLOR'; end if;
  presets:=coalesce(s->'presets','[]'::jsonb);comps:=coalesce(s->'competitions','[]'::jsonb);
  if jsonb_typeof(presets)<>'array' or jsonb_typeof(comps)<>'array' then raise exception 'INVALID_COMPETITIONS'; end if;
  if jsonb_array_length(presets)>200 or jsonb_array_length(comps)>200 then raise exception 'TOO_MANY_TEAMS'; end if;
  base:=s-array['primaryColor','secondaryColor','presets','competitions','type'];
  select coalesce(jsonb_agg(x-'color'),'[]'::jsonb) into players from jsonb_array_elements(s->'players') x;
  base:=jsonb_set(base,'{players}',players);
  select coalesce(jsonb_agg(x-array['scheduledAt','venue','teamColors','presetIds','competitionId','knockoutRound','qualifiedTeamId']),'[]'::jsonb)
    into raw from jsonb_array_elements(s->'matches') x;
  perform public.bc_validate_base_v02(jsonb_set(base,'{matches}',raw));
  if exists(select 1 from jsonb_array_elements(s->'players') x where not public.bc_valid_color(x->'color')) then raise exception 'INVALID_PLAYER_COLOR'; end if;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(s->'players') x;
  if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(presets) x) or
    (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(comps) x) then raise exception 'DUPLICATE_TEAM_ID'; end if;
  for p in select value from jsonb_array_elements(presets) loop
    if jsonb_typeof(p->'id') is distinct from 'string' or jsonb_typeof(p->'name') is distinct from 'string'
      or length(p->>'id') not between 1 and 128 or length(trim(p->>'name')) not between 1 and 60
      or not public.bc_valid_color(p->'color') or jsonb_typeof(p->'players') is distinct from 'array'
      or (p-array['id','name','players','color','numbers'])<>'{}'::jsonb then raise exception 'INVALID_PRESET'; end if;
    if jsonb_typeof(coalesce(p->'numbers','{}'::jsonb))<>'object' then raise exception 'INVALID_NUMBERS'; end if;
    if exists(select 1 from jsonb_each(coalesce(p->'numbers','{}'::jsonb)) e where not p->'players' ? e.key or jsonb_typeof(e.value)<>'number' or (e.value#>>'{}') !~ '^[0-9]{1,2}$') then raise exception 'INVALID_NUMBERS'; end if;
    if (select count(*)<>count(distinct value) from jsonb_each(coalesce(p->'numbers','{}'::jsonb))) then raise exception 'DUPLICATE_NUMBER'; end if;
    if jsonb_array_length(p->'players') not between 2 and 60 or not ids @> p->'players'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(p->'players') x) then raise exception 'INVALID_PRESET_ROSTER'; end if;
  end loop;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(presets) x;
  for c in select value from jsonb_array_elements(comps) loop
    if jsonb_typeof(c->'id') is distinct from 'string' or jsonb_typeof(c->'name') is distinct from 'string'
      or length(c->>'id') not between 1 and 128 or length(trim(c->>'name')) not between 1 and 60
      or c->>'kind' is null or c->>'kind' not in ('league','knockout') or jsonb_typeof(c->'format') is distinct from 'number'
      or (c->>'format') !~ '^[0-9]+$' or jsonb_typeof(c->'teamIds') is distinct from 'array'
      or (c-array['id','name','kind','format','teamIds','doubleLeg'])<>'{}'::jsonb then raise exception 'INVALID_COMPETITION'; end if;
    if jsonb_typeof(coalesce(c->'doubleLeg','false'::jsonb))<>'boolean' or (c->>'kind'='knockout' and coalesce((c->>'doubleLeg')::boolean,false)) then raise exception 'INVALID_LEGS'; end if;
    if (c->>'format')::int not between 2 and 11 or not ids @> c->'teamIds'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(c->'teamIds') x)
      or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds')>16) then raise exception 'INVALID_COMPETITION_TEAMS'; end if;
    if exists(select 1 from jsonb_array_elements(presets) x where c->'teamIds' ? (x->>'id') and jsonb_array_length(x->'players')<(c->>'format')::int) then raise exception 'COMPETITION_FORMAT'; end if;
  end loop;
  for m in select value from jsonb_array_elements(s->'matches') loop
    if m->>'scheduledAt' is not null then
      if jsonb_typeof(m->'scheduledAt')<>'string' then raise exception 'INVALID_DATE'; end if;
      perform (m->>'scheduledAt')::timestamptz;
    end if;
    if m ? 'venue' and (jsonb_typeof(m->'venue')<>'string' or length(m->>'venue')>120) then raise exception 'INVALID_VENUE'; end if;
    if m ? 'teamColors' then
      if jsonb_typeof(m->'teamColors')<>'array' or jsonb_array_length(m->'teamColors')<>2 then raise exception 'INVALID_TEAM_COLOR'; end if;
      if exists(select 1 from jsonb_array_elements(m->'teamColors') v where not public.bc_valid_color(v)) then raise exception 'INVALID_TEAM_COLOR'; end if;
    end if;
    if m ? 'presetIds' then
      if jsonb_typeof(m->'presetIds')<>'array' or jsonb_array_length(m->'presetIds')<>2 then raise exception 'INVALID_TEAM_ID'; end if;
      if exists(select 1 from jsonb_array_elements(m->'presetIds') v where jsonb_typeof(v) not in ('string','null')) or exists(select 1 from jsonb_array_elements_text(m->'presetIds') v where v is not null and not ids ? v) then raise exception 'INVALID_TEAM_ID'; end if;
    end if;
    if m->>'competitionId' is not null then
      select value into c from jsonb_array_elements(comps) x where x->>'id'=m->>'competitionId';
      if c is null or m->>'format'<>c->>'format' or m->'presetIds'->>0 is null or m->'presetIds'->>1 is null
        or m->'presetIds'->>0=m->'presetIds'->>1 or not c->'teamIds' @> m->'presetIds' then raise exception 'INVALID_MATCH_COMPETITION'; end if;
      if jsonb_array_length(c->'teamIds')<2 or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds') not in (2,4,8,16)) then raise exception 'COMPETITION_NOT_READY'; end if;
      if c->>'kind'='knockout' then
        if jsonb_typeof(m->'knockoutRound') is distinct from 'number' or (m->>'knockoutRound') !~ '^[1-4]$' then raise exception 'INVALID_ROUND'; end if;
        if m->>'status'='finished' then
          if m->>'qualifiedTeamId' is null or not m->'presetIds' ? (m->>'qualifiedTeamId') then raise exception 'QUALIFIER_REQUIRED'; end if;
          select count(*) filter(where x->>'team'='0'),count(*) filter(where x->>'team'='1') into gf0,gf1
            from jsonb_array_elements(m->'goals') x where not (x->>'voided')::boolean;
          if gf0<>gf1 and m->>'qualifiedTeamId' is distinct from (m->'presetIds'->>(case when gf0>gf1 then 0 else 1 end)) then raise exception 'WRONG_QUALIFIER'; end if;
        elsif m->>'qualifiedTeamId' is not null then raise exception 'INVALID_QUALIFIER'; end if;
      elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'INVALID_ROUND'; end if;
    elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'COMPETITION_REQUIRED'; end if;
  end loop;
  -- Valida il tabellone: un incontro per coppia, turni futuri solo dopo tutti i risultati.
  for c in select value from jsonb_array_elements(comps) x where x->>'kind'='knockout' and jsonb_array_length(x->'teamIds') in (2,4,8,16) loop
    teams:=c->'teamIds';r:=1;checked:='[]'::jsonb;
    while jsonb_array_length(teams)>=2 loop
      winners:='[]'::jsonb;complete:=true;n:=jsonb_array_length(teams);
      for i in 0..(n/2-1) loop
        pair:=jsonb_build_array(teams->(i*2),teams->(i*2+1));
        select count(*) into found_count from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id'
          and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        if found_count>1 then raise exception 'DUPLICATE_FIXTURE'; end if;
        if found_count=0 then complete:=false;continue;end if;
        select value into m from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        checked:=checked||jsonb_build_array(m->'id');winner:=m->>'qualifiedTeamId';
        if m->>'status'='finished' and winner is not null then winners:=winners||jsonb_build_array(winner);else complete:=false;end if;
      end loop;
      exit when not complete;teams:=winners;r:=r+1;
    end loop;
    if exists(select 1 from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and not checked ? (x->>'id')) then raise exception 'ROUND_NOT_AVAILABLE'; end if;
  end loop;
  if s->>'type'='competition' then
    for c in select value from jsonb_array_elements(comps) x where x->>'kind'='league' loop
      if exists(select 1 from jsonb_array_elements(s->'matches') a join jsonb_array_elements(s->'matches') b on a->>'id'<b->>'id'
        where a->>'competitionId'=c->>'id' and b->>'competitionId'=c->>'id' and
        case when coalesce((c->>'doubleLeg')::boolean,false) then a->'presetIds'=b->'presetIds' else a->'presetIds' @> b->'presetIds' end)
      then raise exception 'DUPLICATE_FIXTURE'; end if;
    end loop;
  end if;
end; $$;
create or replace function public.bc_save(p_id text,p_revision bigint,p_state jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare old jsonb; member_role text; m jsonb; p jsonb; c jsonb;
begin
  select state into old from public.bc_leagues where id=p_id for update;
  select role into member_role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if old is null or member_role is null then raise exception 'FORBIDDEN'; end if;
  if p_state->'type' is distinct from old->'type' then raise exception 'LEAGUE_TYPE_FROZEN'; end if;
  if member_role<>'president' and (p_state->'name' is distinct from old->'name' or p_state->'primaryColor' is distinct from old->'primaryColor' or p_state->'secondaryColor' is distinct from old->'secondaryColor') then raise exception 'PRESIDENT_REQUIRED'; end if;
  for p in select value from jsonb_array_elements(coalesce(old->'presets','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'presets','[]'::jsonb)) x where x->>'id'=p->>'id' and (x->'players'=p->'players' or not exists(select 1 from jsonb_array_elements(old->'matches') m where m->'presetIds' ? (p->>'id')))) then raise exception 'PRESET_ROSTER_FROZEN'; end if;
  end loop;
  for c in select value from jsonb_array_elements(coalesce(old->'competitions','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'competitions','[]'::jsonb)) x where x->>'id'=c->>'id') then raise exception 'CANNOT_REMOVE_COMPETITION'; end if;
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'competitionId'=c->>'id') and
      not exists(select 1 from jsonb_array_elements(p_state->'competitions') x where x=c) then raise exception 'COMPETITION_FROZEN'; end if;
  end loop;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id' and
      (x->'competitionId' is distinct from m->'competitionId' or x->'presetIds' is distinct from m->'presetIds' or x->'knockoutRound' is distinct from m->'knockoutRound')) then raise exception 'EVENT_IDENTITY_FROZEN'; end if;
    if not exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id') and
      (m->>'scheduledAt' is null or length(trim(coalesce(m->>'venue',''))) not between 1 and 120) then raise exception 'EVENT_DETAILS_REQUIRED'; end if;
  end loop;
  return public.bc_save_core_v03(p_id,p_revision,p_state);
end; $$;

update public.bc_leagues l set state=l.state||jsonb_build_object('type',coalesce(l.state->'type',to_jsonb(case when jsonb_array_length(coalesce(l.state->'competitions','[]'::jsonb))>0 then 'competition'::text else 'amateur'::text end)),
 'presets',(select coalesce(jsonb_agg(x||jsonb_build_object('numbers',coalesce(x->'numbers','{}'::jsonb))),'[]'::jsonb) from jsonb_array_elements(coalesce(l.state->'presets','[]'::jsonb)) x),
 'competitions',(select coalesce(jsonb_agg(x||jsonb_build_object('doubleLeg',coalesce(x->'doubleLeg','false'::jsonb))),'[]'::jsonb) from jsonb_array_elements(coalesce(l.state->'competitions','[]'::jsonb)) x)),revision=revision+1;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
grant execute on function public.bc_save(text,bigint,jsonb) to authenticated;

-- BASE COMPATIBILE: social_v041.sql
-- Dopo social_v04.sql, una sola volta su Supabase di TEST.
-- Migrazione non eseguita o verificata su un server in questo workspace.
create or replace function public.bc_validate_rules_v041(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare m jsonb; g jsonb; k jsonb; team jsonb; all_players jsonb; n int; t int; sid text; aid text; kid text;
begin
  if jsonb_typeof(s) <> 'object' or jsonb_typeof(s->'id') is distinct from 'string' or jsonb_typeof(s->'name') is distinct from 'string' or length(s->>'id') not between 1 and 128
    or length(trim(s->>'name')) not between 1 and 60
    or jsonb_typeof(s->'players') is distinct from 'array' or jsonb_typeof(s->'matches') is distinct from 'array'
    or pg_column_size(s) > 5242880 or jsonb_array_length(s->'players') > 200 or jsonb_array_length(s->'matches') > 1000
    or (s - array['id','name','players','matches']) <> '{}'::jsonb then
    raise exception 'INVALID_LEAGUE';
  end if;
  if exists(select 1 from jsonb_array_elements(s->'players') p where
    jsonb_typeof(p) <> 'object' or jsonb_typeof(p->'id') is distinct from 'string' or jsonb_typeof(p->'name') is distinct from 'string' or p->>'id' is null or length(p->>'id') not between 1 and 128 or
    p->>'name' is null or length(trim(p->>'name')) not between 1 and 60 or (p-array['id','name']) <> '{}'::jsonb)
    or (select count(*) <> count(distinct p->>'id') from jsonb_array_elements(s->'players') p)
    or (select count(*) <> count(distinct x->>'id') from jsonb_array_elements(s->'matches') x) then
    raise exception 'INVALID_IDS';
  end if;
  select coalesce(jsonb_agg(p->'id'), '[]'::jsonb) into all_players from jsonb_array_elements(s->'players') p;
  for m in select value from jsonb_array_elements(s->'matches') loop
    if jsonb_typeof(m->'id') is distinct from 'string' or jsonb_typeof(m->'creatorId') is distinct from 'string' or m->>'id' is null or length(m->>'id') not between 1 and 128 or m->>'creatorId' is null
      or (m-array['id','format','names','teams','status','startedAt','finishedAt','goals','keepers','creatorId','competitionRules']) <> '{}'::jsonb
      or m->>'status' not in ('scheduled','live','finished') or m->>'status' is null
      or jsonb_typeof(m->'format') <> 'number' or (m->>'format') !~ '^[0-9]+$'
      or jsonb_typeof(m->'names') is distinct from 'array' or jsonb_typeof(m->'teams') is distinct from 'array'
      or jsonb_typeof(m->'goals') is distinct from 'array' or jsonb_typeof(m->'keepers') is distinct from 'array' then
      raise exception 'INVALID_MATCH';
    end if;
    if jsonb_typeof(coalesce(m->'competitionRules','false'::jsonb))<>'boolean' then raise exception 'INVALID_RULES'; end if;
    n := (m->>'format')::int;
    if n not between 2 and 11 or jsonb_array_length(m->'names') <> 2 or jsonb_array_length(m->'teams') <> 2
      or jsonb_array_length(m->'keepers') <> 2
      or exists(select 1 from jsonb_array_elements(m->'names') name where jsonb_typeof(name) <> 'string' or length(trim(name #>> '{}')) not between 1 and 60)
      or jsonb_typeof(m->'teams'->0) is distinct from 'array' or jsonb_typeof(m->'teams'->1) is distinct from 'array'
      or jsonb_array_length(m->'goals') > 1000 then raise exception 'INVALID_ROSTER'; end if;
    if (select count(*) <> count(distinct p) from jsonb_array_elements_text((m->'teams'->0)||(m->'teams'->1)) p)
      or (select count(*) <> count(distinct x->>'id') from jsonb_array_elements(m->'goals') x) then raise exception 'DUPLICATE_ID'; end if;
    for t in 0..1 loop
      team := m->'teams'->t; k := m->'keepers'->t;
      if (case when coalesce((m->>'competitionRules')::boolean,false) then jsonb_array_length(team) not between n and 60 else jsonb_array_length(team)<>n end) or not all_players @> team then raise exception 'INVALID_ROSTER'; end if;
      if jsonb_typeof(k->'mode') is distinct from 'string' or (k-array['mode','fixed','order','minutes','sound','vibration']) <> '{}'::jsonb or (k ? 'sound' and jsonb_typeof(k->'sound') <> 'boolean') or (k ? 'vibration' and jsonb_typeof(k->'vibration') <> 'boolean') or k->>'mode' is null or k->>'mode' not in ('manual','fixed','rotation','none') then raise exception 'INVALID_KEEPER'; end if;
      if k->>'mode' = 'fixed' and (jsonb_typeof(k->'fixed') is distinct from 'string' or k->>'fixed' is null or not team ? (k->>'fixed')) then raise exception 'INVALID_KEEPER'; end if;
      if k ? 'order' and jsonb_typeof(k->'order') is distinct from 'array' then raise exception 'INVALID_ROTATION'; end if;
      if k->>'mode' = 'rotation' then
        if jsonb_typeof(k->'order') is distinct from 'array' or (k->>'minutes') !~ '^[0-9]+$'
          or k->>'minutes' is null then raise exception 'INVALID_ROTATION'; end if;
        if (k->>'minutes')::int not between 1 and 60 or jsonb_array_length(k->'order') <> n
          or not (k->'order' @> team and team @> k->'order')
          or (select count(*) <> count(distinct p) from jsonb_array_elements_text(k->'order') p) then raise exception 'INVALID_ROTATION'; end if;
      end if;
    end loop;
    if m->>'status' = 'scheduled' and (jsonb_array_length(m->'goals') <> 0 or m->>'startedAt' is not null or m->>'finishedAt' is not null) then raise exception 'INVALID_STATE'; end if;
    if m->>'status' in ('live','finished') and m->>'startedAt' is null then raise exception 'INVALID_STATE'; end if;
    if m->>'status' = 'finished' and (m->>'finishedAt' is null or (m->>'finishedAt')::timestamptz < (m->>'startedAt')::timestamptz) then raise exception 'INVALID_STATE'; end if;
    if m->>'status' = 'live' and m->>'finishedAt' is not null then raise exception 'INVALID_STATE'; end if;
    if m->>'startedAt' is not null then
      if jsonb_typeof(m->'startedAt') <> 'string' then raise exception 'INVALID_TIME'; end if;
      perform (m->>'startedAt')::timestamptz;
    end if;
    if m->>'finishedAt' is not null then
      if jsonb_typeof(m->'finishedAt') <> 'string' then raise exception 'INVALID_TIME'; end if;
      perform (m->>'finishedAt')::timestamptz;
    end if;
    for g in select value from jsonb_array_elements(m->'goals') loop
      if jsonb_typeof(g->'id') is distinct from 'string' or jsonb_typeof(g->'time') is distinct from 'string' or jsonb_typeof(g->'team') is distinct from 'number' or g->>'id' is null or g->>'time' is null or g->>'team' not in ('0','1') or g->>'team' is null
        or jsonb_typeof(g->'ownGoal') is distinct from 'boolean' or jsonb_typeof(g->'voided') is distinct from 'boolean'
        or (g-array['id','team','scorer','assist','keeper','ownGoal','time','voided']) <> '{}'::jsonb then raise exception 'INVALID_GOAL'; end if;
      if jsonb_typeof(g->'scorer') is null or jsonb_typeof(g->'scorer') not in ('string','null')
        or jsonb_typeof(g->'assist') is null or jsonb_typeof(g->'assist') not in ('string','null')
        or jsonb_typeof(g->'keeper') is null or jsonb_typeof(g->'keeper') not in ('string','null') then raise exception 'INVALID_GOAL'; end if;
      perform (g->>'time')::timestamptz;
      t := (g->>'team')::int; sid := g->>'scorer'; aid := g->>'assist'; kid := g->>'keeper';
      if sid is not null and not (m->'teams'->(case when (g->>'ownGoal')::boolean then 1-t else t end)) ? sid then raise exception 'INVALID_SCORER'; end if;
      if aid is not null and ((g->>'ownGoal')::boolean or not (m->'teams'->t) ? aid or aid = sid) then raise exception 'INVALID_ASSIST'; end if;
      if kid is not null and not (m->'teams'->(1-t)) ? kid then raise exception 'INVALID_KEEPER'; end if;
      if not coalesce((m->>'competitionRules')::boolean,false) and m->'keepers'->(1-t)->>'mode' = 'fixed' and kid is distinct from (m->'keepers'->(1-t)->>'fixed') then raise exception 'INVALID_KEEPER'; end if;
    end loop;
  end loop;
end;
$$;

create or replace function public.bc_get(p_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me public.bc_members; l public.bc_leagues; members jsonb;
begin
  select * into me from public.bc_members where league_id=p_id and user_id=auth.uid();
  if not found then raise exception 'FORBIDDEN'; end if;
  select * into l from public.bc_leagues where id=p_id;
  select coalesce(jsonb_agg(jsonb_build_object('player_id',player_id,'role',role)), '[]'::jsonb)
    into members from public.bc_members where league_id=p_id;
  return jsonb_build_object('state',l.state,'revision',l.revision,'role',me.role,'player_id',me.player_id,'members',members);
end; $$;
create or replace function public.bc_validate(s jsonb) returns void language plpgsql set search_path='' as $$
declare base jsonb; p jsonb; c jsonb; m jsonb; raw jsonb; players jsonb; presets jsonb; comps jsonb;
  ids jsonb; teams jsonb; pair jsonb; checked jsonb; winners jsonb; r int; i int; n int; found_count int;
  complete boolean; gf0 int; gf1 int; winner text;
begin
  if coalesce(s->>'type','amateur') not in ('amateur','competition') then raise exception 'INVALID_LEAGUE_TYPE'; end if;
  if pg_column_size(s)>5242880 or not public.bc_valid_color(s->'primaryColor') or not public.bc_valid_color(s->'secondaryColor') then raise exception 'INVALID_LEAGUE_COLOR'; end if;
  presets:=coalesce(s->'presets','[]'::jsonb);comps:=coalesce(s->'competitions','[]'::jsonb);
  if jsonb_typeof(presets)<>'array' or jsonb_typeof(comps)<>'array' then raise exception 'INVALID_COMPETITIONS'; end if;
  if jsonb_array_length(presets)>200 or jsonb_array_length(comps)>200 then raise exception 'TOO_MANY_TEAMS'; end if;
  base:=s-array['primaryColor','secondaryColor','presets','competitions','type'];
  select coalesce(jsonb_agg(x-'color'),'[]'::jsonb) into players from jsonb_array_elements(s->'players') x;
  base:=jsonb_set(base,'{players}',players);
  select coalesce(jsonb_agg(x-array['scheduledAt','venue','teamColors','presetIds','competitionId','knockoutRound','qualifiedTeamId']),'[]'::jsonb)
    into raw from jsonb_array_elements(s->'matches') x;
  perform public.bc_validate_rules_v041(jsonb_set(base,'{matches}',raw));
  if exists(select 1 from jsonb_array_elements(s->'players') x where not public.bc_valid_color(x->'color')) then raise exception 'INVALID_PLAYER_COLOR'; end if;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(s->'players') x;
  if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(presets) x) or
    (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(comps) x) then raise exception 'DUPLICATE_TEAM_ID'; end if;
  for p in select value from jsonb_array_elements(presets) loop
    if jsonb_typeof(p->'id') is distinct from 'string' or jsonb_typeof(p->'name') is distinct from 'string'
      or length(p->>'id') not between 1 and 128 or length(trim(p->>'name')) not between 1 and 60
      or not public.bc_valid_color(p->'color') or jsonb_typeof(p->'players') is distinct from 'array'
      or (p-array['id','name','players','color','numbers'])<>'{}'::jsonb then raise exception 'INVALID_PRESET'; end if;
    if jsonb_typeof(coalesce(p->'numbers','{}'::jsonb))<>'object' then raise exception 'INVALID_NUMBERS'; end if;
    if exists(select 1 from jsonb_each(coalesce(p->'numbers','{}'::jsonb)) e where not p->'players' ? e.key or jsonb_typeof(e.value)<>'number' or (e.value#>>'{}') !~ '^[0-9]{1,2}$') then raise exception 'INVALID_NUMBERS'; end if;
    if (select count(*)<>count(distinct value) from jsonb_each(coalesce(p->'numbers','{}'::jsonb))) then raise exception 'DUPLICATE_NUMBER'; end if;
    if jsonb_array_length(p->'players') not between 0 and 60 or not ids @> p->'players'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(p->'players') x) then raise exception 'INVALID_PRESET_ROSTER'; end if;
  end loop;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(presets) x;
  for c in select value from jsonb_array_elements(comps) loop
    if jsonb_typeof(c->'id') is distinct from 'string' or jsonb_typeof(c->'name') is distinct from 'string'
      or length(c->>'id') not between 1 and 128 or length(trim(c->>'name')) not between 1 and 60
      or c->>'kind' is null or c->>'kind' not in ('league','knockout') or jsonb_typeof(c->'format') is distinct from 'number'
      or (c->>'format') !~ '^[0-9]+$' or jsonb_typeof(c->'teamIds') is distinct from 'array'
      or (c-array['id','name','kind','format','teamIds','doubleLeg'])<>'{}'::jsonb then raise exception 'INVALID_COMPETITION'; end if;
    if jsonb_typeof(coalesce(c->'doubleLeg','false'::jsonb))<>'boolean' or (c->>'kind'='knockout' and coalesce((c->>'doubleLeg')::boolean,false)) then raise exception 'INVALID_LEGS'; end if;
    if (c->>'format')::int not between 2 and 11 or not ids @> c->'teamIds'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(c->'teamIds') x)
      or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds')>16) then raise exception 'INVALID_COMPETITION_TEAMS'; end if;
    -- Le rose possono essere completate dopo il salvataggio della squadra.
  end loop;
  for m in select value from jsonb_array_elements(s->'matches') loop
    if m->>'scheduledAt' is not null then
      if jsonb_typeof(m->'scheduledAt')<>'string' then raise exception 'INVALID_DATE'; end if;
      perform (m->>'scheduledAt')::timestamptz;
    end if;
    if m ? 'venue' and (jsonb_typeof(m->'venue')<>'string' or length(m->>'venue')>120) then raise exception 'INVALID_VENUE'; end if;
    if m ? 'teamColors' then
      if jsonb_typeof(m->'teamColors')<>'array' or jsonb_array_length(m->'teamColors')<>2 then raise exception 'INVALID_TEAM_COLOR'; end if;
      if exists(select 1 from jsonb_array_elements(m->'teamColors') v where not public.bc_valid_color(v)) then raise exception 'INVALID_TEAM_COLOR'; end if;
    end if;
    if m ? 'presetIds' then
      if jsonb_typeof(m->'presetIds')<>'array' or jsonb_array_length(m->'presetIds')<>2 then raise exception 'INVALID_TEAM_ID'; end if;
      if exists(select 1 from jsonb_array_elements(m->'presetIds') v where jsonb_typeof(v) not in ('string','null')) or exists(select 1 from jsonb_array_elements_text(m->'presetIds') v where v is not null and not ids ? v) then raise exception 'INVALID_TEAM_ID'; end if;
    end if;
    if m->>'competitionId' is not null then
      select value into c from jsonb_array_elements(comps) x where x->>'id'=m->>'competitionId';
      if c is null or m->>'format'<>c->>'format' or m->'presetIds'->>0 is null or m->'presetIds'->>1 is null
        or m->'presetIds'->>0=m->'presetIds'->>1 or not c->'teamIds' @> m->'presetIds' then raise exception 'INVALID_MATCH_COMPETITION'; end if;
      if jsonb_array_length(c->'teamIds')<2 or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds') not in (2,4,8,16)) then raise exception 'COMPETITION_NOT_READY'; end if;
      if c->>'kind'='knockout' then
        if jsonb_typeof(m->'knockoutRound') is distinct from 'number' or (m->>'knockoutRound') !~ '^[1-4]$' then raise exception 'INVALID_ROUND'; end if;
        if m->>'status'='finished' then
          if m->>'qualifiedTeamId' is null or not m->'presetIds' ? (m->>'qualifiedTeamId') then raise exception 'QUALIFIER_REQUIRED'; end if;
          select count(*) filter(where x->>'team'='0'),count(*) filter(where x->>'team'='1') into gf0,gf1
            from jsonb_array_elements(m->'goals') x where not (x->>'voided')::boolean;
          if gf0<>gf1 and m->>'qualifiedTeamId' is distinct from (m->'presetIds'->>(case when gf0>gf1 then 0 else 1 end)) then raise exception 'WRONG_QUALIFIER'; end if;
        elsif m->>'qualifiedTeamId' is not null then raise exception 'INVALID_QUALIFIER'; end if;
      elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'INVALID_ROUND'; end if;
    elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'COMPETITION_REQUIRED'; end if;
  end loop;
  -- Valida il tabellone: un incontro per coppia, turni futuri solo dopo tutti i risultati.
  for c in select value from jsonb_array_elements(comps) x where x->>'kind'='knockout' and jsonb_array_length(x->'teamIds') in (2,4,8,16) loop
    teams:=c->'teamIds';r:=1;checked:='[]'::jsonb;
    while jsonb_array_length(teams)>=2 loop
      winners:='[]'::jsonb;complete:=true;n:=jsonb_array_length(teams);
      for i in 0..(n/2-1) loop
        pair:=jsonb_build_array(teams->(i*2),teams->(i*2+1));
        select count(*) into found_count from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id'
          and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        if found_count>1 then raise exception 'DUPLICATE_FIXTURE'; end if;
        if found_count=0 then complete:=false;continue;end if;
        select value into m from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        checked:=checked||jsonb_build_array(m->'id');winner:=m->>'qualifiedTeamId';
        if m->>'status'='finished' and winner is not null then winners:=winners||jsonb_build_array(winner);else complete:=false;end if;
      end loop;
      exit when not complete;teams:=winners;r:=r+1;
    end loop;
    if exists(select 1 from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and not checked ? (x->>'id')) then raise exception 'ROUND_NOT_AVAILABLE'; end if;
  end loop;
  if s->>'type'='competition' then
    for c in select value from jsonb_array_elements(comps) x where x->>'kind'='league' loop
      if exists(select 1 from jsonb_array_elements(s->'matches') a join jsonb_array_elements(s->'matches') b on a->>'id'<b->>'id'
        where a->>'competitionId'=c->>'id' and b->>'competitionId'=c->>'id' and
        case when coalesce((c->>'doubleLeg')::boolean,false) then a->'presetIds'=b->'presetIds' else a->'presetIds' @> b->'presetIds' end)
      then raise exception 'DUPLICATE_FIXTURE'; end if;
    end loop;
  end if;
end; $$;
create or replace function public.bc_save(p_id text,p_revision bigint,p_state jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare old jsonb; member_role text; m jsonb; p jsonb; c jsonb; g jsonb;
begin
  select state into old from public.bc_leagues where id=p_id for update;
  select role into member_role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if old is null or member_role is null then raise exception 'FORBIDDEN'; end if;
  if p_state->'type' is distinct from old->'type' then raise exception 'LEAGUE_TYPE_FROZEN'; end if;
  if member_role<>'president' and (p_state->'name' is distinct from old->'name' or p_state->'primaryColor' is distinct from old->'primaryColor' or p_state->'secondaryColor' is distinct from old->'secondaryColor') then raise exception 'PRESIDENT_REQUIRED'; end if;
  for p in select value from jsonb_array_elements(coalesce(old->'presets','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'presets','[]'::jsonb)) x where x->>'id'=p->>'id') then raise exception 'CANNOT_REMOVE_TEAM'; end if;
  end loop;
  for c in select value from jsonb_array_elements(coalesce(old->'competitions','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'competitions','[]'::jsonb)) x where x->>'id'=c->>'id') then raise exception 'CANNOT_REMOVE_COMPETITION'; end if;
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'competitionId'=c->>'id') and
      not exists(select 1 from jsonb_array_elements(p_state->'competitions') x where x=c) then raise exception 'COMPETITION_FROZEN'; end if;
  end loop;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    if coalesce((m->>'competitionRules')::boolean,false) then
      for g in select value from jsonb_array_elements(m->'goals') loop
        if g->>'keeper' is not null and not exists(select 1 from jsonb_array_elements(old->'matches') om cross join lateral jsonb_array_elements(om->'goals') og where om->>'id'=m->>'id' and og->>'id'=g->>'id') then raise exception 'KEEPER_NOT_USED'; end if;
      end loop;
    end if;
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id' and
      (x->'competitionId' is distinct from m->'competitionId' or x->'presetIds' is distinct from m->'presetIds' or x->'knockoutRound' is distinct from m->'knockoutRound')) then raise exception 'EVENT_IDENTITY_FROZEN'; end if;
    if not exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id') and
      (m->>'scheduledAt' is null or length(coalesce(m->>'venue',''))>120) then raise exception 'EVENT_DETAILS_REQUIRED'; end if;
  end loop;
  return public.bc_save_core_v03(p_id,p_revision,p_state);
end; $$;

update public.bc_leagues l set state=jsonb_set(l.state,'{matches}',
 (select coalesce(jsonb_agg(x||jsonb_build_object('competitionRules',l.state->>'type'='competition')||case when l.state->>'type'='competition' then jsonb_build_object('keepers',jsonb_build_array(jsonb_build_object('mode','none','fixed',null,'order','[]'::jsonb,'minutes',5,'sound',false,'vibration',false),jsonb_build_object('mode','none','fixed',null,'order','[]'::jsonb,'minutes',5,'sound',false,'vibration',false))) else '{}'::jsonb end),'[]'::jsonb) from jsonb_array_elements(l.state->'matches') x)),revision=revision+1;

revoke all on function public.bc_validate_rules_v041(jsonb) from public,anon,authenticated;
revoke all on function public.bc_validate(jsonb) from public,anon,authenticated;
grant execute on function public.bc_save(text,bigint,jsonb) to authenticated;

-- BASE COMPATIBILE: social_v043.sql
-- Dopo social_v041.sql, una sola volta su Supabase di TEST. Non eseguita qui.
create or replace function public.bc_validate(s jsonb) returns void language plpgsql set search_path='' as $$
declare base jsonb; p jsonb; c jsonb; m jsonb; raw jsonb; players jsonb; presets jsonb; comps jsonb;
  ids jsonb; teams jsonb; pair jsonb; checked jsonb; winners jsonb; r int; i int; n int; found_count int;
  complete boolean; gf0 int; gf1 int; winner text;
begin
  if coalesce(s->>'type','amateur') not in ('amateur','competition') then raise exception 'INVALID_LEAGUE_TYPE'; end if;
  if pg_column_size(s)>5242880 or not public.bc_valid_color(s->'primaryColor') or not public.bc_valid_color(s->'secondaryColor') then raise exception 'INVALID_LEAGUE_COLOR'; end if;
  presets:=coalesce(s->'presets','[]'::jsonb);comps:=coalesce(s->'competitions','[]'::jsonb);
  if jsonb_typeof(presets)<>'array' or jsonb_typeof(comps)<>'array' then raise exception 'INVALID_COMPETITIONS'; end if;
  if jsonb_array_length(presets)>200 or jsonb_array_length(comps)>200 then raise exception 'TOO_MANY_TEAMS'; end if;
  base:=s-array['primaryColor','secondaryColor','presets','competitions','type'];
  select coalesce(jsonb_agg(x-'color'),'[]'::jsonb) into players from jsonb_array_elements(s->'players') x;
  base:=jsonb_set(base,'{players}',players);
  select coalesce(jsonb_agg(x-array['scheduledAt','venue','teamColors','presetIds','competitionId','knockoutRound','qualifiedTeamId']),'[]'::jsonb)
    into raw from jsonb_array_elements(s->'matches') x;
  perform public.bc_validate_rules_v041(jsonb_set(base,'{matches}',raw));
  if exists(select 1 from jsonb_array_elements(s->'players') x where not public.bc_valid_color(x->'color')) then raise exception 'INVALID_PLAYER_COLOR'; end if;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(s->'players') x;
  if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(presets) x) or
    (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(comps) x) then raise exception 'DUPLICATE_TEAM_ID'; end if;
  for p in select value from jsonb_array_elements(presets) loop
    if jsonb_typeof(p->'id') is distinct from 'string' or jsonb_typeof(p->'name') is distinct from 'string'
      or length(p->>'id') not between 1 and 128 or length(trim(p->>'name')) not between 1 and 60
      or not public.bc_valid_color(p->'color') or jsonb_typeof(p->'players') is distinct from 'array'
      or (p-array['id','name','players','color','numbers','archived'])<>'{}'::jsonb then raise exception 'INVALID_PRESET'; end if;
    if jsonb_typeof(coalesce(p->'archived','false'::jsonb))<>'boolean' then raise exception 'INVALID_PRESET'; end if;
    if jsonb_typeof(coalesce(p->'numbers','{}'::jsonb))<>'object' then raise exception 'INVALID_NUMBERS'; end if;
    if exists(select 1 from jsonb_each(coalesce(p->'numbers','{}'::jsonb)) e where not p->'players' ? e.key or jsonb_typeof(e.value)<>'number' or (e.value#>>'{}') !~ '^[0-9]{1,2}$') then raise exception 'INVALID_NUMBERS'; end if;
    if (select count(*)<>count(distinct value) from jsonb_each(coalesce(p->'numbers','{}'::jsonb))) then raise exception 'DUPLICATE_NUMBER'; end if;
    if jsonb_array_length(p->'players') not between 0 and 60 or not ids @> p->'players'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(p->'players') x) then raise exception 'INVALID_PRESET_ROSTER'; end if;
  end loop;
  select coalesce(jsonb_agg(x->'id'),'[]'::jsonb) into ids from jsonb_array_elements(presets) x;
  for c in select value from jsonb_array_elements(comps) loop
    if jsonb_typeof(c->'id') is distinct from 'string' or jsonb_typeof(c->'name') is distinct from 'string'
      or length(c->>'id') not between 1 and 128 or length(trim(c->>'name')) not between 1 and 60
      or c->>'kind' is null or c->>'kind' not in ('league','knockout') or jsonb_typeof(c->'format') is distinct from 'number'
      or (c->>'format') !~ '^[0-9]+$' or jsonb_typeof(c->'teamIds') is distinct from 'array'
      or (c-array['id','name','kind','format','teamIds','doubleLeg'])<>'{}'::jsonb then raise exception 'INVALID_COMPETITION'; end if;
    if jsonb_typeof(coalesce(c->'doubleLeg','false'::jsonb))<>'boolean' or (c->>'kind'='knockout' and coalesce((c->>'doubleLeg')::boolean,false)) then raise exception 'INVALID_LEGS'; end if;
    if (c->>'format')::int not between 2 and 11 or not ids @> c->'teamIds'
      or (select count(*)<>count(distinct x) from jsonb_array_elements_text(c->'teamIds') x)
      or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds')>16) then raise exception 'INVALID_COMPETITION_TEAMS'; end if;
    -- Le rose possono essere completate dopo il salvataggio della squadra.
  end loop;
  for m in select value from jsonb_array_elements(s->'matches') loop
    if m->>'scheduledAt' is not null then
      if jsonb_typeof(m->'scheduledAt')<>'string' then raise exception 'INVALID_DATE'; end if;
      perform (m->>'scheduledAt')::timestamptz;
    end if;
    if m ? 'venue' and (jsonb_typeof(m->'venue')<>'string' or length(m->>'venue')>120) then raise exception 'INVALID_VENUE'; end if;
    if m ? 'teamColors' then
      if jsonb_typeof(m->'teamColors')<>'array' or jsonb_array_length(m->'teamColors')<>2 then raise exception 'INVALID_TEAM_COLOR'; end if;
      if exists(select 1 from jsonb_array_elements(m->'teamColors') v where not public.bc_valid_color(v)) then raise exception 'INVALID_TEAM_COLOR'; end if;
    end if;
    if m ? 'presetIds' then
      if jsonb_typeof(m->'presetIds')<>'array' or jsonb_array_length(m->'presetIds')<>2 then raise exception 'INVALID_TEAM_ID'; end if;
      if exists(select 1 from jsonb_array_elements(m->'presetIds') v where jsonb_typeof(v) not in ('string','null')) or exists(select 1 from jsonb_array_elements_text(m->'presetIds') v where v is not null and not ids ? v) then raise exception 'INVALID_TEAM_ID'; end if;
    end if;
    if m->>'competitionId' is not null then
      select value into c from jsonb_array_elements(comps) x where x->>'id'=m->>'competitionId';
      if c is null or m->>'format'<>c->>'format' or m->'presetIds'->>0 is null or m->'presetIds'->>1 is null
        or m->'presetIds'->>0=m->'presetIds'->>1 or not c->'teamIds' @> m->'presetIds' then raise exception 'INVALID_MATCH_COMPETITION'; end if;
      if jsonb_array_length(c->'teamIds')<2 or (c->>'kind'='knockout' and jsonb_array_length(c->'teamIds') not in (2,4,8,16)) then raise exception 'COMPETITION_NOT_READY'; end if;
      if c->>'kind'='knockout' then
        if jsonb_typeof(m->'knockoutRound') is distinct from 'number' or (m->>'knockoutRound') !~ '^[1-4]$' then raise exception 'INVALID_ROUND'; end if;
        if m->>'status'='finished' then
          if m->>'qualifiedTeamId' is null or not m->'presetIds' ? (m->>'qualifiedTeamId') then raise exception 'QUALIFIER_REQUIRED'; end if;
          select count(*) filter(where x->>'team'='0'),count(*) filter(where x->>'team'='1') into gf0,gf1
            from jsonb_array_elements(m->'goals') x where not (x->>'voided')::boolean;
          if gf0<>gf1 and m->>'qualifiedTeamId' is distinct from (m->'presetIds'->>(case when gf0>gf1 then 0 else 1 end)) then raise exception 'WRONG_QUALIFIER'; end if;
        elsif m->>'qualifiedTeamId' is not null then raise exception 'INVALID_QUALIFIER'; end if;
      elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'INVALID_ROUND'; end if;
    elsif m->>'knockoutRound' is not null or m->>'qualifiedTeamId' is not null then raise exception 'COMPETITION_REQUIRED'; end if;
  end loop;
  -- Valida il tabellone: un incontro per coppia, turni futuri solo dopo tutti i risultati.
  for c in select value from jsonb_array_elements(comps) x where x->>'kind'='knockout' and jsonb_array_length(x->'teamIds') in (2,4,8,16) loop
    teams:=c->'teamIds';r:=1;checked:='[]'::jsonb;
    while jsonb_array_length(teams)>=2 loop
      winners:='[]'::jsonb;complete:=true;n:=jsonb_array_length(teams);
      for i in 0..(n/2-1) loop
        pair:=jsonb_build_array(teams->(i*2),teams->(i*2+1));
        select count(*) into found_count from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id'
          and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        if found_count>1 then raise exception 'DUPLICATE_FIXTURE'; end if;
        if found_count=0 then complete:=false;continue;end if;
        select value into m from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and (x->>'knockoutRound')::int=r and x->'presetIds' @> pair;
        checked:=checked||jsonb_build_array(m->'id');winner:=m->>'qualifiedTeamId';
        if m->>'status'='finished' and winner is not null then winners:=winners||jsonb_build_array(winner);else complete:=false;end if;
      end loop;
      exit when not complete;teams:=winners;r:=r+1;
    end loop;
    if exists(select 1 from jsonb_array_elements(s->'matches') x where x->>'competitionId'=c->>'id' and not checked ? (x->>'id')) then raise exception 'ROUND_NOT_AVAILABLE'; end if;
  end loop;
  if s->>'type'='competition' then
    for c in select value from jsonb_array_elements(comps) x where x->>'kind'='league' loop
      if exists(select 1 from jsonb_array_elements(s->'matches') a join jsonb_array_elements(s->'matches') b on a->>'id'<b->>'id'
        where a->>'competitionId'=c->>'id' and b->>'competitionId'=c->>'id' and
        case when coalesce((c->>'doubleLeg')::boolean,false) then a->'presetIds'=b->'presetIds' else a->'presetIds' @> b->'presetIds' end)
      then raise exception 'DUPLICATE_FIXTURE'; end if;
    end loop;
  end if;
end; $$;
update public.bc_leagues l set state=jsonb_set(l.state,'{presets}',(select coalesce(jsonb_agg(p||jsonb_build_object('archived',coalesce(p->'archived','false'::jsonb))),'[]'::jsonb) from jsonb_array_elements(l.state->'presets') p)),revision=revision+1;
revoke all on function public.bc_validate(jsonb) from public,anon,authenticated;

-- Autorizzazioni applicative: modifica personale in amatoriale e controllo esclusivo evento.
create or replace function public.bc_save_core_v03(p_id text, p_revision bigint, p_state jsonb) returns bigint
language plpgsql security definer set search_path = '' as $$
declare l public.bc_leagues; role text; old jsonb; m jsonb; oldm jsonb; g jsonb; oldg jsonb; idx int;
begin
  select * into l from public.bc_leagues where id=p_id for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  select bc_members.role into role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if role is null then raise exception 'FORBIDDEN'; end if;
  if p_state = l.state then return l.revision; end if; -- retry identico non genera un secondo risultato
  if p_revision is null or p_revision <> l.revision then raise exception 'REVISION_CONFLICT: aggiorna la lega prima di riprovare'; end if;
  perform public.bc_validate(p_state);
  if p_state->>'id' <> p_id then raise exception 'INVALID_ID'; end if;
  old := l.state;
  if role='member' then
   if (p_state-array['matches','players']) is distinct from (old-array['matches','players']) or
      jsonb_array_length(p_state->'players')<>jsonb_array_length(old->'players') then raise exception 'ADMIN_REQUIRED';end if;
   idx:=0;
   for oldg in select value from jsonb_array_elements(old->'players') loop
     g:=p_state->'players'->idx;
     if g is distinct from oldg and (old->>'type'<>'amateur' or
       not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and player_id=oldg->>'id') or
       (g-array['name','color']) is distinct from (oldg-array['name','color'])) then raise exception 'ADMIN_REQUIRED';end if;
     idx:=idx+1;
   end loop;
 end if;
  if exists(select 1 from jsonb_array_elements(old->'players') p where not exists(
    select 1 from jsonb_array_elements(p_state->'players') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_PLAYER'; end if;
  if exists(select 1 from jsonb_array_elements(old->'matches') p where not exists(
    select 1 from jsonb_array_elements(p_state->'matches') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_MATCH'; end if;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    select value into oldm from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id';
    if oldm is null then
      if role not in ('president','admin') or m->>'creatorId' is distinct from auth.uid()::text or m->>'status' <> 'scheduled' then raise exception 'ADMIN_REQUIRED'; end if;
    elsif m <> oldm then
      if oldm->>'creatorId' is distinct from auth.uid()::text or m->>'creatorId' is distinct from oldm->>'creatorId' then raise exception 'ONLY_EVENT_CREATOR'; end if;
      if oldm->>'status' = 'finished' then raise exception 'MATCH_FINISHED'; end if;
      if oldm->>'status' = 'scheduled' and m->>'status' not in ('scheduled','live') then raise exception 'INVALID_TRANSITION'; end if;
      if oldm->>'status' = 'live' then
        if m->>'status' not in ('live','finished') or (m-array['status','finishedAt','goals','qualifiedTeamId']) <> (oldm-array['status','finishedAt','goals','qualifiedTeamId']) then raise exception 'ROSTER_FROZEN'; end if;
      end if;
      if jsonb_array_length(m->'goals') < jsonb_array_length(oldm->'goals') then raise exception 'CANNOT_DELETE_GOAL'; end if;
      idx := 0;
      for oldg in select value from jsonb_array_elements(oldm->'goals') loop
        g := m->'goals'->idx;
        if (g-'voided') <> (oldg-'voided') or ((oldg->>'voided')::boolean and not (g->>'voided')::boolean) then raise exception 'GOAL_IMMUTABLE'; end if;
        idx := idx + 1;
      end loop;
      while idx < jsonb_array_length(m->'goals') loop
        if (m->'goals'->idx->>'voided')::boolean then raise exception 'INVALID_NEW_GOAL'; end if;
        idx := idx + 1;
      end loop;
      -- Non consentire gol nel medesimo aggiornamento che avvia o chiude l'evento.
      if oldm->>'status' <> m->>'status' and m->'goals' <> oldm->'goals' then raise exception 'STATE_AND_GOAL_SEPARATE'; end if;
    end if;
  end loop;
  update public.bc_leagues set state=p_state,revision=revision+1 where id=p_id returning revision into p_revision;
  insert into public.bc_audit(league_id,actor,action,revision) values(p_id,auth.uid(),'save',p_revision);
  return p_revision;
end; $$;



create or replace function public.bc_save(p_id text,p_revision bigint,p_state jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare old jsonb; member_role text; m jsonb; p jsonb; c jsonb; g jsonb;
begin
  select state into old from public.bc_leagues where id=p_id for update;
  select role into member_role from public.bc_members where league_id=p_id and user_id=auth.uid();
  if old is null or member_role is null then raise exception 'FORBIDDEN'; end if;
  if p_state->'type' is distinct from old->'type' then raise exception 'LEAGUE_TYPE_FROZEN'; end if;
  if member_role='member' and (p_state->'name' is distinct from old->'name' or p_state->'primaryColor' is distinct from old->'primaryColor' or p_state->'secondaryColor' is distinct from old->'secondaryColor') then raise exception 'PRESIDENT_REQUIRED'; end if;
  for p in select value from jsonb_array_elements(coalesce(old->'presets','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'presets','[]'::jsonb)) x where x->>'id'=p->>'id') then raise exception 'CANNOT_REMOVE_TEAM'; end if;
  end loop;
  for c in select value from jsonb_array_elements(coalesce(old->'competitions','[]'::jsonb)) loop
    if not exists(select 1 from jsonb_array_elements(coalesce(p_state->'competitions','[]'::jsonb)) x where x->>'id'=c->>'id') then raise exception 'CANNOT_REMOVE_COMPETITION'; end if;
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'competitionId'=c->>'id') and
      not exists(select 1 from jsonb_array_elements(p_state->'competitions') x where x=c) then raise exception 'COMPETITION_FROZEN'; end if;
  end loop;
  for m in select value from jsonb_array_elements(p_state->'matches') loop
    if coalesce((m->>'competitionRules')::boolean,false) then
      for g in select value from jsonb_array_elements(m->'goals') loop
        if g->>'keeper' is not null and not exists(select 1 from jsonb_array_elements(old->'matches') om cross join lateral jsonb_array_elements(om->'goals') og where om->>'id'=m->>'id' and og->>'id'=g->>'id') then raise exception 'KEEPER_NOT_USED'; end if;
      end loop;
    end if;
    if exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id' and
      (x->'competitionId' is distinct from m->'competitionId' or x->'presetIds' is distinct from m->'presetIds' or x->'knockoutRound' is distinct from m->'knockoutRound')) then raise exception 'EVENT_IDENTITY_FROZEN'; end if;
    if not exists(select 1 from jsonb_array_elements(old->'matches') x where x->>'id'=m->>'id') and
      (m->>'scheduledAt' is null or length(coalesce(m->>'venue',''))>120) then raise exception 'EVENT_DETAILS_REQUIRED'; end if;
  end loop;
  return public.bc_save_core_v03(p_id,p_revision,p_state);
end; $$;

-- Profili privati: l'email rimane nel servizio Auth, non viene copiata nella lega.
create table public.hayko_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 first_name text not null default '' check(length(first_name)<=60),
 last_name text not null default '' check(length(last_name)<=60),
 nickname text not null default '' check(length(nickname)<=60),
 updated_at timestamptz not null default now()
);
alter table public.hayko_profiles enable row level security;
revoke all on public.hayko_profiles from public,anon,authenticated;

create or replace function public.hayko_new_profile() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.hayko_profiles(user_id,first_name,last_name,nickname) values(
  new.id,left(trim(coalesce(new.raw_user_meta_data->>'first_name','')),60),
  left(trim(coalesce(new.raw_user_meta_data->>'last_name','')),60),
  left(trim(coalesce(new.raw_user_meta_data->>'nickname','')),60));
 return new;
end; $$;
create trigger hayko_auth_profile after insert on auth.users
 for each row execute function public.hayko_new_profile();

create or replace function public.hayko_profile() returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.hayko_profiles;
begin
 if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
 insert into public.hayko_profiles(user_id) values(auth.uid()) on conflict do nothing;
 select * into p from public.hayko_profiles where user_id=auth.uid();
 return jsonb_build_object('first_name',p.first_name,'last_name',p.last_name,'nickname',p.nickname);
end; $$;
create or replace function public.hayko_save_profile(p_first text,p_last text,p_nickname text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
 if p_first is null or p_last is null or p_nickname is null or
  length(trim(p_first)) not between 1 and 60 or length(trim(p_last)) not between 1 and 60 or
  length(trim(p_nickname)) not between 1 and 60 then raise exception 'PROFILE_REQUIRED'; end if;
 insert into public.hayko_profiles(user_id,first_name,last_name,nickname)
 values(auth.uid(),trim(p_first),trim(p_last),trim(p_nickname)) on conflict(user_id) do update
 set first_name=excluded.first_name,last_name=excluded.last_name,nickname=excluded.nickname,updated_at=now();
 return public.hayko_profile();
end; $$;

create table public.hayko_join_requests (
 league_id text not null references public.bc_leagues(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 requested_at timestamptz not null default now(),
 primary key(league_id,user_id)
);
alter table public.hayko_join_requests enable row level security;
revoke all on public.hayko_join_requests from public,anon,authenticated;

-- Un invito produce una richiesta, mai una membership automatica.
create or replace function public.bc_join(p_token text) returns text
language plpgsql security definer set search_path='' as $$
declare i public.bc_invites; previous text;
begin
 if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
 if p_token is null or length(p_token)<>64 then raise exception 'INVALID_INVITE'; end if;
 select * into i from public.bc_invites where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex');
 if not found then raise exception 'INVALID_INVITE'; end if;
 perform 1 from public.bc_leagues where id=i.league_id for update;
 select * into i from public.bc_invites where token_hash=i.token_hash for update;
 if i.revoked or i.expires_at<=now() then raise exception 'INVITE_EXPIRED_OR_REVOKED'; end if;
 if exists(select 1 from public.bc_members where league_id=i.league_id and user_id=auth.uid()) then return i.league_id;end if;
 select status into previous from public.hayko_join_requests where league_id=i.league_id and user_id=auth.uid();
 if previous='pending' then return i.league_id;end if;
 if i.uses>=i.max_uses then raise exception 'INVITE_EXPIRED_OR_REVOKED';end if;
 insert into public.hayko_join_requests(league_id,user_id) values(i.league_id,auth.uid())
 on conflict(league_id,user_id) do update set status='pending',requested_at=now();
 update public.bc_invites set uses=uses+1 where token_hash=i.token_hash;
 return i.league_id;
end; $$;

create or replace function public.hayko_requests(p_id text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'FORBIDDEN';end if;
 if p_id is not null and not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('league_id',r.league_id,'league_name',l.state->>'name',
  'user_id',r.user_id,'name',coalesce(nullif(p.first_name,''),'Giocatore'),'status',r.status) order by r.requested_at),'[]'::jsonb)
 into result from public.hayko_join_requests r join public.bc_leagues l on l.id=r.league_id
 left join public.hayko_profiles p on p.user_id=r.user_id
 where case when p_id is null then r.user_id=auth.uid() else r.league_id=p_id and r.status='pending' end;
 return result;
end; $$;
create or replace function public.hayko_review_request(p_id text,p_user uuid,p_accept boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.bc_leagues where id=p_id for update;
 if not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED';end if;
 if p_accept is null then raise exception 'INVALID_DECISION';end if;
 update public.hayko_join_requests set status=case when p_accept then 'approved' else 'rejected' end
 where league_id=p_id and user_id=p_user and status='pending';
 if not found then raise exception 'REQUEST_NOT_PENDING';end if;
 if p_accept then
  insert into public.bc_members(league_id,user_id,role) values(p_id,p_user,'member') on conflict do nothing;
 end if;
 update public.bc_leagues set revision=revision+1 where id=p_id;
end; $$;

create or replace function public.bc_claim(p_id text,p_player text default null,p_name text default null) returns void
language plpgsql security definer set search_path='' as $$
declare l public.bc_leagues; existing text; chosen text:=p_player; s jsonb;
begin
 select * into l from public.bc_leagues where id=p_id for update;
 select player_id into existing from public.bc_members where league_id=p_id and user_id=auth.uid();
 if not found then raise exception 'FORBIDDEN';end if;
 if existing is not null then raise exception 'ALREADY_ASSOCIATED';end if;
 s:=l.state;
 if chosen is null then
  if p_name is null or length(trim(p_name)) not between 1 and 60 then raise exception 'INVALID_NAME';end if;
  chosen:=replace(gen_random_uuid()::text,'-','');
  s:=jsonb_set(s,'{players}',(s->'players')||jsonb_build_array(jsonb_build_object('id',chosen,'name',trim(p_name),'color',s->'primaryColor')));
 elsif not exists(select 1 from jsonb_array_elements(s->'players') p where p->>'id'=chosen) then raise exception 'INVALID_PLAYER';end if;
 if exists(select 1 from public.bc_members where league_id=p_id and player_id=chosen) then raise exception 'PLAYER_ALREADY_ASSOCIATED';end if;
 perform public.bc_validate(s);
 update public.bc_members set player_id=chosen where league_id=p_id and user_id=auth.uid();
 update public.bc_leagues set state=s,revision=revision+1 where id=p_id;
end; $$;

create or replace function public.hayko_members(p_id text) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'player_id',m.player_id,'role',m.role,
  'name',coalesce((select x->>'name' from jsonb_array_elements(l.state->'players') x where x->>'id'=m.player_id),nullif(p.first_name,''),'Giocatore'))),'[]'::jsonb)
  from public.bc_members m join public.bc_leagues l on l.id=m.league_id left join public.hayko_profiles p on p.user_id=m.user_id where m.league_id=p_id);
end; $$;
create or replace function public.hayko_remove_member(p_id text,p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
declare mine text; theirs text;
begin
 perform 1 from public.bc_leagues where id=p_id for update;
 select role into mine from public.bc_members where league_id=p_id and user_id=auth.uid();
 select role into theirs from public.bc_members where league_id=p_id and user_id=p_user;
 if mine is null or mine not in ('president','admin') or theirs is null or theirs='president' or
  (mine='admin' and theirs<>'member') or p_user=auth.uid() then raise exception 'FORBIDDEN';end if;
 delete from public.bc_members where league_id=p_id and user_id=p_user;
 delete from public.hayko_join_requests where league_id=p_id and user_id=p_user;
 update public.bc_leagues set revision=revision+1 where id=p_id;
end; $$;

revoke all on function public.hayko_new_profile(),public.hayko_profile(),public.hayko_save_profile(text,text,text),
 public.hayko_requests(text),public.hayko_review_request(text,uuid,boolean),public.hayko_members(text),public.hayko_remove_member(text,uuid)
 from public,anon,authenticated;
grant execute on function public.hayko_profile(),public.hayko_save_profile(text,text,text),
 public.hayko_requests(text),public.hayko_review_request(text,uuid,boolean),public.hayko_members(text),public.hayko_remove_member(text,uuid)
 to authenticated;

commit;
