import os
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, HTTPException, Header, Depends, status
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/cases", tags=["Specialist Cases & Privacy"])

from app.services.firebase_auth_service import (
    TRUSTED_ROLES,
    DEFAULT_LEAST_PRIVILEGE_ROLE,
    sanitize_and_validate_role,
    is_synthetic_token_allowed,
    is_firebase_initialized,
    verify_firebase_bearer_token,
)

# In-memory case and child registry for server-side verification and testing
# Can be synced with Firestore via Firebase Admin SDK when credentials are provided
MOCK_CASES_DB: Dict[str, Dict[str, Any]] = {}
MOCK_CHILDREN_DB: Dict[str, Dict[str, Any]] = {}
MOCK_SPECIALISTS_DB: Dict[str, Dict[str, Any]] = {}
MOCK_SCORE_LEDGER_DB: Dict[str, List[Dict[str, Any]]] = {}
MOCK_JOURNEY_PROGRESS_DB: Dict[str, Dict[str, Any]] = {}

class UserContext:
    def __init__(self, uid: str, email: str, role: str, is_verified: bool = True):
        self.uid = uid
        self.email = email
        self.role = sanitize_and_validate_role(role) # 'parent', 'learning_guide', 'specialist', 'clinical_specialist', 'admin'
        self.is_verified = is_verified

    @property
    def is_admin(self) -> bool:
        return self.role == "admin"

    @property
    def is_clinical_specialist(self) -> bool:
        return self.role in ["clinical_specialist", "clinical_professional", "admin"]

    @property
    def is_specialist(self) -> bool:
        return self.role in ["llg", "learning_guide", "specialist", "clinical_specialist", "clinical_professional", "admin"]

