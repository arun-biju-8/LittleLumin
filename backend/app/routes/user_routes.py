# backend/app/routes/user_routes.py
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, Field, validator, root_validator
from firebase_admin import auth, firestore

from app.core.security import get_current_admin
from app.core.firebase import get_firestore_client, get_auth_client
from app.routes.audit_routes import sanitize_audit_details

logger = logging.getLogger("littlelumin.users")

router = APIRouter(prefix="/api/admin/users", tags=["Admin User Lifecycle"])

# =========================================================================
# AUDIT LOGGING HELPER
# =========================================================================

def record_admin_audit_log(
    firestore_client: Any,
    action: str,
    admin_uid: str,
    admin_email: str,
    target_id: Optional[str] = None,
    case_id: Optional[str] = None,
    child_id: Optional[str] = None,
    details: Optional[Dict[str, Any]] = None,
) -> Optional[str]:
    """Record an authoritative administrative audit entry in adminAuditLogs."""
    if firestore_client is None:
        logger.error("Firestore unavailable when attempting to record audit log '%s'", action)
        return None
    try:
        sanitized = sanitize_audit_details(details or {})
        doc_ref = firestore_client.collection("adminAuditLogs").document()
        doc_ref.set({
            "action": action,
            "actorId": admin_uid,
            "actorEmail": admin_email,
            "actorType": "admin",
            "targetId": target_id,
            "caseId": case_id,
            "childId": child_id,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "details": sanitized,
        })
        logger.info("Admin audit log '%s' recorded with id '%s'", action, doc_ref.id)
        return doc_ref.id
    except Exception as e:
        logger.error("Failed to write admin audit log for action '%s': %s", action, type(e).__name__)
        return None


# =========================================================================
# SAFEGUARDS: PREVENT SELF-ACTION & ADMIN ACCIDENTAL DESTRUCTION
# =========================================================================

def check_admin_safeguard(
    target_uid: str,
    current_admin_uid: str,
    firestore_client: Any,
    auth_client: Any,
    action_name: str,
):
    """
    Safeguards against:
    1. Administrators performing self-suspension/deactivation/deletion.
    2. Suspending, deactivating, or deleting administrator accounts without safe policy.
    3. Suspending or deleting the last active administrator.
    """
    if target_uid == current_admin_uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Self-action prohibited: Administrators cannot {action_name} their own account.",
        )

    # Check if target user is an administrator via Firestore adminUsers
    is_target_admin = False
    if firestore_client is not None:
        try:
            admin_doc = firestore_client.collection("adminUsers").document(target_uid).get()
            if admin_doc is not None and getattr(admin_doc, "exists", False) is True:
                is_target_admin = True
        except Exception as e:
            logger.warning("Error checking adminUsers collection for safeguard: %s", type(e).__name__)

    # Check custom claims in Firebase Auth if not already confirmed
    if not is_target_admin and auth_client is not None:
        try:
            target_auth_user = auth_client.get_user(target_uid)
            custom_claims = getattr(target_auth_user, "custom_claims", None) or {}
            if isinstance(custom_claims, dict) and (custom_claims.get("admin") is True or str(custom_claims.get("role", "")).lower() == "admin"):
                is_target_admin = True
        except Exception:
            pass

    if is_target_admin:
        # Check total admin count
        total_admins = 1
        if firestore_client is not None:
            try:
                admin_docs = list(firestore_client.collection("adminUsers").stream())
                total_admins = len(admin_docs)
            except Exception:
                pass

        if total_admins <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Action prohibited: Cannot {action_name} the last active administrator on the platform.",
            )

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Action prohibited: Target user is an administrator. Admin accounts cannot be {action_name}d via user management.",
        )


# =========================================================================
# REQUEST MODELS
# =========================================================================

