import React, { createContext, useContext, useReducer, ReactNode } from 'react';
import { Item } from '../types/api';

export interface CartItem {
    item: Item;
    quantity: number;
}

interface CartState {
    items: CartItem[];
    totalItems: number;
    isOpen: boolean;
}

type CartAction =
    | { type: 'ADD_ITEM'; payload: { item: Item; quantity: number } }
    | { type: 'REMOVE_ITEM'; payload: number }
    | { type: 'UPDATE_QUANTITY'; payload: { itemId: number; quantity: number } }
    | { type: 'CLEAR_CART' }
    | { type: 'TOGGLE_CART' }
    | { type: 'SET_CART_OPEN'; payload: boolean };

const initialState: CartState = {
    items: [],
    totalItems: 0,
    isOpen: false,
};

function cartReducer(state: CartState, action: CartAction): CartState {
    switch (action.type) {
        case 'ADD_ITEM': {
            const { item, quantity } = action.payload;
            const existingItemIndex = state.items.findIndex(cartItem => cartItem.item.id === item.id);

            let newItems: CartItem[];
            if (existingItemIndex >= 0) {
                // 이미 장바구니에 있는 아이템 수량 업데이트
                newItems = state.items.map((cartItem, index) =>
                    index === existingItemIndex
                        ? { ...cartItem, quantity: cartItem.quantity + quantity }
                        : cartItem
                );
            } else {
                // 새 아이템 추가
                newItems = [...state.items, { item, quantity }];
            }

            const totalItems = newItems.reduce((sum, cartItem) => sum + cartItem.quantity, 0);
            return { ...state, items: newItems, totalItems, isOpen: true };
        }

        case 'REMOVE_ITEM': {
            const newItems = state.items.filter(cartItem => cartItem.item.id !== action.payload);
            const totalItems = newItems.reduce((sum, cartItem) => sum + cartItem.quantity, 0);
            return { ...state, items: newItems, totalItems };
        }

        case 'UPDATE_QUANTITY': {
            const { itemId, quantity } = action.payload;
            if (quantity <= 0) {
                return cartReducer(state, { type: 'REMOVE_ITEM', payload: itemId });
            }

            const newItems = state.items.map(cartItem =>
                cartItem.item.id === itemId
                    ? { ...cartItem, quantity }
                    : cartItem
            );
            const totalItems = newItems.reduce((sum, cartItem) => sum + cartItem.quantity, 0);
            return { ...state, items: newItems, totalItems };
        }

        case 'CLEAR_CART':
            return { ...state, items: [], totalItems: 0 };

        case 'TOGGLE_CART':
            return { ...state, isOpen: !state.isOpen };

        case 'SET_CART_OPEN':
            return { ...state, isOpen: action.payload };

        default:
            return state;
    }
}

interface CartContextType {
    state: CartState;
    addItem: (item: Item, quantity: number) => void;
    removeItem: (itemId: number) => void;
    updateQuantity: (itemId: number, quantity: number) => void;
    clearCart: () => void;
    toggleCart: () => void;
    setCartOpen: (open: boolean) => void;
    getCartItem: (itemId: number) => CartItem | undefined;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

export const useCart = () => {
    const context = useContext(CartContext);
    if (context === undefined) {
        throw new Error('useCart must be used within a CartProvider');
    }
    return context;
};

interface CartProviderProps {
    children: ReactNode;
}

export const CartProvider: React.FC<CartProviderProps> = ({ children }) => {
    const [state, dispatch] = useReducer(cartReducer, initialState);

    const addItem = (item: Item, quantity: number) => {
        dispatch({ type: 'ADD_ITEM', payload: { item, quantity } });
    };

    const removeItem = (itemId: number) => {
        dispatch({ type: 'REMOVE_ITEM', payload: itemId });
    };

    const updateQuantity = (itemId: number, quantity: number) => {
        dispatch({ type: 'UPDATE_QUANTITY', payload: { itemId, quantity } });
    };

    const clearCart = () => {
        dispatch({ type: 'CLEAR_CART' });
    };

    const toggleCart = () => {
        dispatch({ type: 'TOGGLE_CART' });
    };

    const setCartOpen = (open: boolean) => {
        dispatch({ type: 'SET_CART_OPEN', payload: open });
    };

    const getCartItem = (itemId: number) => {
        return state.items.find(cartItem => cartItem.item.id === itemId);
    };

    const value: CartContextType = {
        state,
        addItem,
        removeItem,
        updateQuantity,
        clearCart,
        toggleCart,
        setCartOpen,
        getCartItem,
    };

    return (
        <CartContext.Provider value={value}>
            {children}
        </CartContext.Provider>
    );
};