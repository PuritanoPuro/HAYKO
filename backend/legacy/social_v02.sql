-- MVP social autonomo Supabase: non richiede schema.sql v0.1.
-- Snapshot di lega JSON + lock/revisione: percorso MVP, non database analitico finale.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
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

create function public.bc_validate(s jsonb) returns void
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

create function public.bc_get(p_id text) returns jsonb
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
create function public.bc_list() returns jsonb
language sql security definer set search_path = '' as $$
  select coalesce(jsonb_agg(public.bc_get(league_id)), '[]'::jsonb) from public.bc_members where user_id=auth.uid();
$$;
create function public.bc_create(p_state jsonb) returns text
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

create function public.bc_save(p_id text, p_revision bigint, p_state jsonb) returns bigint
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

create function public.bc_invite(p_id text) returns text
language plpgsql security definer set search_path = '' as $$
declare token text := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
begin
  perform 1 from public.bc_leagues where id=p_id for update;
  if not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED'; end if;
  insert into public.bc_invites(token_hash,league_id,expires_at,created_by)
    values(encode(extensions.digest(token,'sha256'),'hex'),p_id,now()+interval '7 days',auth.uid());
  return token;
end; $$;
create function public.bc_join(p_token text) returns text
language plpgsql security definer set search_path = '' as $$
declare i public.bc_invites;
begin
  if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
  if length(p_token) <> 64 then raise exception 'INVALID_INVITE'; end if;
  select * into i from public.bc_invites where token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
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
create function public.bc_revoke_invites(p_id text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.bc_leagues where id=p_id for update;
  if not exists(select 1 from public.bc_members where league_id=p_id and user_id=auth.uid() and role in ('president','admin')) then raise exception 'ADMIN_REQUIRED'; end if;
  update public.bc_invites set revoked=true where league_id=p_id;
end; $$;
create function public.bc_claim(p_id text, p_player text default null, p_name text default null) returns void
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
create function public.bc_role(p_id text, p_player text, p_role text) returns void
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