class SuspendUserRequest(BaseModel):
    category: str = Field(..., min_length=2, max_length=100, description="Suspension category")
    reason: str = Field(..., min_length=3, max_length=1000, description="Detailed reason")
    is_temporary: bool = Field(default=False, alias="isTemporary", description="Temporary vs indefinite")
    suspension_until: Optional[str] = Field(default=None, alias="suspensionUntil", description="ISO review timestamp")
    send_email: bool = Field(default=True, alias="sendEmail", description="Send transactional notice")

    class Config:
        allow_population_by_field_name = True


class RestoreUserRequest(BaseModel):
    restoration_reason: str = Field(..., min_length=3, max_length=1000, alias="restorationReason", description="Findings/reason for restoration")
    send_email: bool = Field(default=True, alias="sendEmail", description="Send transactional notice")

    class Config:
        allow_population_by_field_name = True


class DeactivateUserRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=1000, description="Reason for deactivation")


class DeleteUserRequest(BaseModel):
    reason: str = Field(..., min_length=3, max_length=1000, description="Authoritative deletion justification")
    confirmation: str = Field(..., min_length=1, max_length=256, description="Exact target user email or user ID")


class IssueWarningRequest(BaseModel):
    category: str = Field(..., min_length=2, max_length=100, description="Warning category")
    reason: str = Field(..., min_length=3, max_length=1000, description="Authoritative warning reason")
    notes: Optional[str] = Field(default=None, max_length=1000, description="Internal admin notes")
    send_email: bool = Field(default=True, alias="sendEmail", description="Send warning notice")

    class Config:
        allow_population_by_field_name = True


class ProcessRecoveryDecisionRequest(BaseModel):
    user_id: str = Field(..., min_length=1, alias="userId", description="Target user ID")
    decision_status: str = Field(..., alias="decisionStatus", description="approved, rejected, or additional_verification_required")
    reviewer_notes: Optional[str] = Field(default=None, max_length=1000, alias="reviewerNotes", description="Admin review notes")
    send_email: bool = Field(default=True, alias="sendEmail", description="Send decision notice")

    class Config:
        allow_population_by_field_name = True

    @validator("decision_status")
    def validate_decision_status(cls, v: str) -> str:
        clean = v.strip().lower()
        allowed = {"approved", "rejected", "additional_verification_required"}
        if clean not in allowed:
            raise ValueError(f"decisionStatus must be one of {allowed}")
        return clean


class ProcessAppealDecisionRequest(BaseModel):
    decision_status: Optional[str] = Field(default=None, alias="decisionStatus", description="approved or rejected")
    approve: Optional[bool] = Field(default=None, description="Alternative boolean approval flag")
    admin_notes: str = Field(..., min_length=3, max_length=1000, alias="adminNotes", description="Admin review notes")
    restoration_conditions: Optional[List[str]] = Field(default=None, alias="restorationConditions", description="Optional conditions")

    class Config:
        allow_population_by_field_name = True

    @root_validator(pre=True)
    def normalize_decision_status(cls, values: Dict[str, Any]) -> Dict[str, Any]:
        status_val = values.get("decisionStatus") or values.get("decision_status")
        approve_val = values.get("approve")
        if not status_val and approve_val is not None:
            values["decisionStatus"] = "approved" if approve_val else "rejected"
            values["decision_status"] = "approved" if approve_val else "rejected"
        return values

    @validator("decision_status")
    def validate_decision_status(cls, v: Optional[str]) -> str:
        if not v:
            raise ValueError("Either decisionStatus or approve flag must be provided.")
        clean = v.strip().lower()
        if clean not in {"approved", "rejected"}:
            raise ValueError("decisionStatus must be 'approved' or 'rejected'")
        return clean


class UpdateComplaintStatusRequest(BaseModel):
    new_status: str = Field(..., alias="newStatus", description="pending, under_investigation, resolved, or dismissed")
    investigation_notes: Optional[str] = Field(default=None, max_length=2000, alias="investigationNotes")
    resolution_summary: Optional[str] = Field(default=None, max_length=2000, alias="resolutionSummary")
    notify_parent: bool = Field(default=True, alias="notifyParent")

    class Config:
        allow_population_by_field_name = True

    @validator("new_status")
    def validate_new_status(cls, v: str) -> str:
        clean = v.strip().lower()
        allowed = {"pending", "under_investigation", "resolved", "dismissed"}
        if clean not in allowed:
            raise ValueError(f"newStatus must be one of {allowed}")
        return clean


