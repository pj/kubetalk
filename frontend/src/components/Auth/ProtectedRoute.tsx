import { useAuth } from '../../contexts/AuthContext';

interface ProtectedRouteProps {
  children: React.ReactNode;
}

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const { 
    state, 
    login 
  } = useAuth();
  console.log('ProtectedRoute', state);
  if (!state.isAuthenticated) {
    console.log('Not authenticated, redirecting to login');
    login();
    return <div>Redirecting to login...</div>;
  }

  return <>{children}</>;
} 