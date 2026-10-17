-- Dopo social_v041.sql, una sola volta su Supabase di TEST. Non eseguita qui.
begin;
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
commit;
