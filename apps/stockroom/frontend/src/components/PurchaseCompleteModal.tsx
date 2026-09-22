import React from 'react';
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { PartyPopper, MapPin } from 'lucide-react';

interface PurchaseCompleteModalProps {
    isOpen: boolean;
    itemCount: number;
    onConfirm: () => void;
}

const PurchaseCompleteModal: React.FC<PurchaseCompleteModalProps> = ({
    isOpen,
    itemCount,
    onConfirm,
}) => {
    return (
        <Dialog open={isOpen}>
            <DialogContent
                className="sm:max-w-xl"
                showCloseButton={false}
                onInteractOutside={(e) => e.preventDefault()}
                onEscapeKeyDown={(e) => e.preventDefault()}
            >
                <DialogHeader className="items-center text-center">
                    <div className="mx-auto mb-3 flex h-16 w-16 items-center justify-center rounded-full bg-green-100">
                        <PartyPopper className="h-8 w-8 text-green-600" />
                    </div>
                    <DialogTitle className="text-xl">신청 완료!</DialogTitle>
                    <DialogDescription className="text-center">
                        <strong>{itemCount}종 물품</strong>이 성공적으로 신청되었습니다.
                    </DialogDescription>
                </DialogHeader>

                <div className="rounded-lg border border-amber-200 bg-amber-50 overflow-hidden text-amber-800">
                    <img
                        src="/cabinet.jpg"
                        alt="2층 프론트 검은색 캐비넷"
                        className="w-full"
                    />
                    <div className="flex items-center gap-2 px-4 py-3">
                        <MapPin className="h-4 w-4 shrink-0" />
                        <p className="font-medium text-sm">2층 프론트 검은색 캐비넷에서 수령해 주세요.</p>
                    </div>
                </div>

                <DialogFooter className="sm:flex-col pt-2">
                    <Button className="w-full" onClick={onConfirm}>
                        확인
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    );
};

export default PurchaseCompleteModal;
