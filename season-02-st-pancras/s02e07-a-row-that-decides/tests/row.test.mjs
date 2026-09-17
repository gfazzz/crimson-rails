// CRIMSON RAILS — s02e07, проверка.
//
// Серия помечена NEEDS_BROWSER: раскладку нельзя проверить разбором файла.
// Разбор отвечает на вопрос «что написано», а здесь спрашивают «что
// получилось» — настоящие координаты боксов, посчитанные движком браузера.
//
//   npx playwright install chromium
//   make test-visual SEASON=02

import { test, describe, before, after } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readDocument, readStylesheet, specificity } from "../../support/check.mjs";
import { openPage } from "../../support/visual.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const ownHtml = join(here, "..", "artifacts", "bradshaw.html");
const ownCss = join(here, "..", "artifacts", "bradshaw.css");
const mine = existsSync(ownHtml) && existsSync(ownCss) && !process.env.FORCE_SOLUTION;
const dir = mine ? join(here, "..", "artifacts") : join(here, "..", "solution");

console.log(`Источник: ${mine ? "artifacts" : "solution"}/ (bradshaw.html + bradshaw.css)`);
if (!existsSync(ownCss)) console.log("(свода правил нет — проверяю эталон)");

const doc = readDocument(join(dir, "bradshaw.html"));
const sheet = readStylesheet(join(dir, "bradshaw.css"));
const view = await openPage(join(dir, "bradshaw.html"), join(dir, "bradshaw.css"), { width: 1024 });
after(() => view.close());

const px = (value) => Number.parseFloat(value);
const byX = (list) => [...list].sort((a, b) => a.x - b.x);
const byY = (list) => [...list].sort((a, b) => a.y - b.y);
const near = (a, b, tolerance = 1) => Math.abs(a - b) <= tolerance;
// Зазоры между соседями ряда: от правого края предыдущего до левого следующего.
const gapsX = (list) => byX(list).slice(1).map((item, i) => item.x - (byX(list)[i].x + byX(list)[i].width));
const gapsY = (list) => byY(list).slice(1).map((item, i) => item.y - (byY(list)[i].y + byY(list)[i].height));

const NAV = "nav li";
const LEGEND = ".legend li";

describe("оглавление встало в ряд", () => {
  test("пункты стоят в одном ряду", async () => {
    assert.equal(await view.count(NAV), 3, "Пунктов оглавления три — они из s02e01.");
    assert.equal(
      await view.rowsOf(NAV),
      1,
      "Пункты идут друг под другом: список остался блочным. Ряд начинается с display: flex.",
    );
  });

  test("маркеры списка убраны", async () => {
    assert.equal(
      await view.computed("nav ul", "list-style-type"),
      "none",
      "Точки маркеров в ряду читаются как мусор между пунктами.",
    );
    assert.equal(
      px(await view.computed("nav ul", "padding-inline-start")),
      0,
      "Вместе с маркерами снимают и отступ под них — иначе ряд начинается не от края полосы.",
    );
  });

  test("зазор между пунктами одинаковый", async () => {
    const gaps = gapsX(await view.boxes(NAV));
    assert.ok(gaps.every((g) => g > 0), `Пункты слиплись: зазоры ${gaps.map((g) => g.toFixed(1))}.`);
    assert.ok(
      gaps.every((g) => near(g, gaps[0])),
      `Зазоры разные: ${gaps.map((g) => g.toFixed(1))}. Ряд задаёт один зазор на всех.`,
    );
  });

  test("зазор объявлен зазором, а не полем", async () => {
    const declared = px(await view.computed("nav ul", "column-gap"));
    assert.ok(declared > 0, "column-gap не объявлен: зазор держится на полях пунктов.");
    const gaps = gapsX(await view.boxes(NAV));
    assert.ok(
      near(gaps[0], declared),
      `Между пунктами ${gaps[0].toFixed(1)}px при объявленном зазоре ${declared}px. ` +
        "Разницу дают чьи-то поля: во флексе они не схлопываются, а складываются с зазором.",
    );
  });
});

describe("шапка встала колонкой", () => {
  test("строки шапки разделены одинаково", async () => {
    const gaps = gapsY(await view.boxes("header > *"));
    assert.ok(gaps.length >= 2, "В шапке три строки: название справочника, заголовок линии, выпуск.");
    assert.ok(
      gaps.every((g) => near(g, gaps[0], 0.5)),
      `Зазоры в шапке разные: ${gaps.map((g) => g.toFixed(1))}.`,
    );
  });

  test("поле и зазор не сложились", async () => {
    const declared = px(await view.computed("header", "row-gap"));
    assert.ok(declared > 0, "Шапке объявляют зазор, а не поля строкам.");
    const gaps = gapsY(await view.boxes("header > *"));
    assert.ok(
      near(gaps[0], declared, 0.5),
      `Между строками шапки ${gaps[0].toFixed(1)}px при зазоре ${declared}px. ` +
        "Собственное поле строки во флексе не схлопывается — оно прибавляется к зазору.",
    );
  });
});

