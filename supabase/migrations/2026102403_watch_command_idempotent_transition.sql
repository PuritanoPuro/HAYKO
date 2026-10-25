-- Accept retries whose state transition was committed before the command receipt.
create or replace function public.hayko_watch_command(p_token text,p_command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d public.hayko_watch_devices; existing jsonb; l public.bc_leagues; m jsonb; next_m jsonb;
 idx int; v_command_id text; command_type text; payload jsonb; goal jsonb; result jsonb; team int; changed boolean:=true;
begin
  select * into d from public.hayko_watch_devices where token_hash=extensions.digest(p_token,'sha256') and revoked_at is null;
  if not found then raise exception 'INVALID_DEVICE_TOKEN'; end if;
  v_command_id:=p_command->>'id'; command_type:=p_command->>'type'; payload:=coalesce(p_command->'payload','{}'::jsonb);
  if v_command_id is null or length(v_command_id)>160 then raise exception 'INVALID_COMMAND_ID'; end if;
  select response into existing from public.hayko_watch_commands where device_id=d.id and hayko_watch_commands.command_id=v_command_id;
  if existing is not null then return existing; end if;
  select bl.* into l from public.bc_leagues bl join public.bc_members bm on bm.league_id=bl.id and bm.user_id=d.user_id
   where coalesce(bl.state->>'type','amateur')='amateur'
     and exists(select 1 from jsonb_array_elements(bl.state->'matches') x where x->>'id'=p_command->>'matchId') for update;
  if not found then raise exception 'MATCH_NOT_FOUND'; end if;
  select value,ordinality-1 into m,idx from jsonb_array_elements(l.state->'matches') with ordinality x(value,ordinality)
   where value->>'id'=p_command->>'matchId';
  if m->>'creatorId' is distinct from d.user_id::text then raise exception 'ONLY_EVENT_CREATOR'; end if;
  if command_type='start_match' then
    if m->>'status'='scheduled' then
      next_m:=jsonb_set(jsonb_set(m,'{status}','"live"'::jsonb),'{startedAt}',to_jsonb(now()));
    elsif m->>'status'='live' then
      next_m:=m; changed:=false;
    else raise exception 'INVALID_TRANSITION'; end if;
  elsif command_type='add_goal' then
    if m->>'status'<>'live' then raise exception 'MATCH_NOT_LIVE'; end if;
    team:=(payload->>'team')::int;
    if team not in (0,1) then raise exception 'INVALID_TEAM'; end if;
    if payload->>'scorerId' is not null and not (m->'teams'->team ? (payload->>'scorerId')) then raise exception 'INVALID_SCORER'; end if;
    if payload->>'assistId' is not null and (payload->>'assistId'=payload->>'scorerId' or not (m->'teams'->team ? (payload->>'assistId'))) then raise exception 'INVALID_ASSIST'; end if;
    if payload->>'keeperId' is not null and not (m->'teams'->(1-team) ? (payload->>'keeperId')) then raise exception 'INVALID_KEEPER'; end if;
    goal:=jsonb_build_object('id',v_command_id,'team',team,'scorer',payload->>'scorerId','assist',payload->>'assistId',
      'keeper',payload->>'keeperId','ownGoal',false,'time',now(),'voided',false);
    next_m:=jsonb_set(m,'{goals}',coalesce(m->'goals','[]'::jsonb)||jsonb_build_array(goal));
  elsif command_type='end_match' then
    if m->>'status'='live' then
      next_m:=jsonb_set(jsonb_set(m,'{status}','"finished"'::jsonb),'{finishedAt}',to_jsonb(now()));
    elsif m->>'status'='finished' then
      next_m:=m; changed:=false;
    else raise exception 'MATCH_NOT_LIVE'; end if;
  else raise exception 'UNSUPPORTED_WATCH_COMMAND'; end if;
  if changed then
    l.state:=jsonb_set(l.state,array['matches',idx::text],next_m);
    perform public.bc_validate(l.state);
    update public.bc_leagues set state=l.state,revision=revision+1 where id=l.id returning revision into l.revision;
    insert into public.bc_audit(league_id,actor,action,revision) values(l.id,d.user_id,'watch_'||command_type,l.revision);
  end if;
  result:=jsonb_build_object('ok',true,'commandId',v_command_id,'revision',l.revision,'match',next_m);
  insert into public.hayko_watch_commands(device_id,command_id,response) values(d.id,v_command_id,result);
  return result;
end $$;

revoke all on function public.hayko_watch_snapshot(text),public.hayko_watch_command(text,jsonb) from public;
grant execute on function public.hayko_watch_snapshot(text),public.hayko_watch_command(text,jsonb) to anon,authenticated;
