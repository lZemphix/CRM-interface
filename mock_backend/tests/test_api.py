from collections.abc import Iterator
from datetime import date, datetime

import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def client() -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client


def test_customer_list_keeps_flutter_fields_and_adds_template_summary(
    client: TestClient,
) -> None:
    response = client.get("/customers")
    assert response.status_code == 200
    customers = response.json()
    assert isinstance(customers, list)
    assert [customer["full_name"] for customer in customers] == [
        "Анна Петрова",
        "Максим Дорофеев",
        "Ольга Синицына",
    ]
    for customer in customers:
        assert isinstance(customer["id"], int)
        for field in (
            "full_name",
            "status",
            "acquisition_source_name",
            "primary_phone",
            "primary_branch_name",
            "responsible_employee_name",
        ):
            assert isinstance(customer[field], str)
        for field in ("gender", "date_of_birth", "primary_contact"):
            assert customer[field] is None or isinstance(customer[field], str)
        if customer["date_of_birth"] is not None:
            date.fromisoformat(customer["date_of_birth"])
        assert customer["primary_contact"] == customer["primary_phone"]
        assert datetime.fromisoformat(customer["last_interaction_at"]).tzinfo
        assert "notes" not in customer
        assert "contacts" not in customer


def test_customer_detail_contains_template_sections(client: TestClient) -> None:
    summary = client.get("/customers?limit=1").json()[0]
    response = client.get("/customers/1")
    assert response.status_code == 200
    detail = response.json()
    assert all(detail[key] == value for key, value in summary.items())
    assert detail["contacts"] == [
        {"id": 101, "type": "phone", "value": "+7 916 233-10-45", "is_primary": True},
        {
            "id": 102,
            "type": "email",
            "value": "anna.petrova@mail.ru",
            "is_primary": False,
        },
    ]
    assert len(detail["notes"]) == 2
    assert detail["notes"][0]["author_name"] == "Ирина Ковалёва"
    assert detail["notes"][0]["text"]
    assert datetime.fromisoformat(detail["notes"][0]["created_at"]).tzinfo
    assert detail["assignment_history"][0]["new_employee_name"] == "Ирина Ковалёва"
    assert detail["tasks"][0]["customer_id"] == detail["id"]
    assert datetime.fromisoformat(detail["tasks"][0]["due_at"]).tzinfo
    assert detail["last_interaction_at"] == max(
        event["occurred_at"] for event in detail["interactions"]
    )


def test_referral_and_registration_are_distinct(client: TestClient) -> None:
    referral = client.get("/customers/2").json()
    integration = client.get("/customers/3").json()
    assert referral["acquisition_source_code"] == "referral"
    assert referral["referred_by_customer_id"] == 1
    assert referral["registration_method"] == "employee"
    assert integration["acquisition_source_code"] == "website"
    assert integration["referred_by_customer_id"] is None
    assert integration["registration_method"] == "integration"
    assert integration["created_by_employee_id"] is None
    assert integration["contacts"][1]["type"] == "telegram"
    assert integration["tasks"][0]["assignee_employee_id"] is None


def test_pagination_and_empty_page(client: TestClient) -> None:
    all_customers = client.get("/customers").json()
    page = client.get("/customers", params={"limit": 1, "offset": 1})
    assert page.status_code == 200
    assert page.json() == all_customers[1:2]
    assert client.get("/customers?offset=100").json() == []
    assert client.get("/customers?limit=1").json() == all_customers[:1]


@pytest.mark.parametrize(
    "query", ["limit=0", "limit=-1", "offset=-1", "limit=abc", "offset=1.5"]
)
def test_invalid_pagination(client: TestClient, query: str) -> None:
    response = client.get(f"/customers?{query}")
    assert response.status_code == 422
    assert isinstance(response.json()["detail"], list)


def test_health(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_unsupported_endpoints(client: TestClient) -> None:
    assert client.get("/customers/999").status_code == 404
    assert client.get("/customers/not-an-id").status_code == 422
    assert client.post("/customers", json={}).status_code == 405
