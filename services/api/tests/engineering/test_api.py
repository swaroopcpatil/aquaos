from fastapi.testclient import TestClient

from app.main import create_app
from tests.engineering.test_calculator import BASE

client = TestClient(create_app())
URL = "/api/v1/hydraulics/calculate"


def test_calculate_returns_contract_shape():
    response = client.post(URL, json=BASE)
    assert response.status_code == 200
    body = response.json()
    assert set(body) == {
        "methodology_version", "levels", "head", "tdh_breakdown", "pipe", "flow", "power",
        "assumptions", "warnings", "disclaimer",
    }
    assert abs(body["head"]["total_dynamic_head_m"] - 72.1842) < 0.01
    assert body["flow"]["m3_per_h"] == 10.0 or abs(body["flow"]["m3_per_h"] - 10.0) < 1e-9


def test_calculate_is_reproducible_over_http():
    assert client.post(URL, json=BASE).json() == client.post(URL, json=BASE).json()


def test_missing_pumping_water_level_returns_422():
    payload = {k: v for k, v in BASE.items() if k != "pumping_water_level_m"}
    response = client.post(URL, json=payload)
    assert response.status_code == 422
    assert "pumping_water_level_m" in str(response.json()["detail"])


def test_contradictory_levels_return_422_with_reason():
    response = client.post(URL, json={**BASE, "pumping_water_level_m": 30})
    assert response.status_code == 422
    assert "static water level" in str(response.json()["detail"])


def test_zero_flow_and_bad_diameter_return_422():
    assert client.post(URL, json={**BASE, "flow_rate": 0}).status_code == 422
    assert client.post(URL, json={**BASE, "pipe_internal_diameter_mm": 0}).status_code == 422
    assert client.post(URL, json={**BASE, "flow_rate": "fast"}).status_code == 422
