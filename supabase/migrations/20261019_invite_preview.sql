-- Mostra il nome della lega nei link invito prima di inviare la richiesta.
-- Accetta solo i token lunghi dei link: i codici brevi restano protetti dal
-- limite dei tentativi applicato da bc_join.
begin;

create or replace function public.hayko_invite_preview(p_token text) returns text
language plpgsql security definer set search_path='' as $$
declare
 i public.bc_invites; normalized text; league_name text;
begin
 if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
 if p_token is null or length(p_token)>256 then return 'HAYKO_INVITE_INVALID'; end if;
 normalized := lower(regexp_replace(p_token,'[[:space:]-]','','g'));
 if normalized !~ '^[a-f0-9]{64}$' then return 'HAYKO_INVITE_INVALID'; end if;
 select * into i from public.bc_invites
 where token_hash=encode(sha256(convert_to(normalized,'UTF8')),'hex');
 if not found then return 'HAYKO_INVITE_INVALID'; end if;
 if i.revoked or i.expires_at<=now() or i.uses>=i.max_uses then
  return 'HAYKO_INVITE_EXPIRED';
 end if;
 select state->>'name' into league_name from public.bc_leagues where id=i.league_id;
 if league_name is null or btrim(league_name)='' then return 'HAYKO_INVITE_INVALID'; end if;
 return league_name;
end; $$;

revoke all on function public.hayko_invite_preview(text) from public,anon,authenticated;
grant execute on function public.hayko_invite_preview(text) to authenticated;
notify pgrst,'reload schema';
commit;
