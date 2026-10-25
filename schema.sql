-- NovelVerse core schema. Run in Supabase > SQL Editor.
create extension if not exists pgcrypto;
create type app_role as enum ('user','premium','author','admin');

create table profiles(id uuid primary key references auth.users on delete cascade, username text unique, display_name text, avatar_url text, suspended boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table user_roles(user_id uuid references auth.users on delete cascade, role app_role, primary key(user_id,role));
create table novels(id uuid primary key default gen_random_uuid(), title text not null, author_name text not null, cover_url text, short_desc text, full_desc text, genre text, language text not null default 'English', tags text[] not null default '{}', is_premium boolean not null default false, featured boolean not null default false, status text not null default 'draft' check(status in('draft','published')), views int not null default 0, published_at timestamptz, created_by uuid references auth.users on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table chapters(id uuid primary key default gen_random_uuid(), novel_id uuid not null references novels on delete cascade, position int not null, title text not null, is_premium boolean not null default false, status text not null default 'draft' check(status in('draft','published')), word_count int not null default 0, audio_path text, audio_title text, narrator text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(novel_id,position));
create table chapter_text(chapter_id uuid primary key references chapters on delete cascade, body text not null default '');
create table reading_progress(user_id uuid references auth.users on delete cascade, novel_id uuid references novels on delete cascade, chapter_id uuid references chapters on delete cascade, position numeric not null default 0, updated_at timestamptz not null default now(), primary key(user_id,novel_id));
create table listening_progress(user_id uuid references auth.users on delete cascade, novel_id uuid references novels on delete cascade, chapter_id uuid references chapters on delete cascade, seconds numeric not null default 0, updated_at timestamptz not null default now(), primary key(user_id,novel_id));
create table favorites(user_id uuid references auth.users on delete cascade, novel_id uuid references novels on delete cascade, created_at timestamptz not null default now(), primary key(user_id,novel_id));
create table bookmarks(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade, chapter_id uuid not null references chapters on delete cascade, position numeric not null default 0, created_at timestamptz not null default now());
create table reviews(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade, novel_id uuid not null references novels on delete cascade, rating int not null check(rating between 1 and 5), body text check(char_length(body)<=2000), created_at timestamptz not null default now(), unique(user_id,novel_id));
create table subscriptions(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade, plan text not null check(plan in('monthly','yearly')), status text not null default 'active', current_period_end timestamptz not null, provider text, provider_ref text unique, created_at timestamptz not null default now());
create table reports(id uuid primary key default gen_random_uuid(), user_id uuid references auth.users on delete set null, novel_id uuid references novels on delete cascade, reason text not null check(char_length(reason)<=1000), status text not null default 'open', created_at timestamptz not null default now());
create table audit_logs(id bigint generated always as identity primary key, actor uuid, action text not null, detail jsonb, created_at timestamptz not null default now());
create index on novels(status,created_at desc); create index on novels(views desc); create index on chapters(novel_id,position);

create function is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from user_roles where user_id=auth.uid() and role='admin') $$;
create function has_premium() returns boolean language sql stable security definer set search_path=public as $$ select is_admin() or exists(select 1 from user_roles where user_id=auth.uid() and role='premium') or exists(select 1 from subscriptions where user_id=auth.uid() and status='active' and current_period_end>now()) $$;
create function bump_view(n uuid) returns void language sql security definer set search_path=public as $$ update novels set views=views+1 where id=n and status='published' $$;
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin
 insert into profiles(id,username,display_name) values(new.id,nullif(new.raw_user_meta_data->>'username',''),coalesce(nullif(new.raw_user_meta_data->>'username',''),split_part(new.email,'@',1)));
 insert into user_roles values(new.id,'user'); return new; end $$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

alter table profiles enable row level security; alter table user_roles enable row level security; alter table novels enable row level security; alter table chapters enable row level security; alter table chapter_text enable row level security; alter table reading_progress enable row level security; alter table listening_progress enable row level security; alter table favorites enable row level security; alter table bookmarks enable row level security; alter table reviews enable row level security; alter table subscriptions enable row level security; alter table reports enable row level security; alter table audit_logs enable row level security;

create policy p_read on profiles for select using(true);
create policy p_edit on profiles for update using(id=auth.uid()) with check(id=auth.uid() and suspended=false);
create policy r_own on user_roles for select using(user_id=auth.uid() or is_admin());
create policy r_admin on user_roles for all using(is_admin()) with check(is_admin());
create policy n_read on novels for select using(status='published' or is_admin());
create policy n_admin on novels for all using(is_admin()) with check(is_admin());
create policy c_read on chapters for select using((status='published' and exists(select 1 from novels n where n.id=novel_id and n.status='published')) or is_admin());
create policy c_admin on chapters for all using(is_admin()) with check(is_admin());
create policy t_read on chapter_text for select using(is_admin() or exists(select 1 from chapters c where c.id=chapter_id and c.status='published' and (not c.is_premium or has_premium())));
create policy t_admin on chapter_text for all using(is_admin()) with check(is_admin());
create policy rp_own on reading_progress for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy lp_own on listening_progress for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy f_own on favorites for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy b_own on bookmarks for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy rv_read on reviews for select using(true);
create policy rv_own on reviews for all using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy s_own on subscriptions for select using(user_id=auth.uid() or is_admin());
create policy rep_add on reports for insert with check(user_id=auth.uid());
create policy rep_admin on reports for all using(is_admin()) with check(is_admin());
create policy a_admin on audit_logs for select using(is_admin());

insert into storage.buckets(id,name,public,file_size_limit) values('covers','covers',true,3145728),('audio','audio',false,157286400) on conflict do nothing;
create policy cov_read on storage.objects for select using(bucket_id='covers');
create policy cov_admin on storage.objects for all using(bucket_id='covers' and is_admin()) with check(bucket_id='covers' and is_admin());
create policy aud_admin on storage.objects for all using(bucket_id='audio' and is_admin()) with check(bucket_id='audio' and is_admin());
create policy aud_read on storage.objects for select using(bucket_id='audio' and exists(select 1 from chapters c where c.audio_path=name and c.status='published' and (not c.is_premium or has_premium())));

-- FIRST ADMIN (after you sign up in the app), run once:
-- insert into user_roles select id,'admin' from auth.users where email='YOU@example.com';
