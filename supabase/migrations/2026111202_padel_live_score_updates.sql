-- I campi del punteggio Padel cambiano durante una partita live e non sono
-- parte della formazione. Manteniamo congelati squadre, regole e identità
-- dell'evento, consentendo soltanto lo stato dinamico del tabellone.
do $$
declare
  original_definition text;
  patched_definition text;
  frozen_comparison text :=
    '(m-array[''status'',''finishedAt'',''goals'',''qualifiedTeamId'']) <> (oldm-array[''status'',''finishedAt'',''goals'',''qualifiedTeamId''])';
  padel_comparison text :=
    '(m-array[''status'',''finishedAt'',''goals'',''qualifiedTeamId'',''padelSetScores'',''padelPoints'',''padelPointTotals'',''padelSetDurationsSeconds'',''padelSetStartedAt'']) <> (oldm-array[''status'',''finishedAt'',''goals'',''qualifiedTeamId'',''padelSetScores'',''padelPoints'',''padelPointTotals'',''padelSetDurationsSeconds'',''padelSetStartedAt''])';
begin
  select pg_get_functiondef(
      'public.bc_save_core_v03(text,bigint,jsonb)'::regprocedure
    )
    into original_definition;

  patched_definition := replace(
    original_definition,
    frozen_comparison,
    padel_comparison
  );

  if patched_definition = original_definition then
    if position(padel_comparison in original_definition) > 0 then
      return;
    end if;
    raise exception 'BC_SAVE_CORE_PATCH_TARGET_NOT_FOUND';
  end if;

  execute patched_definition;
end;
$$;
