-- Dopo social_v02.sql, una sola volta su Supabase di TEST. Migrazione transazionale.
begin;
alter function public.bc_validate(jsonb) rename to bc_validate_base_v02;
create function public.bc_valid_color(v jsonb) returns boolean language sql set search_path='' as $$
  select case when v is null then true when jsonb_typeof(v)='number' then
    (v #>> '{}') ~ '^[0-9]+$' and (v #>> '{}')::numeric between 4278190080 and 4294967295 else false end;
$$;
create function public.bc_validate(s jsonb) returns void language plpgsql set search_path='' as $$
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

create function public.bc_save_core_v03(p_id text, p_revision bigint, p_state jsonb) returns bigint
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

create function public.bc_delete(p_id text,p_name text) returns void
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
create function public.bc_claim(p_id text,p_player text default null,p_name text default null) returns void
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
commit;
