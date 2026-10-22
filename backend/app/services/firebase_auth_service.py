# backend/app/services/firebase_auth_service.py
import os
import json
import logging
from typing import Optional, Dict, Any
from fastapi import HTTPException, status

logger = logging.getLogger("littlelumin.auth")

TRUSTED_ROLES = {
    "parent",
    "user",
    "llg",
    "learning_guide",
    "specialist",
    "clinical_specialist",
    "clinical_professional",
    "admin",
}

DEFAULT_LEAST_PRIVILEGE_ROLE = "parent"

_firebase_initialized: bool = False
_firebase_init_error: Optional[str] = None


def is_synthetic_token_allowed() -> bool:
    """
    Synthetic tokens ('user_<uid>_<role>') are strictly forbidden in production.
    They are only permitted when an explicit test flag is active in the environment:
    ALLOW_SYNTHETIC_TOKENS=true or LITTLELUMIN_TEST_MODE=true.
    Never allowed if ENVIRONMENT is explicitly set to 'production' or 'prod'.
    """
    env = os.getenv("ENVIRONMENT", "").strip().lower()
    if env in ("production", "prod"):
        return False

    allow = os.getenv("ALLOW_SYNTHETIC_TOKENS", "").strip().lower()
    test_mode = os.getenv("LITTLELUMIN_TEST_MODE", "").strip().lower()
    return allow in ("true", "1", "yes") or test_mode in ("true", "1", "yes")


def sanitize_and_validate_role(raw_role: Any) -> str:
    """
    Validate token role claim against trusted server-controlled whitelist.
    Enforces least privilege: if role is missing, non-string, or not in TRUSTED_ROLES,
    it strictly defaults to 'parent'.
    """
    if not isinstance(raw_role, str):
        return DEFAULT_LEAST_PRIVILEGE_ROLE
    normalized = raw_role.strip().lower()
    if normalized in TRUSTED_ROLES:
        return normalized
    return DEFAULT_LEAST_PRIVILEGE_ROLE


def init_firebase_admin() -> bool:
    """
    Safely initialize Firebase Admin SDK using configured FIREBASE_PROJECT_ID
    and Render-supported credentials (env var JSON, secret file, ADC).
    Never raises an uncaught exception during startup; records status.
    """
    global _firebase_initialized, _firebase_init_error

    project_id = os.getenv("FIREBASE_PROJECT_ID", "littlelumin-e7d26")

    try:
        import firebase_admin
        from firebase_admin import credentials

        # If already initialized, mark initialized and return
        if firebase_admin._apps:
            _firebase_initialized = True
            _firebase_init_error = None
            return True

        cred = None

        # 1. Check for Service Account JSON in environment variable (Render env var)
        for env_key in [
            "FIREBASE_SERVICE_ACCOUNT_JSON",
            "FIREBASE_ADMIN_CREDENTIALS",
            "FIREBASE_ADMIN_CREDENTIALS_JSON",
            "FIREBASE_CREDENTIALS",
        ]:
            val = os.getenv(env_key)
            if val and val.strip():
                try:
                    cred_dict = json.loads(val.strip())
                    cred = credentials.Certificate(cred_dict)
                    logger.info("Loaded Firebase credentials from %s environment variable", env_key)
                    break
                except Exception as json_err:
                    _firebase_init_error = f"Failed to parse {env_key}: {json_err}"
                    logger.warning("Failed to parse %s: %s", env_key, json_err)

        # 2. Check for credentials file path (Render Secret File or GOOGLE_APPLICATION_CREDENTIALS)
        if cred is None:
            for path_key in ["GOOGLE_APPLICATION_CREDENTIALS", "FIREBASE_ADMIN_KEY_PATH"]:
                file_path = os.getenv(path_key)
                if file_path and os.path.isfile(file_path):
                    try:
                        cred = credentials.Certificate(file_path)
                        logger.info("Loaded Firebase credentials from file: %s", file_path)
                        break
                    except Exception as path_err:
                        _firebase_init_error = f"Failed to load credentials from {file_path}: {path_err}"
                        logger.warning("Failed to load credentials from %s: %s", file_path, path_err)

            # Default Render secret file mount location
            render_secret = "/etc/secrets/firebase-admin.json"
            if cred is None and os.path.isfile(render_secret):
                try:
                    cred = credentials.Certificate(render_secret)
                    logger.info("Loaded Firebase credentials from Render secret file: %s", render_secret)
                except Exception as r_err:
                    _firebase_init_error = f"Failed to load Render secret file: {r_err}"
                    logger.warning("Failed to load Render secret file %s: %s", render_secret, r_err)

        # 3. Try Application Default Credentials (ADC)
        if cred is None:
            try:
                cred = credentials.ApplicationDefault()
                logger.info("Loaded Application Default Credentials (ADC) for Firebase Admin")
            except Exception:
                pass

        # 4. Initialize Firebase App
        if cred is not None:
            firebase_admin.initialize_app(cred, options={"projectId": project_id})
        else:
            # Fallback with projectId options (works in GCP runtime or implicit ADC)
            firebase_admin.initialize_app(options={"projectId": project_id})

        _firebase_initialized = True
        _firebase_init_error = None
        logger.info("Firebase Admin initialized successfully with project_id: %s", project_id)
        return True
    except Exception as e:
        _firebase_initialized = False
        _firebase_init_error = str(e)
        logger.warning("Firebase Admin initialization failed: %s", e)
        return False


def is_firebase_initialized() -> bool:
    """
    Returns True if Firebase Admin default app is currently initialized.
    """
    global _firebase_initialized
    try:
        import firebase_admin
        return bool(firebase_admin._apps)
    except Exception:
        return False


def verify_firebase_bearer_token(token: str) -> Dict[str, Any]:
    """
    Verifies a Firebase ID token using Firebase Admin SDK with check_revoked=True.
    Fails closed:
    - HTTP 401 if token is malformed, invalid, expired, revoked, or audience mismatches.
    - HTTP 503 if Firebase Admin SDK is uninitialized, misconfigured, or has credential/transport errors.
    """
    # 1. Structural check: Firebase ID tokens are signed JWTs with exactly 3 parts (header.payload.signature)
    if token.count(".") != 2:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or unrecognized authentication token format. Valid Firebase JWT required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        import firebase_admin
        from firebase_admin import auth as fb_auth
    except ImportError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Firebase Admin SDK is not installed: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not is_firebase_initialized():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication service unavailable: Firebase Admin SDK is not initialized.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    expected_project = os.getenv("FIREBASE_PROJECT_ID", "littlelumin-e7d26")

    try:
        decoded_token = fb_auth.verify_id_token(token, check_revoked=True)
    except Exception as e:
        err_cls = type(e).__name__
        err_str = str(e)
        # Check for credential / transport / backend configuration errors
        if "CredentialsError" in err_cls or "TransportError" in err_cls or "DefaultCredentials" in err_str:
            logger.error("Firebase Admin credential/transport failure during verification: %s", err_str)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Authentication service configuration error or unavailable: {err_str}",
                headers={"WWW-Authenticate": "Bearer"},
            )
        # Client token errors (InvalidIdTokenError, ExpiredIdTokenError, RevokedIdTokenError, CertificateFetchError, etc.)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or revoked authentication token: {err_str}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token_project = decoded_token.get("firebase", {}).get("project_id") or decoded_token.get("aud")
    if token_project and token_project != expected_project:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token audience mismatch: expected project {expected_project}, got {token_project}",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return decoded_token
