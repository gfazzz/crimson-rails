#!/usr/bin/env python3
"""Таблица серий сезона — из шапок самих серий, а не из головы.

    tools/season_table.py 01            # markdown-таблица
    tools/season_table.py 01 --stats    # хронометраж и число проверок
"""
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def series(season):
    for readme in sorted(glob.glob(f"{ROOT}/season-{season}-*/s{season}e*/README.md")):
        directory = os.path.dirname(readme)
        with open(readme, encoding="utf-8") as handle:
            text = handle.read()
        head = text.split("```", 2)[1]
        title = re.search(r"^# (s\d\de\d\d) — (.+)$", text, re.M)
        yield {
            "dir": os.path.basename(directory),
            "path": directory,
            "code": title.group(1),
            "title": title.group(2),
            "concept": re.search(r"Концепт: (.+)", head).group(1).strip(),
            "artifact": re.search(r"Артефакт: (.+?)\s{2,}", head).group(1).strip(),
            "minutes": int(re.search(r"Время: ~(\d+) мин", head).group(1)),
            "stars": re.search(r"Сложность: (⭐+)", head).group(1),
        }


def table(season, prefix=""):
    rows = ["| Серия | Концепт | Артефакт | ⏱ | |", "|---|---|---|---|---|"]
    for item in series(season):
        rows.append(
            f"| [{item['code']}]({prefix}{item['dir']}/) — {item['title']} | {item['concept']} "
            f"| {item['artifact']} | ~{item['minutes']} мин | {item['stars']} |"
        )
    return "\n".join(rows)


def stats(season):
    items = list(series(season))
    minutes = sum(i["minutes"] for i in items)
    runs = checks = 0
    for item in items:
        test = glob.glob(f"{item['path']}/tests/*.rb")[0]
        out = subprocess.run(
            ["ruby", os.path.basename(test)],
            cwd=os.path.dirname(test), capture_output=True, text=True,
        ).stdout
        found = re.search(r"(\d+) runs, (\d+) assertions", out)
        if found:
            runs += int(found.group(1))
            checks += int(found.group(2))
    return (f"серий: {len(items)} · время: {minutes // 60} ч {minutes % 60:02d} мин · "
            f"проверок: {runs} · утверждений: {checks}")


if __name__ == "__main__":
    season_number = sys.argv[1] if len(sys.argv) > 1 else "01"
    link_prefix = ""
    for argument in sys.argv[2:]:
        if argument.startswith("--prefix="):
            link_prefix = argument.split("=", 1)[1]
    print(stats(season_number) if "--stats" in sys.argv
          else table(season_number, link_prefix))
