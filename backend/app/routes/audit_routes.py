# backend/app/routes/audit_routes.py
import re
import logging
from typing import Optional, Dict, Any
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field, validator
from firebase_admin import firestore

from app.core.security import get_current_admin
from app.core.firebase import get_firestore_client

logger = logging.getLogger("littlelumin.audit")

router = APIRouter(prefix="/api/cases", tags=["Audit Logging"])

SENSITIVE_KEY_PATTERNS = (
    "password",
    "token",
    "secret",
    "private_key",
    "privatekey",
    "credential",
    "service_account",
    "serviceaccount",
    "authorization",
    "bearer",
    "api_key",
    "apikey",
    "auth_token",
)

PROTECTED_METADATA_KEYS = {
    "actorid",
    "actoremail",
    "actortype",
    "timestamp",
    "action",
    "created_at",
    "createdat",
}

def sanitize_audit_details(data: Any, max_depth: int = 4) -> Any:
    """
    Recursively sanitize details to strip credentials, secrets, tokens,
    and client attempts to spoof authoritative audit metadata.
    """
    if max_depth <= 0:
        return "[truncated_depth]"

    if isinstance(data, dict):
        sanitized = {}
        for k, v in data.items():
            if not isinstance(k, str):
                continue
            k_lower = k.lower().replace("-", "_").replace(" ", "")
            # Omit protected server fields and sensitive keys
            if k_lower in PROTECTED_METADATA_KEYS:
                continue
            if any(pat in k_lower for pat in SENSITIVE_KEY_PATTERNS):
                continue
            sanitized[k] = sanitize_audit_details(v, max_depth - 1)
        return sanitized
    elif isinstance(data, list):
        return [sanitize_audit_details(item, max_depth - 1) for item in data[:50]]
    elif isinstance(data, str):
        return data[:1024]
    elif isinstance(data, (int, float, bool)) or data is None:
        return data
    else:
        return str(data)[:256]


class CreateAuditLogRequest(BaseModel):
    action: str = Field(..., min_length=2, max_length=120, description="Audit action identifier")
    target_id: Optional[str] = Field(default=None, max_length=128, description="Target entity ID")
    targetId: Optional[str] = Field(default=None, max_length=128, description="CamelCase target ID alias")
    case_id: Optional[str] = Field(default=None, max_length=128, description="Case identifier")
    caseId: Optional[str] = Field(default=None, max_length=128, description="CamelCase case ID alias")
    child_id: Optional[str] = Field(default=None, max_length=128, description="Child identifier")
    childId: Optional[str] = Field(default=None, max_length=128, description="CamelCase child ID alias")
    details: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Contextual event details")

    class Config:
        extra = "ignore"

    @validator("action")
    def validate_action(cls, v: str) -> str:
        clean = v.strip()
        if not clean:
            raise ValueError("Action must not be empty or whitespace only.")
        if len(clean) < 2 or len(clean) > 120:
            raise ValueError("Action length must be between 2 and 120 characters.")
        if not re.match(r"^[a-zA-Z0-9_\-.: ]+$", clean):
            raise ValueError("Action contains invalid characters.")
        return clean

    @property
    def resolved_target_id(self) -> Optional[str]:
        return self.target_id or self.targetId

    @property
    def resolved_case_id(self) -> Optional[str]:
        return self.case_id or self.caseId

    @property
    def resolved_child_id(self) -> Optional[str]:
        return self.child_id or self.childId


@router.post("/audit-logs", status_code=status.HTTP_201_CREATED)
async def create_audit_log(
    req: CreateAuditLogRequest,
    admin: Dict[str, Any] = Depends(get_current_admin)
) -> Dict[str, Any]:
    """
    Securely record an authoritative administrative audit event.
    Requires a valid Firebase ID token with administrator authorization.
    Never trusts client-supplied timestamps or actor identifiers.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    if not admin_uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authenticated administrator identity missing in session."
        )

    admin_email = admin.get("email") or "admin@littlelumin.com"

    # Sanitize details against credential/token leaks or client metadata injection
    sanitized_details = sanitize_audit_details(req.details or {})

    firestore_client = get_firestore_client()
    if firestore_client is None:
        logger.error("Firestore database client unavailable for audit logging")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Audit logging service is temporarily unavailable (Database offline)."
        )

    audit_payload = {
        "action": req.action,
        "actorId": admin_uid,
        "actorEmail": admin_email,
        "actorType": "admin",
        "targetId": req.resolved_target_id,
        "caseId": req.resolved_case_id,
        "childId": req.resolved_child_id,
        "timestamp": firestore.SERVER_TIMESTAMP,
        "details": sanitized_details,
    }

    try:
        doc_ref = firestore_client.collection("adminAuditLogs").document()
        doc_ref.set(audit_payload)
        logger.info(
            "Secure audit event recorded: action='%s', logId='%s', admin='%s'",
            req.action, doc_ref.id, admin_uid
        )
        return {
            "status": "success",
            "log_id": doc_ref.id,
            "action": req.action,
            "message": "Audit event securely recorded.",
        }
    except Exception as e:
        logger.error("Firestore write failure in create_audit_log: %s", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to record audit event to database."
        )
