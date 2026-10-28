# Ответы компьютера 3

После `bash scripts/setup.sh` и `bash model/build.sh` из `project/`:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U hack -d marketplace < computer-3/answers/02_sellers.sql
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U hack -d marketplace < computer-3/answers/03_average_order.sql
```

Сохраните фактический вывод, версию базы и дату набора; сравните первую выручку с 226987.93, средний чек — с 159.88 (`docs/tasks.md`, `../qa/control_results.csv` от корня проекта). `NULL` выручки или чека требует расследования, а не замены на 0. Нулевые позиции заказа считаются нулевым чеком; поле `orders_without_items` позволяет проверить допущение. Определения — в [metrics.md](metrics.md).

**Статус на 2026-10-28:** первоначально SQL был подготовлен без запуска; затем запросы выполнены на PGlite и PostgreSQL 16.15 в Docker на исходном снимке. Результаты PostgreSQL 16 и проверки доступны в [`../../checkpoint/results/`](../../checkpoint/results/). Контрольные значения лидера и среднего чека совпали. Вопрос 9 отсутствует в `docs/tasks.md`; ответ ожидает его публикации. Определения статусов по вопросам 1 и 4 описаны в `metrics.md` как рабочие допущения.

Первый продавец — `4869f7a5dfa277a7dca6462dcf3b52b2` (guariba, SP): 1 124 заказа, 1 148 единиц, выручка 226 987.93. Средний чек — 159.88, среднее число строк и единиц на заказ — 1.1422. Полный топ-10 и показатели знаменателя приведены в [q2.csv](../../checkpoint/results/run-yzWDmFmN/q2.csv) и [q3.csv](../../checkpoint/results/run-yzWDmFmN/q3.csv). [Проверка согласованности с командой](../quality/team-review.md) описывает итог и ограничения.
