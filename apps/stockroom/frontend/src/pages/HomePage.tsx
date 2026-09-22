import AuthComponent from '../components/AuthComponent';
import ProfileCompletionForm from '../components/ProfileCompletionForm';
import ItemList from '../components/ItemList';
import { useAuth } from '../contexts/AuthContext';
import { Loader2, Info } from 'lucide-react';

const HomePage = () => {
    const { user, loading, needsProfileCompletion } = useAuth();

    if (loading) {
        return (
            <div className="flex items-center justify-center py-24">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
            </div>
        );
    }

    return (
        <div>
            <div className="mb-10 text-center">
                <h1 className="text-4xl font-bold tracking-tight">창고지기</h1>
            </div>

            {!user ? (
                <AuthComponent />
            ) : needsProfileCompletion ? (
                <ProfileCompletionForm />
            ) : (
                <>
                    <div className="flex items-start gap-3 rounded-lg border border-blue-200 bg-blue-50 px-5 py-4 mb-8 text-base text-blue-800">
                        <Info className="h-5 w-5 mt-0.5 shrink-0" />
                        <p>품목별 개인당 최대 10개 수령 가능, 최대 수량을 초과하는 경우에는 비고란에 사유를 작성 바랍니다.</p>
                    </div>
                    <ItemList user={user} />
                </>
            )}
        </div>
    );
};

export default HomePage;
