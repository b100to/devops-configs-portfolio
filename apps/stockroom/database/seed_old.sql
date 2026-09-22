-- 초기 데이터

-- 샘플 사용자 데이터
INSERT INTO users (name, nickname, email, organization, team) VALUES
('김철수', '철수', 'chulsoo@acme-corp.example', '아크메', '개발팀'),
('이영희', '영희', 'younghee@acme-corp.example', '아크메', '디자인팀'),
('박민준', '민준', 'minjun@acme-corp.example', '아크메', '마케팅팀'),
('성춘향', '춘향', 'chunhyang@acme-corp.example', '아크메', '운영팀'),
('최동현', '동현', 'donghyun@acme-corp.example', '아크메', 'QA팀'),
('관리자', 'admin', 'admin@acme-corp.example', '아크메', 'IT팀');

-- 관리자 설정
INSERT INTO admins (user_id, role) VALUES
(6, 'super_admin');

-- 샘플 아이템 데이터
INSERT INTO items (name, description, category_id, available_quantity, max_per_user, image_url) VALUES
-- 필기구 카테고리 (category_id = 1)
('볼펜(검정)', '검은색 볼펜', 1, 200, 5, '/images/pen-black.jpg'),
('3색 볼펜', '빨강, 파랑, 검정 3색 볼펜', 1, 100, 3, '/images/pen-3color.jpg'),
('형광펜(노랑)', '노란색 형광펜', 1, 80, 3, '/images/highlighter-yellow.jpg'),
('형광펜 세트', '검정, 빨강, 파랑 형광펜 세트', 1, 50, 2, '/images/highlighter-set.jpg'),
('샤프', '0.5mm 샤프펜슬', 1, 120, 3, '/images/mechanical-pencil.jpg'),
('연필', 'HB 연필', 1, 150, 5, '/images/pencil.jpg'),
('네임펜', '유성 네임펜', 1, 60, 2, '/images/name-pen.jpg'),
('샤프심', '0.5mm 샤프심', 1, 100, 3, '/images/lead.jpg'),
('지우개', '일반 지우개', 1, 80, 3, '/images/eraser.jpg'),

-- 사무용품 카테고리 (category_id = 2)
('자(30cm)', '30cm 자', 2, 40, 1, '/images/ruler-30cm.jpg'),
('출자', '투명 출자', 2, 30, 1, '/images/triangle-ruler.jpg'),
('스카치 테이프', '투명 스카치 테이프', 2, 50, 2, '/images/scotch-tape.jpg'),
('박스 테이프', '포장용 박스 테이프', 2, 30, 1, '/images/box-tape.jpg'),
('양면 테이프', '양면 접착 테이프', 2, 40, 2, '/images/double-tape.jpg'),
('매직 테이프', '벨크로 매직 테이프', 2, 25, 1, '/images/magic-tape.jpg'),
('가위', '일반 사무용 가위', 2, 20, 1, '/images/scissors.jpg'),
('커터 칼', '사무용 커터 칼', 2, 15, 1, '/images/cutter.jpg'),
('클립 집게(중)', '중형 클립 집게', 2, 60, 3, '/images/clip-medium.jpg'),
('포스트잇(대)', '대형 포스트잇', 2, 80, 3, '/images/postit-large.jpg'),
('포스트잇(소)', '소형 포스트잇', 2, 100, 5, '/images/postit-small.jpg'),
('플래그', '포스트잇 플래그', 2, 70, 3, '/images/flag.jpg'),
('스테이플러', '일반 스테이플러', 2, 15, 1, '/images/stapler.jpg'),
('스테이플러 리무버', '스테이플러 제거기', 2, 10, 1, '/images/stapler-remover.jpg'),
('수정 테이프', '수정용 테이프', 2, 40, 2, '/images/correction-tape.jpg'),
('노트패드(A4)', 'A4 노트패드', 2, 60, 2, '/images/notepad-a4.jpg'),
('노트패드(A5)', 'A5 노트패드', 2, 80, 3, '/images/notepad-a5.jpg'),
('스프링노트', '스프링 제본 노트', 2, 50, 2, '/images/spring-note.jpg'),
('딱풀', '고체 풀', 2, 50, 2, '/images/glue-stick.jpg'),
('투명화일', '투명 클리어화일', 2, 70, 3, '/images/clear-file.jpg'),
('종이파일', '종이 파일', 2, 40, 2, '/images/paper-file.jpg'),
('A4 용지', 'A4 복사용지 500매', 2, 20, 1, '/images/a4-paper.jpg'),
('A4 클립보드', 'A4 클립보드', 2, 25, 1, '/images/clipboard.jpg'),
('파일 속지(A4)', 'A4 파일 속지', 2, 100, 3, '/images/file-insert.jpg'),
('모니터 메모보드', '모니터 부착용 메모보드', 2, 15, 1, '/images/monitor-memo.jpg'),

-- 소모품 카테고리 (category_id = 3)
('각티슈', '티슈', 3, 100, 2, '/images/tissue.jpg'),
('물티슈', '물티슈', 3, 80, 2, '/images/wet-tissue.jpg'),
('건전지 AA', 'AA 건전지', 3, 60, 4, '/images/battery-aa.jpg'),
('건전지 AAA', 'AAA 건전지', 3, 60, 4, '/images/battery-aaa.jpg'),
('자석', '강력 자석', 3, 40, 3, '/images/magnet.jpg'),
('클립', '종이 클립', 3, 200, 10, '/images/paperclip.jpg'),
('면봉', '면봉', 3, 30, 1, '/images/cotton-swab.jpg'),
('보드마카', '화이트보드 마카', 3, 50, 3, '/images/board-marker.jpg'),
('보드마카 지우개', '화이트보드 지우개', 3, 20, 1, '/images/board-eraser.jpg'),
('화이트보드 크리너', '화이트보드 클리너', 3, 15, 1, '/images/board-cleaner.jpg'),
('네임택 집게', '이름표 집게', 3, 50, 3, '/images/name-tag-clip.jpg'),
('케이블 타이(소)', '소형 케이블 타이', 3, 100, 5, '/images/cable-tie-small.jpg'),
('케이블 타이(중)', '중형 케이블 타이', 3, 80, 5, '/images/cable-tie-medium.jpg'),
('쇼핑백(아크메)', '아크메 로고 쇼핑백', 3, 200, 10, '/images/shopping-bag-acme.jpg'),
('무지 쇼핑백(소)', '소형 무지 쇼핑백', 3, 150, 10, '/images/shopping-bag-small.jpg'),
('대봉투(아크메)', '아크메 로고 대봉투', 3, 100, 5, '/images/envelope-acme.jpg'),
('장례식 부의 봉투', '부의 봉투', 3, 20, 2, '/images/funeral-envelope.jpg'),
('축의금 봉투', '축의금 봉투', 3, 30, 3, '/images/congratulation-envelope.jpg'),
('마스크', '일회용 마스크', 3, 500, 20, '/images/mask.jpg'),

-- 의료용품 카테고리 (category_id = 4)
('밴드', '일회용 밴드', 4, 100, 5, '/images/bandage.jpg'),
('마데카솔', '마데카솔 (대여품목 - 사용 후 반납)', 4, 5, 1, '/images/madecassol.jpg'),
('메디폼', '메디폼', 4, 20, 2, '/images/mediform.jpg'),
('파스', '소염진통 파스', 4, 30, 3, '/images/patch.jpg');