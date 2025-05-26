from fastapi import FastAPI, status
from fastapi.responses import JSONResponse
from typing import Dict, Any
import time

app = FastAPI()

# Track startup time for uptime calculation
STARTUP_TIME = time.time()

def get_uptime() -> float:
    """Calculate uptime in seconds"""
    return time.time() - STARTUP_TIME

@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.get("/health")
async def health_check() -> JSONResponse:
    """
    Health check endpoint that returns the status of the API and its dependencies.
    Returns 200 if healthy, 503 if unhealthy.
    """
    health_status: Dict[str, Any] = {
        "status": "healthy",
        "uptime_seconds": get_uptime(),
        "version": "1.0.0",  # TODO: Get this from environment or config
        "checks": {
            "api": {
                "status": "healthy",
                "latency_ms": 0  # We could add actual latency measurement here
            }
        }
    }

    # Check if any critical checks failed
    is_healthy = all(check["status"] == "healthy" 
                    for check in health_status["checks"].values())

    return JSONResponse(
        content=health_status,
        status_code=status.HTTP_200_OK if is_healthy else status.HTTP_503_SERVICE_UNAVAILABLE
    )

@app.get("/asdf")
async def asdf():
    return {"message": "asdf"}