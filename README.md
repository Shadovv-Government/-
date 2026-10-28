# Capibara: модель данных маркетплейса

Командное решение кейса: модель PostgreSQL, ответы на вопросы аналитиков, проверки качества и материалы защиты. Исходные данные хранятся в `raw`, модель собирается в `core`.

## Где что находится

| Путь | Содержание |
|---|---|
| [project/docs/](project/docs/) | Условия кейса и вопросы организаторов |
| [project/model/](project/model/) | Контракт и сборка модели |
| [project/computer-1/](project/computer-1/), [computer-2/](project/computer-2/), [computer-3/](project/computer-3/) | Ответы, проверки и результаты соответствующих участников |
| [project/answers/computer-4/](project/answers/computer-4/), [project/quality/computer-4/](project/quality/computer-4/) | Ответ и проверки компьютера 4 |
| [qa/](qa/) | Профилирование и независимые проверки исходных данных |
| [project/checkpoint/](project/checkpoint/) | Сквозная проверка и сохранённые результаты прогонов |
| [project/deliverables/](project/deliverables/) | Концепция дашборда |
| [output/](output/) | Презентации и иллюстрации |

[Записка о решениях](project/README_SOLUTION.md) и [стратегия развития](project/computer-2/strategy.md) дополняют материалы сдачи. Исходные PDF и презентация кейса находятся в корне.

## Запуск

При запущенном Docker и доступе к интернету настройте отдельную локальную базу:

```bash
cd project
bash scripts/setup.sh
bash checkpoint/run.sh
```

Последняя команда пересоздаёт таблицы `core` и записывает результаты в `project/checkpoint/results/`; не запускайте её на общей или ценной базе. Успешный прогон на PostgreSQL 16.15 сохранён в [results/run-yzWDmFmN/](project/checkpoint/results/run-yzWDmFmN/); в сессиях проверок отключён параллельный план из-за нехватки общей памяти Docker в первой попытке. Данные в `project/data/` в Git не добавляются. Параметр `--reset` удаляет локальный том базы.

Новые вопросы организаторов автоматически в локальной копии не появятся: следите за обновлениями `project/docs/tasks.md` и переносите их, не теряя свою работу. Перед отправкой проверяйте `git status` и не добавляйте секреты или исходные CSV.
