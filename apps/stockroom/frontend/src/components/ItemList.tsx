import React, { useState, useEffect, useMemo } from 'react';
import { Item, Category, User } from '../types/api';
import { getItems, getCategories } from '../services/api';
import { useCart } from '../contexts/CartContext';
import { toast } from 'react-toastify';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ShoppingCart, Loader2, LayoutGrid, Package, Search, Minus, Plus, Check } from 'lucide-react';
import { CATEGORY_STYLES, DEFAULT_STYLE, CATEGORY_FALLBACK, getItemIcon } from '@/lib/item-styles';

interface ItemListProps {
    user: User | null;
}

const ItemList: React.FC<ItemListProps> = ({ user }) => {
    const [items, setItems] = useState<Item[]>([]);
    const [categories, setCategories] = useState<Category[]>([]);
    const [loading, setLoading] = useState(false);
    const [selectedCategory, setSelectedCategory] = useState<string>('all');
    const [quantities, setQuantities] = useState<{ [itemId: number]: number }>({});
    const [searchQuery, setSearchQuery] = useState('');

    const { addItem, getCartItem } = useCart();

    useEffect(() => {
        loadData();
    }, []);

    const loadData = async () => {
        setLoading(true);
        try {
            const [itemsData, categoriesData] = await Promise.all([
                getItems(),
                getCategories()
            ]);
            setItems(itemsData);
            setCategories(categoriesData);
        } catch (error) {
            toast.error('데이터를 불러오는 중 오류가 발생했습니다');
        } finally {
            setLoading(false);
        }
    };

    const filteredItems = useMemo(() => {
        let result = items;
        if (selectedCategory !== 'all') {
            result = result.filter(item => item.category_id === Number(selectedCategory));
        }
        if (searchQuery.trim()) {
            const q = searchQuery.trim().toLowerCase();
            result = result.filter(item =>
                item.name.toLowerCase().includes(q) ||
                (item.description || '').toLowerCase().includes(q)
            );
        }
        return result;
    }, [items, selectedCategory, searchQuery]);

    const handleQuantityChange = (itemId: number, delta: number) => {
        setQuantities(prev => {
            const current = prev[itemId] || 1;
            const next = Math.max(1, Math.min(10, current + delta));
            return { ...prev, [itemId]: next };
        });
    };

    const handleAddToCart = (item: Item) => {
        if (!user) {
            toast.error('사용자 정보를 먼저 입력해주세요');
            return;
        }

        const quantity = quantities[item.id] || 1;

        if (quantity > 10) {
            toast.error('개인당 최대 10개까지 신청 가능합니다');
            return;
        }

        addItem(item, quantity);
        toast.success(`${item.name} ${quantity}개를 장바구니에 추가했습니다`);

        const newQuantities = { ...quantities };
        delete newQuantities[item.id];
        setQuantities(newQuantities);
    };

    if (loading) {
        return (
            <div className="flex items-center justify-center py-12">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
                <span className="ml-2 text-muted-foreground">로딩 중...</span>
            </div>
        );
    }

    return (
        <div>
            {/* 검색 + 카테고리 필터 (sticky) */}
            <div className="sticky top-0 z-10 bg-background pb-4 mb-4">
                <h2 className="text-3xl font-bold tracking-tight mb-4">물품 목록</h2>

                {/* 검색 */}
                <div className="relative mb-3">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                        placeholder="물품 검색..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="pl-9 h-10"
                    />
                </div>

                {/* 카테고리 필터 */}
                <div className="flex flex-wrap gap-2">
                    <button
                        onClick={() => setSelectedCategory('all')}
                        className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full text-sm font-medium transition-colors border ${
                            selectedCategory === 'all'
                                ? 'bg-foreground text-background border-foreground'
                                : 'bg-background text-muted-foreground border-border hover:bg-accent'
                        }`}
                    >
                        <LayoutGrid className="h-3.5 w-3.5" />
                        전체
                        <span className={`text-xs ml-0.5 ${selectedCategory === 'all' ? 'text-background/70' : 'text-muted-foreground/60'}`}>
                            {items.length}
                        </span>
                    </button>
                    {categories.map(category => {
                        const style = CATEGORY_STYLES[category.name] || DEFAULT_STYLE;
                        const CatIcon = CATEGORY_FALLBACK[category.name] || Package;
                        const count = items.filter(i => i.category_id === category.id).length;
                        const isActive = selectedCategory === category.id.toString();
                        return (
                            <button
                                key={category.id}
                                onClick={() => setSelectedCategory(category.id.toString())}
                                className={`inline-flex items-center gap-1.5 px-3.5 py-2 rounded-full text-sm font-medium transition-colors border ${
                                    isActive
                                        ? `${style.badge} border-transparent`
                                        : 'bg-background text-muted-foreground border-border hover:bg-accent'
                                }`}
                            >
                                <CatIcon className={`h-3.5 w-3.5 ${isActive ? '' : style.icon}`} />
                                {category.name}
                                <span className={`text-xs ml-0.5 ${isActive ? 'opacity-70' : 'text-muted-foreground/60'}`}>
                                    {count}
                                </span>
                            </button>
                        );
                    })}
                </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
                {filteredItems.map((item) => {
                    const style = CATEGORY_STYLES[item.category_name || ''] || DEFAULT_STYLE;
                    const Icon = getItemIcon(item.name, item.category_name);
                    const cartItem = getCartItem(item.id);
                    const inCart = !!cartItem;
                    const qty = quantities[item.id] || 1;
                    return (
                        <Card
                            key={item.id}
                            className={`overflow-hidden flex flex-col transition-all hover:shadow-md ${
                                inCart ? 'ring-2 ring-primary/40' : ''
                            }`}
                        >
                            <div className={`relative flex items-center gap-4 px-5 py-5 ${style.bg} border-b`}>
                                {/* 장바구니 담긴 표시 */}
                                {inCart && (
                                    <div className="absolute top-2.5 right-2.5 flex items-center justify-center h-6 w-6 rounded-full bg-primary text-primary-foreground shadow-sm">
                                        <Check className="h-3.5 w-3.5" strokeWidth={3} />
                                    </div>
                                )}
                                <div className={`flex items-center justify-center h-14 w-14 rounded-xl bg-white/70 shadow-sm ${style.icon}`}>
                                    <Icon className="h-7 w-7" strokeWidth={1.8} />
                                </div>
                                <div className="flex-1 min-w-0">
                                    <h3 className="font-bold text-base leading-snug">{item.name}</h3>
                                    {item.category_name && (
                                        <span className={`inline-block text-xs font-medium px-2 py-0.5 rounded mt-1.5 ${style.badge}`}>
                                            {item.category_name}
                                        </span>
                                    )}
                                </div>
                            </div>

                            <CardContent className="pt-4 pb-4 px-5 flex flex-col flex-1">
                                {item.description && (
                                    <p className="text-sm text-muted-foreground mb-4 line-clamp-2 leading-relaxed">{item.description}</p>
                                )}

                                {user && (
                                    <div className="flex items-center gap-2 mt-auto">
                                        {/* +/- 스테퍼 */}
                                        <div className="inline-flex items-center border rounded-md">
                                            <Button
                                                variant="ghost"
                                                size="icon"
                                                className="h-10 w-9 rounded-r-none"
                                                onClick={() => handleQuantityChange(item.id, -1)}
                                                disabled={qty <= 1}
                                            >
                                                <Minus className="h-3.5 w-3.5" />
                                            </Button>
                                            <span className="w-8 text-center text-sm font-bold tabular-nums select-none">
                                                {qty}
                                            </span>
                                            <Button
                                                variant="ghost"
                                                size="icon"
                                                className="h-10 w-9 rounded-l-none"
                                                onClick={() => handleQuantityChange(item.id, 1)}
                                                disabled={qty >= 10}
                                            >
                                                <Plus className="h-3.5 w-3.5" />
                                            </Button>
                                        </div>
                                        <Button
                                            className="flex-1 h-10 text-sm"
                                            variant={inCart ? 'secondary' : 'default'}
                                            onClick={() => handleAddToCart(item)}
                                        >
                                            <ShoppingCart className="h-4.5 w-4.5 mr-1.5" />
                                            {inCart ? `담김 (${cartItem.quantity})` : '담기'}
                                        </Button>
                                    </div>
                                )}
                            </CardContent>
                        </Card>
                    );
                })}
            </div>

            {filteredItems.length === 0 && (
                <div className="text-center py-12 text-muted-foreground">
                    {searchQuery.trim() ? `"${searchQuery}" 검색 결과가 없습니다` : '물품이 없습니다'}
                </div>
            )}
        </div>
    );
};

export default ItemList;
