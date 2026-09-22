import { useState, useEffect } from 'react';
import { Item, Category, Request, CreateItemData, UpdateItemData, UserWithAdmin, Organization, OrganizationType, UpdateUserByAdminData, CreateOrganizationRequest, UpdateOrganizationRequest } from '../types/api';
import { getItems, getCategories, getRequests, createItem, updateItem, deleteItem, deleteRequest, getUsers, addAdmin, removeAdmin, updateUserByAdmin, deactivateUser, getOrganizations, createOrganization, updateOrganization, deleteOrganization } from '../services/api';
import { toast } from 'react-toastify';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Textarea } from '@/components/ui/textarea';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogFooter,
} from '@/components/ui/dialog';
import { Plus, Pencil, Trash2, ImageOff, Loader2, ShieldCheck, ShieldOff, UserX, Search, X, CalendarDays, Building2 } from 'lucide-react';

const formatRelativeDate = (dateStr: string) => {
    const now = new Date();
    const date = new Date(dateStr);
    const diffMs = now.getTime() - date.getTime();
    const diffMin = Math.floor(diffMs / 60000);
    const diffHour = Math.floor(diffMs / 3600000);
    const diffDay = Math.floor(diffMs / 86400000);

    if (diffMin < 1) return '방금 전';
    if (diffMin < 60) return `${diffMin}분 전`;
    if (diffHour < 24) return `${diffHour}시간 전`;
    if (diffDay === 1) return '어제';
    return `${diffDay}일 전`;
};

