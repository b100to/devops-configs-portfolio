-- Google OAuth 지원을 위한 마이그레이션
-- users 테이블에 google_id 컬럼 추가

ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;
ALTER TABLE users ALTER COLUMN password_hash SET DEFAULT '';
ALTER TABLE users ALTER COLUMN team_name SET DEFAULT '';
