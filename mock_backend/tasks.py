"""In-memory implementation of the proposed kanban UI contract."""

from datetime import datetime
from threading import RLock
from typing import Annotated, Literal

from fastapi import APIRouter, HTTPException, Path, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator

from auth import AuthDependency
from data import CUSTOMERS

router = APIRouter(tags=["mock tasks"])
Priority = Literal["low", "normal", "high", "urgent"]
TaskStatus = Literal[
    "new", "in_progress", "completed", "rework", "confirmed", "cancelled"
]
TaskId = Annotated[int, Path(ge=1)]

EMPLOYEES = [
    {"id": 1, "full_name": "Ирина Ковалёва"},
    {"id": 2, "full_name": "Дамир Юсупов"},
    {"id": 3, "full_name": "Светлана Орлова"},
    {"id": 4, "full_name": "Администратор"},
]
EMPLOYEE_NAMES = {item["id"]: item["full_name"] for item in EMPLOYEES}


def _error(status: int, code: str, message: str) -> HTTPException:
    return HTTPException(status_code=status, detail={"code": code, "message": message})


def _aware(value: datetime | None) -> datetime | None:
    if value is not None and value.utcoffset() is None:
        raise ValueError("Укажите часовой пояс в due_at")
    return value


class Column(BaseModel):
    id: int
    name: str
    order: int
    counts_as_done: bool
    status: str = "new"
    version: int = 1
    archived_at: datetime | None = None


class Subtask(BaseModel):
    id: int
    title: str
    done: bool
    order: int


class Task(BaseModel):
    id: int
    column_id: int
    title: str
    description: str
    priority: Priority
    responsible_employee_id: int | None
    responsible_employee_name: str | None
    due_at: datetime | None
    customer_id: int | None
    branch_id: int | None
    subtasks: list[Subtask]
    version: int


class TaskPartyResponse(BaseModel):
    id: int
    full_name: str


class TaskResponse(BaseModel):
    id: int
    column_id: int
    title: str
    description: str | None
    status: str
    priority: Priority
    responsible_employee_id: int | None
    responsible: TaskPartyResponse | None
    due_at: datetime | None
    customer: TaskPartyResponse | None
    branch_id: int | None
    subtasks: list[Subtask]
    version: int


class BoardResponse(BaseModel):
    columns: list[Column]
    tasks: list[TaskResponse]
    truncated: bool = False


class NewSubtask(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=255)


class EditedSubtask(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: int | None = Field(default=None, ge=1)
    title: str = Field(min_length=1, max_length=255)
    done: bool = False
    order: int = Field(ge=0)


class CreateTaskRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    column_id: int = Field(ge=1)
    title: str = Field(min_length=1, max_length=255)
    description: str = Field(default="", max_length=4000)
    priority: Priority = "normal"
    responsible_employee_id: int | None = Field(default=None, ge=1)
    due_at: datetime | None = None
    customer_id: int | None = Field(default=None, ge=1)
    branch_id: int | None = Field(default=None, ge=1)
    reason: str | None = Field(default=None, max_length=1000)
    subtasks: list[NewSubtask] = Field(default_factory=list, max_length=50)

    _check_due = field_validator("due_at")(_aware)


class UpdateTaskRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    expected_version: int = Field(ge=1)
    column_id: int | None = Field(default=None, ge=1)
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    priority: Priority | None = None
    responsible_employee_id: int | None = Field(default=None, ge=1)
    due_at: datetime | None = None
    customer_id: int | None = Field(default=None, ge=1)
    branch_id: int | None = Field(default=None, ge=1)
    subtasks: list[EditedSubtask] | None = None

    _check_due = field_validator("due_at")(_aware)


class VersionedRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    expected_version: int = Field(ge=1)


class ToggleSubtaskRequest(VersionedRequest):
    done: bool


class MoveTaskRequest(VersionedRequest):
    column_id: int = Field(ge=1)


class ColumnNameRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=60)


class ColumnCreateRequest(ColumnNameRequest):
    status: TaskStatus


