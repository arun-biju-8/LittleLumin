# backend/app/core/security.py
import logging
from typing import Dict, Any, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
from app.core.firebase import get_auth_client, get_firestore_client

logger = logging.getLogger("littlelumin.security")

# Reusable Bearer token extraction scheme
oauth2_bearer_scheme = HTTPBearer(
    auto_error=False,
    scheme_name="FirebaseBearerAuth",
    description="Firebase ID Token via 'Authorization: Bearer <token>'"
)

async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(oauth2_bearer_scheme)
) -> Dict[str, Any]:
    """
    FastAPI dependency that extracts and validates a Firebase ID token.
    Enforces token validity and revocation checking.
    Returns the decoded token claims dictionary containing uid, email, custom claims, etc.
    """
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Authorization header. Expected 'Bearer <token>'.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials.strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token is empty.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    auth_client = get_auth_client()

    try:
        # check_revoked=True actively verifies that the token's refresh token has not been revoked
        decoded_token = auth_client.verify_id_token(token, check_revoked=True)

        # Authoritative account status verification: reject suspended or deactivated users
        uid = decoded_token.get("uid") or decoded_token.get("user_id")
        is_admin = decoded_token.get("admin") is True or str(decoded_token.get("role", "")).lower() == "admin"
        if uid and not is_admin:
            firestore_client = get_firestore_client()
            if firestore_client is not None:
                try:
                    user_doc = firestore_client.collection("users").document(uid).get()
                    if user_doc.exists:
                        user_data = user_doc.to_dict() or {}
                        account_status = str(user_data.get("status", "")).lower()
                        if account_status in ("suspended", "deactivated", "deletion_pending"):
                            logger.warning("Access denied: User '%s' account is '%s'", uid, account_status)
                            raise HTTPException(
                                status_code=status.HTTP_403_FORBIDDEN,
                                detail=f"Account is {account_status}. Access to platform resources is restricted.",
                            )
                except HTTPException:
                    raise
                except Exception as e:
                    logger.debug("Non-critical user doc status check notice: %s", type(e).__name__)

        return decoded_token
    except auth.RevokedIdTokenError:
        logger.warning("Authentication failed: Revoked ID token presented")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has been revoked. Please sign in again.",
            headers={"WWW-Authenticate": "Bearer error=\"invalid_token\", error_description=\"Token has been revoked\""},
        )
    except auth.ExpiredIdTokenError:
        logger.warning("Authentication failed: Expired ID token presented")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token has expired. Please refresh your session.",
            headers={"WWW-Authenticate": "Bearer error=\"invalid_token\", error_description=\"Token has expired\""},
        )
    except auth.InvalidIdTokenError as e:
        logger.warning("Authentication failed: Invalid ID token (%s)", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token signature or claims.",
            headers={"WWW-Authenticate": "Bearer error=\"invalid_token\""},
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Authentication failed: Unexpected verification error (%s)", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token verification failed.",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(oauth2_bearer_scheme)
) -> Optional[Dict[str, Any]]:
    """
    FastAPI dependency for endpoints accessible both anonymously and by authenticated users.
    Returns decoded token if valid, None if no credentials were provided,
    or raises 401 if a token was supplied but is invalid/expired.
    """
    if credentials is None or not credentials.credentials:
        return None
    return await get_current_user(credentials)

async def get_current_admin(
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    FastAPI dependency that enforces administrator authorization.
    Authoritative checks:
      1. Firebase Custom Claims: 'admin' == True or 'role' == 'admin'
      2. Firestore Membership: Document exists at 'adminUsers/{uid}'
    If neither check passes, raises HTTP 403 Forbidden.
    """
    uid = current_user.get("uid") or current_user.get("user_id")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User identifier missing in authenticated token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 1. Check custom claims on the verified token
    is_admin_claim = (
        current_user.get("admin") is True or
        str(current_user.get("role", "")).lower() == "admin"
    )

    if is_admin_claim:
        return current_user

    # 2. Check authoritative 'adminUsers' collection in Firestore
    firestore_client = get_firestore_client()
    if firestore_client is not None:
        try:
            admin_doc = firestore_client.collection("adminUsers").document(uid).get()
            if admin_doc.exists:
                return current_user
        except Exception as e:
            logger.warning("Firestore adminUsers collection check encountered an error: %s", type(e).__name__)

    # Neither authoritative check passed
    logger.warning("Access denied: UID '%s' does not possess administrator privileges", uid)
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Forbidden: Administrative privileges required to perform this action.",
    )
