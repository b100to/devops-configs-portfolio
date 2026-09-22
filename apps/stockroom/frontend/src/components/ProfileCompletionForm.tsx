import { useState, useEffect, useRef } from 'react';
import { Organization } from '../types/api';
import { updateProfile, getOrganizations, getMe } from '../services/api';
import { useAuth } from '../contexts/AuthContext';
import { toast } from 'react-toastify';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Check, Search, Building2 } from 'lucide-react';
import { cn } from '@/lib/utils';
import {
    COMPANIES,
    COMPANY_ORG_IDS,
    TEAM_GROUPS,
    TEAMS,
    EMPLOYEES,
    searchEmployees,
    findEmployee,
    type CompanyInfo,
} from '@/lib/employee-directory';

// 조직 이름 → ID 매핑을 위한 캐시
interface OrgIdMap {
    [name: string]: number;
}

const ProfileCompletionForm = () => {
    const { user, completeProfile, login } = useAuth();
    const [loading, setLoading] = useState(false);
    const [orgIdMap, setOrgIdMap] = useState<OrgIdMap>({});

    // 회사/팀/이름 선택 state
    const [selectedCompany, setSelectedCompany] = useState<CompanyInfo | null>(null);
    const [selectedTeam, setSelectedTeam] = useState('');
    const [teamNameInput, setTeamNameInput] = useState(''); // 자회사용 팀명 직접 입력
    const [nameInput, setNameInput] = useState('');
    const [showSuggestions, setShowSuggestions] = useState(false);
    const suggestionsRef = useRef<HTMLDivElement>(null);
    const inputRef = useRef<HTMLInputElement>(null);

    useEffect(() => {
        getOrganizations()
            .then(orgs => {
                const map: OrgIdMap = {};
                orgs.forEach(org => {
                    map[org.name] = org.id;
                });
                setOrgIdMap(map);
            })
            .catch(() => {});
    }, []);

    // 외부 클릭 시 자동완성 닫기
    useEffect(() => {
        const handleClickOutside = (e: MouseEvent) => {
            if (
                suggestionsRef.current &&
                !suggestionsRef.current.contains(e.target as Node) &&
                inputRef.current &&
                !inputRef.current.contains(e.target as Node)
            ) {
                setShowSuggestions(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    // 팀 → organization_id 매핑
    const getOrgId = (teamName: string): number | undefined => {
        const teamInfo = TEAMS[teamName];
        if (!teamInfo?.organizationName) return undefined;
        return orgIdMap[teamInfo.organizationName];
    };

    // 조직(실) 이름 가져오기
    const getOrgName = (teamName: string): string | undefined => {
        return TEAMS[teamName]?.organizationName;
    };

    // 자동완성 후보 (Acme만)
    const suggestions = selectedCompany?.id === 'acme'
        ? searchEmployees(nameInput, selectedTeam || undefined)
        : [];

    // 회사 선택 핸들러
    const handleCompanySelect = (company: CompanyInfo) => {
        setSelectedCompany(company);
        setSelectedTeam('');
        setTeamNameInput('');
        setNameInput('');
    };

    const handleSelectTeam = (team: string) => {
        if (selectedTeam === team) {
            setSelectedTeam('');
        } else {
            setSelectedTeam(team);
            // 이미 입력된 이름이 새 팀에 속하는지 확인
            if (nameInput) {
                const emp = findEmployee(nameInput);
                if (emp && emp.team !== team) {
                    setNameInput('');
                }
            }
        }
    };

    const handleSelectEmployee = (name: string, team: string) => {
        setNameInput(name);
        if (!selectedTeam) {
            setSelectedTeam(team);
        }
        setShowSuggestions(false);
    };

    const handleNameChange = (value: string) => {
        setNameInput(value);
        if (selectedCompany?.id === 'acme') {
            setShowSuggestions(value.length > 0);
        }
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!selectedCompany) {
            toast.error('회사를 선택해주세요');
            return;
        }

        if (!nameInput.trim()) {
            toast.error('이름을 입력해주세요');
            return;
        }

        // Acme: 팀 토글 선택 필수
        if (selectedCompany.hasTeamStructure && !selectedTeam) {
            toast.error('팀을 선택해주세요');
            return;
        }

        // 자회사: 팀명 직접 입력 필수
        if (!selectedCompany.hasTeamStructure && !teamNameInput.trim()) {
            toast.error('팀명을 입력해주세요');
            return;
        }

        const finalTeamName = selectedCompany.hasTeamStructure ? selectedTeam : teamNameInput.trim();
        const finalOrgId = selectedCompany.hasTeamStructure
            ? getOrgId(selectedTeam)
            : COMPANY_ORG_IDS[selectedCompany.id];

        setLoading(true);
        try {
            await updateProfile({
                english_name: nameInput.trim(),
                team_name: finalTeamName,
                organization_id: finalOrgId,
            });
            const updated = await getMe();
            login(updated);
            completeProfile();
            toast.success('프로필이 저장되었습니다');
        } catch (error: any) {
            toast.error(error.message || '프로필 저장 실패');
        } finally {
            setLoading(false);
        }
    };

    // 폼 완성 여부 체크
    const isFormComplete = selectedCompany && nameInput.trim() && (
        (selectedCompany.hasTeamStructure && selectedTeam) ||
        (!selectedCompany.hasTeamStructure && teamNameInput.trim())
    );

    return (
        <div className="flex justify-center">
            <Card className="w-full max-w-lg">
                <CardHeader>
                    <CardTitle>프로필 보완</CardTitle>
                    <CardDescription>
                        원활한 서비스 이용을 위해 소속 회사와 팀, 이름을 확인해주세요.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <form onSubmit={handleSubmit} className="space-y-6">
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
                                            {TEAM_GROUPS.map(group => (
                                                <div key={group.label}>
                                                    <p className="text-[11px] font-medium text-muted-foreground mb-1.5 ml-0.5">
                                                        {group.label}
                                                    </p>
                                                    <div className="flex flex-wrap gap-1.5">
                                                        {group.teams.map(team => {
                                                            const isActive = selectedTeam === team;
                                                            const memberCount = EMPLOYEES.filter(e => e.team === team).length;
                                                            return (
                                                                <button
                                                                    key={team}
                                                                    type="button"
                                                                    onClick={() => handleSelectTeam(team)}
                                                                    disabled={loading}
                                                                    className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-medium transition-colors border ${
                                                                        isActive
                                                                            ? 'bg-foreground text-background border-foreground'
                                                                            : 'bg-background text-muted-foreground border-border hover:bg-accent'
                                                                    }`}
                                                                >
                                                                    {isActive && <Check className="h-3 w-3" />}
                                                                    {team}
                                                                    <span className={`${isActive ? 'text-background/60' : 'text-muted-foreground/50'}`}>
                                                                        {memberCount}
                                                                    </span>
                                                                </button>
                                                            );
                                                        })}
                                                    </div>
                                                </div>
                                            ))}
                                        </div>
                                        {selectedTeam && getOrgName(selectedTeam) && (
                                            <div className="flex items-center gap-1.5 mt-1">
                                                <span className="text-xs text-muted-foreground">소속 조직:</span>
                                                <Badge variant="secondary" className="text-xs">
                                                    {getOrgName(selectedTeam)}
                                                </Badge>
                                            </div>
                                        )}
                                    </>
                                ) : (
                                    <>
                                        <Label htmlFor="team-name">팀명 *</Label>
                                        <Input
                                            id="team-name"
                                            type="text"
                                            placeholder={`${selectedCompany.name} 팀명 입력`}
                                            value={teamNameInput}
                                            onChange={(e) => setTeamNameInput(e.target.value)}
                                            disabled={loading}
                                        />
                                    </>
                                )}
                            </div>
                        )}

                        {/* Step 3: 이름 입력 (Acme: 자동완성, 자회사: 직접 입력) */}
                        {((selectedCompany?.hasTeamStructure && selectedTeam) ||
                          (selectedCompany && !selectedCompany.hasTeamStructure)) && (
                            <div className="space-y-2">
                                <Label htmlFor="profile-name">이름 *</Label>
                                <div className="relative">
                                    {selectedCompany?.hasTeamStructure && (
                                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                                    )}
                                    <Input
                                        ref={inputRef}
                                        id="profile-name"
                                        placeholder={selectedCompany?.hasTeamStructure ? "첫 글자를 입력하세요" : "예: 홍길동 또는 Rowan"}
                                        value={nameInput}
                                        onChange={(e) => handleNameChange(e.target.value)}
                                        onFocus={() => {
                                            if (selectedCompany?.hasTeamStructure) setShowSuggestions(true);
                                        }}
                                        disabled={loading}
                                        autoComplete="off"
                                        className={selectedCompany?.hasTeamStructure ? "pl-9" : ""}
                                        required
                                    />
                                    {/* 자동완성 드롭다운 (Acme만) */}
                                    {showSuggestions && suggestions.length > 0 && (
                                        <div
                                            ref={suggestionsRef}
                                            className="absolute z-10 top-full mt-1 w-full rounded-md border bg-popover shadow-md max-h-48 overflow-y-auto"
                                        >
                                            {suggestions.map(emp => (
                                                <button
                                                    key={`${emp.name}-${emp.team}`}
                                                    type="button"
                                                    className="w-full px-3 py-2 text-left text-sm hover:bg-accent flex items-center justify-between"
                                                    onClick={() => handleSelectEmployee(emp.name, emp.team)}
                                                >
                                                    <span className="font-medium">{emp.name}</span>
                                                    <span className="text-xs text-muted-foreground">{emp.team}</span>
                                                </button>
                                            ))}
                                        </div>
                                    )}
                                </div>
                                {selectedCompany?.hasTeamStructure && nameInput && !findEmployee(nameInput) && (
                                    <p className="text-xs text-muted-foreground">
                                        목록에 없는 이름도 직접 입력 가능합니다.
                                    </p>
                                )}
                            </div>
                        )}

                        <Button type="submit" className="w-full" disabled={loading || !isFormComplete}>
                            {loading ? '저장 중...' : '저장'}
                        </Button>
                    </form>
                </CardContent>
            </Card>
        </div>
    );
};

export default ProfileCompletionForm;
