import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass
from app.routes.ai_routes import router as ai_router

app = FastAPI(
    title="LittleLumin AI API",
    description="FastAPI Backend for LittleLumin OpenAI Activity & Story Generation",
    version="1.0.0"
)

# CORS setup for Flutter web, mobile, and desktop clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(ai_router)

@app.get("/", tags=["Health Check"])
async def root():
    return {
        "status": "online",
        "service": "LittleLumin AI Service",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    uvicorn.run("main:app", host=host, port=port, reload=True)
