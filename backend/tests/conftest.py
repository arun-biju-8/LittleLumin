# backend/tests/conftest.py
import sys
import os
import httpx

# Ensure backend root is on sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# Compatibility patch for Starlette 0.27 TestClient with newer httpx versions
_orig_httpx_init = httpx.Client.__init__
def _compat_httpx_init(self, *args, **kwargs):
    kwargs.pop("app", None)
    return _orig_httpx_init(self, *args, **kwargs)
httpx.Client.__init__ = _compat_httpx_init

import pytest
from starlette.testclient import TestClient
from app.main import app
from app.core.config import settings

@pytest.fixture(scope="session")
def client():
    """Provides a synchronous TestClient instance for API tests."""
    return TestClient(app)

@pytest.fixture(autouse=True)
def reset_settings():
    """Ensure settings are restored after each test."""
    orig_debug = settings.ENABLE_DEBUG_ENDPOINTS
    yield
    settings.ENABLE_DEBUG_ENDPOINTS = orig_debug
