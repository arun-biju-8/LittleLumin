# backend/tests/test_audit.py
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from firebase_admin import auth, firestore

from app.main import app

client = TestClient(app)

class TestAuditLoggingEndpoint:
    """Tests for POST /api/cases/audit-logs."""

    def test_audit_log_unauthenticated_returns_401(self):
        """Requests without Authorization header must return 401."""
        response = client.post(
            "/api/cases/audit-logs",
            json={"action": "user_warning_issued", "target_id": "usr_test"}
        )
        assert response.status_code == 401
        assert "WWW-Authenticate" in response.headers
        assert "Authorization header" in response.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.core.security.get_firestore_client")
    def test_audit_log_non_admin_returns_403(self, mock_get_firestore, mock_verify):
        """Authenticated users lacking administrator privileges must be rejected with 403."""
        mock_verify.return_value = {
            "uid": "regular_parent_user",
            "email": "parent@example.com",
            "role": "parent",
        }
        # Mock Firestore returning non-existent admin doc
        mock_fs = MagicMock()
        mock_get_firestore.return_value = mock_fs
        mock_doc = MagicMock()
        mock_doc.exists = False
        mock_fs.collection.return_value.document.return_value.get.return_value = mock_doc

        response = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer regular_user_token"},
            json={"action": "user_warning_issued", "target_id": "usr_target_1"}
        )
        assert response.status_code == 403
        assert "Administrative privileges required" in response.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.audit_routes.get_firestore_client")
    def test_audit_log_valid_admin_writes_to_firestore(self, mock_get_fs, mock_verify):
        """Authorized admins must successfully write audit records to adminAuditLogs."""
        mock_verify.return_value = {
            "uid": "admin_uid_99",
            "email": "lead_admin@littlelumin.com",
            "admin": True,
        }

        mock_fs = MagicMock()
        mock_get_fs.return_value = mock_fs

        mock_doc_ref = MagicMock()
        mock_doc_ref.id = "audit_doc_random_id_123"
        mock_fs.collection.return_value.document.return_value = mock_doc_ref

        payload = {
            "action": "user_warning_issued",
            "target_id": "usr_violator_1",
            "case_id": "case_101",
            "child_id": "child_202",
            "details": {
                "category": "Inappropriate Content",
                "reason": "Repeated policy violations",
                "notes": "Second warning issued",
            }
        }

        response = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer valid_admin_token"},
            json=payload
        )

        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "success"
        assert data["log_id"] == "audit_doc_random_id_123"
        assert data["action"] == "user_warning_issued"

        # Verify collection call
        mock_fs.collection.assert_called_with("adminAuditLogs")
        mock_doc_ref.set.assert_called_once()
        written_data = mock_doc_ref.set.call_args[0][0]

        # Verify authoritative fields
        assert written_data["action"] == "user_warning_issued"
        assert written_data["actorId"] == "admin_uid_99"
        assert written_data["actorEmail"] == "lead_admin@littlelumin.com"
        assert written_data["actorType"] == "admin"
        assert written_data["targetId"] == "usr_violator_1"
        assert written_data["caseId"] == "case_101"
        assert written_data["childId"] == "child_202"
        assert written_data["timestamp"] == firestore.SERVER_TIMESTAMP
        assert written_data["details"]["category"] == "Inappropriate Content"

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.audit_routes.get_firestore_client")
    def test_audit_log_sanitizes_sensitive_fields_and_spoofed_actors(self, mock_get_fs, mock_verify):
        """Passwords, tokens, credentials, and client-spoofed actor metadata must be stripped."""
        mock_verify.return_value = {
            "uid": "real_admin_uid_42",
            "email": "real_admin@littlelumin.com",
            "role": "admin",
        }

        mock_fs = MagicMock()
        mock_get_fs.return_value = mock_fs
        mock_doc_ref = MagicMock()
        mock_doc_ref.id = "audit_doc_sanitized"
        mock_fs.collection.return_value.document.return_value = mock_doc_ref

        dirty_payload = {
            "action": "account_suspended",
            "targetId": "usr_bad_actor",
            "details": {
                "actorId": "spoofed_admin_id",
                "actorEmail": "spoofed_email@evil.com",
                "timestamp": "2020-01-01T00:00:00Z",
                "password": "ClearTextPassword123",
                "user_token": "bearer secret_token_xyz",
                "service_account_key": "private_cert_data",
                "api_key": "AIzaSySecret",
                "client_secret": "oauth_secret",
                "valid_admin_reason": "Terms violation",
                "nested": {
                    "sub_token": "inner_secret",
                    "safe_note": "Legitimate diagnostic detail"
                }
            }
        }

        response = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer admin_token"},
            json=dirty_payload
        )

        assert response.status_code == 201
        written_data = mock_doc_ref.set.call_args[0][0]

        # Authoritative fields MUST NOT be spoofed
        assert written_data["actorId"] == "real_admin_uid_42"
        assert written_data["actorEmail"] == "real_admin@littlelumin.com"
        assert written_data["targetId"] == "usr_bad_actor"

        # Details must NOT contain sensitive or spoofed fields
        details = written_data["details"]
        assert "actorId" not in details
        assert "actorEmail" not in details
        assert "timestamp" not in details
        assert "password" not in details
        assert "user_token" not in details
        assert "service_account_key" not in details
        assert "api_key" not in details
        assert "client_secret" not in details
        assert details["valid_admin_reason"] == "Terms violation"
        assert "sub_token" not in details["nested"]
        assert details["nested"]["safe_note"] == "Legitimate diagnostic detail"

    @patch("firebase_admin.auth.verify_id_token")
    def test_audit_log_malformed_payload_returns_422(self, mock_verify):
        """Malformed payloads (empty action, invalid types) must be rejected with 422."""
        mock_verify.return_value = {
            "uid": "admin_uid_1",
            "email": "admin@littlelumin.com",
            "admin": True,
        }

        # Empty action
        res1 = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer admin_token"},
            json={"action": "   "}
        )
        assert res1.status_code == 422

        # Missing action entirely
        res2 = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer admin_token"},
            json={"target_id": "usr_1"}
        )
        assert res2.status_code == 422

        # Action with malicious injection chars
        res3 = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer admin_token"},
            json={"action": "action<script>alert(1)</script>"}
        )
        assert res3.status_code == 422

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.audit_routes.get_firestore_client")
    def test_audit_log_firestore_failure_returns_500(self, mock_get_fs, mock_verify):
        """Database write failures must raise 500 and not silently succeed."""
        mock_verify.return_value = {
            "uid": "admin_uid_1",
            "email": "admin@littlelumin.com",
            "admin": True,
        }

        mock_fs = MagicMock()
        mock_get_fs.return_value = mock_fs
        mock_doc_ref = MagicMock()
        mock_doc_ref.set.side_effect = Exception("Firestore connection timed out")
        mock_fs.collection.return_value.document.return_value = mock_doc_ref

        response = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer admin_token"},
            json={"action": "account_suspended", "target_id": "usr_fail"}
        )

        assert response.status_code == 500
        assert "Failed to record audit event" in response.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.routes.audit_routes.get_firestore_client")
    def test_audit_log_database_unavailable_returns_503(self, mock_get_fs, mock_verify):
        """When Firestore client cannot be initialized, returns 503."""
        mock_verify.return_value = {
            "uid": "admin_uid_1",
            "email": "admin@littlelumin.com",
            "admin": True,
        }
        mock_get_fs.return_value = None

        response = client.post(
            "/api/cases/audit-logs",
            headers={"Authorization": "Bearer admin_token"},
            json={"action": "account_suspended", "target_id": "usr_fail"}
        )

        assert response.status_code == 503
        assert "temporarily unavailable" in response.json()["detail"]
