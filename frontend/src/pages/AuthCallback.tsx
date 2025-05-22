import { useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';

export function AuthCallback() {
  const { handleAuthCallback } = useAuth();

  useEffect(() => {
    const handleAuth = async () => {
      const params = new URLSearchParams(window.location.search);
      const code = params.get('code');
      if (!code) {
        return;
      }

      try {
        handleAuthCallback(code);
      } catch (err) {
        console.error('Auth callback failed:', err);
      }
    };

    handleAuth();
  }, [handleAuthCallback]);

  return null;
} 