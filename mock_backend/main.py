"""Локальная HTTP-заглушка: изменения живут только до перезапуска процесса."""

from datetime import date, datetime
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Path, Query
from pydantic import BaseModel

from auth import require_mock_auth
from auth import router as auth_router
from data import CUSTOMERS
from tasks import router as tasks_router

app = FastAPI(title="CRM mock backend", version="0.3.0")
app.include_router(auth_router)
app.include_router(tasks_router)


class ContactResponse(BaseModel):
    id: int
    type: str
    value: str
    label: str | None = None
    is_primary: bool
    created_at: datetime


class NoteResponse(BaseModel):
    id: int
    author_employee_id: int
    text: str
    created_at: datetime
    edited_at: datetime | None


class CustomerSummaryResponse(BaseModel):
    id: int
    full_name: str
    gender: str | None
    date_of_birth: date | None
    status: str
    primary_contact: str | None
    acquisition_source_name: str


class CustomerListResponse(BaseModel):
    items: list[CustomerSummaryResponse]
    total: int
    limit: int
    offset: int


class CustomerDetailResponse(BaseModel):
    id: int
    full_name: str
    gender: str | None
    date_of_birth: date | None
    status: str
    responsible_employee_id: int | None
    created_by_employee_id: int | None
    home_branch_id: int | None
    acquisition_source_id: int
    acquisition_source_code: str
    acquisition_source_name: str
    registration_method: str
    referred_by_customer_id: int | None
    created_at: datetime
    updated_at: datetime
    contacts: list[ContactResponse]
    notes: list[NoteResponse]


# Карточки клиентов остаются фиксированными; канбан хранится отдельно в памяти.
CUSTOMER_SUMMARIES = [
    CustomerSummaryResponse.model_validate(item) for item in CUSTOMERS
]
CUSTOMER_DETAILS = [CustomerDetailResponse.model_validate(item) for item in CUSTOMERS]


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get(
    "/customers",
    response_model=CustomerListResponse,
    dependencies=[Depends(require_mock_auth)],
)
async def list_customers(
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> CustomerListResponse:
    return CustomerListResponse(
        items=CUSTOMER_SUMMARIES[offset : offset + limit],
        total=len(CUSTOMER_SUMMARIES),
        limit=limit,
        offset=offset,
    )


@app.get(
    "/customers/{customer_id}",
    response_model=CustomerDetailResponse,
    dependencies=[Depends(require_mock_auth)],
)
async def get_customer(
    customer_id: Annotated[int, Path(ge=1, le=2**63 - 1)],
) -> CustomerDetailResponse:
    for customer in CUSTOMER_DETAILS:
        if customer.id == customer_id:
            return customer
    raise HTTPException(
        status_code=404,
        detail={"code": "customer_not_found", "message": "Клиент не найден"},
    )
