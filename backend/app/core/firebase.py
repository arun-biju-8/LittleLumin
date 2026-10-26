import os
import json
import base64
import logging
from typing import Optional, Any

# Compatibility shims for runtime google.api_core version check hooks
try:
    import google.api_core
    if not hasattr(google.api_core, "check_python_version"):
        google.api_core.check_python_version = lambda *args, **kwargs: None
    if not hasattr(google.api_core, "check_dependency_versions"):
        google.api_core.check_dependency_versions = lambda *args, **kwargs: None
except ImportError:
    pass

import firebase_admin
from firebase_admin import credentials, firestore, auth
from app.core.config import settings

logger = logging.getLogger("littlelumin.firebase")

_firebase_app: Optional[firebase_admin.App] = None
_firestore_client: Optional[Any] = None

def initialize_firebase_admin() -> Optional[firebase_admin.App]:
    """
    Securely initializes the Firebase Admin SDK using configured credentials.
    Priority order:
      1. Raw or base64 JSON string via FIREBASE_SERVICE_ACCOUNT_KEY
      2. File path via FIREBASE_SERVICE_ACCOUNT_PATH or GOOGLE_APPLICATION_CREDENTIALS
      3. Google Application Default Credentials
      4. Project ID initialization (development / emulator mode)
    """
    global _firebase_app, _firestore_client

    if _firebase_app is not None:
        return _firebase_app

    # Check if default app is already initialized in firebase_admin
    if firebase_admin._apps and firebase_admin._DEFAULT_APP_NAME in firebase_admin._apps:
        _firebase_app = firebase_admin.get_app()
        logger.info("Using pre-existing default Firebase Admin app")
        return _firebase_app

    cred: Optional[credentials.Base] = None
    init_mode: str = "unknown"

    # 1. Check raw or base64 JSON in FIREBASE_SERVICE_ACCOUNT_KEY
    if settings.FIREBASE_SERVICE_ACCOUNT_KEY:
        try:
            raw_val = settings.FIREBASE_SERVICE_ACCOUNT_KEY.strip()
            # Try base64 decode first if it doesn't look like raw json
            if not raw_val.startswith("{"):
                try:
                    decoded = base64.b64decode(raw_val).decode("utf-8")
                    key_dict = json.loads(decoded)
                except Exception:
                    key_dict = json.loads(raw_val)
            else:
                key_dict = json.loads(raw_val)

            cred = credentials.Certificate(key_dict)
            init_mode = "service_account_key_env"
            logger.info("✅ Parsed service account credentials from environment variable")
        except Exception as e:
            logger.error("❌ Failed to parse FIREBASE_SERVICE_ACCOUNT_KEY JSON: %s", type(e).__name__)

    # 2. Check file path
    if cred is None:
        path = settings.FIREBASE_SERVICE_ACCOUNT_PATH or os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
        if path and os.path.isfile(path):
            try:
                cred = credentials.Certificate(path)
                init_mode = f"service_account_file ({os.path.basename(path)})"
                logger.info("✅ Loaded service account credentials from file: %s", os.path.basename(path))
            except Exception as e:
                logger.error("❌ Failed to load service account file: %s", type(e).__name__)

    # 3. Check Application Default Credentials or Project ID fallback
    if cred is None:
        try:
            if settings.is_production or os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
                cred = credentials.ApplicationDefault()
                init_mode = "application_default_credentials"
                logger.info("Using Google Application Default Credentials")
            else:
                cred = None
                init_mode = "project_id_only"
        except Exception:
            # Fallback for development/testing when no GCP service account is provided
            logger.warning("No explicit GCP credentials provided. Initializing with Project ID: %s", settings.FIREBASE_PROJECT_ID)
            cred = None
            init_mode = "project_id_only"

    try:
        options = {"projectId": settings.FIREBASE_PROJECT_ID}
        if cred is not None:
            _firebase_app = firebase_admin.initialize_app(cred, options=options)
        else:
            _firebase_app = firebase_admin.initialize_app(options=options)

        logger.info("✅ Firebase Admin SDK successfully initialized [Mode: %s, Project: %s]", init_mode, settings.FIREBASE_PROJECT_ID)
        return _firebase_app
    except Exception as e:
        logger.error("❌ Error initializing Firebase Admin SDK: %s", str(e))
        return None

def get_firebase_app() -> Optional[firebase_admin.App]:
    global _firebase_app
    if _firebase_app is None:
        return initialize_firebase_admin()
    return _firebase_app

def get_firestore_client() -> Optional[Any]:
    global _firestore_client
    if _firestore_client is not None:
        return _firestore_client
    
    app = get_firebase_app()
    if app is None:
        return None

    try:
        _firestore_client = firestore.client(app=app)
        return _firestore_client
    except Exception as e:
        logger.warning("Firestore client unavailable: %s", type(e).__name__)
        return None

def get_auth_client():
    app = get_firebase_app()
    return auth

def reset_firebase_app_for_testing():
    """Allows test fixtures to reset the singleton state."""
    global _firebase_app, _firestore_client
    if _firebase_app is not None:
        try:
            firebase_admin.delete_app(_firebase_app)
        except Exception:
            pass
        _firebase_app = None
    _firestore_client = None
