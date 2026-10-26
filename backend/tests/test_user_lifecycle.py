# backend/tests/test_user_lifecycle.py
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from firebase_admin import auth, firestore

from app.main import app

client = TestClient(app)

class MockFirestore:
    def __init__(self):
        self._collections = {}

    def collection(self, name):
        if name not in self._collections:
            col = MagicMock()
            self._collections[name] = col
        return self._collections[name]


class TestUserLifecycleEndpoints:
    """Comprehensive test suite for Phase 3 secure user lifecycle endpoints."""

    def test_user_lifecycle_unauthenticated_returns_401(self):
        """Unauthenticated requests must be rejected with 401."""
        res_suspend = client.post("/api/admin/users/usr_1/suspend", json={"category": "Security review", "reason": "Suspicious login"})
        assert res_suspend.status_code == 401

        res_restore = client.post("/api/admin/users/usr_1/restore", json={"restorationReason": "Account verified"})
        assert res_restore.status_code == 401

        res_deactivate = client.post("/api/admin/users/usr_1/deactivate", json={"reason": "Requested inactivity"})
        assert res_deactivate.status_code == 401

        res_delete = client.post("/api/admin/users/usr_1/delete", json={"reason": "User request", "confirmation": "usr_1"})
        assert res_delete.status_code == 401

        res_warning = client.post("/api/admin/users/usr_1/warning", json={"category": "Policy", "reason": "Minor breach"})
        assert res_warning.status_code == 401

        res_recovery = client.post("/api/admin/users/recovery-requests/req_1/decision", json={"userId": "usr_1", "decisionStatus": "approved"})
        assert res_recovery.status_code == 401

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.core.security.get_firestore_client")
    def test_user_lifecycle_non_admin_returns_403(self, mock_get_fs, mock_verify):
        """Authenticated non-admin users must be rejected with 403."""
        mock_verify.return_value = {
            "uid": "parent_regular_user",
            "email": "parent@example.com",
            "role": "parent",
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_fs.collection("adminUsers").document.return_value.get.return_value.exists = False
        mock_fs.collection("users").document.return_value.get.return_value.exists = False

        res = client.post(
            "/api/admin/users/usr_target/suspend",
            headers={"Authorization": "Bearer parent_token"},
            json={"category": "Security review", "reason": "Test suspension"}
        )
        assert res.status_code == 403
        assert "Administrative privileges required" in res.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_suspend_self_prohibited_returns_400(self, mock_get_fs, mock_verify):
        """Admins cannot suspend their own account."""
        mock_verify.return_value = {
            "uid": "admin_uid_super",
            "email": "superadmin@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs

        res = client.post(
            "/api/admin/users/admin_uid_super/suspend",
            headers={"Authorization": "Bearer admin_token"},
            json={"category": "Policy violation", "reason": "Self suspend attempt"}
        )
        assert res.status_code == 400
        assert "cannot suspend their own account" in res.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_suspend_administrator_prohibited_returns_400(self, mock_get_fs, mock_verify):
        """Admins cannot suspend fellow administrator accounts."""
        mock_verify.return_value = {
            "uid": "admin_uid_1",
            "email": "admin1@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs

        # Target user is in adminUsers
        mock_admin_doc = MagicMock()
        mock_admin_doc.exists = True
        mock_fs.collection("adminUsers").document.return_value.get.return_value = mock_admin_doc

        res = client.post(
            "/api/admin/users/target_admin_uid/suspend",
            headers={"Authorization": "Bearer admin_token"},
            json={"category": "Policy violation", "reason": "Attempt on admin"}
        )
        assert res.status_code == 400
        assert "Target user is an administrator" in res.json()["detail"] or "last active administrator" in res.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_suspend_user_success_disables_auth_and_updates_firestore(self, mock_get_fs, mock_get_auth, mock_verify):
        """Suspending a user disables Firebase Auth, revokes tokens, updates Firestore, and logs audit."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        # Target user is not an admin
        mock_fs.collection("adminUsers").document.return_value.get.return_value.exists = False
        mock_auth.get_user.return_value.custom_claims = {}

        # Target user doc in users exists
        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"email": "violator@example.com", "name": "Violator"}
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        audit_doc_ref = MagicMock()
        audit_doc_ref.id = "audit_suspension_1"
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/target_violator/suspend",
            headers={"Authorization": "Bearer admin_token"},
            json={
                "category": "Security review",
                "reason": "Repeated spam generation",
                "isTemporary": True,
                "suspensionUntil": "2026-11-15T00:00:00Z"
            }
        )

        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["user_id"] == "target_violator"
        assert data["account_status"] == "suspended"

        # Verify Firebase Auth account disabled and refresh tokens revoked
        mock_auth.update_user.assert_called_with("target_violator", disabled=True)
        mock_auth.revoke_refresh_tokens.assert_called_with("target_violator")

        # Verify Firestore user doc updated
        update_args = mock_fs.collection("users").document.return_value.update.call_args[0][0]
        assert update_args["status"] == "suspended"
        assert update_args["isSuspended"] is True
        assert update_args["suspendedBy"] == "lead_admin"
        assert update_args["suspensionReason"] == "Repeated spam generation"

        # Verify audit log written
        audit_args = audit_doc_ref.set.call_args[0][0]
        assert audit_args["action"] == "account_suspended"
        assert audit_args["actorId"] == "lead_admin"
        assert audit_args["targetId"] == "target_violator"

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_restore_user_success_enables_auth_and_updates_firestore(self, mock_get_fs, mock_get_auth, mock_verify):
        """Restoring a user re-enables Firebase Auth, updates status to active, and logs audit."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        audit_doc_ref = MagicMock()
        audit_doc_ref.id = "audit_restore_1"
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/target_restored/restore",
            headers={"Authorization": "Bearer admin_token"},
            json={"restorationReason": "Identity successfully verified via compliance check."}
        )

        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["account_status"] == "active"

        # Verify Firebase Auth re-enabled
        mock_auth.update_user.assert_called_with("target_restored", disabled=False)

        # Verify Firestore updated
        update_args = mock_fs.collection("users").document.return_value.update.call_args[0][0]
        assert update_args["status"] == "active"
        assert update_args["isSuspended"] is False
        assert update_args["restoredBy"] == "lead_admin"

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.core.security.get_firestore_client")
    def test_suspended_user_access_rejected_with_403(self, mock_get_fs, mock_verify):
        """Tokens belonging to suspended users must be rejected with 403 Forbidden on protected routes."""
        mock_verify.return_value = {
            "uid": "suspended_parent_99",
            "email": "suspended@example.com",
            "role": "parent",
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs

        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"status": "suspended", "name": "Suspended Parent"}
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        # Accessing an endpoint that requires authenticated user
        res = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer valid_token_but_user_suspended"},
            json={"action": "test_action"}
        )
        assert res.status_code == 403
        assert "Account is suspended" in res.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_deactivate_user_success(self, mock_get_fs, mock_get_auth, mock_verify):
        """Deactivating an account pauses access and marks status as deactivated."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        mock_fs.collection("adminUsers").document.return_value.get.return_value.exists = False
        mock_auth.get_user.return_value.custom_claims = {}

        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        audit_doc_ref = MagicMock()
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/usr_deact/deactivate",
            headers={"Authorization": "Bearer admin_token"},
            json={"reason": "User requested account pause"}
        )
        assert res.status_code == 200
        assert res.json()["account_status"] == "deactivated"
        mock_auth.update_user.assert_called_with("usr_deact", disabled=True)

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_permanent_deletion_confirmation_mismatch_returns_400(self, mock_get_fs, mock_get_auth, mock_verify):
        """Permanent deletion without typing the exact user email or UID must be rejected with 400."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        mock_fs.collection("adminUsers").document.return_value.get.return_value.exists = False
        mock_auth.get_user.return_value.custom_claims = {}

        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {"email": "user_delete_me@example.com"}
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        res = client.post(
            "/api/admin/users/usr_to_delete/delete",
            headers={"Authorization": "Bearer admin_token"},
            json={"reason": "GDPR erase", "confirmation": "wrong_confirmation_string"}
        )
        assert res.status_code == 400
        assert "Confirmation mismatch" in res.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_permanent_deletion_success_with_safeguards_and_cleanup(self, mock_get_fs, mock_get_auth, mock_verify):
        """Valid permanent deletion detaches children, terminates cases, deletes user and auth, and logs audit."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        target_uid = "usr_gdpr_target"
        target_email = "gdpr_user@example.com"

        mock_fs.collection("adminUsers").document.return_value.get.return_value.exists = False
        mock_auth.get_user.return_value.custom_claims = {}

        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {
            "email": target_email,
            "userType": "parent",
        }
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        # Mock child doc stream
        mock_child = MagicMock()
        mock_fs.collection("children").where.return_value.stream.return_value = [mock_child]

        # Mock case doc stream
        mock_case = MagicMock()
        mock_fs.collection("specialistCases").where.return_value.stream.return_value = [mock_case]

        audit_doc_ref = MagicMock()
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            f"/api/admin/users/{target_uid}/delete",
            headers={"Authorization": "Bearer admin_token"},
            json={
                "reason": "Verified DPDP erasure request",
                "confirmation": target_email,
            }
        )

        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert data["cleanup_summary"]["auth_deleted"] is True
        assert data["cleanup_summary"]["user_doc_deleted"] is True
        assert data["cleanup_summary"]["children_detached"] == 1
        assert data["cleanup_summary"]["cases_terminated"] == 1

        # Verify child detached
        mock_child.reference.update.assert_called()
        # Verify case terminated
        mock_case.reference.update.assert_called()
        # Verify user doc deleted
        mock_fs.collection("users").document.return_value.delete.assert_called()
        # Verify Firebase Auth deleted
        mock_auth.delete_user.assert_called_with(target_uid)

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_recovery_decision_approve_restores_user_and_updates_request(self, mock_get_fs, mock_get_auth, mock_verify):
        """Approving a recovery request restores the account and updates the request doc."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        mock_req_doc = MagicMock()
        mock_req_doc.exists = True
        mock_req_doc.to_dict.return_value = {
            "userId": "usr_recovering",
            "status": "pending_review",
        }
        mock_fs.collection("accountRecoveryRequests").document.return_value.get.return_value = mock_req_doc

        audit_doc_ref = MagicMock()
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/recovery-requests/req_test_1/decision",
            headers={"Authorization": "Bearer admin_token"},
            json={
                "userId": "usr_recovering",
                "decisionStatus": "approved",
                "reviewerNotes": "Explained security incident and submitted 2FA proof.",
            }
        )

        assert res.status_code == 200
        assert res.json()["decision_status"] == "approved"

        # Verify recovery request updated to approved
        mock_fs.collection("accountRecoveryRequests").document.return_value.update.assert_called()
        # Verify Auth re-enabled
        mock_auth.update_user.assert_called_with("usr_recovering", disabled=False)
        # Verify Firestore user doc status restored to active
        mock_fs.collection("users").document.return_value.update.assert_called()

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_issue_warning_success_records_warning_and_audit(self, mock_get_fs, mock_verify):
        """Issuing a warning appends a warning record to the user and writes an audit event."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs

        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_fs.collection("users").document.return_value.get.return_value = mock_user_doc

        audit_doc_ref = MagicMock()
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/usr_warn_me/warning",
            headers={"Authorization": "Bearer admin_token"},
            json={
                "category": "Repeated policy violations",
                "reason": "Exceeded allowable unconsented share attempts",
                "notes": "Reviewed with child safety team",
                "sendEmail": True,
            }
        )

        assert res.status_code == 200
        data = res.json()
        assert data["status"] == "success"
        assert "warning_id" in data
        mock_fs.collection("users").document.return_value.update.assert_called()

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_auth_client")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_process_appeal_decision_approve_restores_user_and_audits(self, mock_get_fs, mock_get_auth, mock_verify):
        """Approving an LLG appeal updates the appeal, restores the user account and records an audit log."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs
        mock_auth = MagicMock()
        mock_get_auth.return_value = mock_auth

        mock_appeal_doc = MagicMock()
        mock_appeal_doc.exists = True
        mock_appeal_doc.to_dict.return_value = {
            "llgId": "spec_appealing",
            "status": "pending",
        }
        mock_fs.collection("llgAppeals").document.return_value.get.return_value = mock_appeal_doc

        audit_doc_ref = MagicMock()
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/appeals/app_test_101/decision",
            headers={"Authorization": "Bearer admin_token"},
            json={
                "llgId": "spec_appealing",
                "approve": True,
                "adminNotes": "License recertification verified with governing board.",
                "restorationConditions": ["Complete annual refresher"],
                "sendEmail": True,
            }
        )

        assert res.status_code == 200
        data = res.json()
        assert data["decision"] == "approved"
        assert data["account_restored"] is True

        # Verify appeal document updated
        mock_fs.collection("llgAppeals").document.return_value.update.assert_called()
        # Verify Auth re-enabled
        mock_auth.update_user.assert_called_with("spec_appealing", disabled=False)
        # Verify user doc status set back to active
        mock_fs.collection("users").document.return_value.update.assert_called()

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.user_routes.get_firestore_client")
    def test_update_complaint_status_success_and_audits(self, mock_get_fs, mock_verify):
        """Updating a parent complaint updates investigation details and records an audit log."""
        mock_verify.return_value = {
            "uid": "lead_admin",
            "email": "lead@littlelumin.com",
            "admin": True,
        }
        mock_fs = MockFirestore()
        mock_get_fs.return_value = mock_fs

        mock_comp_doc = MagicMock()
        mock_comp_doc.exists = True
        mock_comp_doc.to_dict.return_value = {
            "parentId": "parent_42",
            "llgId": "spec_99",
            "status": "pending",
        }
        mock_fs.collection("parentComplaints").document.return_value.get.return_value = mock_comp_doc

        audit_doc_ref = MagicMock()
        mock_fs.collection("adminAuditLogs").document.return_value = audit_doc_ref

        res = client.post(
            "/api/admin/users/complaints/comp_test_202/status",
            headers={"Authorization": "Bearer admin_token"},
            json={
                "newStatus": "under_investigation",
                "investigationNotes": "Contacted parent and requested consultation logs.",
                "notifyParent": True,
            }
        )

        assert res.status_code == 200
        data = res.json()
        assert data["new_status"] == "under_investigation"
        mock_fs.collection("parentComplaints").document.return_value.update.assert_called()

