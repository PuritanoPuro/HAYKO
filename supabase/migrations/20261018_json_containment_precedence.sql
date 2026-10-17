-- Incremental repair for SQLSTATE 42883 (boolean -> unknown).
-- Safe to run after the equivalent manual fix: already corrected expressions
-- are accepted. Unexpected definitions abort the entire transaction.
-- No table, stored state, revision, ownership, ACL or validation rule is removed.
begin;

do $patch$
declare
  target record;
  function_id regprocedure;
  definition text;
  original text;
  pair jsonb;
begin
  for target in
    select * from (values
      ('public.bc_validate_rules_v041(jsonb)',
       '[["team @> k->''order''", "team @> (k->''order'')"]]'::jsonb),
      ('public.bc_validate(jsonb)',
       '[["ids @> p->''players''", "ids @> (p->''players'')"],
         ["ids @> c->''teamIds''", "ids @> (c->''teamIds'')"],
         ["c->''teamIds'' @> m->''presetIds''", "(c->''teamIds'') @> (m->''presetIds'')"],
         ["a->''presetIds'' @> b->''presetIds''", "(a->''presetIds'') @> (b->''presetIds'')"]]'::jsonb)
    ) as targets(signature, replacements)
  loop
    function_id := to_regprocedure(target.signature);
    if function_id is null then
      raise exception 'HAYKO_PATCH_MISSING_FUNCTION: %', target.signature;
    end if;
    original := pg_get_functiondef(function_id);
    definition := original;
    for pair in select value from jsonb_array_elements(target.replacements)
    loop
      if strpos(definition, pair->>0) > 0 then
        definition := replace(definition, pair->>0, pair->>1);
      elsif strpos(definition, pair->>1) = 0 then
        raise exception 'HAYKO_PATCH_UNEXPECTED_DEFINITION: % / %',
          target.signature, pair->>0;
      end if;
    end loop;
    if definition <> original then
      -- CREATE OR REPLACE preserves ownership and existing function grants.
      execute definition;
    end if;
  end loop;
end;
$patch$;

commit;
