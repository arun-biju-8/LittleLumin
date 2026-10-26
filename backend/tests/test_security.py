# backend/tests/test_security.py
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from firebase_admin import auth
from app.main import app
from app.core.config import settings

client = TestClient(app)

class TestAuthenticationDependencies:
    """Tests for token extraction and Firebase Auth ID token verification."""

    def test_missing_authorization_header_returns_401(self):
        """Endpoints requiring authentication must return 401 when no token is supplied."""
        response = client.get("/api/admin/verify")
        assert response.status_code == 401
        assert "WWW-Authenticate" in response.headers
        assert "Missing or malformed Authorization header" in response.json()["detail"]

    def test_malformed_authorization_header_returns_401(self):
        """Header without 'Bearer ' prefix must return 401."""
        response = client.get("/api/admin/verify", headers={"Authorization": "Basic 123456"})
        assert response.status_code == 401
        assert "Missing or malformed Authorization header" in response.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    def test_invalid_token_returns_401(self, mock_verify):
        """Invalid token signatures must raise 401."""
        mock_verify.side_effect = auth.InvalidIdTokenError("Invalid token signature")
        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer invalid_token_abc"})
        assert response.status_code == 401
        assert "Invalid authentication token" in response.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    def test_expired_token_returns_401(self, mock_verify):
        """Expired tokens must return 401 with explanatory detail."""
        mock_verify.side_effect = auth.ExpiredIdTokenError("Token expired", "detail")
        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer expired_token_abc"})
        assert response.status_code == 401
        assert "token has expired" in response.json()["detail"].lower()

    @patch("firebase_admin.auth.verify_id_token")
    def test_revoked_token_returns_401(self, mock_verify):
        """Revoked tokens must return 401."""
        mock_verify.side_effect = auth.RevokedIdTokenError("Token revoked")
        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer revoked_token_abc"})
        assert response.status_code == 401
        assert "token has been revoked" in response.json()["detail"].lower()


class TestAdminAuthorization:
    """Tests for Role-Based Access Control and admin verification."""

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.core.security.get_firestore_client")
    def test_non_admin_user_returns_403(self, mock_get_firestore, mock_verify):
        """Authenticated users lacking admin claims and adminUsers record must receive 403."""
        mock_verify.return_value = {
            "uid": "parent_user_1",
            "email": "parent@example.com",
            "userType": "parent"
        }
        # Firestore adminUsers document does not exist
        mock_doc = MagicMock()
        mock_doc.exists = False
        mock_firestore = MagicMock()
        mock_firestore.collection.return_value.document.return_value.get.return_value = mock_doc
        mock_get_firestore.return_value = mock_firestore

        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer valid_parent_token"})
        assert response.status_code == 403
        assert "Administrative privileges required" in response.json()["detail"]

    @patch("firebase_admin.auth.verify_id_token")
    def test_admin_with_admin_boolean_claim_returns_200(self, mock_verify):
        """User with custom claim {'admin': True} must be authorized."""
        mock_verify.return_value = {
            "uid": "admin_user_1",
            "email": "admin@littlelumin.com",
            "admin": True
        }
        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer admin_token_1"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "authorized"
        assert data["uid"] == "admin_user_1"
        assert data["role"] == "admin"

    @patch("firebase_admin.auth.verify_id_token")
    def test_admin_with_role_claim_returns_200(self, mock_verify):
        """User with custom claim {'role': 'admin'} must be authorized."""
        mock_verify.return_value = {
            "uid": "admin_user_2",
            "email": "superadmin@littlelumin.com",
            "role": "admin"
        }
        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer admin_token_2"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "authorized"
        assert data["uid"] == "admin_user_2"

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.core.security.get_firestore_client")
    def test_admin_with_firestore_membership_returns_200(self, mock_get_firestore, mock_verify):
        """User without token claims but present in 'adminUsers/{uid}' collection must be authorized."""
        mock_verify.return_value = {
            "uid": "admin_db_user_3",
            "email": "audit_admin@littlelumin.com",
        }
        mock_doc = MagicMock()
        mock_doc.exists = True
        mock_firestore = MagicMock()
        mock_firestore.collection.return_value.document.return_value.get.return_value = mock_doc
        mock_get_firestore.return_value = mock_firestore

        response = client.get("/api/admin/verify", headers={"Authorization": "Bearer admin_token_3"})
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "authorized"
        assert data["uid"] == "admin_db_user_3"


class TestDebugModelsEndpointSecurity:
    """Tests for /debug/models protection and environment toggling."""

    def test_debug_models_unauthenticated_returns_401(self):
        """Anonymous access to /debug/models must be rejected with 401."""
        response = client.get("/debug/models")
        assert response.status_code == 401

    @patch("firebase_admin.auth.verify_id_token")
    @patch("app.core.security.get_firestore_client")
    def test_debug_models_non_admin_returns_403(self, mock_get_firestore, mock_verify):
        """Non-admin access to /debug/models must be rejected with 403."""
        mock_verify.return_value = {"uid": "parent_user_2", "email": "parent2@example.com"}
        mock_doc = MagicMock()
        mock_doc.exists = False
        mock_firestore = MagicMock()
        mock_firestore.collection.return_value.document.return_value.get.return_value = mock_doc
        mock_get_firestore.return_value = mock_firestore

        response = client.get("/debug/models", headers={"Authorization": "Bearer parent_token"})
        assert response.status_code == 403

    @patch("firebase_admin.auth.verify_id_token")
    def test_debug_models_disabled_by_config_returns_403(self, mock_verify):
        """When ENABLE_DEBUG_ENDPOINTS is False, even admin access returns 403."""
        mock_verify.return_value = {"uid": "admin_user_4", "admin": True}
        settings.ENABLE_DEBUG_ENDPOINTS = False

        response = client.get("/debug/models", headers={"Authorization": "Bearer admin_token_4"})
        assert response.status_code == 403
        assert "disabled in this environment" in response.json()["detail"]


class TestExistingEndpointsUnbroken:
    """Verifies that parent workflows and AI endpoints remain operational without mandatory auth."""

    def test_ai_activity_accessible_without_auth(self):
        """Existing parent app activity generation must remain callable without token."""
        payload = {
            "skill_domain": "Cognitive",
            "difficulty": "Easy",
            "age_years": 4,
            "child_name": "TestChild"
        }
        response = client.post("/api/ai/generate-activity", json=payload)
        # Should succeed (200) with generated or fallback activity, never 401
        assert response.status_code in (200, 503)
        if response.status_code == 200:
            data = response.json()
            assert data["status"] == "success"
            assert "data" in data
            assert data["data"]["title"]