async def get_current_user(authorization: Optional[str] = Header(None)) -> UserContext:
    """
    Authenticate request via Bearer token.
    Extracts identity, verified role, and credentials.
    Rejects unauthenticated requests with HTTP 401.

    Production security requirements:
    1. In production, requires initialized Firebase Admin and successfully verifies every
       Bearer token via verify_id_token(..., check_revoked=True).
    2. Synthetic tokens ('user_...') are strictly rejected in production (HTTP 401).
    3. If Firebase Admin initialization or verification is unavailable in production, fails closed (HTTP 401/503).
    4. Does not trust arbitrary role/userType claims; strictly validates against server whitelist,
       defaulting to least-privilege 'parent'.
    5. Synthetic tokens are preserved ONLY when explicit test mode is active (ALLOW_SYNTHETIC_TOKENS=true).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication token. Bearer token required.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = authorization.split("Bearer ")[1].strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Empty authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 1. Synthetic token check - strictly disallowed in production mode
    if token.startswith("user_"):
        if not is_synthetic_token_allowed():
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Synthetic tokens are strictly rejected in production mode. Valid Firebase Bearer token required.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        # Synthetic tokens only accepted in explicitly enabled test environment
        parts = token.split("_")
        uid = parts[1] if len(parts) > 1 else "unknown"
        raw_role = parts[2] if len(parts) > 2 else DEFAULT_LEAST_PRIVILEGE_ROLE
        role = sanitize_and_validate_role(raw_role)
        is_verified = (parts[3] != "unverified") if len(parts) > 3 else True
        return UserContext(uid=uid, email=f"{uid}@littlelumin.test", role=role, is_verified=is_verified)

    # 2. Production Firebase Admin token verification with check_revoked=True
    decoded_token = verify_firebase_bearer_token(token)

    uid = decoded_token.get("uid") or decoded_token.get("sub")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing valid subject or uid identifier.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Server-controlled role validation:
    # Do not trust arbitrary role or userType claims; strictly enforce server-whitelisted roles
    raw_role = (
        decoded_token.get("role")
        or decoded_token.get("userType")
        or decoded_token.get("custom_claims", {}).get("role")
    )
    role = sanitize_and_validate_role(raw_role)
    email = decoded_token.get("email") or f"{uid}@littlelumin.app"
    is_verified = bool(decoded_token.get("is_verified", decoded_token.get("email_verified", True)))

    return UserContext(uid=uid, email=email, role=role, is_verified=is_verified)

# =========================================================================
# SCHEMAS
# =========================================================================

class CaseResponse(BaseModel):
    case_id: str
    parent_id: str
    parent_name: str
    child_id: str
    child_name: str
    child_age_years: int
    specialist_id: str
    specialist_name: str
    specialist_role: str
    purpose: str
    authorized_data_categories: List[str]
    consent_notice_version: str
    status: str
    is_consent_active: bool
    consented_at: str
    accepted_at: Optional[str] = None
    expires_at: Optional[str] = None
    revoked_at: Optional[str] = None
    revocation_reason: Optional[str] = None

class CreateObservationRequest(BaseModel):
    observation: str = Field(..., min_length=10, description="Detailed observation text")
    recommendations: List[str] = Field(..., min_items=1, description="Actionable recommendations")
    severity: str = Field(default="normal", description="normal, moderate, high, critical")
    referral_needed: bool = Field(default=False, description="Whether clinical external referral is advised")

class ChildDataResponse(BaseModel):
    child_id: str
    child_name: str
    age_years: int
    gender: Optional[str] = None
    purpose: str
    authorized_categories: List[str]
    domain_scores: Optional[Dict[str, float]] = None
    recent_activities: Optional[List[Dict[str, Any]]] = None
    observations: Optional[List[Dict[str, Any]]] = None

class CreateCaseRequest(BaseModel):
    child_id: str
    specialist_id: str
    purpose: str = Field(..., min_length=3, max_length=500)
    authorized_data_categories: List[str] = Field(..., min_items=1)
    consent_notice_version: str = Field(..., min_length=1)
    consent_expires_at: str

class RecordActivityScoreRequest(BaseModel):
    child_id: str
    activity_id: str
    activity_title: Optional[str] = "Activity"
    activity_source: Optional[str] = "preset" # preset, ai_generated, llg_assigned
    skill_domain: str # cognitive, language, motor, social, emotional, creative
    difficulty: str # easy, just_right, challenging
    child_response: str # great, okay, struggled, loved
    engagement: str # very_engaged, somewhat_engaged, not_engaged, high, medium, low
    confidence: str # very_confident, somewhat_confident, not_confident
    time_estimate: Optional[str] = None
    notes: Optional[str] = None

class SpecialistPublicProfile(BaseModel):
    specialist_id: str
    name: str
    role: str
    specializations: List[str]
    is_verified: bool
    bio: Optional[str] = None

# =========================================================================
# ENDPOINTS
# =========================================================================

@router.get("/my-cases", response_model=List[CaseResponse])
async def get_my_cases(
    status_filter: Optional[str] = None,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Returns only cases the authenticated specialist is authorized to access.
    A specialist never receives access to all children's records globally.
    """
    if not current_user.is_specialist:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden: user is not an approved specialist."
        )

    cases = []
    for c_id, case in MOCK_CASES_DB.items():
        if current_user.is_admin or case.get("specialist_id") == current_user.uid:
            if status_filter and case.get("status") != status_filter:
                continue
            cases.append(case)
    return cases

