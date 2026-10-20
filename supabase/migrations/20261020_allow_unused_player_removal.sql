-- Allow administrators to remove a player that has never been used.
-- Historical players, saved-team players and account-linked players remain
-- immutable so matches, statistics and memberships cannot lose references.
begin;

do $patch$
declare
  function_id regprocedure :=
    to_regprocedure('public.bc_save_core_v03(text,bigint,jsonb)');
  definition text;
  original text;
  old_rule text := $rule$
  if exists(select 1 from jsonb_array_elements(old->'players') p where not exists(
    select 1 from jsonb_array_elements(p_state->'players') q where q->>'id'=p->>'id')) then raise exception 'CANNOT_REMOVE_PLAYER'; end if;
$rule$;
  new_rule text := $rule$
  if exists(
    select 1
    from jsonb_array_elements(old->'players') p
    where not exists(
      select 1 from jsonb_array_elements(p_state->'players') q
      where q->>'id'=p->>'id'
    )
    and (
      exists(
        select 1
        from jsonb_array_elements(coalesce(old->'matches','[]'::jsonb)) match,
             lateral jsonb_array_elements(coalesce(match->'teams','[]'::jsonb)) team
        where team ? (p->>'id')
      )
      or exists(
        select 1
        from jsonb_array_elements(coalesce(old->'matches','[]'::jsonb)) match,
             lateral jsonb_array_elements(coalesce(match->'goals','[]'::jsonb)) goal
        where goal->>'scorer'=p->>'id'
           or goal->>'assist'=p->>'id'
           or goal->>'keeper'=p->>'id'
      )
      or exists(
        select 1
        from jsonb_array_elements(coalesce(old->'presets','[]'::jsonb)) preset
        where coalesce(preset->'players','[]'::jsonb) ? (p->>'id')
      )
      or exists(
        select 1 from public.bc_members member
        where member.league_id=p_id and member.player_id=p->>'id'
      )
    )
  ) then raise exception 'CANNOT_REMOVE_PLAYER'; end if;
$rule$;
begin
  if function_id is null then
    raise exception 'HAYKO_PATCH_MISSING_FUNCTION: bc_save_core_v03';
  end if;

  original := pg_get_functiondef(function_id);
  definition := original;
  if strpos(definition, old_rule) > 0 then
    definition := replace(definition, old_rule, new_rule);
  elsif strpos(definition, new_rule) = 0 then
    raise exception 'HAYKO_PATCH_UNEXPECTED_DEFINITION: bc_save_core_v03';
  end if;

  if definition <> original then
    -- CREATE OR REPLACE preserves ownership and existing grants.
    execute definition;
  end if;
end;
$patch$;

commit;
