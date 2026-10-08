"""Disposable local authentication for the UI mock, never for deployment."""

import os
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from threading import RLock
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

router = APIRouter(prefix="/auth", tags=["mock auth"])
bearer = HTTPBearer(auto_error=False)


class LoginRequest(BaseModel):
    login: str = Field(min_length=1, max_length=128)
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokensResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_expires_at: datetime
    refresh_expires_at: datetime
    must_change_password: bool = False


@dataclass
class MockSession:
    access_token: str
    refresh_token: str
    access_expires_at: datetime
    refresh_expires_at: datetime


class MockSessions:
    def __init__(self) -> None:
        self._lock = RLock()
        self._by_access: dict[str, MockSession] = {}
        self._by_refresh: dict[str, MockSession] = {}

    def clear(self) -> None:
        with self._lock:
            self._by_access.clear()
            self._by_refresh.clear()

    def _issue(self) -> TokensResponse:
        now = datetime.now(UTC)
        session = MockSession(
            access_token=secrets.token_urlsafe(32),
            refresh_token=secrets.token_urlsafe(32),
            access_expires_at=now + timedelta(minutes=15),
            refresh_expires_at=now + timedelta(days=7),
        )
        self._by_access[session.access_token] = session
        self._by_refresh[session.refresh_token] = session
        return TokensResponse(
            access_token=session.access_token,
            refresh_token=session.refresh_token,
            access_expires_at=session.access_expires_at,
            refresh_expires_at=session.refresh_expires_at,
        )

    def login(self) -> TokensResponse:
        with self._lock:
            return self._issue()

    def refresh(self, token: str) -> TokensResponse | None:
        with self._lock:
            session = self._by_refresh.pop(token, None)
            if session is None or session.refresh_expires_at <= datetime.now(UTC):
                return None
            self._by_access.pop(session.access_token, None)
            return self._issue()

    def valid_access(self, token: str) -> bool:
        with self._lock:
            session = self._by_access.get(token)
            return session is not None and session.access_expires_at > datetime.now(UTC)

    def logout(self, token: str) -> None:
        with self._lock:
            session = self._by_access.pop(token, None)
            if session is not None:
                self._by_refresh.pop(session.refresh_token, None)


sessions = MockSessions()


def _unauthorized() -> HTTPException:
    return HTTPException(
        status_code=401,
        detail={"code": "invalid_token", "message": "Недействительный токен"},
        headers={"WWW-Authenticate": "Bearer"},
    )


def _token(credentials: HTTPAuthorizationCredentials | None) -> str:
    if credentials is None or not sessions.valid_access(credentials.credentials):
        raise _unauthorized()
    return credentials.credentials


def require_mock_auth(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> str:
    return _token(credentials)


AuthDependency = Annotated[str, Depends(require_mock_auth)]


def _no_store(response: Response) -> None:
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"


@router.post("/login", response_model=TokensResponse)
def login(body: LoginRequest, response: Response) -> TokensResponse:
    expected_login = os.getenv("CRM_MOCK_LOGIN", "admin")
    expected_password = os.getenv("CRM_MOCK_PASSWORD", "123456789098765")
    if not (
        secrets.compare_digest(body.login, expected_login)
        and secrets.compare_digest(body.password, expected_password)
    ):
        raise HTTPException(
            status_code=401,
            detail={
                "code": "invalid_credentials",
                "message": "Неверный логин или пароль",
            },
        )
    _no_store(response)
    return sessions.login()


@router.post("/refresh", response_model=TokensResponse)
def refresh(body: RefreshRequest, response: Response) -> TokensResponse:
    tokens = sessions.refresh(body.refresh_token)
    if tokens is None:
        raise _unauthorized()
    _no_store(response)
    return tokens


@router.post("/logout", status_code=204)
def logout(token: AuthDependency) -> None:
    sessions.logout(token)
