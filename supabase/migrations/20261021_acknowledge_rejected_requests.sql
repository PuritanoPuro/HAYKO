begin;

create or replace function public.hayko_acknowledge_rejected_requests()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'FORBIDDEN';
  end if;

  delete from public.hayko_join_requests
  where user_id = auth.uid()
    and status = 'rejected';
end;
$$;

revoke all on function public.hayko_acknowledge_rejected_requests()
from public, anon, authenticated;
grant execute on function public.hayko_acknowledge_rejected_requests()
to authenticated;

notify pgrst, 'reload schema';
commit;
