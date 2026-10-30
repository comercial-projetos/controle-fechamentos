-- Controle de Fechamentos — configuração do banco no Supabase
-- Cole tudo em: Supabase > SQL Editor > New query > Run

-- 1) Tabela única com fechamentos, clientes e responsáveis
create table if not exists public.registros (
  colecao    text not null check (colecao in ('fechamentos','clientes','responsaveis')),
  id         text not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by text,
  primary key (colecao, id)
);

create or replace function public.registros_touch() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end $$;
drop trigger if exists registros_touch on public.registros;
create trigger registros_touch before update on public.registros
  for each row execute function public.registros_touch();

-- 2) Acesso: qualquer pessoa com o link da página lê e altera (sem login)
alter table public.registros enable row level security;
drop policy if exists "equipe le"      on public.registros;
drop policy if exists "equipe insere"  on public.registros;
drop policy if exists "equipe altera"  on public.registros;
drop policy if exists "equipe exclui"  on public.registros;
create policy "equipe le"     on public.registros for select to anon, authenticated using (true);
create policy "equipe insere" on public.registros for insert to anon, authenticated with check (true);
create policy "equipe altera" on public.registros for update to anon, authenticated using (true) with check (true);
create policy "equipe exclui" on public.registros for delete to anon, authenticated using (true);

-- 3) Tempo real (as mudanças aparecem na hora para todos)
do $$ begin
  alter publication supabase_realtime add table public.registros;
exception when duplicate_object then null; end $$;

-- 4) Anexos: pasta privada "anexos", acessível pela página
insert into storage.buckets (id, name, public, file_size_limit)
values ('anexos', 'anexos', false, 47185920)
on conflict (id) do nothing;

drop policy if exists "equipe anexos le"     on storage.objects;
drop policy if exists "equipe anexos envia"  on storage.objects;
drop policy if exists "equipe anexos exclui" on storage.objects;
create policy "equipe anexos le"     on storage.objects for select to anon, authenticated using (bucket_id = 'anexos');
create policy "equipe anexos envia"  on storage.objects for insert to anon, authenticated with check (bucket_id = 'anexos');
create policy "equipe anexos exclui" on storage.objects for delete to anon, authenticated using (bucket_id = 'anexos');
