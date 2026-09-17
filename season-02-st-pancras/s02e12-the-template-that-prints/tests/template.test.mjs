// CRIMSON RAILS — s02e12, приёмка сезона.
//
// Финал ничего нового не проверяет и всё принимает: полоса печатается
// шаблоном по листу выпуска, а дальше к ней прикладываются все требования
// сезона — семантика, таблица, доступность, каскад, меры, раскладка, цвет.
//
// Главная проверка здесь одна и она простая: шаблон печатают дважды, по двум
// разным листам. Всё, что вшито в шаблон, переживёт смену листа и попадётся.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, mkdtempSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readDocument, readStylesheet, specificity, contrast, parseColor } from "../../support/check.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const pick = (name) => {
  const own = join(root, "artifacts", name);
  return existsSync(own) && !process.env.FORCE_SOLUTION ? own : join(root, "solution", name);
};

const templateFile = pick("bradshaw.html.erb");
const cssFile = pick("bradshaw.css");
const source = templateFile.includes("artifacts") ? "artifacts" : "solution";
console.log(`Источник: ${source}/bradshaw.html.erb`);
if (!existsSync(join(root, "artifacts", "bradshaw.html.erb"))) console.log("(шаблона нет — проверяю эталон)");

const ruby = spawnSync("ruby", ["-v"], { encoding: "utf8" });
if (ruby.error) {
  console.log("Ruby не найден. Полосу печатает ruby render.rb — поставь Ruby 3.0 или новее.");
  process.exit(1);
}

const issueFile = join(root, "data", "april-1891.json");
const controlFile = join(here, "fixtures", "control.json");
const scratch = mkdtempSync(join(tmpdir(), "crimson-"));

const print = (data, out) => {
  const done = spawnSync("ruby", [join(root, "render.rb"), templateFile, data, out], { encoding: "utf8" });
  if (done.status !== 0) {
    console.log(done.stderr || done.stdout);
    throw new Error(`шаблон не напечатал полосу по листу ${data}`);
  }
  return out;
};

const issue = JSON.parse(readFileSync(issueFile, "utf8"));
const control = JSON.parse(readFileSync(controlFile, "utf8"));

// Полоса кладётся рядом с артефактом только тогда, когда печатается твой
// шаблон: прогон эталона ничего в artifacts/ не оставляет.
const mainPage = print(
  issueFile,
  source === "artifacts" ? join(root, "artifacts", "bradshaw.html") : join(scratch, "bradshaw.html"),
);
const controlPage = print(controlFile, join(scratch, "control.html"));

const doc = readDocument(mainPage);
const other = readDocument(controlPage);
const sheet = readStylesheet(cssFile);
const rawMain = readFileSync(mainPage, "utf8");

const scheduleOf = (data) => data.sections.find((s) => s.schedule)?.schedule;
const printed = (data) => scheduleOf(data).stations.filter((s) => s.print).map((s) => s.name);
const suppressed = (data) => scheduleOf(data).stations.filter((s) => !s.print).map((s) => s.name);
const rowNames = (page) =>
  page.tables()[0].bodyRows().map((row) => page.text(page.tables()[0].cells(row)[0]).replace(/\[.*\]$/, "").trim());

