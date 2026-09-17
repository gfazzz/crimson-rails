// CRIMSON RAILS — s02e10, проверка.
//
// Здесь проверяется, с какой полосы свод начинается и чем она становится
// добавкой: разбор правил внутри медиазапросов и снаружи них. Как выглядит
// узкое окно, разбор не знает — он знает, что об этом объявлено.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readDocument, readStylesheet, specificity } from "../../support/check.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const ownHtml = join(here, "..", "artifacts", "bradshaw.html");
const ownCss = join(here, "..", "artifacts", "bradshaw.css");
const mine = existsSync(ownHtml) && existsSync(ownCss) && !process.env.FORCE_SOLUTION;
const dir = mine ? join(here, "..", "artifacts") : join(here, "..", "solution");

console.log(`Источник: ${mine ? "artifacts" : "solution"}/ (bradshaw.html + bradshaw.css)`);
if (!existsSync(ownCss)) console.log("(свода правил нет — проверяю эталон)");

const doc = readDocument(join(dir, "bradshaw.html"));
const sheet = readStylesheet(join(dir, "bradshaw.css"));

const weight = (s) => specificity(s);
const value = (rule, property) => rule.declarations[property]?.value ?? null;
// Рисунок сетки: строки чертежа, каждая — список имён областей.
const plan = (declared) =>
  [...(declared ?? "").matchAll(/"([^"]*)"/g)].map((m) => m[1].trim().split(/\s+/).filter(Boolean));
const areasOf = (declared) => new Set(plan(declared).flat().filter((n) => n !== "."));

const withAreas = (rules) => rules.filter((r) => r.declarations["grid-template-areas"]);
const basePlan = () => {
  const rule = withAreas(sheet.base).at(-1);
  assert.ok(rule, "В своде нет рисунка сетки (s02e08).");
  return rule;
};
// Запросы про ширину окна — те, где встречается width.
const widthQueries = () => sheet.mediaQueries().filter((q) => /width/i.test(q));

describe("свод начинается с узкой полосы", () => {
  test("базовый рисунок — в одну колонку", () => {
    const rows = plan(value(basePlan(), "grid-template-areas"));
    const wide = rows.filter((row) => row.length > 1);
    assert.deepEqual(
      wide.map((row) => row.join(" ")),
      [],
      "Основной свод — тот, что достаётся всем: телефону, часам, браузеру без поддержки " +
        "медиазапросов. Начинают с одной колонки и добавляют вторую, а не наоборот: " +
        "добавку можно не получить, основу получают всегда.",
    );
  });

  test("добавки объявлены снизу вверх", () => {
    const backwards = widthQueries().filter((q) => /max-width|width\s*<=|<=\s*width|width\s*</i.test(q));
    assert.deepEqual(
      backwards,
      [],
      "Запрос «не шире, чем» отнимает у узкого окна то, что ему уже дали. " +
        "Запрос «не уже, чем» добавляет широкому то, чего у него не было.",
    );
    assert.ok(widthQueries().length >= 1, "Ни одного запроса про ширину: полоса не меняется вовсе.");
  });

  test("перелом задан от кегля, а не от пикселя", () => {
    for (const query of widthQueries()) {
      assert.ok(
        !/\d+px/.test(query),
        `Перелом «${query}» задан в пикселях. Читатель, увеличивший шрифт, окна не менял — ` +
          "и перелом не сработает, хотя текста в строку влезает вдвое меньше. В em запрос " +
          "считается от кегля браузера и переживает увеличение.",
      );
      assert.match(query, /\d*\.?\d+\s*r?em/, `В переломе «${query}» нет меры от кегля.`);
    }
  });

  test("переломов не больше трёх", () => {
    assert.ok(
      widthQueries().length <= 3,
      `Переломов ${widthQueries().length}. Их назначает содержимое — та ширина, на которой ` +
        "полоса перестаёт читаться, — а не список моделей телефонов, который устареет к осени.",
    );
  });

  test("в добавках не пересматривают кегли", () => {
    const sizes = sheet.rules
      .filter((r) => r.media !== null && r.media !== "print" && r.declarations["font-size"])
      .map((r) => `@media ${r.media} { ${r.selector} }`);
    assert.deepEqual(
      sizes,
      [],
      "Кегль уже текучий: шкала из s02e09 растёт вместе с окном сама. Пересматривать её " +
        "в медиазапросе значит делать ту же работу дважды и получить скачок на переломе.",
    );
  });
});

describe("широкое окно — добавка", () => {
  test("в добавке объявлены две колонки", () => {
    const rules = withAreas(sheet.rules.filter((r) => r.media !== null && r.media !== "print"));
    assert.ok(rules.length >= 1, "Добавка ничего не перечерчивает: рисунок сетки в ней не объявлен.");
    const rows = plan(value(rules.at(-1), "grid-template-areas"));
    assert.ok(
      rows.some((row) => row.length === 2),
      "В добавке тот же одноколоночный рисунок. Широкому окну полагается служебная колонка сбоку.",
    );
  });

  test("добавка раздаёт те же области", () => {
    const base = areasOf(value(basePlan(), "grid-template-areas"));
    const rules = withAreas(sheet.rules.filter((r) => r.media !== null && r.media !== "print"));
    const wide = areasOf(value(rules.at(-1), "grid-template-areas"));
    assert.deepEqual(
      [...base].filter((name) => !wide.has(name)),
      [],
      "В широком рисунке потерялись области, которые есть в узком: элемент, которому не " +
        "нашлось места, встанет туда, куда его положит автоматическое размещение.",
    );
  });
});

