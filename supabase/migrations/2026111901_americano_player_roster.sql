-- La selezione dell'Americano contiene ID di giocatori, non ID di coppie.
-- La validiamo qui e la togliamo solo dalla copia passata al validatore storico.
create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  normalized jsonb := s;
  normalized_competitions jsonb;
  competition jsonb;
  player_ids jsonb;
  roster jsonb;
  player_count int;
  courts int;
begin
  select coalesce(jsonb_agg(value->'id'), '[]'::jsonb)
    into player_ids
    from jsonb_array_elements(coalesce(s->'players', '[]'::jsonb));

  for competition in
    select value from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb))
  loop
    if competition->>'kind' <> 'americano' then continue; end if;

    if jsonb_typeof(coalesce(competition->'americanoPlayerCount', '8'::jsonb)) <> 'number'
      or jsonb_typeof(coalesce(competition->'americanoCourts', '2'::jsonb)) <> 'number'
      or jsonb_typeof(coalesce(competition->'americanoRounds', '7'::jsonb)) <> 'number'
      or jsonb_typeof(coalesce(competition->'americanoTargetPoints', '24'::jsonb)) <> 'number'
      or jsonb_typeof(coalesce(competition->'americanoRotatingPairs', 'true'::jsonb)) <> 'boolean'
    then raise exception 'INVALID_AMERICANO_CONFIGURATION'; end if;

    player_count := coalesce((competition->>'americanoPlayerCount')::int, 8);
    courts := coalesce((competition->>'americanoCourts')::int, 2);
    if player_count < 4 or player_count % 2 <> 0
      or courts < 1 or courts > player_count / 4
      or coalesce((competition->>'americanoRounds')::int, 7) < 1
      or coalesce((competition->>'americanoTargetPoints')::int, 24) < 8
    then raise exception 'INVALID_AMERICANO_CONFIGURATION'; end if;

    roster := coalesce(competition->'americanoPlayerIds', '[]'::jsonb);
    if jsonb_typeof(roster) <> 'array'
      or jsonb_array_length(roster) > player_count
      or not player_ids @> roster
      or exists (
        select 1 from jsonb_array_elements(roster) entry
        where jsonb_typeof(entry.value) <> 'string'
      )
      or (
        select count(*) <> count(distinct value)
        from jsonb_array_elements_text(roster)
      )
    then raise exception 'INVALID_AMERICANO_PLAYERS'; end if;
  end loop;

  select coalesce(jsonb_agg(value - array[
      'americanoPlayerCount', 'americanoCourts', 'americanoRounds',
      'americanoTargetPoints', 'americanoRotatingPairs', 'americanoPlayerIds'
    ]), '[]'::jsonb)
    into normalized_competitions
    from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb));

  normalized := jsonb_set(normalized, '{competitions}', normalized_competitions);
  perform public.bc_validate_pre_americano(normalized);
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
