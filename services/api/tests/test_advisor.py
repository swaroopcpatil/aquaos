import json

import pytest
from fastapi.testclient import TestClient

from app.ai import advisor
from app.ai.provider import ModelProvider
from app.main import create_app

CALC = {
    "head": {"total_dynamic_head_m": 68.41, "total_friction_loss_m": 3.41},
    "flow": {"m3_per_h": 10.0, "l_per_s": 2.778},
    "power": {"input_power_kw": 3.88, "input_power_hp": 5.2},
    "pipe": {"velocity_m_s": 1.41, "friction_factor": 0.0194},
    "assumptions": ["Clean pipe"],
}


@pytest.fixture
def client():
    return TestClient(create_app(), raise_server_exceptions=False)


def post(client, **kw):
    return client.post("/api/v1/advisor/explain", json={"calculation": CALC, **kw})


@pytest.mark.parametrize("aud", ["farmer", "dealer", "technician"])
def test_mock_uses_input_numbers(client, aud):
    r = post(client, audience=aud)
    assert r.status_code == 200
    body = r.json()
    assert body["provider"] == "mock"
    assert "68.41" in body["summary"] and "10.0" in body["summary"]
    assert "5.2" in body["summary"]


def test_numbers_follow_input(client):
    calc = json.loads(json.dumps(CALC))
    calc["head"]["total_dynamic_head_m"] = 99.99
    r = client.post("/api/v1/advisor/explain", json={"calculation": calc})
    assert "99.99" in r.json()["summary"]


def _patch(monkeypatch, provider):
    monkeypatch.setattr(advisor, "get_provider", lambda: provider)


class Bad(ModelProvider):
    name = "bad"

    def generate(self, system, user):
        return '{"summary": "x"}'


class Boom(ModelProvider):
    name = "boom"

    def generate(self, system, user):
        raise TimeoutError("timed out")


def test_invalid_output_503(client, monkeypatch):
    _patch(monkeypatch, Bad())
    assert post(client).status_code == 503


def test_provider_exception_503(client, monkeypatch):
    _patch(monkeypatch, Boom())
    r = post(client)
    assert r.status_code == 503 and "detail" in r.json()


def test_long_question_422(client):
    assert post(client, question="x" * 501).status_code == 422


def test_incomplete_calculation_422(client):
    r = client.post("/api/v1/advisor/explain", json={"calculation": {"head": {}}})
    assert r.status_code == 422
