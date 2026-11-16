from fastapi.testclient import TestClient

from app.main import create_app


def test_health():
    r = TestClient(create_app()).get("/api/v1/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok", "service": "aquaos-api", "version": "0.1.0"}
