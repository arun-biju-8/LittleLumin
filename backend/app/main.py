import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from app.routes.ai_routes import router as ai_router
from app.routes.case_routes import router as case_router
from app.services.firebase_auth_service import init_firebase_admin, is_firebase_initialized
import google.generativeai as genai

# ✅ Load .env FIRST
load_dotenv()

# Initialize Firebase Admin safely at startup
init_firebase_admin()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Safe startup initialization of Firebase Admin SDK
    init_firebase_admin()
    yield

# ✅ Create app SECOND
app = FastAPI(
    title="LittleLumin AI API",
    description="FastAPI Backend for LittleLumin OpenAI Activity & Story Generation",
    version="1.0.0",
    lifespan=lifespan,
)

# ✅ Add CORS THIRD
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ Include routers FOURTH
app.include_router(ai_router)
app.include_router(case_router)

# ✅ Define routes LAST (after app is created)
@app.get("/")
async def root():
    return {
        "status": "online",
        "service": "LittleLumin AI Service",
        "version": "1.0.0"
    }

@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "firebase_auth": "initialized" if is_firebase_initialized() else "uninitialized"
    }

@app.get("/debug/models")
async def list_models():
    """List available Gemini models"""
    try:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            return {"error": "GEMINI_API_KEY not set"}
        
        genai.configure(api_key=api_key)
        models = []
        for model in genai.list_models():
            models.append({
                "name": model.name,
                "supported_methods": model.supported_generation_methods
            })
        return {"models": models}
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    uvicorn.run("main:app", host=host, port=port)