# backend/tests/test_case_routes_direct.py
import asyncio
import os
import sys

# Ensure backend app is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.routes.case_routes import (
    UserContext,
    MOCK_CASES_DB,
    MOCK_CHILDREN_DB,
    MOCK_SPECIALISTS_DB,
    MOCK_SCORE_LEDGER_DB,
    MOCK_JOURNEY_PROGRESS_DB,
    get_my_cases,
    get_case_child_data,
    submit_case_observation,
    revoke_case_consent,
    accept_case_request,
    create_authoritative_audit_log,
    verify_progression,
    create_consultation_case,
    record_activity_score,
    get_specialists_directory,
    get_current_user,
    CreateObservationRequest,
    AuditLogEntryRequest,
    VerifyProgressionRequest,
    CreateCaseRequest,
    RecordActivityScoreRequest,
)
from fastapi import HTTPException

def setup_mock_db():
    MOCK_CASES_DB.clear()
    MOCK_CHILDREN_DB.clear()
    MOCK_SPECIALISTS_DB.clear()
    MOCK_SCORE_LEDGER_DB.clear()
    MOCK_JOURNEY_PROGRESS_DB.clear()

    # Specialists
    MOCK_SPECIALISTS_DB["spec_A"] = {
        "specialist_id": "spec_A",
        "name": "Dr. Sarah",
        "role": "clinical_specialist",
        "specializations": ["Speech", "Autism"],
        "is_verified": True,
        "bio": "Clinical specialist in pediatric speech.",
        "phone": "+1-555-0199", # Sensitive private field
        "email": "sarah.private@clinic.com", # Sensitive private field
    }

    MOCK_SPECIALISTS_DB["spec_unverified"] = {
        "specialist_id": "spec_unverified",
        "name": "Unverified Pete",
        "role": "specialist",
        "specializations": ["General"],
        "is_verified": False,
        "bio": "Pending verification",
    }

    # Child 1: Leo (Parent: parent_alice)
    MOCK_CHILDREN_DB["child_101"] = {
        "child_id": "child_101",
        "parent_id": "parent_alice",
        "name": "Leo",
        "age_years": 5,
        "gender": "male",
        "domain_scores": {
            "cognitive": 65.0,
            "language": 60.0,
            "motor": 68.0,
            "social": 69.0,
            "emotional": 70.0,
            "creative": 70.0
        },
        "recent_activities": [{"title": "Phonics Sound Match", "domain": "language"}],
        "observations": []
    }

    # Case 1: Assigned to specialist_A, active, consent for domain_scores only, valid unexpired timestamp
    MOCK_CASES_DB["case_101_A"] = {
        "case_id": "case_101_A",
        "parent_id": "parent_alice",
        "parent_name": "Alice",
        "child_id": "child_101",
        "child_name": "Leo",
        "child_age_years": 5,
        "specialist_id": "spec_A",
        "specialist_name": "Dr. Sarah",
        "specialist_role": "clinical_specialist",
        "purpose": "Speech Guidance",
        "authorized_data_categories": ["domain_scores"],
        "consent_notice_version": "v1.0-dpdp",
        "status": "accepted",
        "is_consent_active": True,
        "consented_at": "2026-10-20T10:00:00Z",
        "accepted_at": "2026-10-20T10:05:00Z",
        "expires_at": "2026-12-31T23:59:59Z",
        "revoked_at": None,
        "revocation_reason": None,
    }

    # Case 2: Assigned to specialist_B, active, valid unexpired timestamp
    MOCK_CASES_DB["case_102_B"] = {
        "case_id": "case_102_B",
        "parent_id": "parent_bob",
        "parent_name": "Bob",
        "child_id": "child_202",
        "child_name": "Emma",
        "child_age_years": 4,
        "specialist_id": "spec_B",
        "specialist_name": "Guide John",
        "specialist_role": "learning_guide",
        "purpose": "Early Literacy",
        "authorized_data_categories": ["activity_history"],
        "consent_notice_version": "v1.0-dpdp",
        "status": "accepted",
        "is_consent_active": True,
        "consented_at": "2026-10-20T10:00:00Z",
        "accepted_at": "2026-10-20T10:05:00Z",
        "expires_at": "2026-12-31T23:59:59Z",
        "revoked_at": None,
        "revocation_reason": None,
    }

