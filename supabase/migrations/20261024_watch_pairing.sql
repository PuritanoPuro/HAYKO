create extension if not exists pgcrypto with schema extensions;

create table if not exists public.hayko_watch_pairings (
  code_hash bytea primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz
);

create table if not exists public.hayko_watch_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token_hash bytea not null unique,
  label text not null default 'Smartwatch',
  created_at timestamptz not null default now(),
  last_seen_at timestamptz,
  revoked_at timestamptz
);

create table if not exists public.hayko_watch_commands (
  device_id uuid not null references public.hayko_watch_devices(id) on delete cascade,
  command_id text not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (device_id, command_id)
);

alter table public.hayko_watch_pairings enable row level security;
alter table public.hayko_watch_devices enable row level security;
alter table public.hayko_watch_commands enable row level security;
revoke all on public.hayko_watch_pairings, public.hayko_watch_devices, public.hayko_watch_commands from public, anon, authenticated;

create or replace function public.hayko_watch_pairing_code() returns text
language plpgsql security definer set search_path='' as $$
declare code text; attempts int := 0;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  delete from public.hayko_watch_pairings where expires_at < now() or user_id=auth.uid();
  loop
    code := lpad((floor(random()*1000000))::int::text,6,'0');
    begin
      insert into public.hayko_watch_pairings(code_hash,user_id,expires_at)
      values(extensions.digest(code,'sha256'),auth.uid(),now()+interval '10 minutes');
      return code;
    exception when unique_violation then
      attempts := attempts+1;
      if attempts>10 then raise exception 'PAIRING_CODE_UNAVAILABLE'; end if;
    end;
  end loop;
end $$;

create or replace function public.hayko_watch_redeem(p_code text, p_label text default 'Amazfit Bip 5') returns jsonb
language plpgsql security definer set search_path='' as $$
declare pairing public.hayko_watch_pairings; raw_token text; device_id uuid;
begin
  if p_code !~ '^[0-9]{6}$' then raise exception 'INVALID_PAIRING_CODE'; end if;
  select * into pairing from public.hayko_watch_pairings
   where code_hash=extensions.digest(p_code,'sha256') and used_at is null and expires_at>now() for update;
  if not found then raise exception 'INVALID_OR_EXPIRED_PAIRING_CODE'; end if;
  raw_token := encode(extensions.gen_random_bytes(32),'hex');
  insert into public.hayko_watch_devices(user_id,token_hash,label)
  values(pairing.user_id,extensions.digest(raw_token,'sha256'),left(coalesce(nullif(trim(p_label),''),'Smartwatch'),60))
  returning id into device_id;
  update public.hayko_watch_pairings set used_at=now() where code_hash=pairing.code_hash;
  return jsonb_build_object('deviceId',device_id,'token',raw_token);
end $$;

