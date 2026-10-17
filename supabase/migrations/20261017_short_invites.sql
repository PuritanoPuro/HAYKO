-- HAYKO: aggiornamento incrementale. Non rieseguire il bootstrap iniziale.
begin;
do $$ begin
 if to_regclass('public.hayko_join_requests') is null then
  raise exception 'Installa prima il database HAYKO Account V1';
 end if;
end; $$;

-- Una sola riga per account; nessun codice in chiaro o indirizzo IP.
create table if not exists public.hayko_invite_attempts (
 user_id uuid primary key references auth.users(id) on delete cascade,
 attempted_at timestamptz[] not null default '{}'
);
alter table public.hayko_invite_attempts enable row level security;
revoke all on public.hayko_invite_attempts from public,anon,authenticated;

create or replace function public.hayko_invite_short(p_id text) returns text
language plpgsql security definer set search_path='' as $$
declare
 alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
 random_bytes bytea; code text; position integer; retry integer;
begin
 if auth.uid() is null or not exists (
  select 1 from public.bc_members
  where league_id=p_id and user_id=auth.uid() and role in ('president','admin')
 ) then raise exception 'ADMIN_REQUIRED'; end if;
 for retry in 1..5 loop
  random_bytes := sha256(convert_to(gen_random_uuid()::text,'UTF8'));
  code := '';
  for position in 0..7 loop
   code := code || substr(alphabet,1+(get_byte(random_bytes,position) % 32),1);
  end loop;
  insert into public.bc_invites(token_hash,league_id,expires_at,created_by)
  values(encode(sha256(convert_to(lower(code),'UTF8')),'hex'),p_id,now()+interval '7 days',auth.uid())
  on conflict(token_hash) do nothing;
  if found then return substr(code,1,4)||'-'||substr(code,5,4); end if;
 end loop;
 raise exception 'INVITE_GENERATION_FAILED';
end; $$;

-- Errori di invito come valori di ritorno: un'eccezione annullerebbe anche
-- il contatore dei tentativi. L'app traduce questi valori in messaggi italiani.
create or replace function public.bc_join(p_token text) returns text
language plpgsql security definer set search_path='' as $$
declare
 i public.bc_invites; previous text; normalized text;
 attempts timestamptz[]; stamp timestamptz := clock_timestamp();
begin
 if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
 insert into public.hayko_invite_attempts(user_id) values(auth.uid()) on conflict do nothing;
 select coalesce(array_agg(t order by t),'{}'::timestamptz[]) into attempts
 from unnest((select attempted_at from public.hayko_invite_attempts where user_id=auth.uid() for update)) t
 where t > stamp-interval '15 minutes';
 if cardinality(attempts)>=10 then return 'HAYKO_INVITE_RATE_LIMITED'; end if;
 update public.hayko_invite_attempts set attempted_at=array_append(attempts,stamp) where user_id=auth.uid();

 if p_token is null or length(p_token)>256 then return 'HAYKO_INVITE_INVALID'; end if;
 normalized := lower(regexp_replace(p_token,'[[:space:]-]','','g'));
 if normalized !~ '^[a-hj-np-z2-9]{8}$' and normalized !~ '^[a-f0-9]{64}$' then
  return 'HAYKO_INVITE_INVALID';
 end if;
 select * into i from public.bc_invites
 where token_hash=encode(sha256(convert_to(normalized,'UTF8')),'hex');
 if not found then return 'HAYKO_INVITE_INVALID'; end if;
 perform 1 from public.bc_leagues where id=i.league_id for update;
 if not found then return 'HAYKO_INVITE_INVALID'; end if;
 select * into i from public.bc_invites where token_hash=i.token_hash for update;
 if not found then return 'HAYKO_INVITE_INVALID'; end if;
 if i.revoked or i.expires_at<=now() then return 'HAYKO_INVITE_EXPIRED'; end if;
 if exists(select 1 from public.bc_members where league_id=i.league_id and user_id=auth.uid()) then
  return i.league_id;
 end if;
 select status into previous from public.hayko_join_requests where league_id=i.league_id and user_id=auth.uid();
 if previous='pending' then return i.league_id; end if;
 if i.uses>=i.max_uses then return 'HAYKO_INVITE_EXPIRED'; end if;
 insert into public.hayko_join_requests(league_id,user_id) values(i.league_id,auth.uid())
 on conflict(league_id,user_id) do update set status='pending',requested_at=now();
 update public.bc_invites set uses=uses+1 where token_hash=i.token_hash;
 return i.league_id;
end; $$;

revoke all on function public.hayko_invite_short(text) from public,anon,authenticated;
revoke all on function public.bc_join(text) from public,anon,authenticated;
grant execute on function public.hayko_invite_short(text),public.bc_join(text) to authenticated;
notify pgrst,'reload schema';
commit;
