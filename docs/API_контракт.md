# Контракт API (PocketBase)

Базовый URL: задаётся `--dart-define=API_BASE_URL=...` (по умолчанию `http://127.0.0.1:8090`).

## Аутентификация

| Метод | Путь | Тело | Ответ |
| --- | --- | --- | --- |
| POST | `/api/collections/users/auth-with-password` | `{ identity, password }` | `{ token, record }` |
| GET | `/api/collections/users/auth-refresh` | Header `Authorization: <token>` | `{ token, record }` |
| POST | `/api/collections/users/records` | регистрация | запись user |

## CRUD коллекций

Путь: `/api/collections/{collection}/records`

| Метод | Назначение |
| --- | --- |
| GET | список / фильтр (`page`, `perPage`, `sort`, `filter`, `expand`) |
| GET `/:id` | одна запись |
| POST | создание |
| PATCH `/:id` | изменение |
| DELETE `/:id` | физическое удаление |

Коллекции: `brands`, `categories`, `suppliers`, `products`, `customers`, `loyalty_cards`, `promotions`, `orders`, `order_items`, `reviews`, `users`.

## Пример списка товаров

```
GET /api/collections/products/records?page=1&perPage=10&sort=name&filter=(deleted=false&&name~"strat")&expand=brand,supplier,categories
```

Ответ:

```json
{
  "page": 1,
  "perPage": 10,
  "totalItems": 20,
  "totalPages": 2,
  "items": [ { "id": "...", "name": "...", "expand": { } } ]
}
```

## Ошибки

| Код | Обработка в клиенте |
| --- | --- |
| 400 / 422 | `ValidationException` → ошибки в полях формы |
| 401 | refresh / logout |
| 403 | `ForbiddenException` |
| 404 | `NotFoundException` |
| 409 | `ConflictException` (недостаток остатков — клиентская проверка) |
| сеть / таймаут | `NetworkException` + retry GET |
