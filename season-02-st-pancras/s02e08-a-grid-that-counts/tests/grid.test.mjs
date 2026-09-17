// CRIMSON RAILS — s02e08, проверка.
//
// Серия помечена NEEDS_BROWSER. Раскладку сетки проверяют по настоящим
// координатам областей: где что встало, какой ширины, с каким зазором.
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

const px = (v) => Number.parseFloat(v);
const near = (a, b, tolerance = 1) => Math.abs(a - b) <= tolerance;
const right = (box) => box.x + box.width;
const bottom = (box) => box.y + box.height;

// Внутренняя область полосы — то, что сетка делит между областями.
let field;
let boxes = {};
const AREAS = ["header", "nav", "main", "aside", "footer"];

before(async () => {
  const body = await view.box("body");
  const start = px(await view.computed("body", "padding-inline-start"));
  const end = px(await view.computed("body", "padding-inline-end"));
  field = { x: body.x + start, width: body.width - start - end };
  for (const selector of AREAS) {
    // Отсутствующая область — не крушение прогона, а понятная красная проверка.
    boxes[selector] = await view.box(selector).catch(() => null);
  }
});

const area = (selector) => {
  assert.ok(boxes[selector], `На полосе нет <${selector}> — или он не отрисован.`);
  return boxes[selector];
};

describe("полоса легла в сетку", () => {
  test("служебные сведения вынесены в отдельный ориентир", () => {
    const side = doc.first("aside");
    assert.ok(
      side,
      "Сведения о выпуске — не часть содержания линии. Им место в <aside>: отдельный ориентир " +
        "страницы, по которому можно прыгнуть, и отдельная область сетки.",
    );
    assert.ok(doc.text(side).trim().length > 20, "Справка пуста.");
    assert.ok(!doc.closest(side, "main"), "<aside> внутри <main> — это часть содержания, а не справка рядом с ним.");
  });

  test("у полосы объявлена сетка", async () => {
    assert.equal(
      await view.computed("body", "display"),
      "grid",
      "Полоса осталась потоком: области встают друг под друга, и колонок нет.",
    );
  });

  test("колонок ровно две", async () => {
    const tracks = (await view.computed("body", "grid-template-columns")).trim().split(/\s+/);
    assert.equal(
      tracks.length,
      2,
      `Колонок ${tracks.length} (${tracks.join(", ")}). Полоса делится на содержание и справку.`,
    );
  });

  test("области названы словами", async () => {
    const template = await view.computed("body", "grid-template-areas");
    assert.notEqual(
      template,
      "none",
      "Области не названы. Расстановка по номерам линий читается только со схемой на столе; " +
        "имена читаются сами.",
    );
    for (const selector of AREAS) {
      const placed = boxes[selector] ? await view.computed(selector, "grid-area") : "auto";
      assert.ok(
        !placed.startsWith("auto"),
        `<${selector}> не назначена область: её поставит автоматическое размещение, и куда — ` +
          "зависит от порядка в разметке.",
      );
    }
  });

  test("у сетки нет невостребованных областей", async () => {
    const template = await view.computed("body", "grid-template-areas");
    const declared = new Set([...template.matchAll(/[\w-]+/g)].map((m) => m[0]));
    const claimed = new Set();
    for (const selector of AREAS) {
      if (!boxes[selector]) continue;
      claimed.add((await view.computed(selector, "grid-area")).split(" / ")[0]);
    }
    const orphans = [...declared].filter((name) => !claimed.has(name));
    assert.deepEqual(
      orphans,
      [],
      "Эти области нарисованы в сетке, но никем не заняты — пустое место, о котором знает " +
        "только свод.",
    );
  });
});

