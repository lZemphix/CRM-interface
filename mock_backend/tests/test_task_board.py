from datetime import datetime

from fastapi.testclient import TestClient


def test_fake_login_refresh_and_logout(client: TestClient) -> None:
    wrong = client.post("/auth/login", json={"login": "admin", "password": "wrong"})
    assert wrong.status_code == 401
    assert wrong.json()["detail"]["code"] == "invalid_credentials"

    login = client.post(
        "/auth/login", json={"login": "admin", "password": "123456789098765"}
    )
    assert login.status_code == 200
    tokens = login.json()
    assert tokens["must_change_password"] is False
    assert tokens["token_type"] == "bearer"
    assert datetime.fromisoformat(tokens["access_expires_at"]).tzinfo
    assert datetime.fromisoformat(tokens["refresh_expires_at"]).tzinfo
    assert login.headers["Cache-Control"] == "no-store"

    assert (
        client.get(
            "/task-board", headers={"Authorization": "Bearer invalid"}
        ).status_code
        == 401
    )
    assert (
        client.get(
            "/customers", headers={"Authorization": "Bearer invalid"}
        ).status_code
        == 401
    )

    refreshed = client.post(
        "/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refreshed.status_code == 200
    new_tokens = refreshed.json()
    assert new_tokens["access_token"] != tokens["access_token"]
    assert new_tokens["refresh_token"] != tokens["refresh_token"]
    assert (
        client.post(
            "/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
        ).status_code
        == 401
    )
    assert (
        client.get(
            "/task-board", headers={"Authorization": f"Bearer {tokens['access_token']}"}
        ).status_code
        == 401
    )

    client.headers["Authorization"] = f"Bearer {new_tokens['access_token']}"
    assert client.post("/auth/logout").status_code == 204
    assert client.get("/task-board").status_code == 401
    assert (
        client.post(
            "/auth/refresh", json={"refresh_token": new_tokens["refresh_token"]}
        ).status_code
        == 401
    )


def test_board_response_uses_backend_read_shape(client: TestClient) -> None:
    response = client.get("/task-board")
    assert response.status_code == 200
    board = response.json()
    assert [column["name"] for column in board["columns"]] == [
        "Общая очередь",
        "В работе",
        "На проверке",
        "Готово",
    ]
    assert board["columns"][-1]["counts_as_done"] is True
    assert len(board["tasks"]) == 3
    task = board["tasks"][0]
    assert set(task) == {
        "id",
        "column_id",
        "title",
        "description",
        "status",
        "priority",
        "responsible_employee_id",
        "responsible",
        "due_at",
        "customer",
        "branch_id",
        "subtasks",
        "version",
    }
    assert set(task["subtasks"][0]) == {"id", "title", "done", "order"}
    assert board["truncated"] is False
    assert board["columns"][0]["status"] == "new"
    assert board["columns"][0]["version"] == 1
    assert task["customer"] == {"id": 1, "full_name": "Анна Петрова"}
    assert task["responsible"] is None
    assert client.get("/employees").json()[0] == {
        "id": 1,
        "full_name": "Ирина Ковалёва",
    }


def test_create_edit_toggle_move_and_delete_task(client: TestClient) -> None:
    created = client.post(
        "/tasks",
        json={
            "column_id": 1,
            "title": "Проверить авторизацию",
            "description": "Пройти полный сценарий",
            "priority": "high",
            "responsible_employee_id": None,
            "due_at": "2026-10-05T18:00:00+05:00",
            "customer_id": None,
            "branch_id": None,
            "subtasks": [{"title": "Войти"}, {"title": "Обновить токен"}],
        },
    )
    assert created.status_code == 201
    task = created.json()
    task_id = task["id"]
    assert task["version"] == 1
    assert [item["done"] for item in task["subtasks"]] == [False, False]
    assert client.get(f"/tasks/{task_id}").json() == task

    edited = client.patch(
        f"/tasks/{task_id}",
        json={
            "expected_version": 1,
            "title": "Проверить вход и выход",
            "responsible_employee_id": 4,
            "due_at": None,
            "subtasks": [
                {
                    "id": task["subtasks"][0]["id"],
                    "title": "Войти",
                    "done": True,
                    "order": 0,
                },
                {"title": "Выйти", "done": False, "order": 1},
            ],
        },
    )
    assert edited.status_code == 200
    task = edited.json()
    assert task["version"] == 2
    assert task["responsible"] == {"id": 4, "full_name": "Администратор"}
    assert task["due_at"] is None
    assert task["subtasks"][0]["done"] is True

    second_subtask = task["subtasks"][1]["id"]
    toggled = client.patch(
        f"/tasks/{task_id}/subtasks/{second_subtask}",
        json={"done": True, "expected_version": 2},
    )
    assert toggled.status_code == 200
    assert toggled.json()["version"] == 3
    assert all(item["done"] for item in toggled.json()["subtasks"])

    moved = client.post(
        f"/tasks/{task_id}/move", json={"column_id": 4, "expected_version": 3}
    )
    assert moved.status_code == 200
    assert moved.json()["column_id"] == 4
    assert moved.json()["version"] == 4
    assert any(
        item["id"] == task_id for item in client.get("/task-board").json()["tasks"]
    )

    assert client.delete(f"/tasks/{task_id}").status_code == 204
    assert client.get(f"/tasks/{task_id}").status_code == 404


def test_stale_version_and_invalid_mutation_leave_task_unchanged(
    client: TestClient,
) -> None:
    before = client.get("/tasks/101").json()
    stale = client.patch(
        "/tasks/101", json={"expected_version": 2, "title": "Чужая правка"}
    )
    assert stale.status_code == 409
    assert stale.json()["detail"]["code"] == "version_conflict"
    assert client.get("/tasks/101").json() == before

    invalid = client.patch(
        "/tasks/101", json={"expected_version": 1, "responsible_employee_id": 999}
    )
    assert invalid.status_code == 422
    assert client.get("/tasks/101").json() == before

    missing_tz = client.post(
        "/tasks",
        json={"column_id": 1, "title": "Без зоны", "due_at": "2026-10-05T12:00:00"},
    )
    assert missing_tz.status_code == 422


def test_column_crud_moves_tasks_before_deletion(client: TestClient) -> None:
    created = client.post(
        "/task-columns", json={"name": "Блокировано", "status": "new"}
    )
    assert created.status_code == 201
    column = created.json()
    assert column == {
        "id": 5,
        "name": "Блокировано",
        "order": 4,
        "counts_as_done": False,
        "status": "new",
        "version": 1,
        "archived_at": None,
    }

    renamed = client.patch(
        f"/task-columns/{column['id']}", json={"name": "Ожидает ответа"}
    )
    assert renamed.status_code == 200
    assert renamed.json()["name"] == "Ожидает ответа"

    moved = client.post("/tasks/101/move", json={"column_id": 5, "expected_version": 1})
    assert moved.json()["version"] == 2
    assert client.delete("/task-columns/5?move_to_column_id=2").status_code == 204
    task = client.get("/tasks/101").json()
    assert task["column_id"] == 2
    assert task["version"] == 3
    assert all(item["id"] != 5 for item in client.get("/task-board").json()["columns"])


def test_invalid_column_deletion_is_atomic(client: TestClient) -> None:
    before = client.get("/task-board").json()
    response = client.delete("/task-columns/1?move_to_column_id=1")
    assert response.status_code == 409
    assert client.get("/task-board").json() == before


def test_creation_requires_explicit_column_status(client: TestClient) -> None:
    assert client.post("/task-columns", json={"name": "Без статуса"}).status_code == 422
    result = client.post(
        "/task-columns", json={"name": "Доработка", "status": "rework"}
    )
    assert result.status_code == 201
    column_id = result.json()["id"]
    body = {"title": "Исправить", "column_id": column_id}
    assert client.post("/tasks", json=body).status_code == 422
    body["reason"] = "Неполный результат"
    created = client.post("/tasks", json=body)
    assert created.status_code == 201
    assert created.json()["status"] == "rework"


def test_creation_checks_executor_and_closed_columns(client: TestClient) -> None:
    assert (
        client.post("/tasks", json={"title": "Задача", "column_id": 2}).status_code
        == 409
    )
    assert (
        client.post("/tasks", json={"title": "Задача", "column_id": 4}).status_code
        == 422
    )
    created = client.post(
        "/tasks",
        json={
            "title": "Задача",
            "column_id": 2,
            "responsible_employee_id": 4,
        },
    )
    assert created.status_code == 201
    assert created.json()["due_at"] is None
    assert created.json()["customer"] is None