@router.get("/{case_id}/child-data", response_model=ChildDataResponse)
async def get_case_child_data(
    case_id: str,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Enforces case-specific consent and purpose limitation.
    Returns 404 if case does not exist or specialist is not assigned,
    preventing information leakage about unrelated children.
    """
    case = MOCK_CASES_DB.get(case_id)
    if not case:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case record not found."
        )

    # 1. Specialist assignment check
    if not current_user.is_admin and case.get("specialist_id") != current_user.uid:
        # Return 404 to avoid leaking whether an unrelated child's case exists
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Case record not found."
        )

    # 2. Status & Consent Check
    case_status = case.get("status")
    if case_status not in ["accepted", "active"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access denied: Case is currently in '{case_status}' status. Requires accepted parent consent."
        )

    if case.get("revoked_at") is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Parent has withdrawn consent for this consultation."
        )

    # 2b. Expiry check (Requirement 2)
    expires_at_val = case.get("expires_at") or case.get("consent_expires_at")
    if not expires_at_val:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Case is missing a valid consent expiration timestamp."
        )
    try:
        if isinstance(expires_at_val, str):
            exp_dt = datetime.fromisoformat(expires_at_val.replace("Z", "+00:00"))
        elif isinstance(expires_at_val, datetime):
            exp_dt = expires_at_val
        else:
            raise ValueError("Malformed date")
        if exp_dt.tzinfo is None:
            exp_dt = exp_dt.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > exp_dt:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: Parent consultation consent has expired."
            )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Consent expiration timestamp is malformed."
        )

    # 3. Data minimization & Scope filtering
    child_id = case.get("child_id")
    child_raw = MOCK_CHILDREN_DB.get(child_id, {
        "child_id": child_id,
        "name": case.get("child_name", "Child"),
        "age_years": case.get("child_age_years", 4),
        "domain_scores": {"Cognitive": 65.0, "Language": 72.0, "Social": 58.0},
        "recent_activities": [{"title": "Color Sorting", "domain": "Cognitive"}]
    })

    categories = case.get("authorized_data_categories", [])
    has_profile_access = "child_profile" in categories or "all" in categories
    
    child_name = child_raw.get("name", "Child") if has_profile_access else "Child (Protected)"
    age_years = child_raw.get("age_years", 4) if has_profile_access else 0
    gender = child_raw.get("gender") if has_profile_access else None

    domain_scores = child_raw.get("domain_scores") if ("domain_scores" in categories or "all" in categories) else None
    recent_activities = child_raw.get("recent_activities") if ("activity_history" in categories or "all" in categories) else None
    observations = child_raw.get("observations") if ("observations" in categories or "all" in categories) else None

    return ChildDataResponse(
        child_id=child_id,
        child_name=child_name,
        age_years=age_years,
        gender=gender,
        purpose=case.get("purpose", ""),
        authorized_categories=categories,
        domain_scores=domain_scores,
        recent_activities=recent_activities,
        observations=observations,
    )

@router.post("/{case_id}/observations", status_code=status.HTTP_201_CREATED)
async def submit_case_observation(
    case_id: str,
    req: CreateObservationRequest,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Submits an observation for an active case.
    Enforces role separation: Learning Guides cannot submit clinical severity or referrals.
    """
    case = MOCK_CASES_DB.get(case_id)
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case record not found.")

    if not current_user.is_admin and case.get("specialist_id") != current_user.uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case record not found.")

    if case.get("status") not in ["accepted", "active"] or case.get("revoked_at") is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot submit observation: Active parent consent is required."
        )

    # Validate consent expiry
    expires_at_val = case.get("expires_at") or case.get("consent_expires_at")
    if not expires_at_val:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot submit observation: Consent expiration timestamp is missing.")
    try:
        exp_dt = datetime.fromisoformat(expires_at_val.replace("Z", "+00:00")) if isinstance(expires_at_val, str) else expires_at_val
        if exp_dt.tzinfo is None: exp_dt = exp_dt.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) > exp_dt:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot submit observation: Consent has expired.")
    except Exception as e:
        if isinstance(e, HTTPException): raise e
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot submit observation: Consent expiration timestamp is malformed.")

    # Role separation check
    severity_lower = req.severity.lower().strip()
    is_clinical_grade = severity_lower in ["critical", "high"] or req.referral_needed

    if is_clinical_grade and not current_user.is_clinical_specialist:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Learning Guides are not authorized to submit formal clinical observations, high severity ratings, or medical referrals. This requires an authorized clinical professional role."
        )

    observation_record = {
        "obs_id": f"obs_{int(datetime.now().timestamp())}",
        "case_id": case_id,
        "child_id": case.get("child_id"),
        "author_id": current_user.uid,
        "author_role": current_user.role,
        "observation": req.observation,
        "recommendations": req.recommendations,
        "severity": severity_lower,
        "referral_needed": req.referral_needed,
        "is_immutable": True,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    child_id = case.get("child_id")
    if child_id in MOCK_CHILDREN_DB:
        MOCK_CHILDREN_DB[child_id].setdefault("observations", []).append(observation_record)

    return {"status": "success", "observation": observation_record}

@router.post("/{case_id}/accept", status_code=status.HTTP_200_OK)
async def accept_case_request(
    case_id: str,
    current_user: UserContext = Depends(get_current_user)
):
    case = MOCK_CASES_DB.get(case_id)
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found.")

    if not current_user.is_admin and case.get("specialist_id") != current_user.uid:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found.")

    # Prevent self-approval if parent matches specialist
    if case.get("parent_id") == current_user.uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Clients cannot self-approve consultation requests.")

    # Verify specialist credentials
    if not current_user.is_verified:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Specialist must be verified and authorized to accept cases.")

    if case.get("revoked_at") is not None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Parent has withdrawn consent.")

    expires_at_val = case.get("expires_at") or case.get("consent_expires_at")
    if not expires_at_val:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cannot accept case: Consent expiration timestamp is missing.")

    case["status"] = "accepted"
    case["accepted_at"] = datetime.now(timezone.utc).isoformat()
    return {"status": "success", "case": case}

# =========================================================================
# TRUSTED AUDIT & PROGRESSION ENDPOINTS
# =========================================================================

class AuditLogEntryRequest(BaseModel):
    action: str = Field(..., description="Action name e.g. specialist_case_accepted")
    target_id: Optional[str] = None
    case_id: Optional[str] = None
    child_id: Optional[str] = None
    details: Optional[Dict[str, Any]] = None

@router.post("/audit-logs", status_code=status.HTTP_201_CREATED)
async def create_authoritative_audit_log(
    req: AuditLogEntryRequest,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Authoritative audit record creation.
    Derives actor strictly from verified Firebase token/UserContext.
    Clients cannot spoof actor_id or administrative privileges.
    """
    record = {
        "log_id": f"log_{int(datetime.now(timezone.utc).timestamp())}_{current_user.uid}",
        "actor_id": current_user.uid,
        "actor_role": current_user.role,
        "action": req.action,
        "target_id": req.target_id,
        "case_id": req.case_id,
        "child_id": req.child_id,
        "details": req.details or {},
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "is_immutable": True,
    }
    return {"status": "success", "audit_record": record}

class VerifyProgressionRequest(BaseModel):
    child_id: str
    domain_scores: Dict[str, float]
    current_level: int = Field(default=1, ge=1, le=4)

@router.post("/verify-progression", status_code=status.HTTP_200_OK)
async def verify_progression(
    req: VerifyProgressionRequest,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Authoritative mastery calculation to prevent client tampering with levels or mastery.
    """
    PASSING_SCORE = 70.0
    domains = ["cognitive", "language", "motor", "social", "emotional", "creative"]
    
    for d, s in req.domain_scores.items():
        if s < 0.0 or s > 100.0:
            raise HTTPException(status_code=400, detail=f"Invalid score for domain {d}: {s}")

    mastered = [d for d in domains if req.domain_scores.get(d, 0.0) >= PASSING_SCORE]
    all_mastered = len(mastered) == len(domains)
    next_level = req.current_level + 1 if all_mastered and req.current_level < 4 else req.current_level

    return {
        "status": "success",
        "child_id": req.child_id,
        "mastered_domains": mastered,
        "is_level_complete": all_mastered,
        "authorized_level": next_level,
    }

@router.post("/{case_id}/revoke", status_code=status.HTTP_200_OK)
async def revoke_case_consent(
    case_id: str,
    reason: Optional[str] = "Parent withdrawn consent",
    current_user: UserContext = Depends(get_current_user)
):
    case = MOCK_CASES_DB.get(case_id)
    if not case:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Case not found.")

    if not current_user.is_admin and case.get("parent_id") != current_user.uid:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the parent can revoke consent.")

    case["status"] = "revoked"
    case["revoked_at"] = datetime.now(timezone.utc).isoformat()
    case["revocation_reason"] = reason
    return {"status": "success", "case": case}

# =========================================================================
# PUBLIC SPECIALIST DIRECTORY (Separated from Private Profile Data)
# =========================================================================

@router.get("/specialists/directory", response_model=List[SpecialistPublicProfile])
async def get_specialists_directory(
    current_user: UserContext = Depends(get_current_user)
):
    """
    Public directory of verified specialists for parents seeking consultation.
    Never exposes private data (certificates, email, phone, private verification notes).
    """
    directory = []
    for spec_id, profile in MOCK_SPECIALISTS_DB.items():
        if profile.get("is_verified", False):
            directory.append(SpecialistPublicProfile(
                specialist_id=spec_id,
                name=profile.get("name", "Specialist"),
                role=profile.get("role", "specialist"),
                specializations=profile.get("specializations", []),
                is_verified=True,
                bio=profile.get("bio", ""),
            ))
    return directory

# =========================================================================
# VERIFIED SPECIALIST CASE CREATION & CONSENT SCHEMA VALIDATION
# =========================================================================

ALLOWED_DATA_CATEGORIES = {
    "all", "child_profile", "domain_scores", "skill_scores",
    "milestones", "activity_history", "journey_progress",
    "journeys", "observations", "flags", "feedback"
}

@router.post("/create-case", status_code=status.HTTP_201_CREATED, response_model=CaseResponse)
async def create_consultation_case(
    req: CreateCaseRequest,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Initiates a consultation case with verified specialist assignment,
    validating consent categories, purpose, notice version, deterministic ID,
    and mandatory future consentExpiresAt.
    """
    # 1. Verify child ownership
    child = MOCK_CHILDREN_DB.get(req.child_id)
    if not child:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Child record not found.")

    if not current_user.is_admin and child.get("parent_id") != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Only the child's parent can initiate a consultation case."
        )

    # 2. Prevent self-assignment
    if req.specialist_id == current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Parent cannot assign themselves as the consultation specialist."
        )

    # 3. Validate specialist exists and is verified
    specialist = MOCK_SPECIALISTS_DB.get(req.specialist_id)
    if not specialist or not specialist.get("is_verified", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Intended specialist is not verified. Consultations can only be initiated with verified specialists."
        )

    # 4. Validate consent categories against whitelist
    invalid_cats = [c for c in req.authorized_data_categories if c not in ALLOWED_DATA_CATEGORIES]
    if invalid_cats:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid consent categories: {invalid_cats}. Must be from whitelist."
        )

    # 5. Validate consentExpiresAt is valid future timestamp
    try:
        exp_dt = datetime.fromisoformat(req.consent_expires_at.replace("Z", "+00:00"))
        if exp_dt.tzinfo is None:
            exp_dt = exp_dt.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) >= exp_dt:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Consent expiration timestamp must be in the future."
            )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Malformed consent_expires_at ISO timestamp."
        )

    # 6. Deterministic case ID
    case_id = f"{req.child_id}_{req.specialist_id}"

    case_record = {
        "case_id": case_id,
        "parent_id": current_user.uid,
        "parent_name": current_user.email.split("@")[0].capitalize(),
        "child_id": req.child_id,
        "child_name": child.get("name", "Child"),
        "child_age_years": child.get("age_years", 4),
        "specialist_id": req.specialist_id,
        "specialist_name": specialist.get("name", "Specialist"),
        "specialist_role": specialist.get("role", "specialist"),
        "purpose": req.purpose,
        "authorized_data_categories": req.authorized_data_categories,
        "consent_notice_version": req.consent_notice_version,
        "status": "pending",
        "is_consent_active": False,
        "consented_at": datetime.now(timezone.utc).isoformat(),
        "accepted_at": None,
        "expires_at": req.consent_expires_at,
        "revoked_at": None,
        "revocation_reason": None,
    }

    MOCK_CASES_DB[case_id] = case_record
    return case_record

# =========================================================================
# AUTHORITATIVE ACTIVITY SCORE & PROGRESSION ENDPOINT
# =========================================================================

@router.post("/record-activity-score", status_code=status.HTTP_201_CREATED)
async def record_activity_score(
    req: RecordActivityScoreRequest,
    current_user: UserContext = Depends(get_current_user)
):
    """
    Authoritative score calculation, ledger creation, mastery and progression.
    Validates parent ownership and activity evidence server-side.
    Denies client fabrication of score deltas or level unlocks.
    """
    # 1. Verify child exists and parent ownership
    if not req.activity_id or not req.activity_id.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="activity_id cannot be empty.")

    child = MOCK_CHILDREN_DB.get(req.child_id)
    if not child:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Child record not found.")

    if not current_user.is_admin and child.get("parent_id") != current_user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Only the child's parent can submit activity completion scores."
        )

    # 2. Validate skill domain
    valid_domains = ["cognitive", "language", "motor", "social", "emotional", "creative"]
    domain_norm = req.skill_domain.strip().lower()
    if domain_norm not in valid_domains:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid skill domain: {req.skill_domain}")

    # 3. Server-side score delta calculation from validated evidence
    base_delta = 0.0
    resp_norm = req.child_response.strip().lower()
    if resp_norm in ["great", "loved", "excellent"]:
        base_delta += 3.0
    elif resp_norm in ["okay", "good", "neutral"]:
        base_delta += 1.5
    elif resp_norm in ["struggled", "challenging"]:
        base_delta += 0.5
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid child_response evidence.")

    eng_norm = req.engagement.strip().lower()
    if any(k in eng_norm for k in ["very", "high"]):
        base_delta += 1.5
    elif any(k in eng_norm for k in ["somewhat", "medium"]):
        base_delta += 0.5
    elif any(k in eng_norm for k in ["not", "low"]):
        base_delta += 0.0
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid engagement evidence.")

    conf_norm = req.confidence.strip().lower()
    if any(k in conf_norm for k in ["very", "confident", "high"]):
        base_delta += 1.0

    diff_norm = req.difficulty.strip().lower()
    if any(k in diff_norm for k in ["hard", "challenging"]):
        base_delta *= 1.2
    elif any(k in diff_norm for k in ["easy"]):
        base_delta *= 0.8

    # 4. Option C server-side weight rules
    journey = MOCK_JOURNEY_PROGRESS_DB.setdefault(req.child_id, {
        "current_level": 1,
        "unlocked_levels": [1],
        "completed_activities": []
    })
    current_level = journey.get("current_level", 1)

    weight = 1.0
    if current_level >= 3 and req.activity_source == "ai_generated":
        weight = 0.5

    applied_delta = round(base_delta * weight, 2)

    # 4b. Replay & Duplicate Protection: Prevent duplicate requests from inflating scores
    is_duplicate = req.activity_id in journey.get("completed_activities", [])
    if is_duplicate:
        applied_delta = 0.0

    # 5. Fetch previous score and apply delta with clamping
    domain_scores = child.setdefault("domain_scores", {d: 50.0 for d in valid_domains})
    score_before = float(domain_scores.get(domain_norm, 50.0))
    score_after = round(max(0.0, min(100.0, score_before + applied_delta)), 2)
    domain_scores[domain_norm] = score_after

    # 6. Create immutable ledger record
    event_id = f"evt_{int(datetime.now(timezone.utc).timestamp())}_{req.child_id}_{domain_norm}"
    ledger_entry = {
        "event_id": event_id,
        "child_id": req.child_id,
        "activity_id": req.activity_id,
        "activity_title": req.activity_title,
        "activity_source": req.activity_source,
        "skill_domain": domain_norm,
        "difficulty": req.difficulty,
        "level_at_time": current_level,
        "raw_score_delta": base_delta if not is_duplicate else 0.0,
        "applied_score_delta": applied_delta,
        "weight_applied": weight,
        "score_before": score_before,
        "score_after": score_after,
        "is_duplicate": is_duplicate,
        "submitted_by_parent_id": current_user.uid,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "is_immutable": True,
    }
    MOCK_SCORE_LEDGER_DB.setdefault(req.child_id, []).append(ledger_entry)

    # 7. Server-side mastery & progression calculation
    PASSING_SCORE = 70.0
    mastered_domains = [d for d in valid_domains if domain_scores.get(d, 0.0) >= PASSING_SCORE]
    all_mastered = len(mastered_domains) == len(valid_domains)

    new_level = current_level
    if all_mastered and current_level < 4:
        new_level = current_level + 1
        unlocked = journey.get("unlocked_levels", [1])
        if new_level not in unlocked:
            unlocked.append(new_level)
            journey["unlocked_levels"] = unlocked
        journey["current_level"] = new_level

    if not is_duplicate:
        journey.setdefault("completed_activities", []).append(req.activity_id)

    return {
        "status": "already_completed" if is_duplicate else "success",
        "event_id": event_id,
        "child_id": req.child_id,
        "skill_domain": domain_norm,
        "score_before": score_before,
        "score_after": score_after,
        "applied_score_delta": applied_delta,
        "weight_applied": weight,
        "is_duplicate": is_duplicate,
        "is_domain_mastered": score_after >= PASSING_SCORE,
        "is_level_completed": all_mastered,
        "current_level": new_level,
        "unlocked_levels": journey.get("unlocked_levels", [1]),
    }
