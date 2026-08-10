#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""支付宝账单转 Firefly III csv 工具。

读取支付宝导出的原始对账单，跳过表头之前的说明信息，过滤“不计收支”记录，
补充“预算”“分类”列，并根据映射文件转换“收/付款方式”。
"""

import argparse
import csv
import json
import os
import sys

HEADER_FIRST_FIELD = "交易时间"
INCOME_EXPENSE_COLUMN = "收/支"
PAYMENT_COLUMN = "收/付款方式"
IGNORED_INCOME_EXPENSE = "不计收支"

BUDGET_COLUMN = "预算"
BUDGET_VALUE = "生活费用"
CATEGORY_COLUMN = "分类"
CATEGORY_VALUE = "衣食住行"

DEFAULT_MAPPING_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "alipay_firefly_mapping.json"
)
# 支付宝导出的账单常见编码，按顺序尝试
CANDIDATE_ENCODINGS = ("gbk", "gb18030", "utf-8-sig", "utf-8")


def detect_encoding(path):
    """探测账单文件编码，返回可成功解码的编码名。"""
    with open(path, "rb") as fp:
        raw = fp.read()
    for encoding in CANDIDATE_ENCODINGS:
        try:
            raw.decode(encoding)
        except UnicodeDecodeError:
            continue
        return encoding
    raise ValueError("无法识别文件编码：%s" % path)


def load_mapping(path):
    """加载收/付款方式映射表，文件不存在时返回空映射。"""
    if not path or not os.path.exists(path):
        return {}
    with open(path, "r", encoding="utf-8") as fp:
        mapping = json.load(fp)
    if not isinstance(mapping, dict):
        raise ValueError("映射文件格式错误，应为 JSON 对象：%s" % path)
    return mapping


def strip_cell(value):
    """去掉单元格首尾空白（含支付宝用于防科学计数法的制表符）。"""
    return value.strip() if isinstance(value, str) else value


def normalize_payment(value, mapping):
    """处理收/付款方式：截断 & 之后内容，并按映射转换。"""
    payment = strip_cell(value) or ""
    if "&" in payment:
        payment = payment.split("&", 1)[0].strip()
    return mapping.get(payment, payment)


def find_header(rows):
    """定位表头行索引，表头以“交易时间”开头。"""
    for index, row in enumerate(rows):
        if row and strip_cell(row[0]) == HEADER_FIRST_FIELD:
            return index
    return -1


def convert(input_path, output_path, mapping_path=DEFAULT_MAPPING_FILE):
    """转换支付宝账单，返回写入的交易记录条数。"""
    mapping = load_mapping(mapping_path)
    encoding = detect_encoding(input_path)

    with open(input_path, "r", encoding=encoding, newline="") as fp:
        rows = list(csv.reader(fp))

    header_index = find_header(rows)
    if header_index < 0:
        raise ValueError("未找到以“%s”开头的表头行" % HEADER_FIRST_FIELD)

    header = [strip_cell(cell) for cell in rows[header_index]]
    # 支付宝表头行尾部带有空列，去掉以免生成多余空列
    while header and header[-1] == "":
        header.pop()

    for required in (INCOME_EXPENSE_COLUMN, PAYMENT_COLUMN):
        if required not in header:
            raise ValueError("账单缺少必需列：%s" % required)

    income_expense_index = header.index(INCOME_EXPENSE_COLUMN)
    payment_index = header.index(PAYMENT_COLUMN)
    output_header = header + [BUDGET_COLUMN, CATEGORY_COLUMN]

    written = 0
    with open(output_path, "w", encoding="utf-8-sig", newline="") as fp:
        writer = csv.writer(fp)
        writer.writerow(output_header)

        for row in rows[header_index + 1:]:
            record = [strip_cell(cell) for cell in row[:len(header)]]
            if not any(record):
                continue
            # 补齐缺失列，避免索引越界
            record += [""] * (len(header) - len(record))

            if record[income_expense_index] == IGNORED_INCOME_EXPENSE:
                continue

            record[payment_index] = normalize_payment(record[payment_index], mapping)
            writer.writerow(record + [BUDGET_VALUE, CATEGORY_VALUE])
            written += 1

    return written


def main():
    parser = argparse.ArgumentParser(
        description="将支付宝导出的对账单转换为 Firefly III 可导入的 csv 文件"
    )
    parser.add_argument("-i", "--input", required=True, help="支付宝原始对账单 csv 路径")
    parser.add_argument("-o", "--output", required=True, help="输出 csv 路径")
    parser.add_argument(
        "-m",
        "--mapping",
        default=DEFAULT_MAPPING_FILE,
        help="收/付款方式映射 json 路径（默认：%(default)s）",
    )
    args = parser.parse_args()

    try:
        count = convert(args.input, args.output, args.mapping)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("转换失败：%s" % exc, file=sys.stderr)
        return 1

    print("转换完成，共写入 %d 条交易记录：%s" % (count, args.output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
