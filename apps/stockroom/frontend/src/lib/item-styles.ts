import {
    Pen, PenLine, Pencil, Highlighter, Eraser,
    Scissors, Ruler, StickyNote, BookOpen, FileText,
    FolderOpen, Paperclip, Pin, Battery, Mail,
    ShoppingBag, Pill, Cross, Shield, Link2,
    Package, Clipboard, Droplet, Tag, Flag,
    SprayCan, Box, Monitor,
    type LucideIcon,
} from 'lucide-react';

export const CATEGORY_STYLES: Record<string, { bg: string; icon: string; badge: string }> = {
    '필기구':   { bg: 'bg-blue-50',    icon: 'text-blue-500',    badge: 'bg-blue-100 text-blue-700' },
    '사무용품': { bg: 'bg-amber-50',   icon: 'text-amber-500',   badge: 'bg-amber-100 text-amber-700' },
    '소모품':   { bg: 'bg-emerald-50', icon: 'text-emerald-500', badge: 'bg-emerald-100 text-emerald-700' },
    '의료용품': { bg: 'bg-rose-50',    icon: 'text-rose-500',    badge: 'bg-rose-100 text-rose-700' },
};
export const DEFAULT_STYLE = { bg: 'bg-gray-50', icon: 'text-gray-500', badge: 'bg-gray-100 text-gray-700' };

const ITEM_ICONS: [RegExp, LucideIcon][] = [
    // 필기구
    [/볼펜/, Pen], [/형광펜/, Highlighter], [/샤프/, Pencil],
    [/연필/, Pencil], [/네임펜/, PenLine], [/지우개/, Eraser],
    // 사무용품
    [/가위/, Scissors], [/커터/, Scissors], [/자\(|출자/, Ruler],
    [/테이프/, Paperclip], [/클립 집게/, Paperclip], [/클립보드/, Clipboard],
    [/포스트잇/, StickyNote], [/플래그/, Flag],
    [/스테이플러/, Pin], [/노트패드|스프링노트/, BookOpen],
    [/딱풀/, Droplet], [/투명화일|종이파일|파일 속지/, FolderOpen],
    [/A4 용지/, FileText], [/메모보드/, Monitor],
    // 소모품
    [/티슈/, Box], [/건전지/, Battery], [/클립$/, Paperclip],
    [/면봉/, Pen], [/보드마카 지우개|크리너/, SprayCan], [/보드마카/, PenLine],
    [/네임택/, Tag], [/케이블 타이/, Link2], [/쇼핑백/, ShoppingBag],
    [/봉투/, Mail], [/마스크/, Shield],
    // 의료용품
    [/밴드|메디폼/, Cross], [/마데카솔|파스/, Pill],
];

export const CATEGORY_FALLBACK: Record<string, LucideIcon> = {
    '필기구': Pen, '사무용품': Scissors, '소모품': Package, '의료용품': Cross,
};

export const getItemIcon = (name: string, category?: string): LucideIcon => {
    for (const [pattern, icon] of ITEM_ICONS) {
        if (pattern.test(name)) return icon;
    }
    return (category && CATEGORY_FALLBACK[category]) || Package;
};