describe("кто где встал", () => {
  test("шапка, оглавление и подвал — во всю ширину полосы", () => {
    for (const selector of ["header", "nav", "footer"]) {
      assert.ok(
        near(area(selector).width, field.width, 1.5),
        `<${selector}> шириной ${area(selector).width.toFixed(0)}px при полосе ` +
          `${field.width.toFixed(0)}px: область не растянута на обе колонки.`,
      );
    }
  });

  test("содержание и справка стоят рядом", () => {
    assert.ok(
      right(area("main")) <= area("aside").x + 1,
      "Содержание и справка налезают друг на друга или стоят в одной колонке.",
    );
    assert.ok(
      near(area("main").y, area("aside").y, 1),
      `Верхние грани разъехались: main на ${area("main").y.toFixed(0)}, aside на ` +
        `${area("aside").y.toFixed(0)}. Обе области в одной строке сетки и выровнены по её началу.`,
    );
  });

  test("справка прижата к правому краю полосы", () => {
    assert.ok(
      near(right(area("aside")), field.x + field.width, 1.5),
      "Справка не доходит до края полосы: вторая колонка шире своего содержимого.",
    );
  });

  test("справка не растянута на высоту содержания", async () => {
    const side = area("aside");
    const children = await view.boxes("aside > *");
    assert.ok(children.length >= 2, "В справке есть заголовок и хотя бы одна строка.");
    const contentBottom = Math.max(...children.map(bottom));
    const padding = px(await view.computed("aside", "padding-block-end"));
    const lastMargin = px(await view.computed("aside > :last-child", "margin-block-end"));
    const empty = bottom(side) - contentBottom - padding - lastMargin;
    assert.ok(
      empty <= 4,
      `Под справкой ${empty.toFixed(0)}px пустоты: область растянута на всю высоту строки сетки. ` +
        "По умолчанию клетка растягивает своё содержимое — строку сетки задаёт самая высокая " +
        "область, и все остальные тянутся за ней.",
    );
  });

  test("зазор между колонками — объявленный", async () => {
    const declared = px(await view.computed("body", "column-gap"));
    assert.ok(declared > 0, "Колонки сетки разделяют зазором, а не полями соседей.");
    assert.ok(
      near(area("aside").x - right(area("main")), declared),
      `Между колонками ${(area("aside").x - right(area("main"))).toFixed(1)}px при объявленном ` +
        `${declared}px: разницу дают чьи-то поля.`,
    );
  });

  test("зазоры между строками — объявленные", async () => {
    const declared = px(await view.computed("body", "row-gap"));
    assert.ok(
      near(area("nav").y - bottom(area("header")), declared, 1),
      `Между шапкой и оглавлением ${(area("nav").y - bottom(area("header"))).toFixed(1)}px при ` +
        `зазоре ${declared}px.`,
    );
    const row = Math.max(bottom(area("main")), bottom(area("aside")));
    assert.ok(
      near(area("footer").y - row, declared, 1),
      `Перед подвалом ${(area("footer").y - row).toFixed(1)}px при зазоре ${declared}px.`,
    );
  });

  test("порядок областей совпадает с порядком в разметке", () => {
    assert.ok(area("header").y < area("nav").y, "Шапка ниже оглавления.");
    assert.ok(area("nav").y < area("main").y, "Оглавление ниже содержания.");
    assert.ok(area("main").y < area("footer").y, "Содержание ниже подвала.");
    assert.ok(
      area("main").x < area("aside").x,
      "Справка встала левее содержания: рисунок сетки разошёлся с разметкой, и клавиатура " +
        "пойдёт не туда, куда смотрит глаз.",
    );
  });
});

describe("ничто не вылезает", () => {
  test("у страницы нет прокрутки вбок", async () => {
    assert.equal(
      await view.overflowsHorizontally(),
      false,
      "Страница прокручивается вбок: что-то в сетке шире своей колонки.",
    );
  });

  test("таблица не выходит за свою колонку", async () => {
    const table = await view.box("table");
    assert.ok(
      right(table) <= right(area("main")) + 1,
      `Таблица шире колонки содержания на ${(right(table) - right(area("main"))).toFixed(1)}px. ` +
        "Колонка сетки не растёт под содержимое молча — но и не обрезает его.",
    );
  });

  test("оглавление и обозначения остались рядами", async () => {
    assert.equal(await view.rowsOf("nav li"), 1, "Ряд оглавления из s02e07 распался.");
    assert.ok((await view.count(".legend li")) >= 4, "Условные обозначения из s02e07 на месте.");
    for (const item of await view.boxes(".legend li")) {
      assert.ok(
        right(item) <= right(area("main")) + 1,
        "Обозначения вылезли за колонку содержания: ряд внутри колонки переносится по её ширине.",
      );
    }
  });
});

describe("фокус не двигает сетку", () => {
  test("ссылка в обход не становится клеткой", async () => {
    const before = await view.box("main");
    await view.page.focus(".skip");
    const after = await view.box("main");
    assert.ok(
      near(before.x, after.x) && near(before.y, after.y),
      `Полоса сдвинулась на ${(after.y - before.y).toFixed(0)}px по вертикали и ` +
        `${(after.x - before.x).toFixed(0)}px по горизонтали. Ссылка, вернувшаяся в поток, ` +
        "стала элементом сетки и заняла собственную клетку.",
    );
  });

  test("и при этом она разворачивается", async () => {
    const box = await view.box(".skip");
    assert.ok(
      box.width > 40 && box.height > 10,
      `После фокуса ссылка осталась ${box.width.toFixed(0)}×${box.height.toFixed(0)}px.`,
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

  test("структура полосы цела", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.ok(doc.first("aside"), "Справка — <aside>, а не безымянный блок.");
    assert.ok(!doc.closest(doc.all("a")[0], "nav"));
    const table = doc.tables()[0];
    assert.deepEqual(table.unscopedHeaders().map((th) => doc.text(th)), []);
    for (const row of table.bodyRows()) {
      const first = table.cells(row)[0];
      assert.ok(doc.tag(first) === "th" && doc.attr(first, "scope") === "row", `Строка «${doc.text(first)}» без заголовка.`);
    }
    for (const link of doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"))) {
      assert.ok(doc.byId(doc.attr(link, "href").slice(1)), `Ссылка на ${doc.attr(link, "href")} ведёт в пустоту.`);
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
});
