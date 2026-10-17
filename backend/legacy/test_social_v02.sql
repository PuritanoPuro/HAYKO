-- Eseguire su DATABASE DI TEST Supabase dopo social_v02.sql. Tutto viene annullato.
begin;
insert into auth.users(id,email,aud,role) values
 ('11111111-1111-4111-8111-111111111111','president-test@example.invalid','authenticated','authenticated'),
 ('22222222-2222-4222-8222-222222222222','admin-test@example.invalid','authenticated','authenticated'),
 ('33333333-3333-4333-8333-333333333333','member-test@example.invalid','authenticated','authenticated');
do $$
declare s jsonb; token text; m jsonb; r bigint; denied boolean;
begin
  perform set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
  s := '{"id":"test-league-v02","name":"Test","players":[{"id":"a","name":"A"},{"id":"b","name":"B"},{"id":"c","name":"C"},{"id":"d","name":"D"}],"matches":[]}'::jsonb;
  perform public.bc_create(s);
  perform public.bc_claim('test-league-v02','a',null);
  token := public.bc_invite('test-league-v02');
  perform set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
  perform public.bc_join(token);
  denied := false;
  begin perform public.bc_claim('test-league-v02','a',null); exception when others then denied := true; end;
  assert denied, 'Un giocatore associato non può essere preso da un altro account';
  perform public.bc_claim('test-league-v02','b',null);
  perform set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
  perform public.bc_role('test-league-v02','b','admin');
  perform set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
  m := '{"id":"m","format":2,"names":["A","B"],"teams":[["a","b"],["c","d"]],"status":"scheduled","startedAt":null,"finishedAt":null,"goals":[],"keepers":[{"mode":"manual"},{"mode":"manual"}],"creatorId":"22222222-2222-4222-8222-222222222222","scheduledAt":"2026-10-14T18:00:00Z","venue":"Campo test"}'::jsonb;
  s := jsonb_set(s,'{matches}',jsonb_build_array(m));
  r := (public.bc_get('test-league-v02')->>'revision')::bigint;
  r := public.bc_save('test-league-v02',r,s);
  assert public.bc_save('test-league-v02',r-1,s)=r, 'Retry identico deve essere idempotente';
  perform set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
  denied := false;
  begin perform public.bc_save('test-league-v02',r,jsonb_set(jsonb_set(s,'{matches,0,status}','"live"'),'{matches,0,startedAt}','"2026-10-12T14:00:00Z"'));
  exception when others then if SQLERRM <> 'ONLY_EVENT_CREATOR' then raise; end if; denied := true; end;
  assert denied, 'Anche il presidente non registra per un evento altrui';
  perform set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
  s := jsonb_set(jsonb_set(s,'{matches,0,status}','"live"'),'{matches,0,startedAt}','"2026-10-12T14:00:00Z"');
  r := public.bc_save('test-league-v02',r,s);
  denied := false;
  begin perform public.bc_save('test-league-v02',r-1,jsonb_set(s,'{name}','"Stale"'));
  exception when others then denied := true; end;
  assert denied, 'La revisione superata deve essere rifiutata';
  perform set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
  denied := false;
  begin perform public.bc_get('test-league-v02'); exception when others then denied := true; end;
  assert denied, 'Un non membro non legge la lega';
  perform public.bc_join(token);
  perform public.bc_claim('test-league-v02',null,'Nuovo');
  assert (public.bc_get('test-league-v02')->>'role')='member', 'Un nuovo iscritto non diventa admin';
  perform set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
  perform public.bc_revoke_invites('test-league-v02');
  denied := false;
  begin perform public.bc_join(token); exception when others then denied := true; end;
  assert denied, 'Un invito revocato non si usa';
end; $$;
-- I client non devono avere accesso diretto alle tabelle né al validatore interno.
select not has_table_privilege('authenticated','public.bc_leagues','SELECT') as private_tables;
select not has_function_privilege('authenticated','public.bc_validate(jsonb)','EXECUTE') as private_validator;
rollback;
