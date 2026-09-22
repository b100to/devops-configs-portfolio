// 아크메 팀 구성 (ver.26.02) 기반 직원 디렉토리
// Google 로그인 후 프로필 보완 시 팀/조직 자동 매핑에 사용
//
// [팀 추가] TEAM_GROUPS에 해당 그룹의 teams 배열에 팀명 추가 + TEAMS에 팀 정보 추가
// [직원 추가] EMPLOYEES 배열에 { name, team } 객체 추가
// [조직(실) 추가] TEAM_GROUPS에 새 그룹 추가 + TEAMS에 organizationName 매핑 + DB organizations 테이블에도 INSERT

// 회사 정보
export interface CompanyInfo {
    id: string;
    name: string;
    hasTeamStructure: boolean; // true: TEAM_GROUPS 사용, false: 직접 입력
}

// 회사 목록
export const COMPANIES: CompanyInfo[] = [
    { id: 'acme', name: 'Acme', hasTeamStructure: true },
    { id: 'orbit', name: 'ORBIT', hasTeamStructure: false },
    { id: 'alpha', name: 'Alpha', hasTeamStructure: false },
];

// 회사별 organization_id 매핑 (DB organizations 테이블 기준)
// Acme은 팀별로 organizationName → organizations.name 매핑 사용
export const COMPANY_ORG_IDS: Record<string, number | undefined> = {
    acme: undefined,  // 본사는 팀별로 TEAMS의 organizationName 매핑
    orbit: 9,             // 오빗 (organizations.id = 9)
    alpha: 6,      // 알파 (organizations.id = 6)
};

export interface TeamInfo {
    name: string;
    organizationName?: string; // organizations 테이블의 name과 매칭
}

export interface EmployeeInfo {
    name: string;
    team: string;
}

// 실/그룹 → 팀 목록 (UI 그룹핑용)
export const TEAM_GROUPS: { label: string; teams: string[] }[] = [
    { label: '경영지원', teams: ['재무팀'] },
    { label: '경영지원실', teams: ['운영팀'] },
    { label: '사업1실', teams: ['마케팅팀'] },
    { label: '사업2실', teams: ['디자인팀'] },
    { label: '플랫폼실', teams: ['인프라팀', '데이터팀'] },
    { label: '기술실', teams: ['백엔드팀', '프론트엔드팀'] },
];

// 팀 → 조직(실) 매핑
export const TEAMS: Record<string, TeamInfo> = {
    '재무팀': { name: '재무팀', organizationName: '경영지원' },
    '운영팀': { name: '운영팀', organizationName: '경영지원실' },
    '마케팅팀': { name: '마케팅팀', organizationName: '사업1실' },
    '디자인팀': { name: '디자인팀', organizationName: '사업2실' },
    '인프라팀': { name: '인프라팀', organizationName: '플랫폼실' },
    '데이터팀': { name: '데이터팀', organizationName: '플랫폼실' },
    '백엔드팀': { name: '백엔드팀', organizationName: '기술실' },
    '프론트엔드팀': { name: '프론트엔드팀', organizationName: '기술실' },
};

// 전체 직원 목록 (영어이름 → 팀 매핑)
export const EMPLOYEES: EmployeeInfo[] = [
    // 재무팀
    { name: 'Blake', team: '재무팀' },
    { name: 'Casey', team: '재무팀' },
    // 운영팀
    { name: 'Dana', team: '운영팀' },
    { name: 'Eli', team: '운영팀' },
    // 마케팅팀
    { name: 'Finn', team: '마케팅팀' },
    { name: 'Gray', team: '마케팅팀' },
    // 디자인팀
    { name: 'Harper', team: '디자인팀' },
    { name: 'Indy', team: '디자인팀' },
    // 인프라팀
    { name: 'Jules', team: '인프라팀' },
    { name: 'Kai', team: '인프라팀' },
    // 데이터팀
    { name: 'Lane', team: '데이터팀' },
    { name: 'Morgan', team: '데이터팀' },
    // 백엔드팀
    { name: 'Noel', team: '백엔드팀' },
    { name: 'Parker', team: '백엔드팀' },
    // 프론트엔드팀
    { name: 'Quinn', team: '프론트엔드팀' },
    { name: 'River', team: '프론트엔드팀' },
];

// 이름으로 직원 검색 (case-insensitive prefix match)
// query가 빈 문자열이면 전체 목록 반환 (팀 필터만 적용)
export const searchEmployees = (query: string, team?: string): EmployeeInfo[] => {
    return EMPLOYEES.filter(emp => {
        const matchesTeam = !team || emp.team === team;
        const matchesName = !query || emp.name.toLowerCase().startsWith(query.toLowerCase());
        return matchesTeam && matchesName;
    });
};

// 이름으로 정확한 직원 찾기
export const findEmployee = (name: string): EmployeeInfo | undefined => {
    return EMPLOYEES.find(emp => emp.name.toLowerCase() === name.toLowerCase());
};
