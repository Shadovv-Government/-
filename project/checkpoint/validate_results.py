#!/usr/bin/env python3
"""Проверяет контрольные значения исходного снимка, не подменяя SQL-проверки."""
import csv
import sys
from decimal import Decimal
from pathlib import Path

root = Path(sys.argv[1])


def rows(name):
    with (root / name).open(encoding='utf-8', newline='') as handle:
        return list(csv.DictReader(handle))


def require(condition, message):
    if not condition:
        raise SystemExit(f'FAIL: {message}')
    print(f'PASS: {message}')


monthly = rows('q1.csv')
require(len(monthly) == 24, '24 месяца')
require(sum(Decimal(r['revenue']) for r in monthly) == Decimal('13221498.11'), 'выручка вопроса 1')
require(any(int(r['order_count']) == 0 for r in monthly), 'месяц без заказов не потерян')

sellers = rows('q2.csv')
require(len(sellers) == 10, 'топ-10 продавцов')
require(Decimal(sellers[0]['revenue']) == Decimal('226987.93'), 'выручка лидера продавцов')

basket = rows('q3.csv')
require(len(basket) == 1 and Decimal(basket[0]['average_order_value']) == Decimal('159.88'), 'средний чек')
require(int(basket[0]['orders_with_unknown_value']) == 0, 'нет неизвестных чеков в исходном снимке')

customers = rows('q4.csv')
require(len(customers) == 1 and int(customers[0]['customers']) == 96096, 'число покупателей')
require(int(customers[0]['repeat_customers']) == 2997 and Decimal(customers[0]['repeat_pct']) == Decimal('3.12'), 'повторные покупатели')

categories = rows('q5.csv')
require(len(categories) == 74, '74 категории')
require(max(Decimal(r['revenue']) for r in categories) == Decimal('1233131.72'), 'крупнейшая категория')
require(sum(Decimal(r['revenue']) for r in categories) == Decimal('13221498.11'), 'общая выручка категорий')
require(not any(r['status'] == 'FAIL' for r in rows('q5_checks.csv')), 'проверки категорий не содержат FAIL')
require(not any(r['status'] == 'FAIL' for r in rows('feature_checks.csv')), 'проверки особенностей не содержат FAIL')
category_reconciliation = rows('q5_raw_vs_core.csv')
require(len(category_reconciliation) == 1 and category_reconciliation[0]['status'] == 'PASS', 'сверка категорий raw/core')
