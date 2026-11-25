-- Comptabilité + : configuration Supabase (à coller dans SQL Editor, puis « Run »)

-- 1) Demandes d'accès : n'importe qui peut en ENVOYER une, seul toi peux les LIRE (dans le tableau de bord)
create table if not exists public.access_requests (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  prenom text not null check (char_length(prenom) <= 60),
  nom text not null check (char_length(nom) <= 60),
  courriel text not null check (char_length(courriel) <= 120),
  groupe text check (char_length(groupe) <= 60),
  message text check (char_length(message) <= 500),
  statut text not null default 'nouvelle'
);
alter table public.access_requests enable row level security;
drop policy if exists "envoyer une demande" on public.access_requests;
create policy "envoyer une demande" on public.access_requests
  for insert to anon with check (statut = 'nouvelle');
-- aucune règle de lecture : les demandes ne sont visibles que dans ton tableau de bord Supabase

-- 2) Profil de chaque élève (prénom, groupe), lisible seulement par l'élève lui-même
create table if not exists public.profils (
  id uuid primary key references auth.users(id) on delete cascade,
  prenom text,
  groupe text,
  created_at timestamptz not null default now()
);
alter table public.profils enable row level security;
drop policy if exists "lire son profil" on public.profils;
create policy "lire son profil" on public.profils for select to authenticated using (auth.uid() = id);
drop policy if exists "modifier son profil" on public.profils;
create policy "modifier son profil" on public.profils for update to authenticated using (auth.uid() = id);

create or replace function public.creer_profil() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profils (id, prenom, groupe)
  values (new.id, new.raw_user_meta_data->>'prenom', new.raw_user_meta_data->>'groupe');
  return new;
end $$;
drop trigger if exists a_la_creation_du_compte on auth.users;
create trigger a_la_creation_du_compte after insert on auth.users
  for each row execute function public.creer_profil();

-- 3) Signalements de problèmes (bouton « Signaler un problème ») : n'importe qui peut en ENVOYER un, toi seule les lis
create table if not exists public.problem_reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  type text check (char_length(type) <= 40),
  message text not null check (char_length(message) between 1 and 1000),
  page text check (char_length(page) <= 200),
  appareil text check (char_length(appareil) <= 40),
  statut text not null default 'nouveau'
);
alter table public.problem_reports enable row level security;
drop policy if exists "envoyer un signalement" on public.problem_reports;
create policy "envoyer un signalement" on public.problem_reports
  for insert to anon with check (statut = 'nouveau');
