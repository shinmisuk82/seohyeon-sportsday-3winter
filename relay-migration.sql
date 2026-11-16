-- 이어달리기 예선 2조 + 결승 4개 반 전용 저장소
create table if not exists public.relay_results (group_name text not null check(group_name in ('A','B','F')),class_no int not null check(class_no between 1 and 8),rank int check(rank between 1 and 4),version int not null default 0,updated_by uuid references auth.users(id),updated_at timestamptz default now(),primary key(group_name,class_no));
insert into public.relay_results(group_name,class_no) values
('A',6),
('A',8),
('A',2),
('A',3),
('B',4),
('B',5),
('B',7),
('B',1),
('F',1),
('F',2),
('F',3),
('F',4),
('F',5),
('F',6),
('F',7),
('F',8) on conflict do nothing;
create unique index if not exists relay_unique_rank_a on public.relay_results(rank) where group_name='A' and rank is not null;
create unique index if not exists relay_unique_rank_b on public.relay_results(rank) where group_name='B' and rank is not null;
create unique index if not exists relay_unique_rank_f on public.relay_results(rank) where group_name='F' and rank is not null;
alter table public.relay_results enable row level security;
create policy "relay read" on public.relay_results for select using(true);
create or replace function public.save_relay(p_group text,p_class int,p_version int,p_rank int) returns void language plpgsql security definer set search_path=public as $$
declare r public.relay_results%rowtype;
begin
 if not exists(select 1 from admins where user_id=auth.uid()) then raise exception '관리자만 입력 가능'; end if;
 select * into r from relay_results where group_name=p_group and class_no=p_class for update;
 if not found or r.version<>p_version then raise exception '다른 관리자가 먼저 수정했어. 새로고침 후 확인해 줘'; end if;
 if p_rank is not null and exists(select 1 from relay_results where group_name=p_group and class_no<>p_class and rank=p_rank and (p_group<>'F' or class_no in (select class_no from relay_results where group_name in ('A','B') and rank<=2))) then raise exception '같은 조 순위 중복'; end if;
 if p_group='F' and not exists(select 1 from relay_results where group_name in ('A','B') and class_no=p_class and rank<=2) then raise exception '결승 진출 학급이 아님'; end if;
 update relay_results set rank=p_rank,version=version+1,updated_by=auth.uid(),updated_at=now() where group_name=p_group and class_no=p_class;
 if p_group<>'F' then update relay_results set rank=null,version=version+1 where group_name='F' and rank is not null; end if;
 insert into audit_log(actor,action,target,detail) values(auth.uid(),'save_relay',p_group||':'||p_class,jsonb_build_object('before',r.rank,'after',p_rank));
end $$;
grant execute on function public.save_relay(text,int,int,int) to authenticated;
-- 이전 버전의 잘못 생성된 이어달리기 1대1 경기 제거
delete from public.schedule where match_id like '이어달리기-%';
delete from public.matches where sport='이어달리기';
-- Supabase Dashboard > Database > Publications 에서 relay_results 를 realtime에 추가