describe("полосу печатает шаблон", () => {
  test("заголовок собран из листа выпуска", () => {
    const title = doc.text(doc.first("title"));
    assert.ok(title.includes(issue.title), `В <title> нет названия линии из листа: «${title}».`);
    assert.ok(title.includes(issue.issue.label), "В <title> нет выпуска из листа.");
    assert.equal(doc.text(doc.first("h1")).trim(), issue.title);
  });

  test("оглавление напечатано по листу", () => {
    for (const [page, data] of [[doc, issue], [other, control]]) {
      const links = page.all("a").filter((a) => page.closest(a, "nav"));
      const names = links.map((a) => page.text(a).trim());
      for (const section of data.sections) {
        assert.ok(names.includes(section.name), `В оглавлении нет раздела «${section.name}».`);
      }
      const current = links.filter((a) => page.attr(a, "aria-current"));
      assert.equal(current.length, 1, "Текущий раздел помечается ровно один раз (s02e04).");
      assert.equal(
        page.text(current[0]).trim(),
        data.sections.find((s) => s.current).name,
        "Текущим помечен не тот раздел, что назван текущим в листе: пометка стоит по порядку, " +
          "а не по данным.",
      );
    }
  });

  test("время в ячейках — из листа", () => {
    const table = doc.tables()[0];
    const wanted = scheduleOf(issue).stations.filter((s) => s.print);
    const rows = table.bodyRows();
    assert.equal(rows.length, wanted.length);
    rows.forEach((row, index) => {
      const times = table.cells(row).slice(1).map((cell) => doc.text(cell).trim());
      assert.deepEqual(times, wanted[index].times, `Строка «${wanted[index].name}» напечатана не по листу.`);
    });
  });

  test("примечания и обозначения — из листа", () => {
    for (const note of issue.notes.items) {
      const item = doc.byId(note.id);
      assert.ok(item, `Примечания ${note.id} на полосе нет.`);
      assert.equal(doc.text(item).trim(), note.text, "Текст примечания разошёлся с листом.");
    }
    const legend = [...doc.walk()].find((n) => (doc.attr(n, "class") ?? "").split(/\s+/).includes("legend"));
    assert.deepEqual(doc.children(legend).map((li) => doc.text(li).trim()), scheduleOf(issue) && issue.sections[0].legend);
  });

  test("значения из листа экранированы", () => {
    assert.ok(
      rawMain.includes("&amp;"),
      "Амперсанд из листа напечатан как есть. В обычном ERB печать не экранирует — " +
        "значит всякое значение, в котором встретится &, < или кавычка, уедет в разметку " +
        "как разметка. В Rails то же самое делается само.",
    );
    const aside = doc.first("aside");
    assert.ok(doc.text(aside).includes(issue.aside.printer), "Текст служебной колонки разошёлся с листом.");
  });
});

describe("в шаблоне нет данных", () => {
  test("по другому листу печатается другая полоса", () => {
    assert.equal(other.text(other.first("h1")).trim(), control.title);
    const names = rowNames(other);
    assert.deepEqual(names, printed(control), "Таблица второй полосы напечатана не по своему листу.");
  });

  test("ни одной станции первого листа во второй полосе", () => {
    const text = other.text();
    for (const name of printed(issue)) {
      assert.ok(
        !text.includes(name),
        `«${name}» напечаталась по чужому листу. Значит она не приходит из данных, а лежит ` +
          "в самом шаблоне — как та строка в образце девяностого года.",
      );
    }
  });

  test("ни одной станции с пометой «не печатать»", () => {
    for (const [page, data] of [[doc, issue], [other, control]]) {
      const names = rowNames(page);
      for (const name of suppressed(data)) {
        assert.ok(
          !names.includes(name),
          `«${name}» напечатана в таблице, хотя в листе у неё стоит «не печатать». ` +
            "Служебная остановка, попавшая в расписание, для всякого читающего становится станцией.",
        );
      }
      for (const name of printed(data)) {
        assert.ok(names.includes(name), `«${name}» из листа на полосу не попала.`);
      }
    }
  });

  test("ширина таблицы следует за числом поездов", () => {
    for (const [page, data] of [[doc, issue], [other, control]]) {
      const table = page.tables()[0];
      assert.equal(new Set(table.widths()).size, 1, "Строки таблицы разной длины.");
      assert.equal(table.widthOf(table.bodyRows()[0]), scheduleOf(data).trains.length + 1);
    }
  });

  test("ссылка в обход ведёт туда, куда сказано в листе", () => {
    for (const [page, data] of [[doc, issue], [other, control]]) {
      const first = page.all("a")[0];
      assert.equal(page.attr(first, "href"), `#${data.skip.to}`);
      assert.equal(page.text(first).trim(), data.skip.text);
      const target = page.byId(data.skip.to);
      assert.ok(target && (page.tag(target) === "main" || page.closest(target, "main")));
    }
  });
});

