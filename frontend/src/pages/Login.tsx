import { useNavigate } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";

export default function Login() {   
    const navigate = useNavigate();
    const { login, state } = useAuth();
    if (state.isAuthenticated) {
        navigate('/app');
    }
    return <div>Login
        <button onClick={() => login()}>Login</button> 
        </div>;
}