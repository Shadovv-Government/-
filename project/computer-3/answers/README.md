# Ответы компьютера 3

После `bash scripts/setup.sh` и `bash model/build.sh` из `project/`:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U hack -d marketplace < computer-3/answers/02_sellers.sql
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U hack -d marketplace < computer-3/answers/03_average_order.sql
```

Сохраните фактический вывод, версию базы и дату набора; сравните первую выручку с 226987.93, средний чек — с 159.88 (`docs/tasks.md`, `../qa/control_results.csv` от корня проекта). `NULL` выручки или чека требует расследования, а не замены на 0. Нулевые позиции заказа считаются нулевым чеком; поле `orders_without_items` позволяет проверить допущение. Определения — в [metrics.md](metrics.md).

**Статус на 2026-10-28:** SQL не выполнялся: Docker Desktop не запущен, CSV и PostgreSQL недоступны. Контрольные числа выше — ориентиры из задания и независимого QA, не результаты этих запросов. Фактические топ-10, средние строк и единиц и сопоставление с QA ожидают запуска. Вопрос 9 отсутствует в `docs/tasks.md`; ответ ожидает его публикации. Проверка ответа компьютера 4 и согласованности итогов команды ожидает передачи соответствующих материалов.
