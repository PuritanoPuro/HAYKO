-- I turni confermati sono composti da incontri su campi distinti.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_americano_calendar(jsonb)') is null then
    alter function public.bc_validate(jsonb) rename to bc_validate_pre_americano_calendar;
  end if;
end;
$$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  competition jsonb;
  schedule jsonb;
  round_value jsonb;
  fixture jsonb;
  roster jsonb;
  normalized_competitions jsonb;
  participant_count int;
begin
  for competition in
    select value from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb))
  loop
    if competition->>'kind' <> 'americano' then continue; end if;
    schedule := coalesce(competition->'americanoSchedule', '[]'::jsonb);
    roster := coalesce(competition->'americanoPlayerIds', '[]'::jsonb);
    if jsonb_typeof(schedule) <> 'array' then
      raise exception 'INVALID_AMERICANO_CALENDAR';
    end if;
    if jsonb_array_length(schedule) not in
      (0, coalesce((competition->>'americanoRounds')::int, 7))
    then raise exception 'INVALID_AMERICANO_CALENDAR'; end if;

    for round_value in select value from jsonb_array_elements(schedule) loop
      if jsonb_typeof(round_value) <> 'array' then
        raise exception 'INVALID_AMERICANO_CALENDAR';
      end if;
      if jsonb_array_length(round_value) < 1 or
         jsonb_array_length(round_value) >
           coalesce((competition->>'americanoCourts')::int, 2)
      then raise exception 'INVALID_AMERICANO_CALENDAR'; end if;

      participant_count := 0;
      for fixture in select value from jsonb_array_elements(round_value) loop
        if jsonb_typeof(fixture) <> 'array' then
          raise exception 'INVALID_AMERICANO_CALENDAR';
        end if;
        if jsonb_array_length(fixture) <> 4 or not roster @> fixture or
          exists (
            select 1 from jsonb_array_elements(fixture) entry
            where jsonb_typeof(entry.value) <> 'string'
          )
        then raise exception 'INVALID_AMERICANO_CALENDAR'; end if;
        participant_count := participant_count + 4;
      end loop;
      if (
        select count(distinct player_id.id) <> participant_count
        from jsonb_array_elements(round_value) match_entry,
             jsonb_array_elements_text(match_entry.value) as player_id(id)
      ) then raise exception 'INVALID_AMERICANO_CALENDAR'; end if;
    end loop;
  end loop;

  select coalesce(jsonb_agg(value - 'americanoSchedule'), '[]'::jsonb)
    into normalized_competitions
    from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb));
  perform public.bc_validate_pre_americano_calendar(
    jsonb_set(s, '{competitions}', normalized_competitions)
  );
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
