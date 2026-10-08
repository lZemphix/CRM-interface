from datetime import date, datetime

import pytest
from fastapi.testclient import TestClient


def test_customer_list_matches_backend_contract(
    client: TestClient,
) -> None:
    response = client.get("/customers")
    assert response.status_code == 200
    page = response.json()
    assert set(page) == {"items", "total", "limit", "offset"}
    assert (page["total"], page["limit"], page["offset"]) == (3, 50, 0)
    customers = page["items"]
    assert isinstance(customers, list)
    assert [customer["full_name"] for customer in customers] == [
        "Анна Петрова",
        "Максим Дорофеев",
        "Ольга Синицына",
    ]
    for customer in customers:
        assert set(customer) == {
            "id",
            "full_name",
            "gender",
            "date_of_birth",
            "status",
            "primary_contact",
            "acquisition_source_name",
        }
        if customer["date_of_birth"] is not None:
            date.fromisoformat(customer["date_of_birth"])
        assert customer["primary_contact"] is None or isinstance(
            customer["primary_contact"], str
        )


def test_customer_detail_matches_backend_contract(client: TestClient) -> None:
    response = client.get("/customers/1")
    assert response.status_code == 200
    detail = response.json()
    assert set(detail) == {
        "id",
        "full_name",
        "gender",
        "date_of_birth",
        "status",
        "responsible_employee_id",
        "created_by_employee_id",
        "home_branch_id",
        "acquisition_source_id",
        "acquisition_source_code",
        "acquisition_source_name",
        "registration_method",
        "referred_by_customer_id",
        "created_at",
        "updated_at",
        "contacts",
        "notes",
    }
    assert detail["contacts"] == [
        {
            "id": 101,
            "type": "phone",
            "value": "+7 916 233-10-45",
            "label": "Основной",
            "is_primary": True,
            "created_at": "2026-08-12T10:00:00Z",
        },
        {
            "id": 102,
            "type": "email",
            "value": "anna.petrova@mail.ru",
            "label": "Личный",
            "is_primary": False,
            "created_at": "2026-08-12T10:05:00Z",
        },
    ]
    assert len(detail["notes"]) == 2
    assert detail["notes"][0]["text"]
    assert datetime.fromisoformat(detail["notes"][0]["created_at"]).tzinfo
    assert datetime.fromisoformat(detail["created_at"]).tzinfo
    assert datetime.fromisoformat(detail["updated_at"]).tzinfo


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


def test_pagination_and_empty_page(client: TestClient) -> None:
    all_customers = client.get("/customers").json()["items"]
    page = client.get("/customers", params={"limit": 1, "offset": 1})
    assert page.status_code == 200
    assert page.json() == {
        "items": all_customers[1:2],
        "total": 3,
        "limit": 1,
        "offset": 1,
    }
    assert client.get("/customers?offset=100").json()["items"] == []
    assert client.get("/customers?limit=1").json()["items"] == all_customers[:1]


@pytest.mark.parametrize(
    "query",
    ["limit=0", "limit=-1", "limit=101", "offset=-1", "limit=abc", "offset=1.5"],
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
    not_found = client.get("/customers/999")
    assert not_found.status_code == 404
    assert not_found.json() == {
        "detail": {"code": "customer_not_found", "message": "Клиент не найден"}
    }
    for identifier in ("0", "-1", "not-an-id", str(2**63)):
        assert client.get(f"/customers/{identifier}").status_code == 422
    assert client.post("/customers", json={}).status_code == 405
