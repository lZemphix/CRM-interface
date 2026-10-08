from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from auth import sessions
from main import app
from tasks import board_store


@pytest.fixture
def client() -> Iterator[TestClient]:
    sessions.clear()
    board_store.reset()
    with TestClient(app) as test_client:
        login = test_client.post(
            "/auth/login", json={"login": "admin", "password": "123456789098765"}
        )
        assert login.status_code == 200
        test_client.headers["Authorization"] = f"Bearer {login.json()['access_token']}"
        yield test_client