describe("приёмка сезона: полоса", () => {
  for (const [name, page] of [["выпуск", () => doc], ["контрольный лист", () => other]]) {
    test(`${name}: семантика`, () => {
      const p = page();
      assert.equal(p.attr(p.first("html"), "lang"), "ru");
      assert.equal(p.count("h1"), 1);
      assert.deepEqual(p.headingJumps(), []);
      assert.equal(p.count("div"), 0);
      for (const landmark of ["header", "nav", "main", "aside", "footer"]) {
        assert.equal(p.count(landmark), 1, `Ориентир <${landmark}> должен быть ровно один.`);
      }
      const foreign = [...p.walk()].filter((n) => n.tagName !== "html" && p.attr(n, "lang"));
      assert.ok(foreign.length >= 1, "Иноязычное вкрапление помечается своим lang (s02e04).");
    });

    test(`${name}: таблица`, () => {
      const p = page();
      const table = p.tables()[0];
      assert.ok(table.caption, "У таблицы есть <caption> (s02e02).");
      assert.deepEqual(table.unscopedHeaders().map((th) => p.text(th)), []);
      assert.ok(table.headRows().length >= 2, "Шапка таблицы в две строки: группы и поезда.");
      for (const row of table.bodyRows()) {
        const first = table.cells(row)[0];
        assert.ok(p.tag(first) === "th" && p.attr(first, "scope") === "row", "Строка без заголовка.");
      }
    });

    test(`${name}: доступность`, () => {
      const p = page();
      const first = p.all("a")[0];
      assert.ok(!p.closest(first, "nav"), "Первая ссылка полосы — ссылка в обход (s02e04).");
      for (const image of p.all("img")) {
        assert.ok(p.attr(image, "alt") !== null, `У <img src="${p.attr(image, "src")}"> нет alt.`);
      }
      assert.deepEqual([...p.walk()].filter((n) => Number(p.attr(n, "tabindex") ?? 0) > 0).map((n) => p.tag(n)), []);
      const redundant = { nav: "navigation", main: "main", header: "banner", footer: "contentinfo", table: "table" };
      for (const [tag, role] of Object.entries(redundant)) {
        for (const node of p.all(tag)) assert.notEqual(p.attr(node, "role"), role);
      }
      const meta = p.all("meta").find((m) => p.attr(m, "name") === "viewport");
      assert.match(p.attr(meta, "content") ?? "", /width\s*=\s*device-width/);
      const box = [...p.walk()].find((n) => p.attr(n, "role") === "region");
      assert.ok(box, "Прокручиваемая область расписания (s02e10).");
      assert.equal(p.attr(box, "tabindex"), "0");
      const labelledby = p.attr(box, "aria-labelledby");
      assert.ok(p.attr(box, "aria-label") || (labelledby && p.byId(labelledby)), "У области нет имени.");
    });

    test(`${name}: ссылки ведут куда-то`, () => {
      const p = page();
      for (const link of p.all("a").filter((a) => (p.attr(a, "href") ?? "").startsWith("#"))) {
        assert.ok(p.byId(p.attr(link, "href").slice(1)), `Ссылка на ${p.attr(link, "href")} ведёт в пустоту.`);
      }
    });
  }
});

