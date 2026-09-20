"""Локальная HTTP-заглушка: без БД, авторизации и сохранения изменений."""

from datetime import date, datetime
from typing import Annotated, Literal

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, model_validator

from data import CUSTOMERS

app = FastAPI(title="CRM mock backend", version="0.2.0")


class ContactResponse(BaseModel):
    id: int
    type: Literal["phone", "email", "telegram"]
    value: str
    is_primary: bool


class NoteResponse(BaseModel):
    id: int
    author_employee_id: int
    author_name: str
    text: str
    created_at: datetime
    edited_at: datetime | None
    archived_at: datetime | None


class AssignmentChangeResponse(BaseModel):
    id: int
    previous_employee_id: int | None
    previous_employee_name: str | None
    new_employee_id: int
    new_employee_name: str
    initiator_employee_id: int | None
    initiator_name: str
    changed_at: datetime


class TaskResponse(BaseModel):
    id: int
    customer_id: int
    title: str
    status: Literal[
        "new", "in_progress", "completed", "rework", "confirmed", "cancelled"
    ]
    priority: Literal["low", "normal", "high"]
    due_at: datetime
    author_employee_id: int
    assignee_employee_id: int | None


class InteractionResponse(BaseModel):
    id: int
    occurred_at: datetime
    reason: str
    campaign_name: str | None
    result: str


class CustomerSummaryResponse(BaseModel):
    id: int
    full_name: str
    gender: str | None
    date_of_birth: date | None
    status: str
    primary_contact: str | None
    primary_phone: str | None
    primary_branch_name: str
    responsible_employee_name: str | None
    acquisition_source_name: str
    last_interaction_at: datetime | None


class CustomerDetailResponse(CustomerSummaryResponse):
    primary_branch_id: int
    responsible_employee_id: int | None
    acquisition_source_code: str
    referred_by_customer_id: int | None
    referred_by_customer_name: str | None
    registration_method: Literal["employee", "integration"]
    created_by_employee_id: int | None
    contacts: list[ContactResponse]
    notes: list[NoteResponse]
    assignment_history: list[AssignmentChangeResponse]
    tasks: list[TaskResponse]
    interactions: list[InteractionResponse]

    @model_validator(mode="before")
    @classmethod
    def derive_summary_fields(cls, value: dict) -> dict:
        contacts = value["contacts"]
        interactions = value["interactions"]
        primary_contact = next((c for c in contacts if c["is_primary"]), contacts[0])
        primary_phone = next(
            (c for c in contacts if c["type"] == "phone" and c["is_primary"]), None
        )
        return {
            **value,
            "primary_contact": primary_contact["value"],
            "primary_phone": primary_phone["value"] if primary_phone else None,
            "last_interaction_at": max(
                (item["occurred_at"] for item in interactions), default=None
            ),
        }


# Заглушка читает данные только из памяти; ни один endpoint их не меняет.
CUSTOMER_DETAILS = [CustomerDetailResponse.model_validate(item) for item in CUSTOMERS]


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/customers", response_model=list[CustomerSummaryResponse])
async def list_customers(
    limit: Annotated[int, Query(ge=1)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[CustomerDetailResponse]:
    return CUSTOMER_DETAILS[offset : offset + limit]


@app.get("/customers/{customer_id}", response_model=CustomerDetailResponse)
async def get_customer(customer_id: int) -> CustomerDetailResponse:
    for customer in CUSTOMER_DETAILS:
        if customer.id == customer_id:
            return customer
    raise HTTPException(status_code=404, detail="Customer not found")
