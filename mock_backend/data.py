"""Фиксированные данные карточек из crm_template.html, дополненные датами и ID."""

CUSTOMERS = [
    {
        "id": 1,
        "full_name": "Анна Петрова",
        "gender": "female",
        "date_of_birth": "1992-03-15",
        "status": "active",
        "primary_branch_id": 1,
        "primary_branch_name": "Центр",
        "responsible_employee_id": 1,
        "responsible_employee_name": "Ирина Ковалёва",
        "acquisition_source_code": "instagram",
        "acquisition_source_name": "Instagram",
        "referred_by_customer_id": None,
        "referred_by_customer_name": None,
        "registration_method": "employee",
        "created_by_employee_id": 3,
        "contacts": [
            {
                "id": 101,
                "type": "phone",
                "value": "+7 916 233-10-45",
                "is_primary": True,
            },
            {
                "id": 102,
                "type": "email",
                "value": "anna.petrova@mail.ru",
                "is_primary": False,
            },
        ],
        "notes": [
            {
                "id": 101,
                "author_employee_id": 1,
                "author_name": "Ирина Ковалёва",
                "text": "Хочет попробовать окрашивание балаяж, показала фото из Instagram.",
                "created_at": "2026-09-17T09:30:00Z",
                "edited_at": None,
                "archived_at": None,
            },
            {
                "id": 102,
                "author_employee_id": 3,
                "author_name": "Светлана Орлова",
                "text": "Перенесла запись на среду, попросила напомнить за день.",
                "created_at": "2026-08-29T12:00:00Z",
                "edited_at": "2026-08-29T12:10:00Z",
                "archived_at": None,
            },
        ],
        "assignment_history": [
            {
                "id": 101,
                "previous_employee_id": None,
                "previous_employee_name": None,
                "new_employee_id": 1,
                "new_employee_name": "Ирина Ковалёва",
                "initiator_employee_id": 3,
                "initiator_name": "Светлана Орлова",
                "changed_at": "2026-08-12T10:00:00Z",
            }
        ],
        "tasks": [
            {
                "id": 101,
                "customer_id": 1,
                "title": "Напомнить о записи на стрижку",
                "status": "new",
                "priority": "normal",
                "due_at": "2026-09-20T09:00:00Z",
                "author_employee_id": 3,
                "assignee_employee_id": 1,
            }
        ],
        "interactions": [
            {
                "id": 101,
                "occurred_at": "2026-09-17T14:00:00Z",
                "reason": "Консультация по окрашиванию",
                "campaign_name": None,
                "result": "Запись на стрижку",
            },
            {
                "id": 102,
                "occurred_at": "2026-08-29T11:00:00Z",
                "reason": "Перенос записи",
                "campaign_name": None,
                "result": "Новое время согласовано",
            },
        ],
    },
    {
        "id": 2,
        "full_name": "Максим Дорофеев",
        "gender": "male",
        "date_of_birth": "1988-07-22",
        "status": "active",
        "primary_branch_id": 2,
        "primary_branch_name": "Правый берег",
        "responsible_employee_id": 2,
        "responsible_employee_name": "Дамир Юсупов",
        "acquisition_source_code": "referral",
        "acquisition_source_name": "Рекомендация",
        "referred_by_customer_id": 1,
        "referred_by_customer_name": "Анна Петрова",
        "registration_method": "employee",
        "created_by_employee_id": 2,
        "contacts": [
            {
                "id": 201,
                "type": "phone",
                "value": "+7 903 555-67-12",
                "is_primary": True,
            }
        ],
        "notes": [
            {
                "id": 201,
                "author_employee_id": 2,
                "author_name": "Дамир Юсупов",
                "text": "Часто опаздывает на 10–15 минут — предупреждать о времени записи заранее.",
                "created_at": "2026-09-14T13:30:00Z",
                "edited_at": None,
                "archived_at": None,
            }
        ],
        "assignment_history": [
            {
                "id": 201,
                "previous_employee_id": None,
                "previous_employee_name": None,
                "new_employee_id": 2,
                "new_employee_name": "Дамир Юсупов",
                "initiator_employee_id": 2,
                "initiator_name": "Дамир Юсупов",
                "changed_at": "2026-06-03T08:00:00Z",
            }
        ],
        "tasks": [
            {
                "id": 201,
                "customer_id": 2,
                "title": "Перезвонить по поводу переноса записи",
                "status": "new",
                "priority": "high",
                "due_at": "2026-09-20T12:00:00Z",
                "author_employee_id": 2,
                "assignee_employee_id": None,
            }
        ],
        "interactions": [
            {
                "id": 201,
                "occurred_at": "2026-09-14T12:00:00Z",
                "reason": "Посещение",
                "campaign_name": None,
                "result": "Запросил перенос следующей записи",
            }
        ],
    },
    {
        "id": 3,
        "full_name": "Ольга Синицына",
        "gender": "female",
        "date_of_birth": "1995-11-08",
        "status": "active",
        "primary_branch_id": 3,
        "primary_branch_name": "Северный",
        "responsible_employee_id": 3,
        "responsible_employee_name": "Светлана Орлова",
        "acquisition_source_code": "website",
        "acquisition_source_name": "Сайт",
        "referred_by_customer_id": None,
        "referred_by_customer_name": None,
        "registration_method": "integration",
        "created_by_employee_id": None,
        "contacts": [
            {
                "id": 301,
                "type": "phone",
                "value": "+7 927 111-98-34",
                "is_primary": True,
            },
            {"id": 302, "type": "telegram", "value": "@olga_s", "is_primary": False},
        ],
        "notes": [
            {
                "id": 301,
                "author_employee_id": 3,
                "author_name": "Светлана Орлова",
                "text": "Спросила про абонемент на 5 стрижек для сына.",
                "created_at": "2026-09-18T16:00:00Z",
                "edited_at": None,
                "archived_at": None,
            }
        ],
        "assignment_history": [
            {
                "id": 301,
                "previous_employee_id": None,
                "previous_employee_name": None,
                "new_employee_id": 3,
                "new_employee_name": "Светлана Орлова",
                "initiator_employee_id": None,
                "initiator_name": "Система",
                "changed_at": "2026-08-27T08:00:00Z",
            }
        ],
        "tasks": [
            {
                "id": 301,
                "customer_id": 3,
                "title": "Уточнить наличие абонементов",
                "status": "new",
                "priority": "normal",
                "due_at": "2026-09-19T15:00:00Z",
                "author_employee_id": 3,
                "assignee_employee_id": None,
            }
        ],
        "interactions": [
            {
                "id": 301,
                "occurred_at": "2026-09-18T11:00:00Z",
                "reason": "Вопрос об абонементе",
                "campaign_name": None,
                "result": "Поручено проверить наличие",
            }
        ],
    },
]
