# backend/app/main.py
import logging
from contextlib import asynccontextmanager
from typing import Dict, Any
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
try:
    import google.generativeai as genai
except ImportError:
    genai = None

from app.core.config import settings
from app.core.firebase import initialize_firebase_admin
from app.core.security import get_current_admin
from app.routes.ai_routes import router as ai_router
from app.routes.audit_routes import router as audit_router
from app.routes.user_routes import router as user_router

# Configure centralized logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("littlelumin.api")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup sequence: Initialize Firebase Admin SDK
    logger.info("Initializing LittleLumin Backend API (Environment: %s)", settings.ENVIRONMENT)
    initialize_firebase_admin()
    yield
    # Graceful shutdown
    logger.info("LittleLumin Backend API shutdown completed")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="FastAPI Backend for LittleLumin: AI Activity Generation & Administrative Microservices",
    version=settings.VERSION,
    lifespan=lifespan,
)

# Explicit CORS configuration derived from settings
cors_origins = settings.cors_origins
logger.info("Configured CORS Allowed Origins: %s", cors_origins)

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(ai_router)
app.include_router(audit_router)
app.include_router(user_router)

@app.get("/")
async def root() -> Dict[str, Any]:
    return {
        "status": "online",
        "service": "LittleLumin AI Service",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
    }

@app.get("/health")
async def health() -> Dict[str, str]:
    return {
        "status": "healthy",
        "version": settings.VERSION,
    }

@app.get("/api/admin/verify")
async def verify_admin_session(
    admin: Dict[str, Any] = Depends(get_current_admin)
) -> Dict[str, Any]:
    """
    Session verification endpoint for authorized administrators.
    Requires a valid Firebase ID token with custom claims ('admin: true' or 'role: admin')
    or membership record in the 'adminUsers' Firestore collection.
    """
    return {
        "status": "authorized",
        "uid": admin.get("uid") or admin.get("user_id"),
        "email": admin.get("email"),
        "role": "admin",
    }

@app.get("/debug/models")
async def list_models(
    admin: Dict[str, Any] = Depends(get_current_admin)
) -> Dict[str, Any]:
    """
    List available Gemini models.
    Restricted strictly to authorized administrators and toggled via ENABLE_DEBUG_ENDPOINTS.
    Never exposes API keys or internal stack traces.
    """
    if not settings.ENABLE_DEBUG_ENDPOINTS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Debug diagnostic endpoints are disabled in this environment."
        )

    if genai is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Generative AI library is not available in this environment."
        )

    try:
        api_key = settings.GEMINI_API_KEY
        if not api_key:
            return {"error": "GEMINI_API_KEY not configured"}

        genai.configure(api_key=api_key)
        models = []
        for model in genai.list_models():
            models.append({
                "name": model.name,
                "supported_methods": model.supported_generation_methods
            })
        return {"models": models}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error inspecting Gemini models: %s", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve AI model information."
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=not settings.is_production)