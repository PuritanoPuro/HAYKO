-- Allow the event creator to correct or void goals after a match has ended.
-- Match identity, teams, timestamps and goal identity remain immutable.
begin;

do $patch$
declare
  function_id regprocedure :=
    to_regprocedure('public.bc_save_core_v03(text,bigint,jsonb)');
  definition text;
  original text;
  old_rule text := $rule$
      if oldm->>'status' = 'finished' then raise exception 'MATCH_FINISHED'; end if;
      if oldm->>'status' = 'scheduled' and m->>'status' not in ('scheduled','live') then raise exception 'INVALID_TRANSITION'; end if;
      if oldm->>'status' = 'live' then
        if m->>'status' not in ('live','finished') or (m-array['status','finishedAt','goals','qualifiedTeamId']) <> (oldm-array['status','finishedAt','goals','qualifiedTeamId']) then raise exception 'ROSTER_FROZEN'; end if;
      end if;
      if jsonb_array_length(m->'goals') < jsonb_array_length(oldm->'goals') then raise exception 'CANNOT_DELETE_GOAL'; end if;
      idx := 0;
      for oldg in select value from jsonb_array_elements(oldm->'goals') loop
        g := m->'goals'->idx;
        if (g-'voided') <> (oldg-'voided') or ((oldg->>'voided')::boolean and not (g->>'voided')::boolean) then raise exception 'GOAL_IMMUTABLE'; end if;
        idx := idx + 1;
      end loop;
      while idx < jsonb_array_length(m->'goals') loop
        if (m->'goals'->idx->>'voided')::boolean then raise exception 'INVALID_NEW_GOAL'; end if;
        idx := idx + 1;
      end loop;
      -- Non consentire gol nel medesimo aggiornamento che avvia o chiude l'evento.
      if oldm->>'status' <> m->>'status' and m->'goals' <> oldm->'goals' then raise exception 'STATE_AND_GOAL_SEPARATE'; end if;
$rule$;
  new_rule text := $rule$
      if oldm->>'status' = 'finished' then
        if m->>'status' <> 'finished' or
          (m-array['goals','qualifiedTeamId']) is distinct from
          (oldm-array['goals','qualifiedTeamId']) then raise exception 'MATCH_FINISHED'; end if;
        if jsonb_array_length(m->'goals') <> jsonb_array_length(oldm->'goals') then raise exception 'GOAL_IMMUTABLE'; end if;
        idx := 0;
        for oldg in select value from jsonb_array_elements(oldm->'goals') loop
          g := m->'goals'->idx;
          if g->>'id' is distinct from oldg->>'id' or
            g->>'team' is distinct from oldg->>'team' or
            g->>'time' is distinct from oldg->>'time' or
            ((oldg->>'voided')::boolean and g is distinct from oldg)
          then raise exception 'GOAL_IMMUTABLE'; end if;
          idx := idx + 1;
        end loop;
      else
        if oldm->>'status' = 'scheduled' and m->>'status' not in ('scheduled','live') then raise exception 'INVALID_TRANSITION'; end if;
        if oldm->>'status' = 'live' then
          if m->>'status' not in ('live','finished') or (m-array['status','finishedAt','goals','qualifiedTeamId']) <> (oldm-array['status','finishedAt','goals','qualifiedTeamId']) then raise exception 'ROSTER_FROZEN'; end if;
        end if;
        if jsonb_array_length(m->'goals') < jsonb_array_length(oldm->'goals') then raise exception 'CANNOT_DELETE_GOAL'; end if;
        idx := 0;
        for oldg in select value from jsonb_array_elements(oldm->'goals') loop
          g := m->'goals'->idx;
          if (g-'voided') <> (oldg-'voided') or ((oldg->>'voided')::boolean and not (g->>'voided')::boolean) then raise exception 'GOAL_IMMUTABLE'; end if;
          idx := idx + 1;
        end loop;
        while idx < jsonb_array_length(m->'goals') loop
          if (m->'goals'->idx->>'voided')::boolean then raise exception 'INVALID_NEW_GOAL'; end if;
          idx := idx + 1;
        end loop;
        -- Non consentire gol nel medesimo aggiornamento che avvia o chiude l'evento.
        if oldm->>'status' <> m->>'status' and m->'goals' <> oldm->'goals' then raise exception 'STATE_AND_GOAL_SEPARATE'; end if;
      end if;
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

  if definition <> original then execute definition; end if;
end;
$patch$;

commit;
