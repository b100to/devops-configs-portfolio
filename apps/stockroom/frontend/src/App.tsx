import { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, Navigate } from 'react-router-dom';
import { ToastContainer } from 'react-toastify';
import { CartProvider } from './contexts/CartContext';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import HomePage from './pages/HomePage';
import AdminPage from './pages/AdminPage';
import CartIcon from './components/CartIcon';
import CartDropdown from './components/CartDropdown';
import ProfileDropdown from './components/ProfileDropdown';
import { Loader2 } from 'lucide-react';
import 'react-toastify/dist/ReactToastify.css';

const AppContent = () => {
    const { user, isAdmin, loading } = useAuth();
    const [refreshKey, setRefreshKey] = useState(0);

    const handleDataRefresh = () => {
        setRefreshKey(prev => prev + 1);
    };

    return (
        <Router>
            <div className="min-h-screen bg-background">
                <nav className="sticky top-0 z-50 bg-card/80 backdrop-blur-lg shadow-sm shadow-black/5">
                    <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
                        <div className="flex items-center gap-6">
                            <Link to="/" className="text-base font-semibold transition-colors hover:text-primary">
                                홈
                            </Link>
                            {isAdmin && (
                                <Link to="/admin" className="text-base font-medium text-muted-foreground transition-colors hover:text-primary">
                                    관리자
                                </Link>
                            )}
                        </div>
                        <div className="flex items-center gap-3">
                            <CartIcon />
                            <ProfileDropdown />
                        </div>
                    </div>
                </nav>

                <main className="mx-auto max-w-7xl px-6 py-10">
                    <Routes>
                        <Route path="/" element={<HomePage key={refreshKey} />} />
                        <Route path="/admin" element={
                            loading
                                ? <div className="flex items-center justify-center py-20"><Loader2 className="h-8 w-8 animate-spin text-muted-foreground" /></div>
                                : isAdmin ? <AdminPage /> : <Navigate to="/" replace />
                        } />
                    </Routes>
                </main>

                <CartDropdown user={user} onCheckoutComplete={handleDataRefresh} />

                <ToastContainer
                    position="top-right"
                    autoClose={3000}
                    hideProgressBar={false}
                    newestOnTop={false}
                    closeOnClick
                    rtl={false}
                    pauseOnFocusLoss
                    draggable
                    pauseOnHover
                />
            </div>
        </Router>
    );
};

const App = () => {
    return (
        <AuthProvider>
            <CartProvider>
                <AppContent />
            </CartProvider>
        </AuthProvider>
    );
};

export default App;
