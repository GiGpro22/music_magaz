# Music Shop — Музыкальный магазин

Итоговый индивидуальный проект (Flutter Web + PocketBase) на оценку «5».

## Стек

- Flutter Web (`go_router`, `provider`, `dio`, `shared_preferences`)
- PocketBase как REST API
- GitHub Actions → GitHub Pages

## Быстрый старт

### 1. PocketBase

```bash
cd pocketbase
# скачать pocketbase.exe с https://github.com/pocketbase/pocketbase/releases
./pocketbase serve
```

Создайте коллекции по [`pocketbase/схема.md`](pocketbase/схема.md), затем:

```bash
node seed.mjs
```

Учётные записи:

| Email | Пароль | Роль |
| --- | --- | --- |
| customer@music.ru | music12345 | customer |
| seller@music.ru | music12345 | seller |
| admin@music.ru | music12345 | admin |

После seed привяжите `users.customer` у покупателя к записи из `customers`.

### 2. Клиент

```bash
flutter pub get
flutter run -d chrome --web-port=5555 --dart-define=API_BASE_URL=http://127.0.0.1:8090
```

### 3. Проверки

```bash
flutter analyze
flutter test
flutter build web --release --base-href /music_magaz/ --dart-define=API_BASE_URL=https://YOUR_PB_HOST
cp build/web/index.html build/web/404.html
```

Публикация: push в `main` запускает `.github/workflows/deploy.yml` (GitHub Pages).
Задайте repository variable `API_BASE_URL` на URL вашего PocketBase.

## Роли

- **Покупатель** — каталог, корзина, мои заказы, отзывы
- **Продавец** — CRUD каталога, покупатели, обработка заказов
- **Админ** — поставщики, акции, отчёты, пользователи, hard-delete

## Содержательная особенность

`OrderPricingService` — расчёт заказа: скидка карты лояльности + акции на бренд/категорию + проверка остатков (409).

## Архитектура

`models` → `repositories` → `state` → `screens` / `widgets`. Экраны не знают про Dio/PocketBase.
