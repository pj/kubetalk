import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ProtectedRoute } from './components/Auth/ProtectedRoute';
import './App.css';
import { AuthCallback } from './pages/AuthCallback';
import { AuthProvider } from './contexts/AuthContext';
import Login from './pages/Login';

function App() {
  return (
    <Router>
      <AuthProvider>
        <Routes>
          <Route path="/auth/callback" element={<AuthCallback />} />
          <Route
            path="/"
            element={
              <Login />
            }
          />
          <Route
            path="/app"
            element={
              <ProtectedRoute>
                <div className="min-h-screen bg-gray-50">
                  <header className="bg-white shadow">
                    <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
                      <h1 className="text-3xl font-bold text-gray-900">Query KubeTalk</h1>
                    </div>
                  </header>
                  <main>
                    <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
                      I am protected
                    </div>
                  </main>
                </div>
              </ProtectedRoute>
            }
          />
        </Routes>
      </AuthProvider>
    </Router>
  );
}

export default App;