describe("приёмка сезона: свод", () => {
  const weight = (s) => specificity(s);
  const heavier = (a, b) => {
    for (let i = 0; i < 3; i += 1) if (a[i] !== b[i]) return a[i] > b[i];
    return false;
  };
  const value = (rule, property) => rule.declarations[property]?.value ?? null;
  const palette = (dark) => {
    const found = Object.assign({}, sheet.customProperties("html"), sheet.customProperties(":root"));
    if (!dark) return found;
    for (const rule of sheet.insideMedia("prefers-color-scheme")) {
      for (const [property, declaration] of Object.entries(rule.declarations)) {
        if (property.startsWith("--")) found[property] = declaration.value;
      }
    }
    return found;
  };
  const colourOf = (declared, colours) => {
    const found = declared?.match(/var\(\s*(--[\w-]+)[^)]*\)|#[0-9a-f]{3,8}\b|\b(rgba?|hsla?|oklch)\([^)]*\)/i)?.[0];
    if (!found) return null;
    const name = found.match(/^var\(\s*(--[\w-]+)/)?.[1];
    const raw = name ? colours[name] : found;
    try {
      return raw && parseColor(raw) ? raw : null;
    } catch {
      return null;
    }
  };

  test("каскад: ни громкости, ни экземпляров, от общего к частному", () => {
    assert.deepEqual(sheet.important().map((i) => `${i.selector} { ${i.property} }`), []);
    assert.deepEqual(sheet.selectors().filter((s) => weight(s)[0] > 0), []);
    const seen = new Map();
    for (const rule of sheet.base) {
      for (const property of Object.keys(rule.declarations)) {
        if (property.startsWith("--")) continue;
        const previous = seen.get(property);
        if (previous) {
          assert.ok(!heavier(weight(previous), weight(rule.selector)), `${property}: «${previous}» выше «${rule.selector}», но весит больше.`);
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

  test("меры: от кегля, а не от пикселя", () => {
    const colours = palette(false);
    for (const rule of sheet.declared("font-size")) {
      const declared = value(rule, "font-size");
      const resolved = declared.replace(/var\((--[\w-]+)[^)]*\)/g, (w, n) => colours[n] ?? w);
      assert.ok(!/\b(?!0px)\d*\.?\d+px\b/.test(resolved), `Кегль в пикселях: «${rule.selector}».`);
    }
    for (const rule of sheet.declared("line-height")) {
      const v = value(rule, "line-height");
      assert.ok(/^[\d.]+$/.test(v) || v === "normal", `Интерлиньяж с единицей: «${rule.selector}».`);
    }
    assert.ok(
      Object.values(colours).some((v) => /clamp\(/.test(v) && /\d+\s*r?em/.test(v.split(",")[1] ?? "")),
      "В шкале нет текучей ступени со слагаемым от кегля (s02e09).",
    );
    assert.ok(Object.values(colours).some((v) => /\d+ch\b/.test(v)), "Мера строки в знаках (s02e09).");
  });

  test("раскладка: сперва узкое, потом добавки", () => {
    const queries = sheet.mediaQueries();
    const byWidth = queries.filter((q) => /width/i.test(q));
    assert.ok(byWidth.length >= 1 && byWidth.length <= 3, "Переломов один-три (s02e10).");
    for (const query of byWidth) {
      assert.ok(!/max-width|\d+px/.test(query), `Перелом «${query}» задан сверху вниз или в пикселях.`);
    }
    assert.ok(queries.includes("print"), "Печатный набор (s02e10).");
    assert.ok(queries.some((q) => q.includes("prefers-color-scheme")), "Тёмный набор (s02e11).");
    const base = sheet.base.filter((r) => r.declarations["grid-template-areas"]).at(-1);
    assert.ok(base, "Сетка полосы (s02e08).");
    const rows = [...value(base, "grid-template-areas").matchAll(/"([^"]*)"/g)].map((m) => m[1].trim().split(/\s+/));
    assert.deepEqual(rows.filter((r) => r.length > 1), [], "Основной рисунок сетки не одноколоночный (s02e10).");
  });

  test("цвет: контраст посчитан в обоих наборах", () => {
    for (const dark of [false, true]) {
      const colours = palette(dark);
      const paper = colourOf(
        value(sheet.base.find((r) => ["body", "html", ":root"].includes(r.selector) && r.declarations["background-color"]), "background-color"),
        colours,
      );
      assert.ok(paper, "Цвет бумаги не объявлен у корня полосы.");
      for (const rule of sheet.rules.filter((r) => r.media !== "print")) {
        const own = colourOf(value(rule, "background-color"), colours) ?? paper;
        const ink = colourOf(value(rule, "color"), colours);
        if (ink) {
          const ratio = contrast(ink, own);
          assert.ok(ratio >= 4.5, `${dark ? "тёмный" : "светлый"} набор, «${rule.selector}»: ${ratio.toFixed(2)} вместо 4,5.`);
        }
        for (const property of ["border", "border-inline-start", "outline"]) {
          const line = colourOf(value(rule, property), colours);
          if (!line) continue;
          const ratio = contrast(line, own);
          assert.ok(ratio >= 3, `${dark ? "тёмный" : "светлый"} набор, линейка «${rule.selector}»: ${ratio.toFixed(2)} вместо 3.`);
        }
      }
    }
  });
});