# =========================================================================
# ENDPOINTS
# =========================================================================

@router.post("/{user_id}/suspend", status_code=status.HTTP_200_OK)
async def suspend_user(
    user_id: str,
    req: SuspendUserRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Suspend a user account with authoritative audit tracking.
    Disables the Firebase Auth account, revokes active refresh tokens, and updates Firestore.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    auth_client = get_auth_client()

    if firestore_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database service is temporarily unavailable.",
        )

    # 1. Enforce admin safeguards
    check_admin_safeguard(user_id, admin_uid, firestore_client, auth_client, "suspend")

    # 2. Verify target user exists
    user_ref = firestore_client.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    # 3. Parse optional suspensionUntil timestamp
    suspension_until_dt = None
    if req.suspension_until:
        try:
            suspension_until_dt = datetime.fromisoformat(req.suspension_until.replace("Z", "+00:00"))
        except Exception:
            pass

    # 4. Synchronize Firebase Auth account: disable and revoke refresh tokens
    auth_disabled = False
    try:
        auth_client.update_user(user_id, disabled=True)
        auth_client.revoke_refresh_tokens(user_id)
        auth_disabled = True
    except Exception as e:
        logger.error("Failed to disable/revoke Firebase Auth user '%s': %s", user_id, type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to restrict authentication credentials for target user.",
        )

    # 5. Update Firestore user document
    try:
        update_data = {
            "status": "suspended",
            "isSuspended": True,
            "suspendedAt": firestore.SERVER_TIMESTAMP,
            "suspendedBy": admin_uid,
            "suspensionReason": req.reason,
            "suspensionCategory": req.category,
            "isTemporarySuspension": req.is_temporary,
            "suspensionUntil": suspension_until_dt,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        user_ref.update(update_data)
    except Exception as e:
        logger.error("Failed to update Firestore document on suspend for '%s': %s", user_id, type(e).__name__)
        # Roll back Auth state to avoid inconsistent lock
        try:
            auth_client.update_user(user_id, disabled=False)
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update user profile status in database.",
        )

    # 6. If specialist, also update llgProfiles
    try:
        firestore_client.collection("llgProfiles").document(user_id).update({
            "status": "suspended",
            "suspensionReason": req.reason,
            "suspendedAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception:
        pass

    # 7. Record authoritative immutable audit log
    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="account_suspended",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=user_id,
        details={
            "category": req.category,
            "reason": req.reason,
            "isTemporary": req.is_temporary,
            "suspensionUntil": req.suspension_until,
            "authDisabled": auth_disabled,
        },
    )

    return {
        "status": "success",
        "message": "User account successfully suspended and authentication credentials revoked.",
        "user_id": user_id,
        "account_status": "suspended",
        "audit_log_id": audit_id,
    }


@router.post("/{user_id}/restore", status_code=status.HTTP_200_OK)
async def restore_user(
    user_id: str,
    req: RestoreUserRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Restore a suspended or deactivated account.
    Enables the Firebase Auth account and updates Firestore status to active.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    auth_client = get_auth_client()

    if firestore_client is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database service is temporarily unavailable.",
        )

    # 1. Verify target user exists
    user_ref = firestore_client.collection("users").document(user_id)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    # 2. Synchronize Firebase Auth account: re-enable account
    try:
        auth_client.update_user(user_id, disabled=False)
    except Exception as e:
        logger.error("Failed to enable Firebase Auth user '%s': %s", user_id, type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to restore authentication credentials for target user.",
        )

    # 3. Update Firestore user document
    try:
        user_ref.update({
            "status": "active",
            "isSuspended": False,
            "restoredAt": firestore.SERVER_TIMESTAMP,
            "restoredBy": admin_uid,
            "restorationReason": req.restoration_reason,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception as e:
        logger.error("Failed to update Firestore on restore for '%s': %s", user_id, type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update user profile status in database.",
        )

    # 4. If specialist, also update llgProfiles
    try:
        firestore_client.collection("llgProfiles").document(user_id).update({
            "status": "active",
            "restoredAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception:
        pass

    # 5. Record authoritative audit log
    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="account_restored",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=user_id,
        details={
            "restorationReason": req.restoration_reason,
        },
    )

    return {
        "status": "success",
        "message": "User account successfully restored and credentials activated.",
        "user_id": user_id,
        "account_status": "active",
        "audit_log_id": audit_id,
    }


@router.post("/{user_id}/deactivate", status_code=status.HTTP_200_OK)
async def deactivate_user(
    user_id: str,
    req: DeactivateUserRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Deactivate a user account (reversible pause of service).
    Disables Firebase Auth and marks status as deactivated in Firestore.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    auth_client = get_auth_client()

    if firestore_client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database service is unavailable.")

    # 1. Enforce admin safeguards
    check_admin_safeguard(user_id, admin_uid, firestore_client, auth_client, "deactivate")

    user_ref = firestore_client.collection("users").document(user_id)
    if not user_ref.get().exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    # 2. Disable Auth & revoke tokens
    try:
        auth_client.update_user(user_id, disabled=True)
        auth_client.revoke_refresh_tokens(user_id)
    except Exception as e:
        logger.error("Failed to disable auth on deactivation for '%s': %s", user_id, type(e).__name__)

    # 3. Update Firestore
    try:
        user_ref.update({
            "status": "deactivated",
            "deactivatedAt": firestore.SERVER_TIMESTAMP,
            "deactivatedBy": admin_uid,
            "deactivationReason": req.reason,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception as e:
        logger.error("Failed to update user doc on deactivation for '%s': %s", user_id, type(e).__name__)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update database record.")

    # 4. Audit log
    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="account_deactivated",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=user_id,
        details={"reason": req.reason},
    )

    return {
        "status": "success",
        "message": "User account deactivated.",
        "user_id": user_id,
        "account_status": "deactivated",
        "audit_log_id": audit_id,
    }


@router.post("/{user_id}/delete", status_code=status.HTTP_200_OK)
async def permanently_delete_user(
    user_id: str,
    req: DeleteUserRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Permanently delete a user account through an explicitly confirmed administrative workflow.
    Safeguards:
      1. Requires exact match confirmation (user email or UID).
      2. Rejects self-deletion and deletion of administrator accounts.
      3. Detaches associated children and terminates specialist cases.
      4. Deletes user document from Firestore and Auth account via Admin SDK.
      5. Handles partial failures gracefully and logs safe audit outcomes.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    auth_client = get_auth_client()

    if firestore_client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database service is unavailable.")

    # 1. Enforce admin safeguards
    check_admin_safeguard(user_id, admin_uid, firestore_client, auth_client, "delete")

    # 2. Verify target user exists and fetch metadata
    user_ref = firestore_client.collection("users").document(user_id)
    user_doc = user_ref.get()
    user_data = user_doc.to_dict() if user_doc.exists else {}

    target_email = user_data.get("email", "")
    if not target_email and auth_client is not None:
        try:
            auth_user = auth_client.get_user(user_id)
            target_email = auth_user.email or ""
        except Exception:
            pass

    if not user_doc.exists and not target_email:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    # 3. Explicit confirmation validation
    conf = req.confirmation.strip()
    is_confirmed = False
    if target_email and conf.lower() == target_email.lower():
        is_confirmed = True
    elif conf == user_id:
        is_confirmed = True

    if not is_confirmed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Confirmation mismatch: confirmation must match the exact user email '{target_email}' or User ID.",
        )

    user_type = user_data.get("userType", "parent")
    cleanup_status = {
        "children_detached": 0,
        "cases_terminated": 0,
        "llg_profile_deleted": False,
        "user_doc_deleted": False,
        "auth_deleted": False,
        "errors": [],
    }

    # 4. Detach dependent children to prevent orphaned states
    if user_type == "parent":
        try:
            children_query = firestore_client.collection("children").where("parentId", "==", user_id).stream()
            for child in children_query:
                child.reference.update({
                    "isParentDeleted": True,
                    "parentDeletedAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                })
                cleanup_status["children_detached"] += 1
        except Exception as e:
            cleanup_status["errors"].append(f"children_detach: {type(e).__name__}")

    # 5. Terminate active specialist cases
    try:
        field_filter = "parentId" if user_type == "parent" else "specialistId"
        cases_query = firestore_client.collection("specialistCases").where(field_filter, "==", user_id).stream()
        for c in cases_query:
            c.reference.update({
                "status": "revoked",
                "revokedAt": firestore.SERVER_TIMESTAMP,
                "revocationReason": f"Account permanently removed by administrative request ({req.reason})",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
            cleanup_status["cases_terminated"] += 1
    except Exception as e:
        cleanup_status["errors"].append(f"cases_terminate: {type(e).__name__}")

    # 6. Delete llgProfiles document if exists
    try:
        firestore_client.collection("llgProfiles").document(user_id).delete()
        cleanup_status["llg_profile_deleted"] = True
    except Exception:
        pass

    # 7. Delete Firestore user document
    try:
        user_ref.delete()
        cleanup_status["user_doc_deleted"] = True
    except Exception as e:
        cleanup_status["errors"].append(f"user_doc_delete: {type(e).__name__}")

    # 8. Delete Firebase Auth user (idempotent)
    if auth_client is not None:
        try:
            auth_client.delete_user(user_id)
            cleanup_status["auth_deleted"] = True
        except auth.UserNotFoundError:
            cleanup_status["auth_deleted"] = True  # Already deleted
        except Exception as e:
            cleanup_status["errors"].append(f"auth_delete: {type(e).__name__}")

    # 9. Record audit log
    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="account_permanently_deleted",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=user_id,
        details={
            "email": target_email,
            "role": user_type,
            "reason": req.reason,
            "cleanup": cleanup_status,
        },
    )

    if cleanup_status["errors"] and not cleanup_status["user_doc_deleted"] and not cleanup_status["auth_deleted"]:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Permanent deletion failed: {', '.join(cleanup_status['errors'])}",
        )

    return {
        "status": "success",
        "message": "User account permanently removed under administrative audit trail.",
        "user_id": user_id,
        "cleanup_summary": cleanup_status,
        "audit_log_id": audit_id,
    }


@router.post("/{user_id}/warning", status_code=status.HTTP_200_OK)
async def issue_warning(
    user_id: str,
    req: IssueWarningRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Issue an administrative warning and update user warnings history.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    if firestore_client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database service is unavailable.")

    user_ref = firestore_client.collection("users").document(user_id)
    if not user_ref.get().exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    warning_id = f"warn_{int(datetime.now(timezone.utc).timestamp() * 1000)}"
    warning_record = {
        "warningId": warning_id,
        "category": req.category,
        "reason": req.reason,
        "notes": req.notes,
        "issuedAt": firestore.SERVER_TIMESTAMP,
        "issuedBy": admin_uid,
        "emailSent": req.send_email,
    }

    try:
        user_ref.update({
            "status": "warning_issued",
            "warnings": firestore.ArrayUnion([warning_record]),
            "lastWarningAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception as e:
        logger.error("Failed to append warning to user '%s': %s", user_id, type(e).__name__)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to record warning record.")

    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="user_warning_issued",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=user_id,
        details={
            "warningId": warning_id,
            "category": req.category,
            "reason": req.reason,
            "emailSent": req.send_email,
        },
    )

    return {
        "status": "success",
        "message": "Warning successfully issued to user.",
        "user_id": user_id,
        "warning_id": warning_id,
        "audit_log_id": audit_id,
    }


@router.post("/recovery-requests/{request_id}/decision", status_code=status.HTTP_200_OK)
async def process_recovery_decision(
    request_id: str,
    req: ProcessRecoveryDecisionRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Process an account recovery review request (approved, rejected, additional_verification_required).
    If approved, automatically executes account restoration.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    auth_client = get_auth_client()

    if firestore_client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database service is unavailable.")

    # 1. Fetch recovery request document
    req_ref = firestore_client.collection("accountRecoveryRequests").document(request_id)
    req_doc = req_ref.get()
    if not req_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account recovery request not found.")

    req_data = req_doc.to_dict() or {}
    current_status = req_data.get("status", "pending_review")
    if current_status == "approved":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Recovery request has already been approved and processed.",
        )

    # 2. Update recovery request document
    try:
        req_ref.update({
            "status": req.decision_status,
            "reviewedAt": firestore.SERVER_TIMESTAMP,
            "reviewerId": admin_uid,
            "reviewerNotes": req.reviewer_notes,
        })
    except Exception as e:
        logger.error("Failed to update recovery request '%s': %s", request_id, type(e).__name__)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to update recovery request.")

    # 3. If approved, automatically restore the user account
    if req.decision_status == "approved":
        # Enable Firebase Auth account
        try:
            auth_client.update_user(req.user_id, disabled=False)
        except Exception as e:
            logger.error("Failed to enable user in auth on recovery approval '%s': %s", req.user_id, type(e).__name__)

        # Update Firestore user document
        try:
            firestore_client.collection("users").document(req.user_id).update({
                "status": "active",
                "isSuspended": False,
                "restoredAt": firestore.SERVER_TIMESTAMP,
                "restoredBy": admin_uid,
                "restorationReason": f"Approved through Recovery Request ({req.reviewer_notes or 'Administrative approval'})",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception as e:
            logger.error("Failed to restore user doc on recovery approval '%s': %s", req.user_id, type(e).__name__)

        # Update llgProfiles if applicable
        try:
            firestore_client.collection("llgProfiles").document(req.user_id).update({
                "status": "active",
                "restoredAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception:
            pass

    # 4. Record audit log
    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="recovery_decision_processed",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=req.user_id,
        details={
            "requestId": request_id,
            "decision": req.decision_status,
            "reviewerNotes": req.reviewer_notes,
        },
    )

    return {
        "status": "success",
        "message": f"Account recovery decision '{req.decision_status}' successfully processed.",
        "request_id": request_id,
        "decision_status": req.decision_status,
        "audit_log_id": audit_id,
    }


@router.post("/appeals/{appeal_id}/decision", status_code=status.HTTP_200_OK)
async def process_appeal_decision(
    appeal_id: str,
    req: ProcessAppealDecisionRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Authoritative administrative decision on a suspension appeal.
    If approved, enables Firebase Auth, restores Firestore status, and records audit trail.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    auth_client = get_auth_client()

    if firestore_client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database service is unavailable.")

    appeal_ref = firestore_client.collection("llgAppeals").document(appeal_id)
    appeal_doc = appeal_ref.get()
    if not appeal_doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appeal record not found.")

    appeal_data = appeal_doc.to_dict() or {}
    llg_id = appeal_data.get("llgId")
    if not llg_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Appeal missing target specialist ID.")

    # 1. Update appeal record
    appeal_ref.update({
        "status": req.decision_status,
        "adminNotes": req.admin_notes,
        "reviewedBy": admin_uid,
        "reviewedAt": firestore.SERVER_TIMESTAMP,
        "restorationConditions": req.restoration_conditions or [],
        "updatedAt": firestore.SERVER_TIMESTAMP,
    })

    # 2. If approved, restore specialist account
    if req.decision_status == "approved":
        if auth_client:
            try:
                auth_client.update_user(llg_id, disabled=False)
            except Exception as e:
                logger.error("Failed to enable specialist auth on appeal approval '%s': %s", llg_id, type(e).__name__)

        try:
            firestore_client.collection("users").document(llg_id).update({
                "status": "active",
                "isSuspended": False,
                "restoredAt": firestore.SERVER_TIMESTAMP,
                "restorationReason": f"Appeal approved ({req.admin_notes})",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception as e:
            logger.error("Failed to update user doc on appeal approval '%s': %s", llg_id, type(e).__name__)

        try:
            firestore_client.collection("llgProfiles").document(llg_id).update({
                "status": "active",
                "restoredAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception:
            pass

    # 3. Notify specialist
    try:
        firestore_client.collection("notifications").add({
            "userId": llg_id,
            "type": "appeal_decision",
            "appealId": appeal_id,
            "title": "Appeal Approved: Account Restored" if req.decision_status == "approved" else "Appeal Decision",
            "body": f"Your suspension appeal was reviewed: {req.admin_notes}",
            "actionRoute": "/account-status",
            "createdAt": firestore.SERVER_TIMESTAMP,
        })
    except Exception:
        pass

    # 4. Audit Log
    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="appeal_approved_account_restored" if req.decision_status == "approved" else "appeal_rejected",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=llg_id,
        details={
            "appealId": appeal_id,
            "decision": req.decision_status,
            "adminNotes": req.admin_notes,
            "conditions": req.restoration_conditions,
        },
    )

    return {
        "status": "success",
        "message": f"Appeal decision '{req.decision_status}' successfully recorded.",
        "appeal_id": appeal_id,
        "decision": req.decision_status,
        "account_restored": req.decision_status == "approved",
        "audit_log_id": audit_id,
    }


@router.post("/complaints/{complaint_id}/status", status_code=status.HTTP_200_OK)
async def update_complaint_status(
    complaint_id: str,
    req: UpdateComplaintStatusRequest,
    admin: Dict[str, Any] = Depends(get_current_admin),
) -> Dict[str, Any]:
    """
    Authoritative complaint investigation status update and notification dispatch.
    """
    admin_uid = admin.get("uid") or admin.get("user_id")
    admin_email = admin.get("email") or "admin@littlelumin.com"

    firestore_client = get_firestore_client()
    if firestore_client is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database service is unavailable.")

    complaint_ref = firestore_client.collection("parentComplaints").document(complaint_id)
    doc = complaint_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Complaint record not found.")

    complaint_data = doc.to_dict() or {}
    parent_id = complaint_data.get("parentId")
    specialist_name = complaint_data.get("specialistName", "the specialist")

    update_payload = {
        "status": req.new_status,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    if req.investigation_notes is not None:
        update_payload["investigationNotes"] = req.investigation_notes
    if req.resolution_summary is not None:
        update_payload["resolutionSummary"] = req.resolution_summary
    if req.new_status in {"resolved", "dismissed"}:
        update_payload["resolvedAt"] = firestore.SERVER_TIMESTAMP

    complaint_ref.update(update_payload)

    # Notify parent if requested
    if req.notify_parent and parent_id:
        try:
            firestore_client.collection("notifications").add({
                "userId": parent_id,
                "type": "complaint_status_update",
                "complaintId": complaint_id,
                "title": f"Complaint Status: {req.new_status.replace('_', ' ').title()}",
                "body": req.resolution_summary or f"Your complaint regarding {specialist_name} status updated to {req.new_status}.",
                "actionRoute": "/llg-connect",
                "createdAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception:
            pass

    audit_id = record_admin_audit_log(
        firestore_client=firestore_client,
        action="parent_complaint_status_updated",
        admin_uid=admin_uid,
        admin_email=admin_email,
        target_id=complaint_id,
        details={
            "newStatus": req.new_status,
            "investigationNotes": req.investigation_notes,
            "resolutionSummary": req.resolution_summary,
        },
    )

    return {
        "status": "success",
        "message": f"Complaint status updated to '{req.new_status}'.",
        "complaint_id": complaint_id,
        "new_status": req.new_status,
        "audit_log_id": audit_id,
    }