async def run_tests():
    print("Running Case Routes Security Tests...")
    # Explicitly enable test environment for backend unit tests
    os.environ["ALLOW_SYNTHETIC_TOKENS"] = "true"
    os.environ["ENVIRONMENT"] = "test"
    setup_mock_db()

    user_spec_A = UserContext(uid="spec_A", email="a@test.com", role="clinical_specialist", is_verified=True)
    user_spec_B = UserContext(uid="spec_B", email="b@test.com", role="learning_guide", is_verified=True)
    user_spec_C = UserContext(uid="spec_C", email="c@test.com", role="specialist", is_verified=True)
    user_unverified = UserContext(uid="spec_unverified", email="u@test.com", role="specialist", is_verified=False)
    user_alice = UserContext(uid="parent_alice", email="alice@test.com", role="parent")
    user_bob = UserContext(uid="parent_bob", email="bob@test.com", role="parent")

    # TEST 1: Specialist A cannot see Specialist B's cases
    my_cases_a = await get_my_cases(current_user=user_spec_A)
    assert len(my_cases_a) == 1, f"Expected 1 case for spec_A, got {len(my_cases_a)}"
    assert my_cases_a[0]["case_id"] == "case_101_A"
    print("[PASS] Test 1: Specialist dashboard queries are isolated per specialist.")

    # TEST 2: Specialist C accessing Case A returns 404 to avoid leaking child existence
    try:
        await get_case_child_data("case_101_A", current_user=user_spec_C)
        assert False, "Unassigned specialist should have been denied access!"
    except HTTPException as e:
        assert e.status_code == 404, f"Expected 404 to prevent enumeration, got {e.status_code}"
    print("[PASS] Test 2: Unassigned specialist receives 404 without leaking existence.")

    # TEST 3: Data minimization - only authorized categories returned & child profile masked
    child_data = await get_case_child_data("case_101_A", current_user=user_spec_A)
    assert child_data.domain_scores is not None, "Domain scores should be present (authorized)"
    assert child_data.recent_activities is None, "Activity history must be masked/null (unauthorized)"
    assert child_data.child_name == "Child (Protected)", "Child name must be masked when child_profile unauthorized"
    assert child_data.gender is None, "Gender must be masked when child_profile unauthorized"
    print("[PASS] Test 3: Data minimization enforces authorized category filtering and profile masking.")

    # TEST 4: Role separation - Learning Guide CANNOT submit clinical-grade severity
    req_clinical = CreateObservationRequest(
        observation="Child exhibits severe developmental speech delays requiring clinical investigation.",
        recommendations=["Full clinical audiology referral"],
        severity="critical",
        referral_needed=True
    )
    try:
        await submit_case_observation("case_102_B", req_clinical, current_user=user_spec_B)
        assert False, "Learning Guide should not be allowed to submit critical clinical observation!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for Learning Guide clinical attempt, got {e.status_code}"
    print("[PASS] Test 4: Learning Guide prohibited from clinical severity and referrals.")

    # TEST 5: Clinical Specialist CAN submit clinical-grade severity for assigned case
    obs_res = await submit_case_observation("case_101_A", req_clinical, current_user=user_spec_A)
    assert obs_res["status"] == "success"
    assert obs_res["observation"]["is_immutable"] is True
    print("[PASS] Test 5: Verified clinical professional permitted to submit clinical records.")

    # TEST 6: Parent revocation terminates specialist access immediately
    await revoke_case_consent("case_101_A", reason="Parent requested withdrawal", current_user=user_alice)
    try:
        await get_case_child_data("case_101_A", current_user=user_spec_A)
        assert False, "Specialist should be blocked after parent revocation!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 after revocation, got {e.status_code}"
    print("[PASS] Test 6: Consent revocation instantly denies further access.")

    # TEST 7: Expired or missing consent timestamp denies access (Requirement 2)
    MOCK_CASES_DB["case_missing_expiry"] = {
        "case_id": "case_missing_expiry",
        "parent_id": "parent_alice",
        "child_id": "child_101",
        "specialist_id": "spec_A",
        "status": "accepted",
        "authorized_data_categories": ["domain_scores"],
        "expires_at": None,  # MISSING
        "revoked_at": None,
    }
    try:
        await get_case_child_data("case_missing_expiry", current_user=user_spec_A)
        assert False, "Case with missing expiry must be denied!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for missing expiry, got {e.status_code}"
    print("[PASS] Test 7a: Missing consent expiry timestamp strictly denied.")

    MOCK_CASES_DB["case_expired"] = {
        "case_id": "case_expired",
        "parent_id": "parent_alice",
        "child_id": "child_101",
        "specialist_id": "spec_A",
        "status": "accepted",
        "authorized_data_categories": ["domain_scores"],
        "expires_at": "2020-01-01T00:00:00Z",  # EXPIRED
        "revoked_at": None,
    }
    try:
        await get_case_child_data("case_expired", current_user=user_spec_A)
        assert False, "Case with expired consent must be denied!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for expired consent, got {e.status_code}"
    print("[PASS] Test 7b: Expired consent timestamp strictly denied.")

    # TEST 8: Transition lockdown - unverified specialist cannot accept case (Requirement 3)
    MOCK_CASES_DB["case_pending_unverified"] = {
        "case_id": "case_pending_unverified",
        "parent_id": "parent_alice",
        "child_id": "child_101",
        "specialist_id": "spec_unverified",
        "status": "pending",
        "expires_at": "2026-12-31T23:59:59Z",
        "revoked_at": None,
    }
    try:
        await accept_case_request("case_pending_unverified", current_user=user_unverified)
        assert False, "Unverified specialist must not be allowed to accept cases!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for unverified specialist accept, got {e.status_code}"
    print("[PASS] Test 8: Unverified specialist cannot accept pending cases.")

    # TEST 9: Authoritative audit logs endpoint derives actor strictly from token (Requirement 5)
    audit_res = await create_authoritative_audit_log(
        AuditLogEntryRequest(action="case_review_started", case_id="case_101_A", child_id="child_101"),
        current_user=user_spec_A
    )
    assert audit_res["status"] == "success"
    assert audit_res["audit_record"]["actor_id"] == "spec_A"
    assert audit_res["audit_record"]["actor_role"] == "clinical_specialist"
    assert audit_res["audit_record"]["is_immutable"] is True
    print("[PASS] Test 9: Authoritative audit record securely generated from verified token.")

    # TEST 10: Authoritative progression verification calculates mastery (Requirement 4)
    prog_res = await verify_progression(
        VerifyProgressionRequest(
            child_id="child_101",
            domain_scores={"cognitive": 75.0, "language": 72.0, "motor": 70.0, "social": 70.0, "emotional": 70.0, "creative": 70.0},
            current_level=1
        ),
        current_user=user_alice
    )
    assert prog_res["status"] == "success"
    assert prog_res["is_level_complete"] is True
    assert prog_res["authorized_level"] == 2
    print("[PASS] Test 10: Authoritative progression verification protects level unlocking.")

    # TEST 11: Authoritative activity score recording & server-side delta calculation
    score_res = await record_activity_score(
        RecordActivityScoreRequest(
            child_id="child_101",
            activity_id="act_cognitive_puzzles",
            activity_title="Block Puzzles",
            activity_source="preset",
            skill_domain="cognitive",
            difficulty="just_right",
            child_response="great",
            engagement="very_engaged",
            confidence="confident",
        ),
        current_user=user_alice
    )
    assert score_res["status"] == "success"
    assert score_res["skill_domain"] == "cognitive"
    assert score_res["applied_score_delta"] > 0
    assert score_res["score_after"] > score_res["score_before"]
    assert len(MOCK_SCORE_LEDGER_DB["child_101"]) == 1
    assert MOCK_SCORE_LEDGER_DB["child_101"][0]["is_immutable"] is True
    print("[PASS] Test 11: Authoritative score calculation, ledger creation & delta calculation succeed.")

    # TEST 12: Non-parent CANNOT submit score events for child
    try:
        await record_activity_score(
            RecordActivityScoreRequest(
                child_id="child_101",
                activity_id="act_hack",
                skill_domain="cognitive",
                difficulty="easy",
                child_response="great",
                engagement="high",
                confidence="high",
            ),
            current_user=user_bob # Bob trying to submit for Alice's child!
        )
        assert False, "Non-parent should be forbidden from submitting scores!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for non-parent score submit, got {e.status_code}"
    print("[PASS] Test 12: Non-parent strictly prohibited from submitting child scores.")

    # TEST 13: Case creation with unverified specialist is denied
    try:
        await create_consultation_case(
            CreateCaseRequest(
                child_id="child_101",
                specialist_id="spec_unverified",
                purpose="Language evaluation",
                authorized_data_categories=["domain_scores"],
                consent_notice_version="v1.0-dpdp",
                consent_expires_at="2026-12-31T23:59:59Z"
            ),
            current_user=user_alice
        )
        assert False, "Case targeting unverified specialist should be denied!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for unverified specialist, got {e.status_code}"
    print("[PASS] Test 13: Consultation case creation rejected for unverified specialists.")

    # TEST 14: Malformed consent categories fail case creation
    try:
        await create_consultation_case(
            CreateCaseRequest(
                child_id="child_101",
                specialist_id="spec_A",
                purpose="Evaluation",
                authorized_data_categories=["invalid_secret_telemetry"],
                consent_notice_version="v1.0-dpdp",
                consent_expires_at="2026-12-31T23:59:59Z"
            ),
            current_user=user_alice
        )
        assert False, "Malformed consent category should be rejected!"
    except HTTPException as e:
        assert e.status_code == 400, f"Expected 400 for malformed category, got {e.status_code}"
    print("[PASS] Test 14: Malformed consent category schema strictly rejected.")

    # TEST 15: Public specialist directory never leaks private specialist data
    directory = await get_specialists_directory(current_user=user_alice)
    assert len(directory) == 1, f"Expected 1 verified specialist in directory, got {len(directory)}"
    spec_entry = directory[0]
    assert spec_entry.specialist_id == "spec_A"
    assert spec_entry.is_verified is True
    # Ensure sensitive fields are not in the response model
    assert not hasattr(spec_entry, "phone")
    assert not hasattr(spec_entry, "email")
    print("[PASS] Test 15: Public specialist directory isolates verified specialists and omits private fields.")

    # TEST 16: Authentication token parsing & rejection of untrusted arbitrary tokens
    # Valid structured testing token succeeds
    u_ctx = await get_current_user("Bearer user_alice_parent")
    assert u_ctx.uid == "alice"
    assert u_ctx.role == "parent"
    assert u_ctx.is_verified is True

    # Missing authorization header fails with 401
    try:
        await get_current_user(None)
        assert False, "Missing header should fail with 401"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401 for missing auth header, got {e.status_code}"

    # Invalid header format (not Bearer) fails with 401
    try:
        await get_current_user("Basic dXNlcjpwYXNz")
        assert False, "Non-bearer header should fail with 401"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401 for non-bearer auth header, got {e.status_code}"

    # Empty token fails with 401
    try:
        await get_current_user("Bearer ")
        assert False, "Empty token should fail with 401"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401 for empty token, got {e.status_code}"

    # Arbitrary random token string fails with 401 (no fallback to specialist role!)
    try:
        await get_current_user("Bearer arbitrary_hacker_token_12345")
        assert False, "Arbitrary token should fail with 401"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401 for arbitrary token, got {e.status_code}"
    print("[PASS] Test 16: Authentication token parsing strictly enforces Bearer verification and rejects untrusted tokens.")

    # TEST 17: Repeated submission & replayed request cannot inflate scores (idempotency)
    # First submission of new activity
    res_first = await record_activity_score(
        RecordActivityScoreRequest(
            child_id="child_101",
            activity_id="act_math_shapes_1",
            activity_title="Shape Counting",
            activity_source="preset",
            skill_domain="cognitive",
            difficulty="just_right",
            child_response="great",
            engagement="high",
            confidence="confident",
        ),
        current_user=user_alice
    )
    assert res_first["status"] == "success"
    assert res_first["is_duplicate"] is False
    assert res_first["applied_score_delta"] > 0
    score_after_first = res_first["score_after"]

    # Replayed submission of the exact same activity
    res_replay = await record_activity_score(
        RecordActivityScoreRequest(
            child_id="child_101",
            activity_id="act_math_shapes_1", # Same activity!
            activity_title="Shape Counting",
            activity_source="preset",
            skill_domain="cognitive",
            difficulty="just_right",
            child_response="great",
            engagement="high",
            confidence="confident",
        ),
        current_user=user_alice
    )
    assert res_replay["status"] == "already_completed"
    assert res_replay["is_duplicate"] is True
    assert res_replay["applied_score_delta"] == 0.0, "Duplicate submission must have delta 0.0 to prevent inflation!"
    assert res_replay["score_after"] == score_after_first, "Duplicate submission must NOT inflate child score!"
    print("[PASS] Test 17: Replayed/duplicate activity submission strictly prevented from inflating scores.")

    # TEST 18: Invalid or empty activity ID rejected with HTTP 400
    try:
        await record_activity_score(
            RecordActivityScoreRequest(
                child_id="child_101",
                activity_id="", # Empty activity ID!
                skill_domain="cognitive",
                difficulty="easy",
                child_response="great",
                engagement="high",
                confidence="confident",
            ),
            current_user=user_alice
        )
        assert False, "Empty activity_id should be rejected!"
    except HTTPException as e:
        assert e.status_code == 400, f"Expected 400 for empty activity_id, got {e.status_code}"
    print("[PASS] Test 18: Empty or invalid activity ID strictly rejected with HTTP 400.")

    # TEST 19: Non-existent child rejected with HTTP 404
    try:
        await record_activity_score(
            RecordActivityScoreRequest(
                child_id="child_does_not_exist_999",
                activity_id="act_any",
                skill_domain="cognitive",
                difficulty="easy",
                child_response="great",
                engagement="high",
                confidence="confident",
            ),
            current_user=user_alice
        )
        assert False, "Non-existent child should be rejected with 404!"
    except HTTPException as e:
        assert e.status_code == 404, f"Expected 404 for non-existent child, got {e.status_code}"
    print("[PASS] Test 19: Non-existent child record submission rejected with HTTP 404.")

    # TEST 20: Forged activity evidence rejected with HTTP 400
    try:
        await record_activity_score(
            RecordActivityScoreRequest(
                child_id="child_101",
                activity_id="act_fresh_102",
                skill_domain="cognitive",
                difficulty="easy",
                child_response="hacked_score_cheat", # Invalid evidence value!
                engagement="high",
                confidence="confident",
            ),
            current_user=user_alice
        )
        assert False, "Forged activity evidence should be rejected with 400!"
    except HTTPException as e:
        assert e.status_code == 400, f"Expected 400 for forged evidence, got {e.status_code}"
    print("[PASS] Test 20: Forged/tampered activity evidence rejected with HTTP 400.")

    # TEST 21: Server progression cannot unlock levels from client-supplied claims
    # progression verification verifies domain scores against passing threshold (70.0)
    # domain_scores with invalid negative or >100 values must be rejected
    try:
        await verify_progression(
            VerifyProgressionRequest(
                child_id="child_101",
                domain_scores={"cognitive": 105.0, "language": 75.0, "motor": 75.0, "social": 75.0, "emotional": 75.0, "creative": 75.0},
                current_level=1
            ),
            current_user=user_alice
        )
        assert False, "Score > 100 should be rejected by progression verification!"
    except HTTPException as e:
        assert e.status_code == 400, f"Expected 400 for score > 100, got {e.status_code}"
    print("[PASS] Test 21: Progression verification rejects fabricated scores (> 100.0) and protects level unlocking.")

    # TEST 22: REGRESSION - Synthetic tokens are strictly rejected in production mode
    # Test A: ALLOW_SYNTHETIC_TOKENS="false"
    os.environ["ALLOW_SYNTHETIC_TOKENS"] = "false"
    try:
        await get_current_user("Bearer user_alice_parent")
        assert False, "Synthetic token must be strictly rejected when ALLOW_SYNTHETIC_TOKENS is false!"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401, got {e.status_code}"
        assert "Synthetic tokens are strictly rejected in production mode" in e.detail

    # Test B: Elevated synthetic token attempt in production mode
    try:
        await get_current_user("Bearer user_hacker_admin")
        assert False, "Elevated synthetic token must be strictly rejected in production mode!"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401, got {e.status_code}"

    # Test C: ENVIRONMENT="production" overrides even if ALLOW_SYNTHETIC_TOKENS is "true"
    os.environ["ALLOW_SYNTHETIC_TOKENS"] = "true"
    os.environ["ENVIRONMENT"] = "production"
    try:
        await get_current_user("Bearer user_alice_parent")
        assert False, "Synthetic token must be strictly rejected when ENVIRONMENT is production!"
    except HTTPException as e:
        assert e.status_code == 401, f"Expected 401, got {e.status_code}"
    
    # Restore test environment
    os.environ["ALLOW_SYNTHETIC_TOKENS"] = "true"
    os.environ["ENVIRONMENT"] = "test"
    print("[PASS] Test 22: Regression - Synthetic tokens are strictly rejected in production mode.")

    # TEST 23: REGRESSION - Production mode fails closed when Firebase Admin uninitialized or verification fails
    os.environ["ALLOW_SYNTHETIC_TOKENS"] = "false"
    try:
        # Test 23a: Malformed token fails closed with 401
        try:
            await get_current_user("Bearer unverified_bearer_token_123")
            assert False, "Production mode must fail closed on unverified live token!"
        except HTTPException as e:
            assert e.status_code == 401, f"Expected 401 fail-closed, got {e.status_code}"

        # Test 23b: 3-part JWT token with unverified signature / unconfigured credentials fails closed with 401/503
        try:
            await get_current_user("Bearer eyJhbGciOi.eyJzdWIiOi.invalid_signature")
            assert False, "Production mode must fail closed on live token!"
        except HTTPException as e:
            assert e.status_code in [401, 503], f"Expected 401 or 503 fail-closed, got {e.status_code}"
    finally:
        os.environ["ALLOW_SYNTHETIC_TOKENS"] = "true"
        os.environ["ENVIRONMENT"] = "test"
    print("[PASS] Test 23: Regression - Production mode fails closed (401/503) without bypassing verification.")

    # TEST 24: REGRESSION - Arbitrary/untrusted role claims strictly default to least-privilege ('parent')
    # Test A: Synthetic token with unauthorized role claim 'superadmin'
    u_hacker = await get_current_user("Bearer user_hacker_superadmin")
    assert u_hacker.role == "parent", f"Arbitrary role should be demoted to 'parent', got {u_hacker.role}"
    assert u_hacker.is_admin is False, "Arbitrary role must NOT grant admin privileges"
    assert u_hacker.is_specialist is False, "Arbitrary role must NOT grant specialist privileges"

    # Test B: Synthetic token with unauthorized role claim 'root'
    u_root = await get_current_user("Bearer user_root_root")
    assert u_root.role == "parent", f"Root role should be demoted to 'parent', got {u_root.role}"

    # Test C: Direct UserContext instantiation with unauthorized role
    u_direct = UserContext(uid="sneaky", email="s@test.com", role="clinical_godmode")
    assert u_direct.role == "parent", f"Direct UserContext instantiation should sanitize to 'parent', got {u_direct.role}"
    assert u_direct.is_clinical_specialist is False

    # Test D: Demoted user cannot access specialist endpoint
    try:
        await get_my_cases(current_user=u_hacker)
        assert False, "Demoted user should be forbidden from accessing specialist cases!"
    except HTTPException as e:
        assert e.status_code == 403, f"Expected 403 for demoted user, got {e.status_code}"
    print("[PASS] Test 24: Regression - Arbitrary/untrusted role claims strictly default to least-privilege 'parent'.")

    # TEST 25: REGRESSION - Firebase token verification strictly fails closed without bypassing
    from app.services.firebase_auth_service import verify_firebase_bearer_token
    try:
        verify_firebase_bearer_token("fake_unverified_token")
        assert False, "Unverified token should fail closed!"
    except HTTPException as e:
        assert e.status_code in [401, 503], f"Expected 401 or 503, got {e.status_code}"
    print("[PASS] Test 25: Regression - Firebase token verification strictly fails closed without bypassing.")

    print("\nALL 25 BACKEND AUTHORIZATION & SECURITY TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    asyncio.run(run_tests())
