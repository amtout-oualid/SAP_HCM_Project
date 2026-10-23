"""Integration tests for FastAPI endpoints using TestClient."""

import pytest
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_root_endpoint():
    """Verify root documentation and endpoint discovery."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "endpoints" in data
    assert "evaluate_score_for_rap" in data["endpoints"]


def test_health_endpoint():
    """Verify system health endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "sap-evaluator-api"
    assert "default_model" in data


def test_roles_endpoint():
    """Verify role catalog returns software_engineering_intern role."""
    response = client.get("/roles")
    assert response.status_code == 200
    data = response.json()
    assert "available_roles" in data
    roles = [r["name"] for r in data["available_roles"]]
    assert "software_engineering_intern" in roles

    intern_role = next(r for r in data["available_roles"] if r["name"] == "software_engineering_intern")
    category_keys = [c["key"] for c in intern_role["categories"]]
    assert "open_source" in category_keys
    assert "self_projects" in category_keys
    assert "production" in category_keys
    assert "technical_skills" in category_keys


def test_evaluate_invalid_url():
    """Verify endpoint rejects invalid Google Drive links with HTTP 400."""
    payload = {
        "gdrive_url": "https://example.com/invalid-link",
        "role": "software_engineering_intern"
    }
    response = client.post("/evaluate/score", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data


def test_evaluate_full_invalid_url():
    """Verify full evaluation endpoint rejects invalid Google Drive links with HTTP 400."""
    payload = {
        "gdrive_url": "https://example.com/invalid-link",
        "role": "software_engineering_intern",
        "offer_info": "Software Engineer"
    }
    response = client.post("/evaluate/full", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data


def test_evaluate_csv_invalid_url():
    """Verify CSV export endpoint rejects invalid Google Drive links with HTTP 400."""
    payload = {
        "gdrive_url": "https://example.com/invalid-link",
        "role": "software_engineering_intern"
    }
    response = client.post("/evaluate/csv", json=payload)
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data


def test_evaluate_missing_payload():
    """Verify endpoint returns 422 Unprocessable Entity when required gdrive_url is missing."""
    response = client.post("/evaluate/score", json={})
    assert response.status_code == 422