const AdminPage = () => {
    const [items, setItems] = useState<Item[]>([]);
    const [categories, setCategories] = useState<Category[]>([]);
    const [requests, setRequests] = useState<Request[]>([]);
    const [users, setUsers] = useState<UserWithAdmin[]>([]);
    const [organizations, setOrganizations] = useState<Organization[]>([]);
    const [loading, setLoading] = useState(false);
    const [activeTab, setActiveTab] = useState('items');

    const [showAddForm, setShowAddForm] = useState(false);
    const [newItem, setNewItem] = useState<CreateItemData>({
        name: '',
        description: '',
        category_id: undefined,
        image_url: ''
    });
    const [newItemImageFile, setNewItemImageFile] = useState<File | null>(null);
    const [newItemImagePreview, setNewItemImagePreview] = useState<string>('');

    const [editingItem, setEditingItem] = useState<Item | null>(null);
    const [editForm, setEditForm] = useState<UpdateItemData>({
        name: '',
        description: '',
        category_id: undefined,
        image_url: ''
    });
    const [editItemImageFile, setEditItemImageFile] = useState<File | null>(null);
    const [editItemImagePreview, setEditItemImagePreview] = useState<string>('');
    const [isImageRemoved, setIsImageRemoved] = useState<boolean>(false);

    // 신청 내역 필터 상태
    const [requestSearch, setRequestSearch] = useState('');
    const [requestStatusFilter, setRequestStatusFilter] = useState<string>('all');
    const [requestDateFrom, setRequestDateFrom] = useState('');
    const [requestDateTo, setRequestDateTo] = useState('');

    // 사용자 수정 관련 상태
    const [editingUser, setEditingUser] = useState<UserWithAdmin | null>(null);
    const [editUserForm, setEditUserForm] = useState<UpdateUserByAdminData>({});

    // 조직 관리 상태
    const [showAddOrgForm, setShowAddOrgForm] = useState(false);
    const [newOrg, setNewOrg] = useState<CreateOrganizationRequest>({ name: '', type: 'organization', description: '' });
    const [editingOrg, setEditingOrg] = useState<Organization | null>(null);
    const [editOrgForm, setEditOrgForm] = useState<UpdateOrganizationRequest>({});

    useEffect(() => {
        loadData();
    }, [activeTab]);

    const loadData = async () => {
        setLoading(true);
        try {
            const [itemsData, categoriesData, orgsData] = await Promise.all([
                getItems(),
                getCategories(),
                getOrganizations(),
            ]);
            setItems(itemsData);
            setCategories(categoriesData);
            setOrganizations(orgsData || []);

            if (activeTab === 'requests') {
                const requestsData = await getRequests();
                setRequests(requestsData);
            }
            if (activeTab === 'accounts') {
                const usersData = await getUsers();
                setUsers(usersData);
            }
            if (activeTab === 'organizations') {
                const orgsData = await getOrganizations();
                setOrganizations(orgsData);
            }
        } catch (error) {
            console.error('loadData error:', error);
            toast.error('데이터를 불러오는 중 오류가 발생했습니다');
        } finally {
            setLoading(false);
        }
    };

    const handleCreateItem = async (e: React.FormEvent) => {
        e.preventDefault();
        try {
            let itemData = { ...newItem };
            if (newItemImageFile) {
                const base64 = await fileToBase64(newItemImageFile);
                itemData.image_url = base64;
            }

            await createItem(itemData);
            toast.success('물품이 추가되었습니다');
            setShowAddForm(false);
            setNewItem({
                name: '',
                description: '',
                category_id: undefined,
                image_url: ''
            });
            setNewItemImageFile(null);
            setNewItemImagePreview('');
            loadData();
        } catch (error) {
            toast.error('물품 추가 중 오류가 발생했습니다');
        }
    };

    const handleUpdateItem = async (id: number, updates: UpdateItemData) => {
        try {
            await updateItem(id, updates);
            toast.success('물품이 수정되었습니다');
            setEditingItem(null);
            setEditItemImageFile(null);
            setEditItemImagePreview('');
            setIsImageRemoved(false);
            loadData();
        } catch (error) {
            toast.error('물품 수정 중 오류가 발생했습니다');
        }
    };

    const handleEditSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (editingItem) {
            let updateData = { ...editForm };

            if (isImageRemoved) {
                updateData.image_url = '';
            } else if (editItemImageFile) {
                try {
                    const base64 = await fileToBase64(editItemImageFile);
                    updateData.image_url = base64;
                } catch (error) {
                    toast.error('이미지 처리 중 오류가 발생했습니다');
                    return;
                }
            }

            await handleUpdateItem(editingItem.id, updateData);
        }
    };

    const fileToBase64 = (file: File): Promise<string> => {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => resolve(reader.result as string);
            reader.onerror = error => reject(error);
        });
    };

    const handleNewItemImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            setNewItemImageFile(file);
            const reader = new FileReader();
            reader.onload = () => {
                setNewItemImagePreview(reader.result as string);
            };
            reader.readAsDataURL(file);
        } else {
            setNewItemImageFile(null);
            setNewItemImagePreview('');
        }
    };

    const handleEditItemImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            setEditItemImageFile(file);
            setIsImageRemoved(false);
            const reader = new FileReader();
            reader.onload = () => {
                setEditItemImagePreview(reader.result as string);
            };
            reader.readAsDataURL(file);
        } else {
            setEditItemImageFile(null);
            setEditItemImagePreview('');
        }
    };

    const handleRemoveImage = () => {
        setEditItemImageFile(null);
        setEditItemImagePreview('');
        setIsImageRemoved(true);
    };

    const openEditForm = (item: Item) => {
        setEditingItem(item);
        setEditForm({
            name: item.name,
            description: item.description || '',
            category_id: item.category_id,
            image_url: item.image_url || ''
        });
        setEditItemImagePreview(item.image_url || '');
        setEditItemImageFile(null);
        setIsImageRemoved(false);
    };

    const handleDeleteItem = async (id: number) => {
        if (window.confirm('정말로 이 물품을 삭제하시겠습니까?')) {
            try {
                await deleteItem(id);
                toast.success('물품이 삭제되었습니다');
                loadData();
            } catch (error) {
                toast.error('물품 삭제 중 오류가 발생했습니다');
            }
        }
    };

    const handleDeleteRequest = async (id: number) => {
        if (window.confirm('이 신청 내역을 삭제하시겠습니까?')) {
            try {
                await deleteRequest(id);
                toast.success('신청 내역이 삭제되었습니다');
                loadData();
            } catch (error) {
                toast.error('신청 삭제 중 오류가 발생했습니다');
            }
        }
    };

    const handleToggleAdmin = async (userId: number, currentlyAdmin: boolean) => {
        try {
            if (currentlyAdmin) {
                await removeAdmin(userId);
                toast.success('관리자 권한이 제거되었습니다');
            } else {
                await addAdmin(userId);
                toast.success('관리자로 추가되었습니다');
            }
            loadData();
        } catch (error: any) {
            toast.error(error.message || '관리자 변경 실패');
        }
    };

    const openEditUserForm = (user: UserWithAdmin) => {
        setEditingUser(user);
        setEditUserForm({
            english_name: user.english_name,
            team_name: user.team_name,
        });
    };

    const handleEditUserSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!editingUser) return;
        try {
            await updateUserByAdmin(editingUser.id, editUserForm);
            toast.success('사용자 정보가 수정되었습니다');
            setEditingUser(null);
            loadData();
        } catch (error: any) {
            toast.error(error.message || '사용자 수정 실패');
        }
    };

    const handleDeactivateUser = async (userId: number, userName: string) => {
        if (!window.confirm(`${userName} 사용자를 비활성화하시겠습니까? 이 작업은 되돌릴 수 없습니다.`)) return;
        try {
            await deactivateUser(userId);
            toast.success('사용자가 비활성화되었습니다');
            loadData();
        } catch (error: any) {
            toast.error(error.message || '사용자 비활성화 실패');
        }
    };

    const handleCreateOrganization = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!newOrg.name.trim()) {
            toast.error('조직명을 입력해주세요');
            return;
        }
        try {
            await createOrganization(newOrg);
            toast.success('추가되었습니다');
            setShowAddOrgForm(false);
            setNewOrg({ name: '', type: 'organization', description: '' });
            loadData();
        } catch (error: any) {
            toast.error(error.message || '조직 추가 실패');
        }
    };

    const openEditOrgForm = (org: Organization) => {
        setEditingOrg(org);
        setEditOrgForm({
            name: org.name,
            description: org.description || '',
        });
    };

    const handleEditOrgSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!editingOrg) return;
        try {
            await updateOrganization(editingOrg.id, editOrgForm);
            toast.success('수정되었습니다');
            setEditingOrg(null);
            loadData();
        } catch (error: any) {
            toast.error(error.message || '조직 수정 실패');
        }
    };

    const handleDeleteOrganization = async (id: number, name: string) => {
        if (!window.confirm(`"${name}"을(를) 삭제하시겠습니까?`)) return;
        try {
            await deleteOrganization(id);
            toast.success('삭제되었습니다');
            loadData();
        } catch (error: any) {
            toast.error(error.message || '조직 삭제 실패');
        }
    };

    const statusMap: Record<string, { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' }> = {
        pending: { label: '대기', variant: 'secondary' },
        approved: { label: '승인', variant: 'default' },
        rejected: { label: '거절', variant: 'destructive' },
        completed: { label: '완료', variant: 'outline' },
        delivered: { label: '수령완료', variant: 'outline' },
    };

    const filteredRequests = (requests || []).filter(r => {
        const matchesSearch = requestSearch === '' ||
            (r.user_name || '').toLowerCase().includes(requestSearch.toLowerCase()) ||
            (r.user_english_name || '').toLowerCase().includes(requestSearch.toLowerCase()) ||
            (r.item_name || '').toLowerCase().includes(requestSearch.toLowerCase());
        const matchesStatus = requestStatusFilter === 'all' || r.status === requestStatusFilter;
        const requestDate = r.requested_at.slice(0, 10);
        const matchesDateFrom = !requestDateFrom || requestDate >= requestDateFrom;
        const matchesDateTo = !requestDateTo || requestDate <= requestDateTo;
        return matchesSearch && matchesStatus && matchesDateFrom && matchesDateTo;
    });

    const statusCounts = (requests || []).reduce<Record<string, number>>((acc, r) => {
        acc[r.status] = (acc[r.status] || 0) + 1;
        return acc;
    }, {});

    const renderOrgList = (type: OrganizationType) => {
        const filtered = organizations.filter(o => o.type === type);
        if (filtered.length === 0) {
            return <p className="text-sm text-muted-foreground">등록된 항목이 없습니다.</p>;
        }
        return (
            <div className="flex flex-wrap gap-2">
                {filtered.map(org => (
                    <Badge key={org.id} variant={type === 'company' ? 'secondary' : 'outline'} className="text-sm py-1.5 px-3 gap-1.5">
                        {type === 'company' && <Building2 className="h-3.5 w-3.5" />}
                        {org.name}
                        <button onClick={() => openEditOrgForm(org)} className="ml-1 hover:text-primary">
                            <Pencil className="h-3 w-3" />
                        </button>
                        <button onClick={() => handleDeleteOrganization(org.id, org.name)} className="hover:text-destructive">
                            <X className="h-3 w-3" />
                        </button>
                    </Badge>
                ))}
            </div>
        );
    };

    return (
        <div>
            <div className="mb-6">
                <h1 className="text-3xl font-bold tracking-tight">관리자 페이지</h1>
            </div>

            <Tabs value={activeTab} onValueChange={setActiveTab}>
                <TabsList>
                    <TabsTrigger value="items">물품 관리</TabsTrigger>
                    <TabsTrigger value="requests">신청 내역</TabsTrigger>
                    <TabsTrigger value="accounts">계정 관리</TabsTrigger>
                    <TabsTrigger value="organizations">조직 관리</TabsTrigger>
                </TabsList>

                <TabsContent value="items" className="space-y-4">
                    <div className="flex items-center justify-between">
                        <h2 className="text-xl font-semibold">물품 관리</h2>
                        <Button size="sm" onClick={() => setShowAddForm(true)}>
                            <Plus className="h-4 w-4 mr-2" />
                            물품 추가
                        </Button>
                    </div>

                    {/* 물품 추가 다이얼로그 */}
                    <Dialog open={showAddForm} onOpenChange={setShowAddForm}>
                        <DialogContent className="sm:max-w-lg">
                            <DialogHeader>
                                <DialogTitle>새 물품 추가</DialogTitle>
                            </DialogHeader>
                            <form onSubmit={handleCreateItem} className="space-y-4">
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <Label>물품명 *</Label>
                                        <Input
                                            required
                                            value={newItem.name}
                                            onChange={(e) => setNewItem({ ...newItem, name: e.target.value })}
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <Label>카테고리</Label>
                                        <Select
                                            value={newItem.category_id?.toString() || ''}
                                            onValueChange={(value) => setNewItem({ ...newItem, category_id: value ? Number(value) : undefined })}
                                        >
                                            <SelectTrigger>
                                                <SelectValue placeholder="선택하세요" />
                                            </SelectTrigger>
                                            <SelectContent>
                                                {categories.map(category => (
                                                    <SelectItem key={category.id} value={category.id.toString()}>
                                                        {category.name}
                                                    </SelectItem>
                                                ))}
                                            </SelectContent>
                                        </Select>
                                    </div>
                                </div>
                                <div className="space-y-2">
                                    <Label>설명</Label>
                                    <Textarea
                                        value={newItem.description}
                                        onChange={(e) => setNewItem({ ...newItem, description: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label>이미지</Label>
                                    <Input
                                        type="file"
                                        accept="image/*"
                                        onChange={handleNewItemImageChange}
                                    />
                                    {newItemImagePreview && (
                                        <img src={newItemImagePreview} alt="미리보기" className="mt-2 h-32 rounded-md object-cover" />
                                    )}
                                </div>
                                <DialogFooter>
                                    <Button type="button" variant="outline" onClick={() => setShowAddForm(false)}>취소</Button>
                                    <Button type="submit">추가</Button>
                                </DialogFooter>
                            </form>
                        </DialogContent>
                    </Dialog>

                    {/* 물품 수정 다이얼로그 */}
                    <Dialog open={!!editingItem} onOpenChange={(open) => !open && setEditingItem(null)}>
                        <DialogContent className="sm:max-w-lg">
                            <DialogHeader>
                                <DialogTitle>물품 수정</DialogTitle>
                            </DialogHeader>
                            <form onSubmit={handleEditSubmit} className="space-y-4">
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <Label>물품명 *</Label>
                                        <Input
                                            required
                                            value={editForm.name}
                                            onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                                        />
                                    </div>
                                    <div className="space-y-2">
                                        <Label>카테고리</Label>
                                        <Select
                                            value={editForm.category_id?.toString() || ''}
                                            onValueChange={(value) => setEditForm({ ...editForm, category_id: value ? Number(value) : undefined })}
                                        >
                                            <SelectTrigger>
                                                <SelectValue placeholder="선택하세요" />
                                            </SelectTrigger>
                                            <SelectContent>
                                                {categories.map(category => (
                                                    <SelectItem key={category.id} value={category.id.toString()}>
                                                        {category.name}
                                                    </SelectItem>
                                                ))}
                                            </SelectContent>
                                        </Select>
                                    </div>
                                </div>
                                <div className="space-y-2">
                                    <Label>설명</Label>
                                    <Textarea
                                        value={editForm.description}
                                        onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label>이미지</Label>
                                    <Input
                                        type="file"
                                        accept="image/*"
                                        onChange={handleEditItemImageChange}
                                    />
                                    {editItemImagePreview && !isImageRemoved && (
                                        <div className="mt-2 relative inline-block">
                                            <img src={editItemImagePreview} alt="미리보기" className="h-32 rounded-md object-cover" />
                                            <Button
                                                type="button"
                                                variant="destructive"
                                                size="sm"
                                                className="absolute top-1 right-1"
                                                onClick={handleRemoveImage}
                                            >
                                                <ImageOff className="h-3 w-3 mr-1" />
                                                제거
                                            </Button>
                                        </div>
                                    )}
                                    {isImageRemoved && (
                                        <p className="text-sm text-muted-foreground mt-1">이미지가 제거됩니다</p>
                                    )}
                                </div>
                                <DialogFooter>
                                    <Button type="button" variant="outline" onClick={() => setEditingItem(null)}>취소</Button>
                                    <Button type="submit">수정 완료</Button>
                                </DialogFooter>
                            </form>
                        </DialogContent>
                    </Dialog>

                    {/* 물품 목록 테이블 */}
                    {loading ? (
                        <div className="flex items-center justify-center py-12">
                            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                        </div>
                    ) : (
                        <div className="rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead className="w-12">ID</TableHead>
                                        <TableHead>이름</TableHead>
                                        <TableHead>카테고리</TableHead>
                                        <TableHead>상태</TableHead>
                                        <TableHead className="text-right">작업</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {items.map(item => (
                                        <TableRow key={item.id}>
                                            <TableCell className="font-mono text-xs">{item.id}</TableCell>
                                            <TableCell className="font-medium">{item.name}</TableCell>
                                            <TableCell>{item.category_name || '-'}</TableCell>
                                            <TableCell>
                                                <Badge variant={item.is_active ? 'default' : 'secondary'}>
                                                    {item.is_active ? '활성' : '비활성'}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <div className="flex justify-end gap-1">
                                                    <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openEditForm(item)}>
                                                        <Pencil className="h-4 w-4" />
                                                    </Button>
                                                    <Button variant="ghost" size="icon" className="h-8 w-8 text-destructive" onClick={() => handleDeleteItem(item.id)}>
                                                        <Trash2 className="h-4 w-4" />
                                                    </Button>
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </div>
                    )}
                </TabsContent>

                <TabsContent value="requests" className="space-y-4">
                    <h2 className="text-xl font-semibold">신청 내역</h2>

                    {/* 검색 + 상태 필터 */}
                    <div className="space-y-3">
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                            <Input
                                placeholder="사용자명 또는 물품명으로 검색..."
                                value={requestSearch}
                                onChange={(e) => setRequestSearch(e.target.value)}
                                className="pl-9 pr-9"
                            />
                            {requestSearch && (
                                <button
                                    onClick={() => setRequestSearch('')}
                                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                                >
                                    <X className="h-4 w-4" />
                                </button>
                            )}
                        </div>
                        <div className="flex items-center gap-2">
                            <CalendarDays className="h-4 w-4 text-muted-foreground shrink-0" />
                            <Input
                                type="date"
                                value={requestDateFrom}
                                onChange={(e) => setRequestDateFrom(e.target.value)}
                                className="w-auto h-9 text-sm"
                            />
                            <span className="text-muted-foreground text-sm">~</span>
                            <Input
                                type="date"
                                value={requestDateTo}
                                onChange={(e) => setRequestDateTo(e.target.value)}
                                className="w-auto h-9 text-sm"
                            />
                            {(requestDateFrom || requestDateTo) && (
                                <button
                                    onClick={() => { setRequestDateFrom(''); setRequestDateTo(''); }}
                                    className="text-muted-foreground hover:text-foreground"
                                >
                                    <X className="h-4 w-4" />
                                </button>
                            )}
                        </div>
                        <div className="flex flex-wrap gap-2">
                            <button
                                onClick={() => setRequestStatusFilter('all')}
                                className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-colors border ${
                                    requestStatusFilter === 'all'
                                        ? 'bg-foreground text-background border-foreground'
                                        : 'bg-background text-muted-foreground border-border hover:bg-accent'
                                }`}
                            >
                                전체
                                <span className={`${requestStatusFilter === 'all' ? 'text-background/70' : 'text-muted-foreground/60'}`}>
                                    {(requests || []).length}
                                </span>
                            </button>
                            {Object.entries(statusMap).map(([key, { label }]) => {
                                const count = statusCounts[key] || 0;
                                if (count === 0) return null;
                                const isActive = requestStatusFilter === key;
                                return (
                                    <button
                                        key={key}
                                        onClick={() => setRequestStatusFilter(key)}
                                        className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium transition-colors border ${
                                            isActive
                                                ? 'bg-foreground text-background border-foreground'
                                                : 'bg-background text-muted-foreground border-border hover:bg-accent'
                                        }`}
                                    >
                                        {label}
                                        <span className={`${isActive ? 'text-background/70' : 'text-muted-foreground/60'}`}>
                                            {count}
                                        </span>
                                    </button>
                                );
                            })}
                        </div>
                    </div>

                    {loading ? (
                        <div className="flex items-center justify-center py-12">
                            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                        </div>
                    ) : (
                        <div className="rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead className="w-12">ID</TableHead>
                                        <TableHead>사용자</TableHead>
                                        <TableHead>영어이름</TableHead>
                                        <TableHead>물품</TableHead>
                                        <TableHead className="text-right">수량</TableHead>
                                        <TableHead>비고</TableHead>
                                        <TableHead>상태</TableHead>
                                        <TableHead>신청일</TableHead>
                                        <TableHead className="w-12"></TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {filteredRequests.length > 0 ? filteredRequests.map(request => (
                                        <TableRow key={request.id}>
                                            <TableCell className="font-mono text-xs">{request.id}</TableCell>
                                            <TableCell>{request.user_name}</TableCell>
                                            <TableCell className="text-sm text-muted-foreground">{request.user_english_name || '-'}</TableCell>
                                            <TableCell>{request.item_name}</TableCell>
                                            <TableCell className="text-right">{request.quantity}</TableCell>
                                            <TableCell className="text-sm text-muted-foreground max-w-[200px] truncate">{request.notes || '-'}</TableCell>
                                            <TableCell>
                                                <Badge variant={statusMap[request.status]?.variant || 'secondary'}>
                                                    {statusMap[request.status]?.label || request.status}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-sm text-muted-foreground">
                                                <div>{new Date(request.requested_at).toLocaleDateString()}</div>
                                                <div className="text-xs text-muted-foreground/70">{formatRelativeDate(request.requested_at)}</div>
                                            </TableCell>
                                            <TableCell>
                                                <Button variant="ghost" size="icon" className="h-8 w-8 text-destructive" onClick={() => handleDeleteRequest(request.id)}>
                                                    <Trash2 className="h-4 w-4" />
                                                </Button>
                                            </TableCell>
                                        </TableRow>
                                    )) : (
                                        <TableRow>
                                            <TableCell colSpan={9} className="text-center py-8 text-muted-foreground">
                                                {requestSearch || requestStatusFilter !== 'all' || requestDateFrom || requestDateTo
                                                    ? '검색 결과가 없습니다.'
                                                    : '신청 내역이 없습니다.'}
                                            </TableCell>
                                        </TableRow>
                                    )}
                                </TableBody>
                            </Table>
                        </div>
                    )}
                </TabsContent>

                <TabsContent value="accounts" className="space-y-4">
                    <h2 className="text-xl font-semibold">계정 관리</h2>

                    {/* 사용자 수정 다이얼로그 */}
                    <Dialog open={!!editingUser} onOpenChange={(open) => !open && setEditingUser(null)}>
                        <DialogContent className="sm:max-w-md">
                            <DialogHeader>
                                <DialogTitle>사용자 정보 수정</DialogTitle>
                            </DialogHeader>
                            <form onSubmit={handleEditUserSubmit} className="space-y-4">
                                <div className="space-y-2">
                                    <Label>영어 이름</Label>
                                    <Input
                                        value={editUserForm.english_name || ''}
                                        onChange={(e) => setEditUserForm({ ...editUserForm, english_name: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label>팀명</Label>
                                    <Input
                                        value={editUserForm.team_name || ''}
                                        onChange={(e) => setEditUserForm({ ...editUserForm, team_name: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label>소속 조직</Label>
                                    <Select
                                        value={editUserForm.organization_id?.toString() || ''}
                                        onValueChange={(value) => setEditUserForm({ ...editUserForm, organization_id: value ? parseInt(value) : undefined })}
                                    >
                                        <SelectTrigger>
                                            <SelectValue placeholder="선택 안함" />
                                        </SelectTrigger>
                                        <SelectContent>
                                            {organizations.map(org => (
                                                <SelectItem key={org.id} value={org.id.toString()}>
                                                    {org.name}
                                                </SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </div>
                                <DialogFooter>
                                    <Button type="button" variant="outline" onClick={() => setEditingUser(null)}>취소</Button>
                                    <Button type="submit">수정 완료</Button>
                                </DialogFooter>
                            </form>
                        </DialogContent>
                    </Dialog>

                    {loading ? (
                        <div className="flex items-center justify-center py-12">
                            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                        </div>
                    ) : (
                        <div className="rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead className="w-12">ID</TableHead>
                                        <TableHead>이름</TableHead>
                                        <TableHead>이메일</TableHead>
                                        <TableHead>팀</TableHead>
                                        <TableHead>소속</TableHead>
                                        <TableHead>권한</TableHead>
                                        <TableHead className="text-right">작업</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {users.map(user => (
                                        <TableRow key={user.id}>
                                            <TableCell className="font-mono text-xs">{user.id}</TableCell>
                                            <TableCell className="font-medium">{user.english_name}</TableCell>
                                            <TableCell className="text-sm text-muted-foreground">{user.email || '-'}</TableCell>
                                            <TableCell>{user.team_name || '-'}</TableCell>
                                            <TableCell>{user.organization_name || '-'}</TableCell>
                                            <TableCell>
                                                <Badge variant={user.is_admin ? 'default' : 'secondary'}>
                                                    {user.is_admin ? '관리자' : '일반'}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <div className="flex justify-end gap-1">
                                                    <Button variant="ghost" size="icon" className="h-8 w-8" onClick={() => openEditUserForm(user)}>
                                                        <Pencil className="h-4 w-4" />
                                                    </Button>
                                                    <Button
                                                        variant={user.is_admin ? 'destructive' : 'default'}
                                                        size="xs"
                                                        onClick={() => handleToggleAdmin(user.id, user.is_admin)}
                                                    >
                                                        {user.is_admin ? (
                                                            <><ShieldOff className="h-3 w-3 mr-1" />권한 제거</>
                                                        ) : (
                                                            <><ShieldCheck className="h-3 w-3 mr-1" />관리자 추가</>
                                                        )}
                                                    </Button>
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="h-8 w-8 text-destructive"
                                                        onClick={() => handleDeactivateUser(user.id, user.english_name)}
                                                    >
                                                        <UserX className="h-4 w-4" />
                                                    </Button>
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </div>
                    )}
                </TabsContent>

                <TabsContent value="organizations" className="space-y-4">
                    <h2 className="text-xl font-semibold">조직 관리</h2>

                    <Tabs defaultValue="company" className="w-full">
                        <TabsList className="grid w-full grid-cols-3">
                            <TabsTrigger value="company">
                                회사 ({organizations.filter(o => o.type === 'company').length})
                            </TabsTrigger>
                            <TabsTrigger value="organization">
                                조직 ({organizations.filter(o => o.type === 'organization').length})
                            </TabsTrigger>
                            <TabsTrigger value="team">
                                팀 ({organizations.filter(o => o.type === 'team').length})
                            </TabsTrigger>
                        </TabsList>

                        {/* 회사 탭 */}
                        <TabsContent value="company" className="space-y-3 mt-4">
                            <div className="flex items-center justify-between">
                                <p className="text-sm text-muted-foreground">Acme, ORBIT, 알파 등</p>
                                <Button size="sm" variant="outline" onClick={() => { setNewOrg({ name: '', type: 'company', description: '' }); setShowAddOrgForm(true); }}>
                                    <Plus className="h-4 w-4 mr-1" /> 회사 추가
                                </Button>
                            </div>
                            {renderOrgList('company')}
                        </TabsContent>

                        {/* 조직 탭 */}
                        <TabsContent value="organization" className="space-y-3 mt-4">
                            <div className="flex items-center justify-between">
                                <p className="text-sm text-muted-foreground">경영지원실, 기술실 등 (실/본부 단위)</p>
                                <Button size="sm" variant="outline" onClick={() => { setNewOrg({ name: '', type: 'organization', description: '' }); setShowAddOrgForm(true); }}>
                                    <Plus className="h-4 w-4 mr-1" /> 조직 추가
                                </Button>
                            </div>
                            {renderOrgList('organization')}
                        </TabsContent>

                        {/* 팀 탭 */}
                        <TabsContent value="team" className="space-y-3 mt-4">
                            <div className="flex items-center justify-between">
                                <p className="text-sm text-muted-foreground">백엔드팀, 마케팅팀 등 (팀 단위)</p>
                                <Button size="sm" variant="outline" onClick={() => { setNewOrg({ name: '', type: 'team', description: '' }); setShowAddOrgForm(true); }}>
                                    <Plus className="h-4 w-4 mr-1" /> 팀 추가
                                </Button>
                            </div>
                            {renderOrgList('team')}
                        </TabsContent>
                    </Tabs>

                    {/* 추가 다이얼로그 */}
                    <Dialog open={showAddOrgForm} onOpenChange={setShowAddOrgForm}>
                        <DialogContent className="sm:max-w-md">
                            <DialogHeader>
                                <DialogTitle>
                                    {newOrg.type === 'company' ? '새 회사 추가' : newOrg.type === 'organization' ? '새 조직 추가' : '새 팀 추가'}
                                </DialogTitle>
                            </DialogHeader>
                            <form onSubmit={handleCreateOrganization} className="space-y-4">
                                <div className="space-y-2">
                                    <Label>이름 *</Label>
                                    <Input
                                        required
                                        placeholder={newOrg.type === 'company' ? '예: Acme' : newOrg.type === 'organization' ? '예: 기술실' : '예: 백엔드팀'}
                                        value={newOrg.name}
                                        onChange={(e) => setNewOrg({ ...newOrg, name: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label>설명 (선택)</Label>
                                    <Input
                                        placeholder="간단한 설명"
                                        value={newOrg.description || ''}
                                        onChange={(e) => setNewOrg({ ...newOrg, description: e.target.value })}
                                    />
                                </div>
                                <DialogFooter>
                                    <Button type="button" variant="outline" onClick={() => setShowAddOrgForm(false)}>취소</Button>
                                    <Button type="submit">추가</Button>
                                </DialogFooter>
                            </form>
                        </DialogContent>
                    </Dialog>

                    {/* 조직 수정 다이얼로그 */}
                    <Dialog open={!!editingOrg} onOpenChange={(open) => !open && setEditingOrg(null)}>
                        <DialogContent className="sm:max-w-md">
                            <DialogHeader>
                                <DialogTitle>수정</DialogTitle>
                            </DialogHeader>
                            <form onSubmit={handleEditOrgSubmit} className="space-y-4">
                                <div className="space-y-2">
                                    <Label>이름 *</Label>
                                    <Input
                                        required
                                        value={editOrgForm.name || ''}
                                        onChange={(e) => setEditOrgForm({ ...editOrgForm, name: e.target.value })}
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label>설명 (선택)</Label>
                                    <Input
                                        value={editOrgForm.description || ''}
                                        onChange={(e) => setEditOrgForm({ ...editOrgForm, description: e.target.value })}
                                    />
                                </div>
                                <DialogFooter>
                                    <Button type="button" variant="outline" onClick={() => setEditingOrg(null)}>취소</Button>
                                    <Button type="submit">수정 완료</Button>
                                </DialogFooter>
                            </form>
                        </DialogContent>
                    </Dialog>
                </TabsContent>
            </Tabs>
        </div>
    );
};

export default AdminPage;
