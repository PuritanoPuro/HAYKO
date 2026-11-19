-- Il tempo di gioco esclude le pause e resta fisso dopo la conclusione.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_americano_elapsed_time(jsonb)') is null then
    alter function public.bc_validate(jsonb) rename to bc_validate_pre_americano_elapsed_time;
  end if;
end;
$$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  competition jsonb;
  result_round jsonb;
  court_result jsonb;
begin
  for competition in
    select value from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb))
  loop
    if competition->>'kind' <> 'americano' then continue; end if;
    for result_round in
      select value from jsonb_array_elements(
        coalesce(competition->'americanoResults', '[]'::jsonb)
      )
    loop
      for court_result in select value from jsonb_array_elements(result_round) loop
        if (court_result ? 'pausedAt' and
            jsonb_typeof(court_result->'pausedAt') <> 'string') or
           (court_result ? 'finishedAt' and
            jsonb_typeof(court_result->'finishedAt') <> 'string') or
           (court_result ? 'pausedSeconds' and
            (jsonb_typeof(court_result->'pausedSeconds') <> 'number' or
             (court_result->>'pausedSeconds') !~ '^[0-9]+$')) or
           (court_result ? 'pausedAt' and court_result ? 'finishedAt')
        then raise exception 'INVALID_AMERICANO_TIME'; end if;
      end loop;
    end loop;
  end loop;
  perform public.bc_validate_pre_americano_elapsed_time(s);
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
