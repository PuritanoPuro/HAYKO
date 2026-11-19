-- Stato del turno Americano: il calendario confermato può essere avviato.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_americano_turn_state(jsonb)') is null then
    alter function public.bc_validate(jsonb) rename to bc_validate_pre_americano_turn_state;
  end if;
end;
$$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  competition jsonb;
  normalized_competitions jsonb;
  round_index int;
  rounds int;
  status text;
begin
  for competition in
    select value from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb))
  loop
    if competition->>'kind' <> 'americano' then continue; end if;
    if competition ? 'americanoCurrentRound' and
       jsonb_typeof(competition->'americanoCurrentRound') <> 'number'
    then raise exception 'INVALID_AMERICANO_TURN'; end if;
    round_index := coalesce((competition->>'americanoCurrentRound')::int, 0);
    rounds := coalesce((competition->>'americanoRounds')::int, 7);
    status := coalesce(competition->>'americanoTurnStatus', 'scheduled');
    if round_index < 0 or round_index >= rounds or
       status not in ('scheduled', 'live', 'finished') or
       (status <> 'scheduled' and
        jsonb_array_length(coalesce(competition->'americanoSchedule', '[]'::jsonb)) = 0)
    then raise exception 'INVALID_AMERICANO_TURN'; end if;
  end loop;

  select coalesce(jsonb_agg(value - 'americanoCurrentRound' - 'americanoTurnStatus'),
                  '[]'::jsonb)
    into normalized_competitions
    from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb));
  perform public.bc_validate_pre_americano_turn_state(
    jsonb_set(s, '{competitions}', normalized_competitions)
  );
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
