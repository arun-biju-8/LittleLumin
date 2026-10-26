# backend/app/core/config.py
import os
import logging
from typing import List
from dotenv import load_dotenv

# Ensure environment variables are loaded
load_dotenv()

logger = logging.getLogger("littlelumin.config")

class Settings:
    PROJECT_NAME: str = "LittleLumin Backend API"
    VERSION: str = "1.1.0"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development").lower().strip()
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", 8000))

    # Firebase Configuration
    FIREBASE_PROJECT_ID: str = os.getenv("FIREBASE_PROJECT_ID", "littlelumin-e7d26").strip()
    FIREBASE_SERVICE_ACCOUNT_KEY: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY", "").strip()
    FIREBASE_SERVICE_ACCOUNT_PATH: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()

    # Diagnostic & Debug
    ENABLE_DEBUG_ENDPOINTS: bool = os.getenv("ENABLE_DEBUG_ENDPOINTS", "false").lower().strip() in ("true", "1", "yes")

    # Gemini AI
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "").strip()

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT in ("production", "prod")

    @property
    def cors_origins(self) -> List[str]:
        raw = os.getenv("CORS_ORIGINS") or os.getenv("ALLOWED_ORIGINS") or ""
        origins = [o.strip() for o in raw.split(",") if o.strip()]

        if not origins:
            if self.is_production:
                origins = [
                    "https://littlelumin-e7d26.web.app",
                    "https://littlelumin-e7d26.firebaseapp.com",
                ]
            else:
                origins = [
                    "https://littlelumin-e7d26.web.app",
                    "https://littlelumin-e7d26.firebaseapp.com",
                    "http://localhost:3000",
                    "http://localhost:5000",
                    "http://127.0.0.1:8000",
                    "http://localhost:8080",
                ]

        # In production, disallow wildcard '*'
        if self.is_production and "*" in origins:
            logger.warning("⚠️ Wildcard '*' CORS origin detected in production. Removing wildcard for security.")
            origins = [o for o in origins if o != "*"]
            if not origins:
                origins = [
                    "https://littlelumin-e7d26.web.app",
                    "https://littlelumin-e7d26.firebaseapp.com",
                ]

        return origins

settings = Settings()