describe("условные обозначения — тот же ряд", () => {
  test("пункты стоят в одну линию", async () => {
    assert.ok((await view.count(LEGEND)) >= 4, "Обозначений на полосе четыре.");
    assert.equal(await view.rowsOf(LEGEND), 1, "При ширине в 1024px все четыре помещаются в ряд.");
  });

  test("пункты выровнены по одной верхней грани", async () => {
    const tops = (await view.boxes(LEGEND)).map((b) => b.y);
    assert.ok(tops.every((t) => near(t, tops[0])), `Верхние грани разъехались: ${tops.map((t) => t.toFixed(1))}.`);
  });
});

describe("ряд переносится сам", () => {
  before(async () => {
    await view.resize(380);
    await view.page.waitForTimeout(50);
  });

  test("оглавление стало больше чем одним рядом", async () => {
    assert.ok(
      (await view.rowsOf(NAV)) > 1,
      "При ширине в 380px ряд остался одним: без flex-wrap он не переносится, а сжимается.",
    );
  });

  test("условные обозначения перенеслись", async () => {
    assert.ok((await view.rowsOf(LEGEND)) > 1, "Четыре обозначения в 380px в один ряд не помещаются.");
  });

  test("ни один пункт не вылез за полосу", async () => {
    const body = await view.box("body");
    const padding = px(await view.computed("body", "padding-inline-end"));
    const edge = body.x + body.width - padding;
    for (const selector of [NAV, LEGEND]) {
      for (const item of await view.boxes(selector)) {
        assert.ok(
          item.x + item.width <= edge + 1,
          `Пункт «${selector}» выходит за край полосы на ${(item.x + item.width - edge).toFixed(1)}px. ` +
            "Ряд без переноса не сжимает текст — он вылезает наружу.",
        );
      }
    }
  });

  test("порядок пунктов не переставлен", async () => {
    const boxes = await view.boxes(NAV);
    const visual = [...boxes].sort((a, b) => a.y - b.y || a.x - b.x);
    assert.deepEqual(
      visual,
      boxes,
      "Порядок на экране разошёлся с порядком в разметке. Клавиатура и голос идут по разметке — " +
        "перестановка средствами раскладки их обманывает.",
    );
  });
});

describe("спрятанное осталось спрятанным", () => {
  before(async () => {
    await view.resize(1024);
    await view.page.waitForTimeout(50);
  });

  test("ссылка в обход размером в точку", async () => {
    const box = await view.box(".skip");
    assert.ok(
      box.width <= 2 && box.height <= 2,
      `Ссылка в обход занимает ${box.width.toFixed(0)}×${box.height.toFixed(0)}px — её видно.`,
    );
  });

  test("при фокусе она возвращается", async () => {
    await view.page.focus(".skip");
    const box = await view.box(".skip");
    assert.ok(
      box.width > 40 && box.height > 10,
      `После фокуса ссылка так и осталась ${box.width.toFixed(0)}×${box.height.toFixed(0)}px. ` +
        "Приём из s02e06 работает только парой правил.",
    );
    await view.page.evaluate(() => document.activeElement.blur());
  });
});

describe("свод остался сводом", () => {
  const weight = (s) => specificity(s);
  const heavier = (a, b) => {
    for (let i = 0; i < 3; i += 1) if (a[i] !== b[i]) return a[i] > b[i];
    return false;
  };

  test("ни одного «в обязательном порядке» и ни одного идентификатора", () => {
    assert.deepEqual(sheet.important().map((i) => `${i.selector} { ${i.property} }`), []);
    assert.deepEqual(sheet.selectors().filter((s) => weight(s)[0] > 0), []);
  });

  test("переопределения стоят ниже и точнее", () => {
    const seen = new Map();
    for (const rule of sheet.base) {
      for (const property of Object.keys(rule.declarations)) {
        const previous = seen.get(property);
        if (previous) {
          assert.ok(
            !heavier(weight(previous), weight(rule.selector)),
            `Свойство ${property}: «${previous}» стоит выше, чем «${rule.selector}», но весит больше.`,
          );
        }
        seen.set(property, rule.selector);
      }
    }
  });

  test("классы разметки и правила свода сходятся", () => {
    const inMarkup = new Set();
    for (const node of doc.walk()) {
      for (const name of (doc.attr(node, "class") ?? "").split(/\s+/)) if (name) inMarkup.add(name);
    }
    const inSheet = new Set();
    for (const selector of sheet.selectors()) {
      for (const m of selector.matchAll(/\.([A-Za-z_][\w-]*)/g)) inSheet.add(m[1]);
    }
    assert.deepEqual([...inMarkup].filter((c) => !inSheet.has(c)), []);
    assert.deepEqual([...inSheet].filter((c) => !inMarkup.has(c)), []);
  });

  test("структура полосы и таблица на месте", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.ok(!doc.closest(doc.all("a")[0], "nav"));
    const table = doc.tables()[0];
    assert.deepEqual(table.unscopedHeaders().map((th) => doc.text(th)), []);
    assert.equal(new Set(table.widths()).size, 1);
    for (const row of table.bodyRows()) {
      const first = table.cells(row)[0];
      assert.ok(doc.tag(first) === "th" && doc.attr(first, "scope") === "row", `Строка «${doc.text(first)}» без заголовка.`);
    }
    for (const link of doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"))) {
      assert.ok(doc.byId(doc.attr(link, "href").slice(1)), `Ссылка на ${doc.attr(link, "href")} ведёт в пустоту.`);
    }
  });
});
