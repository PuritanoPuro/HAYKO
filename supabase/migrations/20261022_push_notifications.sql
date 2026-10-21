begin;

create table if not exists public.hayko_push_devices (
  installation_id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now(),
  check (length(installation_id) between 20 and 4096)
);

create index if not exists hayko_push_devices_user_idx
on public.hayko_push_devices(user_id);

alter table public.hayko_push_devices enable row level security;
revoke all on public.hayko_push_devices from public, anon, authenticated;

create table if not exists public.hayko_push_outbox (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(title) between 1 and 120),
  body text not null check (length(body) between 1 and 500),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  last_error text
);

create index if not exists hayko_push_outbox_pending_idx
on public.hayko_push_outbox(created_at)
where sent_at is null;

alter table public.hayko_push_outbox enable row level security;
revoke all on public.hayko_push_outbox from public, anon, authenticated;
grant select, delete on public.hayko_push_devices to service_role;
grant select, update on public.hayko_push_outbox to service_role;

create or replace function public.hayko_register_push_device(
  p_installation_id text,
  p_platform text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'FORBIDDEN'; end if;
  if p_installation_id is null or length(p_installation_id) not between 20 and 4096 then
    raise exception 'INVALID_INSTALLATION_ID';
  end if;
  if p_platform not in ('ios', 'android') then
    raise exception 'INVALID_PLATFORM';
  end if;

  insert into public.hayko_push_devices(installation_id, user_id, platform)
  values (p_installation_id, auth.uid(), p_platform)
  on conflict(installation_id) do update
  set user_id = excluded.user_id,
      platform = excluded.platform,
      updated_at = now();
end;
$$;

create or replace function public.hayko_unregister_push_device(p_installation_id text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.hayko_push_devices
  where installation_id = p_installation_id and user_id = auth.uid();
$$;

create or replace function public.hayko_queue_join_request_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  league_name text;
  player_name text;
begin
  select coalesce(nullif(l.state->>'name', ''), 'Lega')
  into league_name
  from public.bc_leagues l
  where l.id = new.league_id;

  if new.status = 'pending' and tg_op = 'INSERT' then
    select coalesce(nullif(p.first_name, ''), 'Un giocatore')
    into player_name
    from public.hayko_profiles p
    where p.user_id = new.user_id;

    insert into public.hayko_push_outbox(user_id, title, body, payload)
    select m.user_id,
           'Nuova richiesta di accesso',
           coalesce(player_name, 'Un giocatore') || ' vuole entrare in ' || league_name || '.',
           jsonb_build_object('type', 'join_request', 'league', new.league_id)
    from public.bc_members m
    where m.league_id = new.league_id
      and m.role in ('president', 'admin')
      and m.user_id <> new.user_id;
  elsif new.status = 'pending' and tg_op = 'UPDATE' and
      old.status is distinct from new.status then
    select coalesce(nullif(p.first_name, ''), 'Un giocatore')
    into player_name
    from public.hayko_profiles p
    where p.user_id = new.user_id;

    insert into public.hayko_push_outbox(user_id, title, body, payload)
    select m.user_id,
           'Nuova richiesta di accesso',
           coalesce(player_name, 'Un giocatore') || ' vuole entrare in ' || league_name || '.',
           jsonb_build_object('type', 'join_request', 'league', new.league_id)
    from public.bc_members m
    where m.league_id = new.league_id
      and m.role in ('president', 'admin')
      and m.user_id <> new.user_id;
  elsif tg_op = 'UPDATE' and old.status = 'pending' and
      new.status in ('approved', 'rejected') then
    insert into public.hayko_push_outbox(user_id, title, body, payload)
    values (
      new.user_id,
      case when new.status = 'approved'
        then 'Richiesta approvata' else 'Richiesta non approvata' end,
      case when new.status = 'approved'
        then 'Ora puoi accedere a ' || league_name || '.'
        else 'La richiesta di accesso a ' || league_name || ' non è stata approvata.' end,
      jsonb_build_object('type', 'league', 'league', new.league_id)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists hayko_join_request_push on public.hayko_join_requests;

create trigger hayko_join_request_push
after insert or update of status on public.hayko_join_requests
for each row execute function public.hayko_queue_join_request_push();

revoke all on function public.hayko_register_push_device(text, text),
  public.hayko_unregister_push_device(text)
from public, anon, authenticated;
grant execute on function public.hayko_register_push_device(text, text),
  public.hayko_unregister_push_device(text)
to authenticated;

notify pgrst, 'reload schema';
commit;
