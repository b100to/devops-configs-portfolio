import React, { useState } from 'react';
import { useCart } from '../contexts/CartContext';
import { createRequest } from '../services/api';
import { User } from '../types/api';
import { toast } from 'react-toastify';
import PurchaseCompleteModal from './PurchaseCompleteModal';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Textarea } from '@/components/ui/textarea';

import { Minus, Plus, Trash2, ShoppingBag, ClipboardList, MessageSquare, X } from 'lucide-react';
import { CATEGORY_STYLES, DEFAULT_STYLE, getItemIcon } from '@/lib/item-styles';

interface CartDropdownProps {
    user: User | null;
    onCheckoutComplete?: () => void;
}

const CartDropdown: React.FC<CartDropdownProps> = ({ user, onCheckoutComplete }) => {
    const { state, removeItem, updateQuantity, clearCart, setCartOpen } = useCart();
    const [showPurchaseCompleteModal, setShowPurchaseCompleteModal] = useState(false);
    const [purchasedItemCount, setPurchasedItemCount] = useState(0);
    const [notes, setNotes] = useState('');
    const [submitting, setSubmitting] = useState(false);

    const handleQuantityChange = (itemId: number, newQuantity: number) => {
        if (newQuantity <= 0) {
            removeItem(itemId);
        } else if (newQuantity <= 10) {
            updateQuantity(itemId, newQuantity);
        }
    };

    const handleCheckout = async () => {
        if (!user) {
            toast.error('사용자 정보를 먼저 입력해주세요');
            return;
        }

        if (state.items.length === 0) {
            toast.error('장바구니가 비어있습니다');
            return;
        }

        setSubmitting(true);
        try {
            for (const cartItem of state.items) {
                await createRequest({
                    user_id: user.id,
                    item_id: cartItem.item.id,
                    quantity: cartItem.quantity,
                    notes: notes.trim() || undefined,
                });
            }

            setPurchasedItemCount(state.items.length);
            setShowPurchaseCompleteModal(true);
            clearCart();
            setNotes('');
            setCartOpen(false);

            if (onCheckoutComplete) {
                onCheckoutComplete();
            }
        } catch (error) {
            toast.error('신청 처리 중 오류가 발생했습니다. 다시 시도해주세요.');
        } finally {
            setSubmitting(false);
        }
    };

    const handleConfirm = () => {
        setShowPurchaseCompleteModal(false);
    };

    return (
        <>
            {/* 비차단 고정 사이드 패널 */}
            <div
                className={`fixed inset-y-0 right-0 z-40 w-full sm:w-[400px] bg-background border-l shadow-2xl flex flex-col transition-transform duration-300 ease-in-out ${
                    state.isOpen ? 'translate-x-0' : 'translate-x-full'
                }`}
            >
                {/* 헤더 */}
                <div className="flex items-center justify-between p-4 border-b">
                    <div className="flex items-center gap-2">
                        <ShoppingBag className="h-5 w-5" />
                        <span className="font-semibold text-lg">장바구니</span>
                        {state.totalItems > 0 && (
                            <Badge variant="secondary" className="text-xs">
                                {state.items.length}종 · {state.totalItems}개
                            </Badge>
                        )}
                    </div>
                    <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8"
                        onClick={() => setCartOpen(false)}
                    >
                        <X className="h-4 w-4" />
                    </Button>
                </div>

                {/* 아이템 목록 */}
                <div className="flex-1 overflow-y-auto p-4">
                    {state.items.length === 0 ? (
                        <div className="flex flex-col items-center justify-center h-full text-muted-foreground gap-3">
                            <ShoppingBag className="h-16 w-16 opacity-15" />
                            <div className="text-center">
                                <p className="font-medium text-foreground/60">장바구니가 비어있습니다</p>
                                <p className="text-sm mt-1">물품 목록에서 필요한 물품을 담아주세요</p>
                            </div>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {state.items.map((cartItem) => {
                                const style = CATEGORY_STYLES[cartItem.item.category_name || ''] || DEFAULT_STYLE;
                                const Icon = getItemIcon(cartItem.item.name, cartItem.item.category_name);
                                return (
                                    <div key={cartItem.item.id} className={`rounded-lg border ${style.bg} p-3`}>
                                        <div className="flex items-start gap-3">
                                            <div className={`flex items-center justify-center h-10 w-10 rounded-lg bg-white/70 shadow-sm shrink-0 ${style.icon}`}>
                                                <Icon className="h-5 w-5" strokeWidth={1.8} />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-start justify-between gap-2">
                                                    <div>
                                                        <h4 className="font-semibold text-sm leading-snug">{cartItem.item.name}</h4>
                                                        {cartItem.item.category_name && (
                                                            <span className={`inline-block text-[10px] font-medium px-1.5 py-0.5 rounded mt-1 ${style.badge}`}>
                                                                {cartItem.item.category_name}
                                                            </span>
                                                        )}
                                                    </div>
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="h-7 w-7 shrink-0 text-muted-foreground hover:text-destructive"
                                                        onClick={() => removeItem(cartItem.item.id)}
                                                    >
                                                        <Trash2 className="h-3.5 w-3.5" />
                                                    </Button>
                                                </div>
                                                <div className="flex items-center gap-1.5 mt-2">
                                                    <Button
                                                        variant="outline"
                                                        size="icon"
                                                        className="h-8 w-8 bg-white/80"
                                                        onClick={() => handleQuantityChange(cartItem.item.id, cartItem.quantity - 1)}
                                                    >
                                                        <Minus className="h-3.5 w-3.5" />
                                                    </Button>
                                                    <span className="w-10 text-center text-sm font-bold tabular-nums">
                                                        {cartItem.quantity}
                                                    </span>
                                                    <Button
                                                        variant="outline"
                                                        size="icon"
                                                        className="h-8 w-8 bg-white/80"
                                                        onClick={() => handleQuantityChange(cartItem.item.id, cartItem.quantity + 1)}
                                                        disabled={cartItem.quantity >= 10}
                                                    >
                                                        <Plus className="h-3.5 w-3.5" />
                                                    </Button>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    )}
                </div>

                {/* 푸터 */}
                {state.items.length > 0 && (
                    <div className="border-t p-4 space-y-3">
                        {/* 비고 */}
                        <div className="space-y-1.5">
                            <div className="flex items-center gap-1.5">
                                <MessageSquare className="h-4 w-4 text-muted-foreground" />
                                <span className="text-sm font-medium">비고</span>
                                <span className="text-xs text-muted-foreground">(10개 초과 시 사유 필수)</span>
                            </div>
                            <Textarea
                                placeholder="전달 사항을 입력하세요"
                                value={notes}
                                onChange={(e) => setNotes(e.target.value)}
                                className="min-h-[200px] text-base resize-none"
                            />
                        </div>
                        <div className="flex justify-between items-center">
                            <span className="text-sm text-muted-foreground">총 신청</span>
                            <span className="font-bold text-base">{state.items.length}종 · {state.totalItems}개</span>
                        </div>
                        <div className="flex gap-2">
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={clearCart}
                            >
                                전체 삭제
                            </Button>
                            <Button
                                className="flex-1"
                                onClick={handleCheckout}
                                disabled={!user || submitting}
                            >
                                <ClipboardList className="h-4 w-4 mr-1.5" />
                                {submitting ? '신청 중...' : '일괄 신청하기'}
                            </Button>
                        </div>
                    </div>
                )}
            </div>

            <PurchaseCompleteModal
                isOpen={showPurchaseCompleteModal}
                itemCount={purchasedItemCount}
                onConfirm={handleConfirm}
            />
        </>
    );
};

export default CartDropdown;
