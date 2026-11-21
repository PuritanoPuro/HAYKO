-- Il primo battitore è configurabile finché la partita è programmata.
-- Durante la partita resta un dato immutabile della formazione.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_padel_service(jsonb)') is null then
    alter function public.bc_validate(jsonb)
      rename to bc_validate_pre_padel_service;
  end if;
end $$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  match_value jsonb;
  first_server text;
  normalized_matches jsonb;
begin
  for match_value in
    select value from jsonb_array_elements(coalesce(s->'matches', '[]'::jsonb))
  loop
    if match_value->'padelFirstServerId' is not null and
       jsonb_typeof(match_value->'padelFirstServerId') <> 'null' then
      if coalesce(s->>'sport', 'football') <> 'padel' or
         jsonb_typeof(match_value->'padelFirstServerId') <> 'string' then
        raise exception 'INVALID_PADEL_SERVER';
      end if;
      first_server := match_value->>'padelFirstServerId';
      if not exists (
        select 1
        from jsonb_array_elements(coalesce(match_value->'teams', '[]'::jsonb)) team,
             jsonb_array_elements_text(team.value) player
        where player.value = first_server
      ) then
        raise exception 'INVALID_PADEL_SERVER';
      end if;
    end if;
  end loop;

  select coalesce(jsonb_agg(value - 'padelFirstServerId'), '[]'::jsonb)
    into normalized_matches
    from jsonb_array_elements(coalesce(s->'matches', '[]'::jsonb));
  perform public.bc_validate_pre_padel_service(
    jsonb_set(s, '{matches}', normalized_matches)
  );
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
