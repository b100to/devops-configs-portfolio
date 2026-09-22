-- 회사 물품 신청 시스템 데이터베이스 스키마 (v2)

-- 조직 테이블 (회사/조직/팀 통합 관리)
-- type: company(회사), organization(조직/실), team(팀)
CREATE TABLE organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    type VARCHAR(20) NOT NULL DEFAULT 'organization',
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 초기 데이터: 회사
INSERT INTO organizations (name, type, description) VALUES
('Acme', 'company', '아크메 본사'),
('ORBIT', 'company', '오빗'),
('알파', 'company', '알파');

-- 초기 데이터: 조직 (아크메 본사 소속)
INSERT INTO organizations (name, type, description) VALUES
('경영지원실', 'organization', '경영 기획 및 전략 수립'),
('사업1실', 'organization', '비즈니스 성장 전략'),
('사업2실', 'organization', '2사업부 성장'),
('플랫폼실', 'organization', '플랫폼 사업부'),
('기술실', 'organization', 'IT 제품 개발');

-- 초기 데이터: 팀
INSERT INTO organizations (name, type, description) VALUES
('인프라팀', 'team', NULL),
('백엔드팀', 'team', NULL),
('프론트엔드팀', 'team', NULL),
('데이터팀', 'team', NULL),
('디자인팀', 'team', NULL),
('마케팅팀', 'team', NULL),
('운영팀', 'team', NULL),
('재무팀', 'team', NULL);

-- 사용자 테이블
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    korean_name VARCHAR(100) NOT NULL,
    english_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL DEFAULT '', -- bcrypt 해시된 4자리 패스워드 (Google 로그인 시 빈값)
    organization_id INTEGER REFERENCES organizations(id),
    team_name VARCHAR(100) NOT NULL DEFAULT '',
    email VARCHAR(255) UNIQUE,
    google_id VARCHAR(255) UNIQUE, -- Google OAuth sub ID
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP
);

-- 카테고리 테이블
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 초기 카테고리 데이터
INSERT INTO categories (name, description) VALUES
('필기구', '각종 펜, 연필, 샤프 등'),
('사무용품', '일반적인 사무용품'),
('소모품', '소모성 사무용품'),
('의료용품', '응급처치용 의료용품');

-- 물품 테이블
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_id INTEGER REFERENCES categories(id),
    available_quantity INTEGER NOT NULL DEFAULT 0,
    max_per_user INTEGER NOT NULL DEFAULT 1,
    image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 신청 테이블
CREATE TABLE requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    item_id INTEGER NOT NULL REFERENCES items(id),
    quantity INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(50) DEFAULT 'pending',
    notes TEXT,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    processed_by INTEGER REFERENCES users(id)
);

-- 관리자 테이블
CREATE TABLE admins (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    role VARCHAR(50) NOT NULL DEFAULT 'admin',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_users_korean_name ON users(korean_name);
CREATE INDEX idx_users_english_name ON users(english_name);
CREATE INDEX idx_users_organization ON users(organization_id);
CREATE INDEX idx_users_team ON users(team_name);
CREATE INDEX idx_items_category ON items(category_id);
CREATE INDEX idx_items_active ON items(is_active);
CREATE INDEX idx_requests_user ON requests(user_id);
CREATE INDEX idx_requests_item ON requests(item_id);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_admins_user ON admins(user_id);
CREATE INDEX idx_organizations_name ON organizations(name);
CREATE INDEX idx_organizations_type ON organizations(type);

-- 업데이트 시간 자동 갱신 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- items 테이블 업데이트 트리거
CREATE TRIGGER update_items_updated_at BEFORE UPDATE ON items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();