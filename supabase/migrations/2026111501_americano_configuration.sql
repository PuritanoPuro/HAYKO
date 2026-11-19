-- Conserva la configurazione specifica dell'Americano nello stato della lega,
-- validandola prima di inoltrare il payload al validatore Padel esistente.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_americano(jsonb)') is null then
    alter function public.bc_validate(jsonb) rename to bc_validate_pre_americano;
  end if;
end;
$$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  normalized jsonb := s;
  normalized_competitions jsonb;
  competition jsonb;
  player_count int;
  courts int;
begin
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
  end loop;

  select coalesce(jsonb_agg(value - array[
      'americanoPlayerCount', 'americanoCourts', 'americanoRounds',
      'americanoTargetPoints', 'americanoRotatingPairs'
    ]), '[]'::jsonb)
    into normalized_competitions
    from jsonb_array_elements(coalesce(s->'competitions', '[]'::jsonb));

  normalized := jsonb_set(normalized, '{competitions}', normalized_competitions);
  perform public.bc_validate_pre_americano(normalized);
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