class BoardStore:
    def __init__(self) -> None:
        self.lock = RLock()
        self.reset()

    def reset(self) -> None:
        with self.lock:
            self.columns = {
                1: Column(id=1, name="Общая очередь", order=0, counts_as_done=False),
                2: Column(
                    id=2,
                    name="В работе",
                    order=1,
                    counts_as_done=False,
                    status="in_progress",
                ),
                3: Column(
                    id=3,
                    name="На проверке",
                    order=2,
                    counts_as_done=False,
                    status="completed",
                ),
                4: Column(
                    id=4,
                    name="Готово",
                    order=3,
                    counts_as_done=True,
                    status="confirmed",
                ),
            }
            self.tasks = {
                101: Task(
                    id=101,
                    column_id=1,
                    title="Уточнить наличие абонементов",
                    description="Связаться с клиентом и сообщить условия.",
                    priority="normal",
                    responsible_employee_id=None,
                    responsible_employee_name=None,
                    due_at=datetime.fromisoformat("2026-09-29T18:00:00+05:00"),
                    customer_id=1,
                    branch_id=1,
                    subtasks=[
                        Subtask(id=1001, title="Проверить наличие", done=True, order=0),
                        Subtask(
                            id=1002, title="Позвонить клиенту", done=False, order=1
                        ),
                    ],
                    version=1,
                ),
                102: Task(
                    id=102,
                    column_id=1,
                    title="Перезвонить по поводу переноса записи",
                    description="Согласовать удобное время.",
                    priority="urgent",
                    responsible_employee_id=None,
                    responsible_employee_name=None,
                    due_at=datetime.fromisoformat("2026-09-30T18:00:00+05:00"),
                    customer_id=2,
                    branch_id=2,
                    subtasks=[
                        Subtask(
                            id=1003,
                            title="Уточнить свободные окна",
                            done=False,
                            order=0,
                        )
                    ],
                    version=1,
                ),
                103: Task(
                    id=103,
                    column_id=2,
                    title="Исправить отображение карточки клиента",
                    description="Проверить выбор клиента и состояния загрузки.",
                    priority="high",
                    responsible_employee_id=4,
                    responsible_employee_name="Администратор",
                    due_at=None,
                    customer_id=None,
                    branch_id=None,
                    subtasks=[
                        Subtask(
                            id=1004, title="Воспроизвести ошибку", done=True, order=0
                        ),
                        Subtask(
                            id=1005, title="Проверить исправление", done=False, order=1
                        ),
                    ],
                    version=1,
                ),
            }
            self.next_column_id = 5
            self.next_task_id = 104
            self.next_subtask_id = 1006

    def task(self, task_id: int) -> Task:
        task = self.tasks.get(task_id)
        if task is None:
            raise _error(404, "task_not_found", "Задача не найдена")
        return task

    def column(self, column_id: int) -> Column:
        column = self.columns.get(column_id)
        if column is None:
            raise _error(404, "column_not_found", "Колонка не найдена")
        return column

    @staticmethod
    def check_version(task: Task, expected: int) -> None:
        if task.version != expected:
            raise _error(
                409, "version_conflict", "Задача уже изменена другим пользователем"
            )

    @staticmethod
    def employee_name(employee_id: int | None) -> str | None:
        if employee_id is None:
            return None
        name = EMPLOYEE_NAMES.get(employee_id)
        if name is None:
            raise _error(422, "invalid_employee", "Сотрудник не найден")
        return name

    def board(self) -> BoardResponse:
        with self.lock:
            return BoardResponse(
                columns=sorted(self.columns.values(), key=lambda item: item.order),
                tasks=[self.response(task) for task in self.tasks.values()],
            )

    def response(self, task: Task) -> TaskResponse:
        with self.lock:
            customer = next(
                (item for item in CUSTOMERS if item["id"] == task.customer_id), None
            )
            responsible = task.responsible_employee_id
            return TaskResponse(
                id=task.id,
                column_id=task.column_id,
                title=task.title,
                description=task.description or None,
                status=self.column(task.column_id).status,
                priority=task.priority,
                responsible_employee_id=responsible,
                responsible=None
                if responsible is None
                else TaskPartyResponse(
                    id=responsible, full_name=EMPLOYEE_NAMES[responsible]
                ),
                due_at=task.due_at,
                customer=None
                if customer is None
                else TaskPartyResponse(
                    id=customer["id"], full_name=customer["full_name"]
                ),
                branch_id=task.branch_id,
                subtasks=task.subtasks,
                version=task.version,
            )

    def create_task(self, body: CreateTaskRequest) -> Task:
        with self.lock:
            column = self.column(body.column_id)
            if column.status in {"confirmed", "cancelled"}:
                raise _error(
                    422, "invalid_task", "Нельзя создать задачу в закрытом статусе"
                )
            if (
                column.status in {"in_progress", "completed"}
                and body.responsible_employee_id is None
            ):
                raise _error(
                    409, "task_without_executor", "Для этого статуса нужен исполнитель"
                )
            if column.status == "rework" and not (body.reason or "").strip():
                raise _error(422, "invalid_task", "Укажите причину доработки")
            name = self.employee_name(body.responsible_employee_id)
            subtasks = [
                Subtask(
                    id=self.next_subtask_id + index,
                    title=item.title.strip(),
                    done=False,
                    order=index,
                )
                for index, item in enumerate(body.subtasks)
            ]
            if not body.title.strip() or any(not item.title for item in subtasks):
                raise _error(422, "invalid_task", "Название не может быть пустым")
            self.next_subtask_id += len(subtasks)
            task = Task(
                id=self.next_task_id,
                column_id=body.column_id,
                title=body.title.strip(),
                description=body.description.strip(),
                priority=body.priority,
                responsible_employee_id=body.responsible_employee_id,
                responsible_employee_name=name,
                due_at=body.due_at,
                customer_id=body.customer_id,
                branch_id=body.branch_id,
                subtasks=subtasks,
                version=1,
            )
            self.tasks[task.id] = task
            self.next_task_id += 1
            return task.model_copy(deep=True)

    def update_task(self, task_id: int, body: UpdateTaskRequest) -> Task:
        with self.lock:
            current = self.task(task_id)
            self.check_version(current, body.expected_version)
            task = current.model_copy(deep=True)
            fields = body.model_fields_set - {"expected_version"}
            for field in (
                "column_id",
                "title",
                "description",
                "priority",
                "responsible_employee_id",
                "due_at",
                "customer_id",
                "branch_id",
                "subtasks",
            ):
                if field not in fields:
                    continue
                value = getattr(body, field)
                if (
                    field in {"title", "description", "priority", "column_id"}
                    and value is None
                ):
                    raise _error(422, "invalid_task", f"Поле {field} нельзя очистить")
                if field == "column_id":
                    self.column(value)
                if field == "responsible_employee_id":
                    task.responsible_employee_name = self.employee_name(value)
                if field == "title" and not value.strip():
                    raise _error(422, "invalid_task", "Название не может быть пустым")
                if field in {"title", "description"}:
                    value = value.strip()
                if field == "subtasks":
                    if value is None:
                        raise _error(
                            422, "invalid_subtask", "Список подзадач не может быть null"
                        )
                    value = self._edited_subtasks(current, value)
                setattr(task, field, value)
            if task != current:
                task.version += 1
                self.tasks[task_id] = task
            return task.model_copy(deep=True)

    def _edited_subtasks(self, task: Task, items: list[EditedSubtask]) -> list[Subtask]:
        known = {item.id for item in task.subtasks}
        ids = [item.id for item in items if item.id is not None]
        if len(ids) != len(set(ids)) or not set(ids) <= known:
            raise _error(422, "invalid_subtask", "Подзадача не принадлежит задаче")
        if any(not item.title.strip() for item in items):
            raise _error(
                422, "invalid_subtask", "Название подзадачи не может быть пустым"
            )
        result = []
        for item in items:
            if item.id is None:
                identifier = self.next_subtask_id
                self.next_subtask_id += 1
            else:
                identifier = item.id
            result.append(
                Subtask(
                    id=identifier,
                    title=item.title.strip(),
                    done=item.done,
                    order=item.order,
                )
            )
        return sorted(result, key=lambda item: item.order)

    def toggle_subtask(
        self, task_id: int, subtask_id: int, body: ToggleSubtaskRequest
    ) -> Task:
        with self.lock:
            current = self.task(task_id)
            self.check_version(current, body.expected_version)
            task = current.model_copy(deep=True)
            subtask = next(
                (item for item in task.subtasks if item.id == subtask_id), None
            )
            if subtask is None:
                raise _error(404, "subtask_not_found", "Подзадача не найдена")
            if subtask.done != body.done:
                subtask.done = body.done
                task.version += 1
                self.tasks[task_id] = task
            return task.model_copy(deep=True)

    def move_task(self, task_id: int, body: MoveTaskRequest) -> Task:
        with self.lock:
            current = self.task(task_id)
            self.check_version(current, body.expected_version)
            self.column(body.column_id)
            if current.column_id != body.column_id:
                task = current.model_copy(
                    update={"column_id": body.column_id, "version": current.version + 1}
                )
                self.tasks[task_id] = task
                return task.model_copy(deep=True)
            return current.model_copy(deep=True)

    def create_column(self, body: ColumnCreateRequest) -> Column:
        with self.lock:
            name = body.name.strip()
            if not name:
                raise _error(422, "invalid_column", "Название не может быть пустым")
            column = Column(
                id=self.next_column_id,
                name=name,
                order=len(self.columns),
                counts_as_done=body.status == "confirmed",
                status=body.status,
            )
            self.columns[column.id] = column
            self.next_column_id += 1
            return column.model_copy()

    def rename_column(self, column_id: int, body: ColumnNameRequest) -> Column:
        with self.lock:
            current = self.column(column_id)
            name = body.name.strip()
            if not name:
                raise _error(422, "invalid_column", "Название не может быть пустым")
            column = current.model_copy(update={"name": name})
            self.columns[column_id] = column
            return column.model_copy()

    def delete_column(self, column_id: int, target_id: int) -> None:
        with self.lock:
            self.column(column_id)
            self.column(target_id)
            if len(self.columns) == 1 or column_id == target_id:
                raise _error(
                    409, "invalid_column_target", "Нужна другая колонка для задач"
                )
            for task_id, task in list(self.tasks.items()):
                if task.column_id == column_id:
                    self.tasks[task_id] = task.model_copy(
                        update={"column_id": target_id, "version": task.version + 1}
                    )
            del self.columns[column_id]
            for index, column in enumerate(
                sorted(self.columns.values(), key=lambda item: item.order)
            ):
                self.columns[column.id] = column.model_copy(update={"order": index})


