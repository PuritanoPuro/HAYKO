-- Consente al payload delle leghe multisport di attraversare il validatore
-- storico senza indebolire le regole già applicate a giocatori e partite.
-- Americano riusa le invarianti strutturali del campionato; la tipologia
-- originale resta memorizzata nello stato della lega.
do $$
begin
  if to_regprocedure('public.bc_validate_pre_sport(jsonb)') is null then
    alter function public.bc_validate(jsonb) rename to bc_validate_pre_sport;
  end if;
end;
$$;

create or replace function public.bc_validate(s jsonb) returns void
language plpgsql set search_path = '' as $$
declare
  normalized jsonb := s - 'sport';
  normalized_competitions jsonb;
begin
  if coalesce(s->>'sport', 'football') not in ('football', 'padel') then
    raise exception 'INVALID_SPORT';
  end if;

  select coalesce(
      jsonb_agg(
        case
          when competition->>'kind' = 'americano'
            then jsonb_set(competition, '{kind}', '"league"'::jsonb)
          else competition
        end
      ),
      '[]'::jsonb
    )
    into normalized_competitions
    from jsonb_array_elements(
      coalesce(s->'competitions', '[]'::jsonb)
    ) competition;

  normalized := jsonb_set(
    normalized,
    '{competitions}',
    normalized_competitions
  );

  perform public.bc_validate_pre_sport(normalized);
end;
$$;

revoke all on function public.bc_validate(jsonb) from public, anon, authenticated;
