# 2026 어디서나 운동장

## 미리보기
`index.html`을 열면 브라우저 내 체험 모드로 메뉴와 관리자 입력을 시험할 수 있습니다. 이 상태의 데이터는 해당 브라우저에만 저장되며, 실제 교사별 로그인·공유는 되지 않습니다.

## 실제 운영 연결
1. Supabase 프로젝트를 만듭니다.
2. SQL Editor에서 `schema.sql` 실행 후 `seed.sql` 실행.
3. Authentication > Users에서 교사별 이메일/비밀번호 계정 생성.
4. SQL Editor에서 `insert into public.admins(user_id,display_name,role) values ('AUTH-USER-UUID','교사명','owner');` 형식으로 총괄 관리자를 등록하고, 다른 교사는 `teacher` 역할로 등록합니다. 비밀번호는 파일에 기록하지 마세요.
5. Supabase Database > Publications/Realtime에서 matches, records, penalties, rank_overrides, schedule 테이블의 실시간 발행을 켭니다.
6. `config.js`에 Project URL과 anon/publishable key를 입력합니다. **service_role key는 절대 넣지 마세요.**
7. GitHub의 새 public 저장소 `seohyeon-league-2026`에 파일을 업로드하고 Settings > Pages > Deploy from branch > main / root를 선택합니다.
8. 두 교사 계정으로 동시 입력, 동일 경기 동시 수정 충돌, 감점 누적 및 취소를 실제 테스트합니다.

## 운영상 확인할 사항
- 계획서에는 이어달리기가 조별 1·2위 **결승 진출**이라고 적혀 있으나, 사용자 지정은 **준결승 진출**입니다. 현재는 사용자 지정대로 준결승을 구성했습니다.
- 계획서의 10회/20회 기준은 '쓰레기 및 질서 관련 지적'입니다. 현재 화면은 스포츠맨십 감점과 마일리지·질서 감점을 합산합니다. 실제 규정 적용 전에 확정이 필요합니다.
- 조별 동률 처리 기준, 기록경기 단위와 동점 처리, 자동 몰수패 처리 기준은 정해지지 않아 자동 확정하지 않습니다.
- 기록경기 점수는 모든 8개 반 기록이 입력되고 동률이 없을 때만 산정됩니다.
- 자동 점수는 준결승/결승 결과가 확정된 후 1, 2, 3~4, 5~8위에 적용합니다. 중간 조별리그 승점은 종합점수에 가산하지 않습니다.
- 준결승 자동 배정은 양쪽 조의 모든 경기가 종료되고 승점 동률이 없을 때만 동작합니다. 동률 처리 규정이 정해지면 추가 구현이 필요합니다.
- 준결승·결승 대진은 이전 라운드 결과로 계산되며, 잘못된 이전 결과 수정 시 후속 결과를 다시 검토해야 합니다.
- 경기 중 실시간 운영 전에는 별도 테스트 프로젝트에서 검증하세요.


## 이어달리기 수정
예선 A조(6,8,2,3), B조(4,5,7,1)의 각 1·2위가 4개 반 결승으로 진출해. 준결승은 없어. 기존 Supabase를 사용 중이라면 `relay-migration.sql`을 SQL Editor에서 실행해. 새 데이터베이스도 기존 schema.sql과 seed.sql 실행 후 이 파일을 실행해야 해.