board_store = BoardStore()


@router.get("/employees", response_model=list[dict[str, int | str]])
def list_employees(_token: AuthDependency) -> list[dict[str, int | str]]:
    return EMPLOYEES


@router.get(
    "/task-board",
    response_model=BoardResponse,
)
def get_task_board(_token: AuthDependency) -> BoardResponse:
    return board_store.board()


@router.get("/tasks/{task_id}", response_model=TaskResponse)
def get_task(task_id: TaskId, _token: AuthDependency) -> TaskResponse:
    with board_store.lock:
        return board_store.response(board_store.task(task_id))


@router.post("/tasks", response_model=TaskResponse, status_code=201)
def create_task(body: CreateTaskRequest, _token: AuthDependency) -> TaskResponse:
    with board_store.lock:
        return board_store.response(board_store.create_task(body))


@router.patch("/tasks/{task_id}", response_model=TaskResponse)
def update_task(
    task_id: TaskId, body: UpdateTaskRequest, _token: AuthDependency
) -> TaskResponse:
    with board_store.lock:
        return board_store.response(board_store.update_task(task_id, body))


@router.patch("/tasks/{task_id}/subtasks/{subtask_id}", response_model=TaskResponse)
def toggle_subtask(
    task_id: TaskId,
    subtask_id: Annotated[int, Path(ge=1)],
    body: ToggleSubtaskRequest,
    _token: AuthDependency,
) -> TaskResponse:
    with board_store.lock:
        return board_store.response(
            board_store.toggle_subtask(task_id, subtask_id, body)
        )


@router.post("/tasks/{task_id}/move", response_model=TaskResponse)
def move_task(
    task_id: TaskId, body: MoveTaskRequest, _token: AuthDependency
) -> TaskResponse:
    with board_store.lock:
        return board_store.response(board_store.move_task(task_id, body))


@router.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: TaskId, _token: AuthDependency) -> None:
    with board_store.lock:
        board_store.task(task_id)
        del board_store.tasks[task_id]


@router.post("/task-columns", response_model=Column, status_code=201)
def create_column(body: ColumnCreateRequest, _token: AuthDependency) -> Column:
    return board_store.create_column(body)


@router.patch("/task-columns/{column_id}", response_model=Column)
def rename_column(
    column_id: Annotated[int, Path(ge=1)],
    body: ColumnNameRequest,
    _token: AuthDependency,
) -> Column:
    return board_store.rename_column(column_id, body)


@router.delete("/task-columns/{column_id}", status_code=204)
def delete_column(
    column_id: Annotated[int, Path(ge=1)],
    _token: AuthDependency,
    move_to_column_id: Annotated[int, Query(ge=1)],
) -> None:
    board_store.delete_column(column_id, move_to_column_id)
