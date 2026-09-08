import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from app.routes.ai_routes import router as ai_router
import google.generativeai as genai

# ✅ Load .env FIRST
load_dotenv()

# ✅ Create app SECOND
app = FastAPI(
    title="LittleLumin AI API",
    description="FastAPI Backend for LittleLumin OpenAI Activity & Story Generation",
    version="1.0.0"
)

# ✅ Add CORS THIRD
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ Include router FOURTH
app.include_router(ai_router)

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
    return {"status": "healthy"}

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