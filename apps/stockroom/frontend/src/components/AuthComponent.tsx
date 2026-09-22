import { useState, useEffect, useRef, useCallback } from 'react';
import { LoginRequest, RegisterRequest } from '../types/api';
import { loginUser, registerUser, googleLogin, getOrganizations } from '../services/api';
import { useAuth } from '../contexts/AuthContext';
import { toast } from 'react-toastify';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ChevronDown, ChevronUp, Building2, Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import {
    COMPANIES,
    COMPANY_ORG_IDS,
    TEAM_GROUPS,
    TEAMS,
    searchEmployees,
    type CompanyInfo,
} from '@/lib/employee-directory';

declare global {
    interface Window {
        google?: {
            accounts: {
                id: {
                    initialize: (config: {
                        client_id: string;
                        callback: (response: { credential: string }) => void;
                    }) => void;
                    renderButton: (
                        element: HTMLElement,
                        config: { theme?: string; size?: string; width?: number; text?: string; shape?: string }
                    ) => void;
                };
            };
        };
    }
}

const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID || '';

// 조직 이름 → ID 매핑을 위한 캐시
interface OrgIdMap {
    [name: string]: number;
}

const AuthComponent = () => {
    const { login } = useAuth();
    const [isLogin, setIsLogin] = useState(true);
    const [showLegacyLogin, setShowLegacyLogin] = useState(false);
    const [loading, setLoading] = useState(false);
    const googleButtonRef = useRef<HTMLDivElement>(null);

    // 회원가입용 state
    const [selectedCompany, setSelectedCompany] = useState<CompanyInfo | null>(null);
    const [selectedTeam, setSelectedTeam] = useState<string>('');
    const [orgIdMap, setOrgIdMap] = useState<OrgIdMap>({});
    const [nameSuggestions, setNameSuggestions] = useState<string[]>([]);
    const [showSuggestions, setShowSuggestions] = useState(false);

    const [loginData, setLoginData] = useState<LoginRequest>({
        name: '',
        password: ''
    });

    const [registerData, setRegisterData] = useState<RegisterRequest>({
        name: '',
        password: '',
        organization_id: undefined,
        team_name: '',
        email: ''
    });

    const handleGoogleCallback = useCallback(async (response: { credential: string }) => {
        setLoading(true);
        try {
            const result = await googleLogin({ credential: response.credential });
            toast.success(`${result.user.english_name}님, 환영합니다!`);
            login(result);
        } catch (error: any) {
            toast.error(error.message || 'Google 로그인 실패');
        } finally {
            setLoading(false);
        }
    }, [login]);

    // 조직 목록 로드 (org name → id 매핑용)
    useEffect(() => {
        if (!isLogin) {
            loadOrganizations();
        }
    }, [isLogin]);

    // Google Sign-In 버튼 렌더링
    useEffect(() => {
        if (!GOOGLE_CLIENT_ID || !googleButtonRef.current) return;

        const renderGoogleButton = () => {
            if (window.google && googleButtonRef.current) {
                window.google.accounts.id.initialize({
                    client_id: GOOGLE_CLIENT_ID,
                    callback: handleGoogleCallback,
                });
                window.google.accounts.id.renderButton(googleButtonRef.current, {
                    theme: 'outline',
                    size: 'large',
                    width: 400,
                    text: 'signin_with',
                    shape: 'pill',
                });
            }
        };

        if (window.google) {
            renderGoogleButton();
        } else {
            const interval = setInterval(() => {
                if (window.google) {
                    renderGoogleButton();
                    clearInterval(interval);
                }
            }, 100);
            return () => clearInterval(interval);
        }
    }, [isLogin, handleGoogleCallback]);

    const loadOrganizations = async () => {
        try {
            const orgs = await getOrganizations();
            const map: OrgIdMap = {};
            orgs.forEach(org => {
                map[org.name] = org.id;
            });
            setOrgIdMap(map);
        } catch (error) {
            console.error('조직 목록 로드 실패:', error);
        }
    };

    // 회사 선택 핸들러
    const handleCompanySelect = (company: CompanyInfo) => {
        setSelectedCompany(company);
        setSelectedTeam('');
        setRegisterData(prev => ({
            ...prev,
            team_name: '',
            organization_id: COMPANY_ORG_IDS[company.id]
        }));
    };

    // 팀 선택 핸들러 (Acme용)
    const handleTeamSelect = (teamName: string) => {
        setSelectedTeam(teamName);
        const teamInfo = TEAMS[teamName];
        const orgId = teamInfo?.organizationName ? orgIdMap[teamInfo.organizationName] : undefined;

        setRegisterData(prev => ({
            ...prev,
            team_name: teamName,
            organization_id: orgId
        }));
    };

    // 이름 입력 핸들러 (자동완성 포함)
    const handleNameChange = (value: string) => {
        setRegisterData(prev => ({ ...prev, name: value }));

        // Acme이고 팀이 선택된 경우에만 자동완성
        if (selectedCompany?.id === 'acme' && selectedTeam && value.length > 0) {
            const matches = searchEmployees(value, selectedTeam);
            setNameSuggestions(matches.map(e => e.name));
            setShowSuggestions(matches.length > 0);
        } else {
            setNameSuggestions([]);
            setShowSuggestions(false);
        }
    };

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!loginData.name.trim() || !loginData.password.trim()) {
            toast.error('이름과 패스워드를 입력해주세요');
            return;
        }

        if (loginData.password.length !== 4) {
            toast.error('패스워드는 4자리여야 합니다');
            return;
        }

        setLoading(true);
        try {
            const response = await loginUser(loginData);
            toast.success(`${response.user.english_name}님, 환영합니다!`);
            login(response);
        } catch (error: any) {
            toast.error(error.message || '로그인 실패');
        } finally {
            setLoading(false);
        }
    };

    const handleRegister = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!selectedCompany) {
            toast.error('회사를 선택해주세요');
            return;
        }

        if (selectedCompany.id === 'acme' && !selectedTeam) {
            toast.error('팀을 선택해주세요');
            return;
        }

        if (!registerData.name.trim() || !registerData.password.trim() || !registerData.email?.trim()) {
            toast.error('필수 항목을 모두 입력해주세요');
            return;
        }

        // 자회사는 팀명 직접 입력 필수
        if (!selectedCompany.hasTeamStructure && !registerData.team_name.trim()) {
            toast.error('팀명을 입력해주세요');
            return;
        }

        if (registerData.password.length !== 4) {
            toast.error('패스워드는 4자리여야 합니다');
            return;
        }

        setLoading(true);
        try {
            const response = await registerUser(registerData);
            toast.success(response.message);
            setIsLogin(true);
            resetRegisterForm();
        } catch (error: any) {
            toast.error(error.message || '회원가입 실패');
        } finally {
            setLoading(false);
        }
    };

    const resetRegisterForm = () => {
        setSelectedCompany(null);
        setSelectedTeam('');
        setRegisterData({
            name: '',
            password: '',
            organization_id: undefined,
            team_name: '',
            email: ''
        });
    };

    return (
        <div className="flex justify-center">
            <Card className="w-full max-w-md">
                <CardHeader className="flex flex-row items-center justify-between">
                    <CardTitle>{isLogin ? '로그인' : '회원가입'}</CardTitle>
                    <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => {
                            setIsLogin(!isLogin);
                            if (isLogin) resetRegisterForm();
                        }}
                    >
                        {isLogin ? '회원가입하기' : '로그인하기'}
                    </Button>
                </CardHeader>
                <CardContent>
                    {isLogin ? (
                        <div className="space-y-4">
                            {GOOGLE_CLIENT_ID && (
                                <div className="flex justify-center">
                                    <div ref={googleButtonRef} />
                                </div>
                            )}

                            <div className="relative">
                                <div className="absolute inset-0 flex items-center">
                                    <span className="w-full border-t" />
                                </div>
                                <div className="relative flex justify-center text-xs uppercase">
                                    <span className="bg-card px-2 text-muted-foreground">또는</span>
                                </div>
                            </div>

                            <Button
                                variant="ghost"
                                size="sm"
                                className="w-full text-muted-foreground"
                                onClick={() => setShowLegacyLogin(!showLegacyLogin)}
                            >
                                이름/패스워드로 로그인
                                {showLegacyLogin ? <ChevronUp className="h-4 w-4 ml-1" /> : <ChevronDown className="h-4 w-4 ml-1" />}
                            </Button>

                            {showLegacyLogin && (
                                <form onSubmit={handleLogin} className="space-y-4">
                                    <div className="space-y-2">
                                        <Label htmlFor="login-name">이름 (한글 또는 영어)</Label>
                                        <Input
                                            id="login-name"
                                            type="text"
                                            placeholder="예: 홍길동 또는 Rowan"
                                            value={loginData.name}
                                            onChange={(e) => setLoginData({ ...loginData, name: e.target.value })}
                                            disabled={loading}
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="login-password">패스워드 (4자리)</Label>
                                        <Input
                                            id="login-password"
                                            type="password"
                                            placeholder="4자리 숫자"
                                            maxLength={4}
                                            value={loginData.password}
                                            onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                                            disabled={loading}
                                        />
                                    </div>
                                    <Button type="submit" className="w-full" disabled={loading}>
                                        {loading ? '로그인 중...' : '로그인'}
                                    </Button>
                                </form>
                            )}
                        </div>
                    ) : (
                        <form onSubmit={handleRegister} className="space-y-5">
                            {/* Step 1: 회사 선택 */}
                            <div className="space-y-3">
                                <Label className="text-base font-medium">회사 선택 *</Label>
                                <div className="grid grid-cols-3 gap-2">
                                    {COMPANIES.map((company) => (
                                        <button
                                            key={company.id}
                                            type="button"
                                            onClick={() => handleCompanySelect(company)}
                                            disabled={loading}
                                            className={cn(
                                                "relative flex flex-col items-center gap-1 p-3 rounded-lg border-2 transition-all",
                                                "hover:border-primary/50 hover:bg-muted/50",
                                                selectedCompany?.id === company.id
                                                    ? "border-primary bg-primary/5"
                                                    : "border-muted"
                                            )}
                                        >
                                            <Building2 className={cn(
                                                "h-5 w-5",
                                                selectedCompany?.id === company.id ? "text-primary" : "text-muted-foreground"
                                            )} />
                                            <span className={cn(
                                                "text-sm font-medium",
                                                selectedCompany?.id === company.id ? "text-primary" : ""
                                            )}>
                                                {company.name}
                                            </span>
                                            {selectedCompany?.id === company.id && (
                                                <Check className="absolute top-1 right-1 h-4 w-4 text-primary" />
                                            )}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Step 2: 팀 선택 (Acme) 또는 팀명 입력 (자회사) */}
                            {selectedCompany && (
                                <div className="space-y-3">
                                    {selectedCompany.hasTeamStructure ? (
                                        <>
                                            <Label className="text-base font-medium">팀 선택 *</Label>
                                            <div className="space-y-3">
                                                {TEAM_GROUPS.map((group) => (
                                                    <div key={group.label}>
                                                        <span className="text-xs text-muted-foreground font-medium">
                                                            {group.label}
                                                        </span>
                                                        <div className="flex flex-wrap gap-1.5 mt-1">
                                                            {group.teams.map((team) => (
                                                                <button
                                                                    key={team}
                                                                    type="button"
                                                                    onClick={() => handleTeamSelect(team)}
                                                                    disabled={loading}
                                                                    className={cn(
                                                                        "px-2.5 py-1 text-sm rounded-full border transition-all",
                                                                        selectedTeam === team
                                                                            ? "border-primary bg-primary text-primary-foreground"
                                                                            : "border-muted hover:border-primary/50 hover:bg-muted/50"
                                                                    )}
                                                                >
                                                                    {team}
                                                                </button>
                                                            ))}
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        </>
                                    ) : (
                                        <>
                                            <Label htmlFor="reg-team">팀명 *</Label>
                                            <Input
                                                id="reg-team"
                                                type="text"
                                                placeholder={`${selectedCompany.name} 팀명 입력`}
                                                value={registerData.team_name}
                                                onChange={(e) => setRegisterData({ ...registerData, team_name: e.target.value })}
                                                disabled={loading}
                                            />
                                        </>
                                    )}
                                </div>
                            )}

                            {/* Step 3: 공통 필드 (회사+팀 선택 후 표시) */}
                            {((selectedCompany?.hasTeamStructure && selectedTeam) ||
                              (selectedCompany && !selectedCompany.hasTeamStructure)) && (
                                <>
                                    <div className="space-y-2 relative">
                                        <Label htmlFor="reg-english">이름 *</Label>
                                        <Input
                                            id="reg-english"
                                            type="text"
                                            placeholder="예: 홍길동 또는 Rowan"
                                            value={registerData.name}
                                            onChange={(e) => handleNameChange(e.target.value)}
                                            onBlur={() => setTimeout(() => setShowSuggestions(false), 150)}
                                            onFocus={() => {
                                                if (nameSuggestions.length > 0) setShowSuggestions(true);
                                            }}
                                            disabled={loading}
                                            autoComplete="off"
                                        />
                                        {/* 자동완성 드롭다운 */}
                                        {showSuggestions && nameSuggestions.length > 0 && (
                                            <div className="absolute z-10 w-full mt-1 bg-background border rounded-md shadow-lg max-h-40 overflow-auto">
                                                {nameSuggestions.map((name) => (
                                                    <button
                                                        key={name}
                                                        type="button"
                                                        className="w-full px-3 py-2 text-left hover:bg-muted transition-colors"
                                                        onClick={() => {
                                                            setRegisterData(prev => ({ ...prev, english_name: name }));
                                                            setShowSuggestions(false);
                                                        }}
                                                    >
                                                        {name}
                                                    </button>
                                                ))}
                                            </div>
                                        )}
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="reg-password">패스워드 (4자리) *</Label>
                                        <Input
                                            id="reg-password"
                                            type="password"
                                            placeholder="4자리 숫자"
                                            maxLength={4}
                                            value={registerData.password}
                                            onChange={(e) => setRegisterData({ ...registerData, password: e.target.value })}
                                            disabled={loading}
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="reg-email">이메일 *</Label>
                                        <Input
                                            id="reg-email"
                                            type="email"
                                            placeholder="example@acme-corp.example"
                                            value={registerData.email}
                                            onChange={(e) => setRegisterData({ ...registerData, email: e.target.value })}
                                            disabled={loading}
                                            required
                                        />
                                    </div>
                                    <Button type="submit" className="w-full" disabled={loading}>
                                        {loading ? '회원가입 중...' : '회원가입'}
                                    </Button>
                                </>
                            )}
                        </form>
                    )}
                </CardContent>
            </Card>
        </div>
    );
};

export default AuthComponent;
