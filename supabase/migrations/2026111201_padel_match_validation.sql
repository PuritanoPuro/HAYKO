-- Valida i dati Padel aggiunti ai match e inoltra al validatore storico una
-- copia priva delle sole chiavi specifiche dello sport. bc_save conserva e
-- salva comunque lo stato originale completo.
create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  normalized jsonb := s - 'sport';
  normalized_competitions jsonb;
  normalized_matches jsonb;
  match_value jsonb;
  set_value jsonb;
  best_of int;
begin
  if coalesce(s->>'sport', 'football') not in ('football', 'padel') then
    raise exception 'INVALID_SPORT';
  end if;
  if jsonb_typeof(coalesce(s->'matches', '[]'::jsonb)) <> 'array' then
    raise exception 'INVALID_MATCH';
  end if;

  for match_value in
    select value from jsonb_array_elements(coalesce(s->'matches', '[]'::jsonb))
  loop
    if match_value ? 'padelBestOf' and (
      jsonb_typeof(match_value->'padelBestOf') <> 'number'
      or (match_value->>'padelBestOf') !~ '^(3|5)$'
    ) then raise exception 'INVALID_PADEL_RULES'; end if;
    best_of := coalesce((match_value->>'padelBestOf')::int, 3);

    if match_value ? 'padelGameRule' and (
      jsonb_typeof(match_value->'padelGameRule') <> 'string'
      or match_value->>'padelGameRule' not in ('golden_point', 'advantages')
    ) then raise exception 'INVALID_PADEL_RULES'; end if;
    if match_value ? 'padelDecidingSet' and (
      jsonb_typeof(match_value->'padelDecidingSet') <> 'string'
      or match_value->>'padelDecidingSet' not in
        ('super_tiebreak_10', 'tiebreak_7', 'full_set')
    ) then raise exception 'INVALID_PADEL_RULES'; end if;

    if match_value ? 'padelSetScores' then
      if jsonb_typeof(match_value->'padelSetScores') <> 'array'
        or jsonb_array_length(match_value->'padelSetScores') > best_of
      then raise exception 'INVALID_PADEL_SCORE'; end if;
      for set_value in
        select value from jsonb_array_elements(match_value->'padelSetScores')
      loop
        if jsonb_typeof(set_value) <> 'array'
          or jsonb_array_length(set_value) <> 2
          or exists (
            select 1 from jsonb_array_elements(set_value) games
            where jsonb_typeof(games) <> 'number'
              or (games #>> '{}') !~ '^[0-9]+$'
          )
        then raise exception 'INVALID_PADEL_SCORE'; end if;
      end loop;
    end if;

    if match_value ? 'padelPoints' then
      if jsonb_typeof(match_value->'padelPoints') <> 'array'
        or jsonb_array_length(match_value->'padelPoints') <> 2
        or exists (
          select 1 from jsonb_array_elements(match_value->'padelPoints') point
          where jsonb_typeof(point) <> 'string'
            or (point #>> '{}') !~ '^(0|15|30|40|AD|[0-9]{1,3})$'
        )
      then raise exception 'INVALID_PADEL_SCORE'; end if;
    end if;

    if match_value ? 'padelPointTotals' then
      if jsonb_typeof(match_value->'padelPointTotals') <> 'array'
        or jsonb_array_length(match_value->'padelPointTotals') <> 2
        or exists (
          select 1 from jsonb_array_elements(match_value->'padelPointTotals') total
          where jsonb_typeof(total) <> 'number'
            or (total #>> '{}') !~ '^[0-9]+$'
        )
      then raise exception 'INVALID_PADEL_SCORE'; end if;
    end if;

    if match_value ? 'padelSetDurationsSeconds' then
      if jsonb_typeof(match_value->'padelSetDurationsSeconds') <> 'array'
        or jsonb_array_length(match_value->'padelSetDurationsSeconds') >
          jsonb_array_length(coalesce(match_value->'padelSetScores', '[]'::jsonb))
        or exists (
          select 1 from jsonb_array_elements(match_value->'padelSetDurationsSeconds') duration
          where jsonb_typeof(duration) <> 'number'
            or (duration #>> '{}') !~ '^[0-9]+$'
        )
      then raise exception 'INVALID_PADEL_SCORE'; end if;
    end if;

    if match_value->>'padelSetStartedAt' is not null then
      if jsonb_typeof(match_value->'padelSetStartedAt') <> 'string'
      then raise exception 'INVALID_PADEL_SCORE'; end if;
      perform (match_value->>'padelSetStartedAt')::timestamptz;
    end if;
  end loop;

  select coalesce(jsonb_agg(value - array[
      'padelBestOf', 'padelGameRule', 'padelDecidingSet', 'padelSetScores',
      'padelPoints', 'padelPointTotals', 'padelSetDurationsSeconds',
      'padelSetStartedAt'
    ]), '[]'::jsonb)
    into normalized_matches
    from jsonb_array_elements(coalesce(s->'matches', '[]'::jsonb));

  select coalesce(jsonb_agg(
      case when competition->>'kind' = 'americano'
        then jsonb_set(competition, '{kind}', '"league"'::jsonb)
        else competition end
    ), '[]'::jsonb)
    into normalized_competitions
    from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb)) competition;

  normalized := jsonb_set(normalized, '{matches}', normalized_matches);
  normalized := jsonb_set(normalized, '{competitions}', normalized_competitions);
  perform public.bc_validate_pre_sport(normalized);
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
