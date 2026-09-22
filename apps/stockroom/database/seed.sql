-- 초기 데이터 v2
-- schema.sql의 organizations, categories INSERT 실행 후 이 파일 실행

-- 샘플 사용자 데이터 (패스워드는 bcrypt로 해시된 4자리)
-- 패스워드 예시: 1234 -> $2a$10$hashedpassword (실제로는 bcrypt 라이브러리로 해시)
-- organization_id 참고: 1=Acme, 2=ORBIT, 3=알파, 4=경영지원실, 5=사업1실, 6=사업2실, 7=플랫폼실, 8=기술실
INSERT INTO users (korean_name, english_name, password_hash, organization_id, team_name, email) VALUES
('홍길동', 'Rowan', '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdKzquG2ZKMKHMQw6Kx/XQkPQZqHRa', 8, '인프라팀', 'rowan@acme-corp.example'), -- 패스워드: 1234
('김철수', 'Charles', '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdKzquG2ZKMKHMQw6Kx/XQkPQZqHRa', 8, '백엔드팀', 'charles@acme-corp.example'), -- 패스워드: 1234
('이영희', 'Emma', '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdKzquG2ZKMKHMQw6Kx/XQkPQZqHRa', 5, '디자인팀', 'emma@acme-corp.example'), -- 패스워드: 1234
('박민준', 'Mike', '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdKzquG2ZKMKHMQw6Kx/XQkPQZqHRa', 6, '마케팅팀', 'mike@acme-corp.example'), -- 패스워드: 1234
('관리자', 'Admin', '$2a$10$N9qo8uLOickgx2ZMRZoMye1VdKzquG2ZKMKHMQw6Kx/XQkPQZqHRa', 8, '운영팀', 'admin@acme-corp.example'); -- 패스워드: 1234

-- 관리자 설정
INSERT INTO admins (user_id, role) VALUES
(5, 'super_admin');

-- 샘플 아이템 데이터 (available_quantity=9999, max_per_user=10 고정)
INSERT INTO items (name, description, category_id, available_quantity, max_per_user, image_url) VALUES
-- 필기구 카테고리 (category_id = 1)
('볼펜(검정)', '검은색 볼펜', 1, 9999, 10, NULL),
('3색 볼펜', '빨강, 파랑, 검정 3색 볼펜', 1, 9999, 10, NULL),
('형광펜(노랑)', '노란색 형광펜', 1, 9999, 10, NULL),
('형광펜 세트', '검정, 빨강, 파랑 형광펜 세트', 1, 9999, 10, NULL),
('샤프', '0.5mm 샤프펜슬', 1, 9999, 10, NULL),
('연필', 'HB 연필', 1, 9999, 10, NULL),
('네임펜', '유성 네임펜', 1, 9999, 10, NULL),
('샤프심', '0.5mm 샤프심', 1, 9999, 10, NULL),
('지우개', '일반 지우개', 1, 9999, 10, NULL),

-- 사무용품 카테고리 (category_id = 2)
('자(30cm)', '30cm 자', 2, 9999, 10, NULL),
('출자', '투명 출자', 2, 9999, 10, NULL),
('스카치 테이프', '투명 스카치 테이프', 2, 9999, 10, NULL),
('박스 테이프', '포장용 박스 테이프', 2, 9999, 10, NULL),
('양면 테이프', '양면 접착 테이프', 2, 9999, 10, NULL),
('매직 테이프', '벨크로 매직 테이프', 2, 9999, 10, NULL),
('가위', '일반 사무용 가위', 2, 9999, 10, NULL),
('커터 칼', '사무용 커터 칼', 2, 9999, 10, NULL),
('클립 집게(중)', '중형 클립 집게', 2, 9999, 10, NULL),
('포스트잇(대)', '대형 포스트잇', 2, 9999, 10, NULL),
('포스트잇(소)', '소형 포스트잇', 2, 9999, 10, NULL),
('플래그', '포스트잇 플래그', 2, 9999, 10, NULL),
('스테이플러', '일반 스테이플러', 2, 9999, 10, NULL),
('스테이플러 리무버', '스테이플러 제거기', 2, 9999, 10, NULL),
('수정 테이프', '수정용 테이프', 2, 9999, 10, NULL),
('노트패드(A4)', 'A4 노트패드', 2, 9999, 10, NULL),
('노트패드(A5)', 'A5 노트패드', 2, 9999, 10, NULL),
('스프링노트', '스프링 제본 노트', 2, 9999, 10, NULL),
('딱풀', '고체 풀', 2, 9999, 10, NULL),
('투명화일', '투명 클리어화일', 2, 9999, 10, NULL),
('종이파일', '종이 파일', 2, 9999, 10, NULL),
('A4 용지', 'A4 복사용지 500매', 2, 9999, 10, NULL),
('A4 클립보드', 'A4 클립보드', 2, 9999, 10, NULL),
('파일 속지(A4)', 'A4 파일 속지', 2, 9999, 10, NULL),
('모니터 메모보드', '모니터 부착용 메모보드', 2, 9999, 10, NULL),

-- 소모품 카테고리 (category_id = 3)
('각티슈', '티슈', 3, 9999, 10, NULL),
('물티슈', '물티슈', 3, 9999, 10, NULL),
('건전지 AA', 'AA 건전지', 3, 9999, 10, NULL),
('건전지 AAA', 'AAA 건전지', 3, 9999, 10, NULL),
('자석', '강력 자석', 3, 9999, 10, NULL),
('클립', '종이 클립', 3, 9999, 10, NULL),
('면봉', '면봉', 3, 9999, 10, NULL),
('보드마카', '화이트보드 마카', 3, 9999, 10, NULL),
('보드마카 지우개', '화이트보드 지우개', 3, 9999, 10, NULL),
('화이트보드 크리너', '화이트보드 클리너', 3, 9999, 10, NULL),
('네임택 집게', '이름표 집게', 3, 9999, 10, NULL),
('케이블 타이(소)', '소형 케이블 타이', 3, 9999, 10, NULL),
('케이블 타이(중)', '중형 케이블 타이', 3, 9999, 10, NULL),
('쇼핑백(아크메)', '아크메 로고 쇼핑백', 3, 9999, 10, NULL),
('무지 쇼핑백(소)', '소형 무지 쇼핑백', 3, 9999, 10, NULL),
('대봉투(아크메)', '아크메 로고 대봉투', 3, 9999, 10, NULL),
('장례식 부의 봉투', '부의 봉투', 3, 9999, 10, NULL),
('축의금 봉투', '축의금 봉투', 3, 9999, 10, NULL),
('마스크', '일회용 마스크', 3, 9999, 10, NULL),

-- 의료용품 카테고리 (category_id = 4)
('밴드', '일회용 밴드', 4, 9999, 10, NULL),
('마데카솔', '마데카솔 (대여품목 - 사용 후 반납)', 4, 9999, 10, NULL),
('메디폼', '메디폼', 4, 9999, 10, NULL),
('파스', '소염진통 파스', 4, 9999, 10, NULL);
