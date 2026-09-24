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


def rails_runs(season):
    """Пары (проверок, утверждений) по порядку серий — для сезонов, у которых
    артефакт не файл, а слой приложения.

    Такие сезоны проверяются на копии приложения: `support/reference.sh`
    кладёт в неё solution всех серий, прогоняет миграции и запускает проверки.
    Запускать серии по отдельности здесь нельзя — сезон кумулятивен.
    Возвращает None, если сезон устроен иначе."""
    script = sorted(glob.glob(f"{ROOT}/season-{season}-*/support/reference.sh"))
    if not script:
        return None
    out = subprocess.run([script[0]], capture_output=True, text=True, timeout=1800).stdout
    # Если прогон называет серии («серия: s05e03»), проверки складываются по
    # сериям: серия с двумя файлами даёт две строки, а серия с браузером в
    # обычном прогоне не даёт ни одной. Иначе — по порядку, как в сезоне 4.
    if re.search(r"^серия: s\d\de\d\d", out, re.M):
        totals = {}
        for code, runs, checks in re.findall(
                r"^серия: (s\d\de\d\d).*?(\d+) runs, (\d+) assertions, 0 failures, 0 errors",
                out, re.M | re.S):
            pair = totals.setdefault(code, [0, 0])
            pair[0] += int(runs)
            pair[1] += int(checks)
        return totals
    return re.findall(r"(\d+) runs, (\d+) assertions, 0 failures, 0 errors", out)


def stats(season):
    """Хронометраж и число проверок. Раннер выбирается по тому, что лежит в
    tests/: minitest у Ruby, встроенный node --test у остального."""
    items = list(series(season))
    minutes = sum(i["minutes"] for i in items)
    runs = checks = 0
    unmeasured = []
    environment = dict(os.environ, FORCE_SOLUTION="1")
    prepared = rails_runs(season)
    for index, item in enumerate(items):
        # Сезон с приложением уже посчитан одним прогоном: серии кумулятивны,
        # и по отдельности их не запустить.
        if prepared is not None:
            found = prepared.get(item["code"]) if isinstance(prepared, dict) else (
                prepared[index] if index < len(prepared) else None)
            if found:
                runs += int(found[0])
                checks += int(found[1])
            else:
                unmeasured.append(item["code"])
            continue
        # Серии с браузером в обычный подсчёт не входят: без установленного
        # chromium их прогон не падает, а ждёт. VISUAL=1 включает их обратно.
        if os.path.exists(f"{item['path']}/NEEDS_BROWSER") and not os.environ.get("VISUAL"):
            unmeasured.append(item["code"])
            continue
        ruby_tests = sorted(glob.glob(f"{item['path']}/tests/*.rb"))
        node_tests = sorted(glob.glob(f"{item['path']}/tests/*.test.mjs"))
        if ruby_tests:
            out = subprocess.run(
                ["ruby", os.path.basename(ruby_tests[0])],
                cwd=os.path.dirname(ruby_tests[0]), capture_output=True, text=True,
                env=environment, timeout=600,
            ).stdout
            found = re.search(r"(\d+) runs, (\d+) assertions, 0 failures, 0 errors", out)
        elif node_tests:
            out = subprocess.run(
                ["node", "--test", *[os.path.basename(t) for t in node_tests]],
                cwd=os.path.dirname(node_tests[0]), capture_output=True, text=True,
                env=environment, timeout=600,
            ).stdout
            found = re.search(r"^# pass (\d+)$", out, re.M)
            if not re.search(r"^# fail 0$", out, re.M):
                found = None
        else:
            found = None
        if not found:
            unmeasured.append(item["code"])
            continue
        runs += int(found.group(1))
        if found.lastindex and found.lastindex > 1:
            checks += int(found.group(2))
    line = (f"серий: {len(items)} · время: {minutes // 60} ч {minutes % 60:02d} мин · "
            f"проверок: {runs}")
    if checks:
        line += f" · утверждений: {checks}"
    if unmeasured:
        line += f" (не измерены без браузера: {', '.join(unmeasured)})"
    return line


if __name__ == "__main__":
    season_number = sys.argv[1] if len(sys.argv) > 1 else "01"
    link_prefix = ""
    for argument in sys.argv[2:]:
        if argument.startswith("--prefix="):
            link_prefix = argument.split("=", 1)[1]
    print(stats(season_number) if "--stats" in sys.argv
          else table(season_number, link_prefix))