describe("расписание влезает в узкое окно", () => {
  const scrollRules = () =>
    sheet.rules.filter((r) => {
      const v = value(r, "overflow-x") ?? value(r, "overflow");
      return v && /auto|scroll/.test(v);
    });

  const wrapper = () => {
    for (const rule of scrollRules()) {
      const name = rule.selector.match(/\.([A-Za-z_][\w-]*)/)?.[1];
      if (!name) continue;
      const node = [...doc.walk()].find(
        (n) => (doc.attr(n, "class") ?? "").split(/\s+/).includes(name) && [...doc.walk(n)].some((c) => c.tagName === "table"),
      );
      if (node) return node;
    }
    return null;
  };

  test("таблица лежит в прокручиваемой области", () => {
    assert.ok(
      wrapper(),
      "Расписание в пять колонок не влезает ни в телефон, ни в широкое окно при крупном шрифте. " +
        "Уменьшать кегль нельзя, переносить столбцы некуда — значит область прокручивается.",
    );
  });

  test("область доступна с клавиатуры", () => {
    const box = wrapper();
    assert.equal(
      doc.attr(box, "tabindex"),
      "0",
      "Прокручиваемую область, в которую нельзя попасть клавишей, нельзя и прокрутить " +
        "без мыши. tabindex=\"0\" ставит её в обход на своё место.",
    );
  });

  test("у области есть роль и имя", () => {
    const box = wrapper();
    assert.equal(
      doc.attr(box, "role"),
      "region",
      "Попав в область клавишей, читатель должен услышать, куда он попал. Роль region " +
        "объявляет её местом, а не просто коробкой.",
    );
    const labelledby = doc.attr(box, "aria-labelledby");
    const label = doc.attr(box, "aria-label");
    assert.ok(labelledby || label, "У области нет имени: «регион» без названия ничего не сообщает.");
    if (labelledby) {
      assert.ok(doc.byId(labelledby), `aria-labelledby ведёт на #${labelledby}, а такого места на полосе нет.`);
    }
  });

  test("прокрутка объявлена всегда, а не в добавке", () => {
    const outside = scrollRules().some((r) => r.media === null);
    assert.ok(
      outside,
      "Прокрутка объявлена только внутри медиазапроса. Узким окно делает не только телефон: " +
        "достаточно увеличить шрифт на широком экране.",
    );
  });
});

describe("полоса печатается", () => {
  const printRules = () => sheet.rules.filter((r) => r.media === "print");

  test("для бумаги есть свои правила", () => {
    assert.ok(
      printRules().length >= 2,
      "Расписание печатают. Без печатного набора на бумагу уедут фон, оглавление по ссылкам " +
        "и полоса прокрутки.",
    );
  });

  test("на бумаге рисунок в одну колонку", () => {
    const rules = withAreas(printRules());
    assert.ok(rules.length >= 1, "Печатный набор не перечерчивает сетку.");
    const wide = plan(value(rules.at(-1), "grid-template-areas")).filter((row) => row.length > 1);
    assert.deepEqual(wide.map((r) => r.join(" ")), [], "На бумаге колонка одна: сбоку печатать нечего.");
  });

  test("на бумаге не печатают оглавление и ссылку в обход", () => {
    const hidden = printRules()
      .filter((r) => value(r, "display") === "none")
      .map((r) => r.selector);
    assert.ok(
      hidden.some((s) => s.includes("nav")),
      "Оглавление по ссылкам на бумаге бесполезно: нажать нечего.",
    );
    const skipClass = (doc.attr(doc.all("a")[0], "class") ?? "").split(/\s+/)[0];
    assert.ok(
      hidden.some((s) => s.includes(`.${skipClass}`)),
      "Ссылка в обход на бумаге — строка ни о чём.",
    );
  });

  test("на бумаге печатают содержание", () => {
    const hidden = printRules()
      .filter((r) => value(r, "display") === "none")
      .map((r) => r.selector);
    for (const needed of ["main", "table", "footer", "aside"]) {
      assert.ok(
        !hidden.includes(needed),
        `Печатный набор прячет <${needed}>. На бумагу идёт содержание, а не его отсутствие.`,
      );
    }
  });
});

describe("свод остался сводом", () => {
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
        if (property.startsWith("--")) continue;
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

  test("структура полосы цела", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.ok(doc.first("aside"));
    assert.ok(!doc.closest(doc.all("a")[0], "nav"));
    const meta = doc.all("meta").find((m) => doc.attr(m, "name") === "viewport");
    assert.ok(meta, "Объявление области просмотра из s02e09 на месте.");
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
});
