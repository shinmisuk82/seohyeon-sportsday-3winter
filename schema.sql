-- Run in Supabase SQL editor. Create teacher users in Authentication > Users.
create extension if not exists pgcrypto;
create table public.admins (user_id uuid primary key references auth.users(id) on delete cascade, display_name text not null, role text not null default 'teacher' check(role in ('teacher','owner')));
create table public.matches (id text primary key, sport text not null, stage text not null, group_name text, slot int not null, home int, away int, winner int, home_score numeric, away_score numeric, version int not null default 0, updated_by uuid references auth.users(id), updated_at timestamptz default now(), check(home between 1 and 8), check(away between 1 and 8), check(winner between 1 and 8));
create table public.records (sport text not null, class_no int not null check(class_no between 1 and 8), result numeric, version int not null default 0, updated_by uuid references auth.users(id), updated_at timestamptz default now(), primary key(sport,class_no));
create table public.penalties (id uuid primary key default gen_random_uuid(), class_no int not null check(class_no between 1 and 8), kind text not null check(kind in ('sportsmanship_negative','mileage','sportsmanship_positive')), reason text not null default '', created_by uuid not null references auth.users(id), created_at timestamptz not null default now(), voided_by uuid references auth.users(id), voided_at timestamptz);
create table public.rank_overrides (sport text not null, class_no int not null check(class_no between 1 and 8), rank int not null check(rank between 1 and 8), version int not null default 0, updated_by uuid references auth.users(id), primary key(sport,class_no));
create table public.schedule (match_id text primary key references public.matches(id), starts_at timestamptz, venue text, updated_by uuid references auth.users(id));
create table public.audit_log (id bigint generated always as identity primary key, actor uuid, action text not null, target text not null, detail jsonb, created_at timestamptz default now());
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from admins where user_id=auth.uid())$$;
create or replace function public.is_owner() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from admins where user_id=auth.uid() and role='owner')$$;
alter table admins enable row level security; alter table matches enable row level security; alter table records enable row level security; alter table penalties enable row level security; alter table rank_overrides enable row level security; alter table schedule enable row level security; alter table audit_log enable row level security;
create policy "read admins" on admins for select to authenticated using(public.is_admin());
create policy "read matches" on matches for select using(true);
create policy "read records" on records for select using(true);
create policy "read penalties" on penalties for select using(true);
create policy "read ranks" on rank_overrides for select using(true);
create policy "read schedule" on schedule for select using(true);
create policy "read audit" on audit_log for select to authenticated using(public.is_owner());
-- All writes through RPC: no client UPDATE/INSERT grants.
create or replace function public.save_match(p_id text,p_version int,p_winner int,p_home_score numeric default null,p_away_score numeric default null)
returns void language plpgsql security definer set search_path=public as $$
declare m public.matches%rowtype;
begin
 if not public.is_admin() then raise exception '관리자 권한이 없습니다'; end if;
 select * into m from matches where id=p_id for update;
 if not found then raise exception '경기를 찾을 수 없습니다'; end if;
 if m.version<>p_version then raise exception '다른 관리자가 먼저 수정했습니다. 새로고침 후 다시 입력하세요'; end if;
 if p_winner is not null and p_winner not in (m.home,m.away) then raise exception '대진에 없는 학급입니다'; end if;
 update matches set winner=p_winner,home_score=p_home_score,away_score=p_away_score,version=version+1,updated_by=auth.uid(),updated_at=now() where id=p_id;
 insert into audit_log(actor,action,target,detail) values(auth.uid(),'save_match',p_id,jsonb_build_object('old',to_jsonb(m),'winner',p_winner,'home_score',p_home_score,'away_score',p_away_score));
end $$;
create or replace function public.save_record(p_sport text,p_class int,p_version int,p_result numeric)
returns void language plpgsql security definer set search_path=public as $$
declare r public.records%rowtype;
begin
 if not public.is_admin() then raise exception '관리자 권한이 없습니다'; end if;
 select * into r from records where sport=p_sport and class_no=p_class for update;
 if not found or r.version<>p_version then raise exception '기록이 변경되었습니다. 새로고침하세요'; end if;
 update records set result=p_result,version=version+1,updated_by=auth.uid(),updated_at=now() where sport=p_sport and class_no=p_class;
 insert into audit_log(actor,action,target,detail) values(auth.uid(),'save_record',p_sport||':'||p_class,jsonb_build_object('before',r.result,'after',p_result));
end $$;
create or replace function public.add_penalty(p_class int,p_kind text,p_reason text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception '관리자 권한이 없습니다'; end if;
 if p_class not between 1 and 8 or p_kind not in ('sportsmanship_negative','mileage','sportsmanship_positive') then raise exception '잘못된 입력'; end if;
 insert into penalties(class_no,kind,reason,created_by) values(p_class,p_kind,left(coalesce(p_reason,''),300),auth.uid());
 insert into audit_log(actor,action,target,detail) values(auth.uid(),'add_penalty',p_class::text,jsonb_build_object('kind',p_kind,'reason',p_reason));
end $$;
create or replace function public.void_penalty(p_id uuid) returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception '관리자 권한이 없습니다'; end if;
 update penalties set voided_by=auth.uid(),voided_at=now() where id=p_id and voided_at is null;
 if not found then raise exception '이미 취소되었거나 없는 내역입니다'; end if;
 insert into audit_log(actor,action,target) values(auth.uid(),'void_penalty',p_id::text);
end $$;
create or replace function public.save_rank(p_sport text,p_class int,p_version int,p_rank int) returns void language plpgsql security definer set search_path=public as $$
declare r public.rank_overrides%rowtype;
begin
 if not public.is_admin() then raise exception '관리자 권한이 없습니다'; end if;
 select * into r from rank_overrides where sport=p_sport and class_no=p_class for update;
 if not found or r.version<>p_version then raise exception '등위가 변경되었습니다. 새로고침하세요'; end if;
 update rank_overrides set rank=p_rank,version=version+1,updated_by=auth.uid() where sport=p_sport and class_no=p_class;
 insert into audit_log(actor,action,target,detail) values(auth.uid(),'save_rank',p_sport||':'||p_class,jsonb_build_object('rank',p_rank));
end $$;
create or replace function public.save_schedule(p_id text,p_starts_at timestamptz,p_venue text) returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception '관리자 권한이 없습니다'; end if;
 insert into schedule(match_id,starts_at,venue,updated_by) values(p_id,p_starts_at,left(coalesce(p_venue,''),100),auth.uid()) on conflict(match_id) do update set starts_at=excluded.starts_at,venue=excluded.venue,updated_by=excluded.updated_by;
 insert into audit_log(actor,action,target) values(auth.uid(),'save_schedule',p_id);
end $$;
grant execute on function public.save_match(text,int,int,numeric,numeric),public.save_record(text,int,int,numeric),public.add_penalty(int,text,text),public.void_penalty(uuid),public.save_rank(text,int,int,int),public.save_schedule(text,timestamptz,text) to authenticated;
-- Enable realtime in Supabase dashboard for matches, records, penalties, rank_overrides, schedule.
