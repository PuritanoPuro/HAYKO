-- Eseguire dopo v02 + v03 soltanto su Supabase DI TEST. Tutto viene annullato.
begin;
insert into auth.users(id,email,aud,role) values
 ('11111111-1111-4111-8111-111111111111','president-v03@example.invalid','authenticated','authenticated'),
 ('22222222-2222-4222-8222-222222222222','member-v03@example.invalid','authenticated','authenticated');
do $$
declare s jsonb; m jsonb; r bigint; denied boolean; token text;
begin
 perform set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
 s:='{"id":"test-v03","name":"L","primaryColor":4290508136,"secondaryColor":4287544575,"presets":[],"competitions":[],"players":[{"id":"a","name":"A","color":4290508136},{"id":"b","name":"B","color":4290508136},{"id":"c","name":"C","color":4290508136},{"id":"d","name":"D","color":4290508136}],"matches":[]}'::jsonb;
 perform public.bc_create(s);token:=public.bc_invite('test-v03');
 m:='{"id":"m","format":2,"names":["A","B"],"teams":[["a","b"],["c","d"]],"status":"scheduled","startedAt":null,"finishedAt":null,"goals":[],"keepers":[{"mode":"manual"},{"mode":"manual"}],"creatorId":"11111111-1111-4111-8111-111111111111","scheduledAt":"2026-10-14T18:00:00Z","venue":"Campo uno","teamColors":[4287544575,4294945636],"presetIds":[null,null],"competitionId":null,"knockoutRound":null,"qualifiedTeamId":null}'::jsonb;
 s:=jsonb_set(s,'{matches}',jsonb_build_array(m));r:=public.bc_save('test-v03',0,s);
 s:=jsonb_set(s,'{matches,0,venue}','"Campo due"');r:=public.bc_save('test-v03',r,s);
 s:=jsonb_set(jsonb_set(s,'{matches,0,status}','"live"'),'{matches,0,startedAt}','"2026-10-14T18:00:00Z"');r:=public.bc_save('test-v03',r,s);
 denied:=false;
 begin perform public.bc_save('test-v03',r,jsonb_set(s,'{matches,0,venue}','"Modifica vietata"'));
 exception when others then if SQLERRM<>'ROSTER_FROZEN' then raise;end if;denied:=true;end;
 assert denied,'Luogo bloccato dopo l’avvio';
 perform set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
 perform public.bc_join(token);
 denied:=false;
 begin perform public.bc_delete('test-v03','L');exception when others then if SQLERRM<>'PRESIDENT_REQUIRED' then raise;end if;denied:=true;end;
 assert denied,'Solo presidente elimina';
 perform set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
 perform public.bc_delete('test-v03','L');
 assert not exists(select 1 from public.bc_leagues where id='test-v03'),'Lega rimossa';
 assert not exists(select 1 from public.bc_members where league_id='test-v03'),'Membership rimosse';
 assert not exists(select 1 from public.bc_invites where league_id='test-v03'),'Inviti rimossi';
end; $$;
rollback;
