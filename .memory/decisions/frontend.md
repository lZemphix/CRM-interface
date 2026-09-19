# Flutter и клиентский API

Записи перенесены 2026-09-19. Если Notes не указывает дату исходного решения, date означает дату его фиксации при миграции; точный день принятия неизвестен. Active означает действующее требование, а не гарантию реализации. Открытые вопросы внутри Notes не являются утверждёнными решениями.

## FE-01 — Оболочка и состояние навигации

date: 2026-09-19
status: active
tags: flutter, appshell, sidebar, navigation, indexedstack, cache

Decision:
AppShell хранит выбранный AppScreen и постоянный sidebar; экран модуля занимает область контента. Callback переключения передаётся sidebar, hover остаётся локальной визуальной реакцией.

Reason:
Общую навигацию не нужно копировать в каждый экран.

Alternatives considered:
Копии sidebar на каждом экране; индексы без понятных имен вместо enum.

Affected areas:
lib/layout/app_shell.dart; lib/layout/sidebar.dart; lib/core/navigation/

Notes:
IndexedStack обсуждался как сохранение State, не как HTTP-кэш; внедрение не подтверждено. Текущий switch удаляет экран: повторный initState отправляет запрос. Future создавать вне build(). Политика обновления кэша ещё не выбрана.

## FE-02 — Dio и repository без обязательного frontend use case

date: 2026-09-19
status: active
tags: dio, http, repository, futurebuilder, json, dto

Decision:
Один общий настроенный Dio/ApiClient передаётся repositories модулей. Repository знает endpoint и преобразует JSON в DTO. Для простого чтения допустим вызов repository из слоя состояния без класса-посредника, который только повторяет вызов.

Reason:
Готовый сетевой клиент уменьшает собственный код таймаутов, перехватчиков, ошибок и отмены. Простой frontend-сценарий не требует повторения backend-слоёв.

Alternatives considered:
package:http признан достаточным технически; выбран Dio. Пустой GetClients удалён.

Affected areas:
lib/core/api_client/client.dart; lib/modules/customers/repos/; lib/modules/customers/models/

Notes:
getCustomers возвращает Future<List<Customer>>; FutureBuilder отображает ожидание/ошибку, ListView — данные. Отдельный слой состояния/controller — направление; сейчас State создаёт ApiClient, управление временем жизни общего клиента ещё не доведено.

## FE-03 — Давность посещения в компактной карточке

date: 2026-09-14
status: active
tags: last-interaction, last-visit, acquisition, customer-card

Decision:
Вместо источника привлечения в компактной карточке показывать давность последнего визита (Сегодня, 1 дн., 3 нед., 2 мес., 1 г.; без истории — Нет визитов). Backend возвращает точную временную отметку, Flutter вычисляет локализованную строку.

Reason:
Повседневной работе полезнее видеть, давно ли обращался клиент. Первоначальный источник остаётся в подробностях/аналитике.

Alternatives considered:
Источник привлечения в фиолетовой рамке компактной карточки заменяется.

Affected areas:
lib/modules/customers/widgets/; будущие visits/interactions и API

Notes:
last_interaction_at — предварительное название. Последний визит не равен автоматически любому interaction: точная семантика события ещё открыта. Сейчас API даты визита не возвращает.

## FE-04 — HTTP-контракт и независимая работа над UI

date: 2026-09-19
status: active
tags: mock, openapi, http, websocket, refresh

Decision:
- Flutter-клиент не работает автономно без backend. Мгновенная синхронизация через WebSocket не входит в текущий план: после пользовательских операций клиент повторно получает актуальные данные обычным HTTP-запросом.
Flutter можно разрабатывать через отдельный mock, повторяющий согласованные схемы/OpenAPI, ошибки и пагинацию. Первый список использует реальный GET /customers с демо-клиентами.

Reason:
Не нужно ждать весь backend ради интерфейса; один контракт предотвращает расхождение mock и production.

Alternatives considered:
WebSocket для всех изменений сразу и production-запуск фиктивных данных не выбраны.

Affected areas:
web/api/customers/; Flutter repositories; отдельные dev mock/seed средства

Notes:
Mock допустим, но отдельный mock-сервер ещё не создан. HTTP-повтор после собственных операций не означает мгновенное получение изменений другого сотрудника.