create or replace function public.hayko_watch_snapshot(p_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.hayko_watch_devices; item record;
begin
  select * into d from public.hayko_watch_devices
   where token_hash=extensions.digest(p_token,'sha256') and revoked_at is null;
  if not found then raise exception 'INVALID_DEVICE_TOKEN'; end if;
  update public.hayko_watch_devices set last_seen_at=now() where id=d.id;
  select l.id league_id,l.revision,l.state,m.value match
    into item
    from public.bc_leagues l
    join public.bc_members member on member.league_id=l.id and member.user_id=d.user_id
    cross join lateral jsonb_array_elements(l.state->'matches') m(value)
   where m.value->>'creatorId'=d.user_id::text and m.value->>'status' in ('scheduled','live')
   order by (m.value->>'status'='live') desc,
     abs(extract(epoch from (coalesce((m.value->>'scheduledAt')::timestamptz,now())-now())))
   limit 1;
  if item is null then return jsonb_build_object('match',null); end if;
  return jsonb_build_object('leagueId',item.league_id,'revision',item.revision,
    'players',item.state->'players','match',item.match,'serverTime',now());
end $$;

create or replace function public.hayko_watch_command(p_token text,p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.hayko_watch_devices; existing jsonb; l public.bc_leagues; m jsonb; next_m jsonb;
 idx int; command_id text; command_type text; payload jsonb; goal jsonb; result jsonb; team int;
begin
  select * into d from public.hayko_watch_devices where token_hash=extensions.digest(p_token,'sha256') and revoked_at is null;
  if not found then raise exception 'INVALID_DEVICE_TOKEN'; end if;
  command_id:=p_command->>'id'; command_type:=p_command->>'type'; payload:=coalesce(p_command->'payload','{}'::jsonb);
  if command_id is null or length(command_id)>160 then raise exception 'INVALID_COMMAND_ID'; end if;
  select response into existing from public.hayko_watch_commands where device_id=d.id and hayko_watch_commands.command_id=command_id;
  if existing is not null then return existing; end if;
  select bl.* into l from public.bc_leagues bl join public.bc_members bm on bm.league_id=bl.id and bm.user_id=d.user_id
   where exists(select 1 from jsonb_array_elements(bl.state->'matches') x where x->>'id'=p_command->>'matchId') for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  select value,ordinality-1 into m,idx from jsonb_array_elements(l.state->'matches') with ordinality x(value,ordinality)
   where value->>'id'=p_command->>'matchId';
  if m->>'creatorId' is distinct from d.user_id::text then raise exception 'ONLY_EVENT_CREATOR'; end if;
  if command_type='start_match' then
    if m->>'status'<>'scheduled' then raise exception 'INVALID_TRANSITION'; end if;
    next_m:=jsonb_set(jsonb_set(m,'{status}','"live"'::jsonb),'{startedAt}',to_jsonb(now()));
  elsif command_type='add_goal' then
    if m->>'status'<>'live' then raise exception 'MATCH_NOT_LIVE'; end if;
    team:=(payload->>'team')::int;
    if team not in (0,1) then raise exception 'INVALID_TEAM'; end if;
    if payload->>'scorerId' is not null and not (m->'teams'->team ? (payload->>'scorerId')) then raise exception 'INVALID_SCORER'; end if;
    if payload->>'assistId' is not null and (payload->>'assistId'=payload->>'scorerId' or not (m->'teams'->team ? (payload->>'assistId'))) then raise exception 'INVALID_ASSIST'; end if;
    if not coalesce((m->>'competitionRules')::boolean,false) and payload->>'keeperId' is not null and not (m->'teams'->(1-team) ? (payload->>'keeperId')) then raise exception 'INVALID_KEEPER'; end if;
    goal:=jsonb_build_object('id',command_id,'team',team,'scorer',payload->>'scorerId','assist',payload->>'assistId',
      'keeper',case when coalesce((m->>'competitionRules')::boolean,false) then null else payload->>'keeperId' end,
      'ownGoal',false,'time',now(),'voided',false);
    next_m:=jsonb_set(m,'{goals}',coalesce(m->'goals','[]'::jsonb)||jsonb_build_array(goal));
  else raise exception 'UNSUPPORTED_WATCH_COMMAND'; end if;
  l.state:=jsonb_set(l.state,array['matches',idx::text],next_m);
  perform public.bc_validate(l.state);
  update public.bc_leagues set state=l.state,revision=revision+1 where id=l.id returning revision into l.revision;
  insert into public.bc_audit(league_id,actor,action,revision) values(l.id,d.user_id,'watch_'||command_type,l.revision);
  result:=jsonb_build_object('ok',true,'commandId',command_id,'revision',l.revision,'match',next_m);
  insert into public.hayko_watch_commands(device_id,command_id,response) values(d.id,command_id,result);
  return result;
end $$;

create or replace function public.hayko_watch_devices() returns jsonb
language sql security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',label,'createdAt',created_at,'lastSeenAt',last_seen_at)
 order by created_at desc),'[]'::jsonb) from public.hayko_watch_devices where user_id=auth.uid() and revoked_at is null
$$;

create or replace function public.hayko_watch_revoke(p_device uuid) returns void
language sql security definer set search_path='' as $$
 update public.hayko_watch_devices set revoked_at=now() where id=p_device and user_id=auth.uid()
$$;

revoke all on function public.hayko_watch_pairing_code(),public.hayko_watch_redeem(text,text),public.hayko_watch_snapshot(text),public.hayko_watch_command(text,jsonb),public.hayko_watch_devices(),public.hayko_watch_revoke(uuid) from public;
grant execute on function public.hayko_watch_pairing_code(),public.hayko_watch_devices(),public.hayko_watch_revoke(uuid) to authenticated;
grant execute on function public.hayko_watch_redeem(text,text),public.hayko_watch_snapshot(text),public.hayko_watch_command(text,jsonb) to anon,authenticated;
