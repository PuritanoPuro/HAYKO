-- Punti per campo e stato dei turni Americano. La sequenza dei punti consente
-- di annullare esattamente l'ultima assegnazione.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_americano_scores(jsonb)') is null then
    alter function public.bc_validate(jsonb) rename to bc_validate_pre_americano_scores;
  end if;
end;
$$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  competition jsonb;
  schedule jsonb;
  results jsonb;
  result_round jsonb;
  court_result jsonb;
  points jsonb;
  status text;
  target_points int;
  round_index int;
  index_value int;
  normalized_competitions jsonb;
begin
  for competition in
    select value from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb))
  loop
    if competition->>'kind' <> 'americano' then continue; end if;
    schedule := coalesce(competition->'americanoSchedule', '[]'::jsonb);
    results := coalesce(competition->'americanoResults', '[]'::jsonb);
    status := coalesce(competition->>'americanoTurnStatus', 'scheduled');
    target_points := coalesce((competition->>'americanoTargetPoints')::int, 24);
    round_index := coalesce((competition->>'americanoCurrentRound')::int, 0);
    if status not in ('scheduled', 'live', 'paused', 'completed', 'finished') or
       jsonb_typeof(results) <> 'array'
    then raise exception 'INVALID_AMERICANO_RESULTS'; end if;
    if jsonb_array_length(results) not in (0, jsonb_array_length(schedule))
    then raise exception 'INVALID_AMERICANO_RESULTS'; end if;

    index_value := 0;
    for result_round in select value from jsonb_array_elements(results) loop
      if jsonb_typeof(result_round) <> 'array' or
         jsonb_array_length(result_round) <> jsonb_array_length(schedule->index_value)
      then raise exception 'INVALID_AMERICANO_RESULTS'; end if;
      for court_result in select value from jsonb_array_elements(result_round) loop
        points := court_result->'points';
        if jsonb_typeof(court_result) <> 'object' or
           jsonb_typeof(points) <> 'array' or
           jsonb_array_length(points) > target_points or
           jsonb_typeof(court_result->'finished') <> 'boolean' or
           (court_result ? 'startedAt' and
            jsonb_typeof(court_result->'startedAt') <> 'string') or
           exists (
             select 1 from jsonb_array_elements(points) point_entry
             where point_entry.value not in ('0'::jsonb, '1'::jsonb)
           )
        then raise exception 'INVALID_AMERICANO_RESULTS'; end if;
        if (court_result->>'finished')::boolean and
           jsonb_array_length(points) <> target_points
        then raise exception 'INVALID_AMERICANO_RESULTS'; end if;
      end loop;
      index_value := index_value + 1;
    end loop;
    if status in ('completed', 'finished') and
       (jsonb_array_length(results) = 0 or
        exists (
          select 1 from jsonb_array_elements(results->round_index) court_entry
          where court_entry.value->>'finished' <> 'true'
        ))
    then raise exception 'INVALID_AMERICANO_RESULTS'; end if;
  end loop;

  select coalesce(jsonb_agg(
           case when value->>'kind' = 'americano' then
             (value - 'americanoResults') ||
             jsonb_build_object(
               'americanoTurnStatus',
               case when value->>'americanoTurnStatus' in ('paused', 'completed')
                    then 'live'
                    else coalesce(value->>'americanoTurnStatus', 'scheduled') end
             )
           else value end
         ), '[]'::jsonb)
    into normalized_competitions
    from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb));
  perform public.bc_validate_pre_americano_scores(
    jsonb_set(s, '{competitions}', normalized_competitions)
  );
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
