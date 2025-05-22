import { createContext, useContext, useEffect, type ReactNode, useReducer } from 'react';
import { useNavigate } from 'react-router-dom';

interface AuthState {
  isAuthenticated: boolean;
  tokens: {
    idToken: string | null;
    accessToken: string | null;
    refreshToken: string | null;
  };
  authCode: string | null;
}

type AuthAction =
  | { type: 'SET_TOKENS'; payload: { idToken: string; accessToken: string; refreshToken: string } }
  | { type: 'SET_AUTH_CODE'; payload: string | null }
  | { type: 'SET_IS_AUTHENTICATED'; payload: boolean }
  | { type: 'CLEAR_AUTH' };

const initialState: AuthState = {
  isAuthenticated: false,
  tokens: {
    idToken: null,
    accessToken: null,
    refreshToken: null
  },
  authCode: null
};

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case 'SET_TOKENS':
      return { ...state, tokens: action.payload };
    case 'SET_AUTH_CODE':
      return { ...state, authCode: action.payload };
    case 'CLEAR_AUTH':
      return {
        ...state,
        // user: null,
        isAuthenticated: false,
        tokens: {
          idToken: null,
          accessToken: null,
          refreshToken: null
        },
        authCode: null
      };
    case 'SET_IS_AUTHENTICATED':
      return { ...state, isAuthenticated: action.payload };
    default:
      return state;
  }
}

interface AuthContextType {
  state: AuthState;
  login: () => void;
  logout: () => void;
  handleAuthCallback: (code: string) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, initialState);
  const navigate = useNavigate();

  // Effect to handle token exchange when auth code changes
  useEffect(() => {
    const exchangeToken = async () => {
      if (!state.authCode) return;

      const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID;
      const cognitoDomain = import.meta.env.VITE_COGNITO_DOMAIN;
      const redirectUri = `${window.location.origin}/auth/callback`;

      const body = new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: clientId,
        code: state.authCode,
        redirect_uri: redirectUri,
      });

      try {
        console.log('Exchanging code for token with params:', {
          grant_type: 'authorization_code',
          client_id: clientId,
          code: state.authCode,
          redirect_uri: redirectUri,
        });

        const response = await fetch(`https://${cognitoDomain}/oauth2/token`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body.toString(),
        });

        if (!response.ok) {
          const errorData = await response.json();
          console.error('Token exchange failed:', {
            status: response.status,
            statusText: response.statusText,
            error: errorData
          });
          throw new Error(`Token exchange failed: ${errorData.error_description || errorData.error}`);
        }

        const data = await response.json();
        dispatch({
          type: 'SET_TOKENS',
          payload: {
            idToken: data.id_token,
            accessToken: data.access_token,
            refreshToken: data.refresh_token
          }
        });
        console.log('Tokens set:', data);
        dispatch({ type: 'SET_IS_AUTHENTICATED', payload: true });

        navigate('/app');
      } catch (error) {
        console.error('Token exchange failed:', error);
        throw error;
      }
    };

    exchangeToken();
  }, [state.authCode]);

  const login = () => {
    const cognitoDomain = import.meta.env.VITE_COGNITO_DOMAIN;
    const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID;
    const redirectUri = `${window.location.origin}/auth/callback`;
    
    const loginUrl = `https://${cognitoDomain}/login?client_id=${clientId}&response_type=code&scope=email+openid+profile&redirect_uri=${encodeURIComponent(redirectUri)}`;
    window.location.href = loginUrl;
  };

  const handleAuthCallback = (code: string) => {
    dispatch({ type: 'SET_AUTH_CODE', payload: code });
  };

  const logout = () => {
    if (state.isAuthenticated) {
      dispatch({ type: 'CLEAR_AUTH' });
    }
  };

  const value = {
    state,
    login,
    logout,
    handleAuthCallback,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
} 