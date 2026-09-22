import { useState, useEffect, useRef } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Organization, Request as RequestType } from '../types/api';
import { getOrganizations, updateProfile, getMyRequests } from '../services/api';
import { toast } from 'react-toastify';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { LogOut, User, Settings, ClipboardList, Search, Check } from 'lucide-react';
import {
    TEAM_GROUPS,
    TEAMS,
    EMPLOYEES,
    searchEmployees,
    findEmployee,
} from '@/lib/employee-directory';

const ProfileDropdown = () => {
    const { user, isAdmin, logout, refreshUser } = useAuth();
    const [profileOpen, setProfileOpen] = useState(false);
    const [historyOpen, setHistoryOpen] = useState(false);

    // 프로필 수정 상태
    const [organizations, setOrganizations] = useState<Organization[]>([]);
    const [selectedTeam, setSelectedTeam] = useState('');
    const [nameInput, setNameInput] = useState('');
    const [showNameSuggestions, setShowNameSuggestions] = useState(false);
    const [saving, setSaving] = useState(false);
    const nameSuggestionsRef = useRef<HTMLDivElement>(null);
    const nameInputRef = useRef<HTMLInputElement>(null);

    // 내 신청 내역
    const [myRequests, setMyRequests] = useState<RequestType[]>([]);
    const [loadingRequests, setLoadingRequests] = useState(false);
    const [historySearch, setHistorySearch] = useState('');
    const [historyFilter, setHistoryFilter] = useState<string>('all');

    useEffect(() => {
        if (profileOpen && user) {
            setNameInput(user.english_name || '');
            setSelectedTeam(user.team_name || '');
            setShowNameSuggestions(false);
            getOrganizations().then(setOrganizations).catch(() => {});
        }
    }, [profileOpen, user]);

    // 외부 클릭 시 자동완성 닫기
    useEffect(() => {
        const handleClickOutside = (e: MouseEvent) => {
            if (
                nameSuggestionsRef.current &&
                !nameSuggestionsRef.current.contains(e.target as Node) &&
                nameInputRef.current &&
                !nameInputRef.current.contains(e.target as Node)
            ) {
                setShowNameSuggestions(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    useEffect(() => {
        if (historyOpen) {
            setLoadingRequests(true);
            getMyRequests()
                .then((data) => setMyRequests(data || []))
                .catch(() => toast.error('신청 내역을 불러오지 못했습니다'))
                .finally(() => setLoadingRequests(false));
        }
    }, [historyOpen]);

    if (!user) return null;

    const displayName = user.english_name || '?';

    const handleLogout = () => {
        logout();
        window.location.href = '/';
    };

    // 팀 → organization_id 매핑
    const getOrgId = (teamName: string): number | undefined => {
        const teamInfo = TEAMS[teamName];
        if (!teamInfo?.organizationName) return undefined;
        const org = organizations.find(o => o.name === teamInfo.organizationName);
        return org?.id;
    };

    const getOrgName = (teamName: string): string | undefined => {
        return TEAMS[teamName]?.organizationName;
    };

    // 팀 미선택 시에도 전체 표시
    const nameSuggestions = searchEmployees(nameInput, selectedTeam || undefined);

    const handleSelectTeam = (team: string) => {
        if (selectedTeam === team) {
            setSelectedTeam('');
        } else {
            setSelectedTeam(team);
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
        setShowNameSuggestions(false);
    };

    const handleProfileSave = async () => {
        if (!nameInput.trim() || !selectedTeam) {
            toast.error('이름과 팀을 선택해주세요');
            return;
        }
        setSaving(true);
        try {
            await updateProfile({
                english_name: nameInput.trim(),
                team_name: selectedTeam,
                organization_id: getOrgId(selectedTeam),
            });
            await refreshUser();
            toast.success('프로필이 수정되었습니다');
            setProfileOpen(false);
        } catch (err: any) {
            toast.error(err.message || '프로필 수정 실패');
        } finally {
            setSaving(false);
        }
    };

    const formatDate = (dateStr: string) => {
        const d = new Date(dateStr);
        return `${d.getMonth() + 1}/${d.getDate()} ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
    };

    return (
        <>
            <DropdownMenu>
                <DropdownMenuTrigger className="inline-flex items-center justify-center h-10 px-4 rounded-full bg-primary/10 text-primary hover:bg-primary/20 outline-none focus-visible:ring-2 focus-visible:ring-ring cursor-pointer">
                    <span className="text-sm font-semibold whitespace-nowrap">{displayName}</span>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                    <DropdownMenuLabel className="font-normal">
                        <div className="flex flex-col gap-1">
                            <div className="flex items-center gap-2">
                                <User className="h-3.5 w-3.5 text-muted-foreground" />
                                <span className="font-medium">{user.english_name || '?'}</span>
                            </div>
                            {user.email && (
                                <p className="text-xs text-muted-foreground">{user.email}</p>
                            )}
                            <div className="flex items-center gap-1.5 mt-0.5">
                                {user.team_name && (
                                    <span className="text-xs text-muted-foreground">{user.team_name}</span>
                                )}
                                {user.organization_name && (
                                    <span className="text-xs text-muted-foreground">· {user.organization_name}</span>
                                )}
                            </div>
                            {isAdmin && (
                                <Badge variant="default" className="w-fit mt-0.5 text-[10px] px-1.5 py-0">관리자</Badge>
                            )}
                        </div>
                    </DropdownMenuLabel>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={() => setProfileOpen(true)}>
                        <Settings className="h-4 w-4 mr-2" />
                        프로필 수정
                    </DropdownMenuItem>
                    <DropdownMenuItem onClick={() => setHistoryOpen(true)}>
                        <ClipboardList className="h-4 w-4 mr-2" />
                        내 신청 내역
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={handleLogout} className="text-destructive focus:text-destructive">
                        <LogOut className="h-4 w-4 mr-2" />
                        로그아웃
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>

            {/* 프로필 수정 다이얼로그 */}
            <Dialog open={profileOpen} onOpenChange={setProfileOpen}>
                <DialogContent className="sm:max-w-lg py-8">
                    <DialogHeader>
                        <DialogTitle>프로필 수정</DialogTitle>
                    </DialogHeader>

                    {/* 팀 선택 (스크롤 영역) */}
                    <div className="space-y-2 pt-2">
                        <Label>팀 선택</Label>
                        <div className="max-h-52 overflow-y-auto space-y-2.5 rounded-md border p-3">
                            {TEAM_GROUPS.map(group => (
                                <div key={group.label}>
                                    <p className="text-[11px] font-medium text-muted-foreground mb-1 ml-0.5">
                                        {group.label}
                                    </p>
                                    <div className="flex flex-wrap gap-1.5">
                                        {group.teams.map(team => {
                                            const isActive = selectedTeam === team;
                                            return (
                                                <button
                                                    key={team}
                                                    type="button"
                                                    onClick={() => handleSelectTeam(team)}
                                                    disabled={saving}
                                                    className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium transition-colors border ${
                                                        isActive
                                                            ? 'bg-foreground text-background border-foreground'
                                                            : 'bg-background text-muted-foreground border-border hover:bg-accent'
                                                    }`}
                                                >
                                                    {isActive && <Check className="h-3 w-3" />}
                                                    {team}
                                                </button>
                                            );
                                        })}
                                    </div>
                                </div>
                            ))}
                        </div>
                        {selectedTeam && getOrgName(selectedTeam) && (
                            <div className="flex items-center gap-1.5">
                                <span className="text-xs text-muted-foreground">소속:</span>
                                <Badge variant="secondary" className="text-xs">
                                    {getOrgName(selectedTeam)}
                                </Badge>
                            </div>
                        )}
                    </div>

                    {/* 이름 입력 (자동완성) */}
                    <div className="space-y-2 pt-2">
                        <Label>이름 (영어)</Label>
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                            <Input
                                ref={nameInputRef}
                                placeholder="첫 글자를 입력하세요"
                                value={nameInput}
                                onChange={(e) => {
                                    setNameInput(e.target.value);
                                    setShowNameSuggestions(e.target.value.length > 0);
                                }}
                                onFocus={() => setShowNameSuggestions(true)}
                                disabled={saving}
                                autoComplete="off"
                                className="pl-9"
                            />
                            {showNameSuggestions && nameSuggestions.length > 0 && (
                                <div
                                    ref={nameSuggestionsRef}
                                    className="absolute z-10 top-full mt-1 w-full rounded-md border bg-popover shadow-md max-h-40 overflow-y-auto"
                                >
                                    {nameSuggestions.map(emp => (
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
                    </div>

                    <Button
                        onClick={handleProfileSave}
                        disabled={saving || !nameInput.trim() || !selectedTeam}
                        className="w-full mt-2"
                    >
                        {saving ? '저장 중...' : '저장'}
                    </Button>
                </DialogContent>
            </Dialog>

            {/* 내 신청 내역 다이얼로그 */}
            <Dialog open={historyOpen} onOpenChange={(open) => {
                setHistoryOpen(open);
                if (!open) { setHistorySearch(''); setHistoryFilter('all'); }
            }}>
                <DialogContent className="sm:max-w-lg max-h-[70vh] flex flex-col">
                    <DialogHeader>
                        <DialogTitle>내 신청 내역</DialogTitle>
                    </DialogHeader>
                    <div className="flex items-center gap-2">
                        <div className="relative flex-1">
                            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground" />
                            <Input
                                placeholder="물품명 검색"
                                value={historySearch}
                                onChange={(e) => setHistorySearch(e.target.value)}
                                className="pl-8 h-8 text-sm"
                            />
                        </div>
                        <Select value={historyFilter} onValueChange={setHistoryFilter}>
                            <SelectTrigger className="w-24 h-8 text-xs">
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectItem value="all">전체</SelectItem>
                                <SelectItem value="pending">대기</SelectItem>
                                <SelectItem value="completed">완료</SelectItem>
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="overflow-y-auto flex-1 -mx-1 px-1">
                        {loadingRequests ? (
                            <p className="text-sm text-muted-foreground text-center py-8">불러오는 중...</p>
                        ) : (() => {
                            const filtered = myRequests
                                .filter(r => historyFilter === 'all' || r.status === historyFilter)
                                .filter(r => !historySearch || r.item_name?.toLowerCase().includes(historySearch.toLowerCase()));
                            return filtered.length === 0 ? (
                                <p className="text-sm text-muted-foreground text-center py-8">
                                    {myRequests.length === 0 ? '신청 내역이 없습니다' : '검색 결과가 없습니다'}
                                </p>
                            ) : (
                                <div className="space-y-2">
                                    {filtered.map(req => (
                                        <div key={req.id} className="flex items-center justify-between p-3 rounded-lg border text-sm">
                                            <div className="flex-1 min-w-0">
                                                <span className="font-medium">{req.item_name}</span>
                                                <span className="text-muted-foreground ml-2">x{req.quantity}</span>
                                            </div>
                                            <div className="flex items-center gap-2 shrink-0">
                                                <Badge variant={req.status === 'completed' ? 'default' : 'secondary'} className="text-[10px]">
                                                    {req.status === 'completed' ? '완료' : req.status === 'pending' ? '대기' : req.status}
                                                </Badge>
                                                <span className="text-xs text-muted-foreground">{formatDate(req.requested_at)}</span>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            );
                        })()}
                    </div>
                </DialogContent>
            </Dialog>
        </>
    );
};

export default ProfileDropdown;
