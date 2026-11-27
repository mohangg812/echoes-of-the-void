"""Render the editable Markdown delivery documents as Word files (python-docx)."""
from pathlib import Path
import argparse
import re

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Cm, Pt


DOCS = Path(__file__).resolve().parents[1] / "Documentation"
NAMES = {
    "Спецификация_игры": "Спецификация требований_Теневой вор",
    "Техническое_задание_Теневой_вор": "Техническое_задание_Теневой_вор",
    "Руководство_пользователя": "Руководство_пользователя",
    "Пояснительная_записка": "Пояснительная_записка",
    "Программа_и_методика_испытаний": "Программа_и_методика_испытаний",
    "Протокол_испытаний": "Протокол_испытаний",
}
REPORT_ADDENDA = {
    "ЛР26ТРПО.docx": (
        "В локальном комплекте теперь есть отдельное Word-ТЗ: «Техническое_задание_Теневой_вор.docx». "
        "Уточнения требований см. в «Спецификация требований_Теневой вор.docx». "
        "Рисунки 1 и 2 отражают состояние на дату первоначального отчёта."
    ),
    "ЛР28ТРПО4.docx": (
        "В Godot 4.7.2 повторно подтверждены семь прохождений без тревоги, 758 проверок симуляции "
        "и 10 проверок сцены без провалов. Windows x64-экспорт запущен отдельно от исходников. "
        "Подтверждены сохранение и эвакуация за 43 хода после восстановления тестового маршрута. "
        "См. «Протокол_испытаний.docx»."
    ),
    "Задача_на_день_23.11.2026.docx": (
        "Состояние и план выше относятся к 23 ноября. Позднее добавлены ТЗ, методика, протокол, "
        "руководство и снимки, обновлена спецификация. Введены проверка семи JSON-карт, сохранение "
        "забега, аудиошины и настройки; выполнен Windows-экспорт. Фактические границы проверки "
        "приведены в «Протокол_испытаний.docx». Демо, публикация и ревью здесь не подтверждаются."
    ),
}


def inline(paragraph, text):
    for part in re.split(r"(\*\*.+?\*\*|`[^`]+`)", text):
        if part.startswith("**") and part.endswith("**"):
            paragraph.add_run(part[2:-2]).bold = True
        elif part.startswith("`") and part.endswith("`"):
            paragraph.add_run(part[1:-1]).font.name = "Consolas"
        else:
            paragraph.add_run(part)


def render(source, destination):
    doc = Document()
    section = doc.sections[0]
    section.page_width, section.page_height = Cm(21), Cm(29.7)
    section.left_margin, section.right_margin = Cm(3), Cm(1.5)
    section.top_margin = section.bottom_margin = Cm(2)
    for style in ("Normal", "Title", "Heading 1", "Heading 2", "List Bullet"):
        doc.styles[style].font.name = "Times New Roman"
    doc.styles["Normal"].font.size = Pt(12)
    lines = source.read_text(encoding="utf-8").splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        if not line:
            continue
        if line.startswith("|"):
            rows = []
            while True:
                cols = [cell.strip() for cell in line.strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", cell) for cell in cols):
                    rows.append(cols)
                if i >= len(lines) or not lines[i].startswith("|"):
                    break
                line = lines[i]
                i += 1
            table = doc.add_table(rows=0, cols=len(rows[0]))
            table.style = "Table Grid"
            for row_id, cells in enumerate(rows):
                for col, text in zip(table.add_row().cells, cells):
                    inline(col.paragraphs[0], f"**{text}**" if row_id == 0 else text)
        elif line.startswith("### "):
            doc.add_heading(line[4:], level=2)
        elif line.startswith("## "):
            doc.add_heading(line[3:], level=1)
        elif line.startswith("# "):
            title = doc.add_heading(line[2:], level=0)
            title.alignment = WD_ALIGN_PARAGRAPH.CENTER
            doc.core_properties.title = line[2:]
        elif line.startswith("- "):
            inline(doc.add_paragraph(style="List Bullet"), line[2:])
        elif match := re.fullmatch(r"!\[(.+)]\((.+)\)", line):
            doc.add_picture(str(DOCS / match[2]), width=Cm(15))
            doc.add_paragraph(match[1], style="Caption")
        else:
            inline(doc.add_paragraph(), line)
    doc.core_properties.author = "Команда проекта Echoes of the Void"
    doc.save(destination)


def add_to_historical_reports():
    title = "Дополнение от 27.11.2026 — редакция 2.0"
    for name, text in REPORT_ADDENDA.items():
        destination = DOCS / name
        doc = Document(destination)
        if not any(paragraph.text == title for paragraph in doc.paragraphs):
            doc.add_page_break()
            doc.add_heading(title, level=1)
            doc.add_paragraph(text)
            doc.save(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update-reports", action="store_true", help="append the dated addenda once")
    args = parser.parse_args()
    for source_name, docx_name in NAMES.items():
        render(DOCS / f"{source_name}.md", DOCS / f"{docx_name}.docx")
    if args.update_reports:
        add_to_historical_reports()
