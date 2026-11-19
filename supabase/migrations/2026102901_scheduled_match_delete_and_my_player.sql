-- Scheduled events can be removed by their creator. A player's personal
-- identity is updated atomically so unrelated match revisions cannot conflict.
begin;

create or replace function public.bc_update_my_player(
  p_id text,
  p_name text,
  p_color bigint
) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  league public.bc_leagues;
  player text;
  next_players jsonb;
  next_revision bigint;
begin
  select * into league from public.bc_leagues where id=p_id for update;
  if not found then raise exception 'NOT_FOUND'; end if;

  select player_id into player
  from public.bc_members
  where league_id=p_id and user_id=auth.uid();
  if player is null then raise exception 'PLAYER_NOT_ASSOCIATED'; end if;
  if league.state->>'type' <> 'amateur' then raise exception 'AMATEUR_ONLY'; end if;
  if length(trim(coalesce(p_name,''))) not between 1 and 60 then
    raise exception 'INVALID_PLAYER_NAME';
  end if;
  if not public.bc_valid_color(to_jsonb(p_color)) then
    raise exception 'INVALID_PLAYER_COLOR';
  end if;
  if exists(
    select 1 from jsonb_array_elements(league.state->'players') value
    where value->>'id' <> player
      and lower(trim(value->>'name')) = lower(trim(p_name))
  ) then raise exception 'DUPLICATE_PLAYER_NAME'; end if;

  select jsonb_agg(
    case when value->>'id'=player
      then jsonb_set(jsonb_set(value,'{name}',to_jsonb(trim(p_name))),
                     '{color}',to_jsonb(p_color))
      else value end
    order by ordinality
  ) into next_players
  from jsonb_array_elements(league.state->'players') with ordinality;
  if not exists(
    select 1 from jsonb_array_elements(league.state->'players') value
    where value->>'id'=player
  ) then raise exception 'PLAYER_NOT_FOUND'; end if;

  update public.bc_leagues
  set state=jsonb_set(state,'{players}',next_players), revision=revision+1
  where id=p_id returning revision into next_revision;
  insert into public.bc_audit(league_id,actor,action,revision)
  values(p_id,auth.uid(),'update_my_player',next_revision);
  return next_revision;
end; $$;

revoke all on function public.bc_update_my_player(text,text,bigint)
from public, anon;
grant execute on function public.bc_update_my_player(text,text,bigint)
to authenticated;

do $patch$
declare
  function_id regprocedure :=
    to_regprocedure('public.bc_save_core_v03(text,bigint,jsonb)');
  definition text;
  original text;
  rule_start int;
  rule_end int;
  old_start text := $rule$if exists(select 1 from jsonb_array_elements(old->'matches') p where not exists($rule$;
  old_end text := $rule$then raise exception 'CANNOT_REMOVE_MATCH'; end if;$rule$;
  new_rule text := $rule$
  if exists(
    select 1 from jsonb_array_elements(old->'matches') match
    where not exists(
      select 1 from jsonb_array_elements(p_state->'matches') next_match
      where next_match->>'id'=match->>'id'
    )
    and (
      match->>'status'<>'scheduled'
      or match->>'creatorId' is distinct from auth.uid()::text
    )
  ) then raise exception 'CANNOT_REMOVE_MATCH'; end if;
$rule$;
begin
  if function_id is null then
    raise exception 'HAYKO_PATCH_MISSING_FUNCTION: bc_save_core_v03';
  end if;
  original := pg_get_functiondef(function_id);
  definition := original;
  if strpos(definition, 'jsonb_array_elements(p_state->''matches'') next_match') = 0 then
    rule_start := strpos(definition, old_start);
    rule_end := strpos(substring(definition from rule_start), old_end);
    if rule_start = 0 or rule_end = 0 then
      raise exception 'HAYKO_PATCH_UNEXPECTED_DEFINITION: bc_save_core_v03';
    end if;
    rule_end := rule_start + rule_end - 1 + length(old_end);
    definition := substring(definition from 1 for rule_start - 1)
      || new_rule || substring(definition from rule_end);
  end if;
  if definition <> original then execute definition; end if;
end;
$patch$;

commit;
