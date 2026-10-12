# PocketBase — Музыкальный магазин

## Установка

1. Скачайте сборку для Windows: https://github.com/pocketbase/pocketbase/releases
2. Распакуйте `pocketbase.exe` в эту папку.
3. Запуск:

```bash
./pocketbase serve
```

- Админка: http://127.0.0.1:8090/_/
- API: http://127.0.0.1:8090/api/

При первом запуске создайте учётную запись суперпользователя.

## Настройка схемы

Следуйте файлу [схема.md](схема.md): создайте коллекции, поля, связи и API Rules.

## Seed-данные

После создания коллекций (с открытыми правилами List/Create) выполните:

```bash
node seed.mjs
```

Затем закройте API Rules по ролям и создайте трёх пользователей:

| Почта | Пароль | role |
| --- | --- | --- |
| customer@music.ru | music12345 | customer |
| seller@music.ru | music12345 | seller |
| admin@music.ru | music12345 | admin |

## Экспорт схемы

В админке: Settings → Export collections → сохраните JSON рядом как `pb_schema.json`.

## Клиент Flutter

```bash
flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://127.0.0.1:8090
```
