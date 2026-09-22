import React from 'react';
import { useCart } from '../contexts/CartContext';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ShoppingCart } from 'lucide-react';

const CartIcon: React.FC = () => {
    const { state, toggleCart } = useCart();

    return (
        <Button
            variant="ghost"
            size="icon-lg"
            className="relative"
            onClick={toggleCart}
            aria-label={`장바구니 ${state.totalItems}개 아이템`}
        >
            <ShoppingCart className="h-5.5 w-5.5" />
            {state.totalItems > 0 && (
                <Badge className="absolute -top-1 -right-1 h-5 w-5 flex items-center justify-center p-0 text-xs">
                    {state.totalItems}
                </Badge>
            )}
        </Button>
    );
};

export default CartIcon;
