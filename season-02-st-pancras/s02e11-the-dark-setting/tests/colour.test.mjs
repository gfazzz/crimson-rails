// CRIMSON RAILS — s02e11, проверка.
//
// Здесь считается коэффициент контраста каждой пары «набор на фоне» — в обоих
// наборах, светлом и тёмном. Это арифметика по WCAG, а не мнение о том,
// красиво ли получилось.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readDocument, readStylesheet, specificity, contrast, parseColor } from "../../support/check.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const ownHtml = join(here, "..", "artifacts", "bradshaw.html");
const ownCss = join(here, "..", "artifacts", "bradshaw.css");
const mine = existsSync(ownHtml) && existsSync(ownCss) && !process.env.FORCE_SOLUTION;
const dir = mine ? join(here, "..", "artifacts") : join(here, "..", "solution");

console.log(`Источник: ${mine ? "artifacts" : "solution"}/ (bradshaw.html + bradshaw.css)`);
if (!existsSync(ownCss)) console.log("(свода правил нет — проверяю эталон)");

const doc = readDocument(join(dir, "bradshaw.html"));
const sheet = readStylesheet(join(dir, "bradshaw.css"));

const ROOTS = [":root", "html"];
const weight = (s) => specificity(s);
const value = (rule, property) => rule.declarations[property]?.value ?? null;
const DARK = "prefers-color-scheme";
const isPrint = (rule) => rule.media === "print";

// Цвет внутри значения: и записанный прямо, и взятый из палитры.
const COLOUR = /var\(\s*(--[\w-]+)[^)]*\)|#[0-9a-f]{3,8}\b|\b(rgba?|hsla?|oklch|lab|color)\([^)]*\)/i;
const pickColour = (declared) => declared?.match(COLOUR)?.[0] ?? null;

const lightPalette = () =>
  Object.assign({}, ...ROOTS.map((selector) => sheet.customProperties(selector)));
const darkPalette = () => {
  const palette = lightPalette();
  for (const rule of sheet.insideMedia(DARK)) {
    for (const [property, declaration] of Object.entries(rule.declarations)) {
      if (property.startsWith("--")) palette[property] = declaration.value;
    }
  }
  return palette;
};

const resolve = (declared, palette) => {
  const found = pickColour(declared);
  if (!found) return null;
  const name = found.match(/^var\(\s*(--[\w-]+)/)?.[1];
  const raw = name ? palette[name] : found;
  if (!raw) return null;
  try {
    return parseColor(raw) ? raw : null;
  } catch {
    return null;
  }
};

// Правила, красящие набор: вне печати (на бумаге чёрным по белому — не тема).
const painting = () => sheet.rules.filter((r) => !isPrint(r));

const themes = () => [
  { name: "светлый набор", palette: lightPalette() },
  { name: "тёмный набор", palette: darkPalette() },
];

const paperOf = (palette) => {
  for (const rule of painting()) {
    if (!["body", ...ROOTS].includes(rule.selector)) continue;
    const background = resolve(value(rule, "background-color") ?? value(rule, "background"), palette);
    if (background) return background;
  }
  return null;
};

describe("палитра объявлена, а не рассыпана", () => {
  test("цвета взяты из палитры", () => {
    const loose = [];
    for (const rule of painting()) {
      for (const property of ["color", "background-color", "background", "border", "border-inline-start", "border-block-start", "outline"]) {
        const declared = value(rule, property);
        if (!declared) continue;
        const found = pickColour(declared);
        if (found && !found.startsWith("var(")) loose.push(`${rule.selector} { ${property}: ${declared} }`);
      }
    }
    assert.deepEqual(
      loose,
      [],
      "Цвет, написанный на месте, темы не знает: при тёмном наборе он останется прежним. " +
        "Палитра — это имена, у которых в каждой теме своё значение.",
    );
  });

  test("в палитре есть бумага и набор", () => {
    const palette = lightPalette();
    const colours = Object.entries(palette).filter(([, v]) => {
      try {
        return Boolean(parseColor(v));
      } catch {
        return false;
      }
    });
    assert.ok(
      colours.length >= 4,
      `Цветов в палитре ${colours.length}. На полосе их не меньше четырёх: бумага, набор, ` +
        "линейка и красные чернила.",
    );
    assert.ok(paperOf(palette), "Цвет бумаги не объявлен у корня полосы: фон окна останется белым.");
  });

  test("обе темы объявлены браузеру", () => {
    const declared = painting().find((r) => ROOTS.includes(r.selector) && r.declarations["color-scheme"]);
    assert.ok(
      declared,
      "color-scheme не объявлен. Браузер красит этим свои поля ввода, полосы прокрутки и фон " +
        "за краем полосы — без объявления они останутся светлыми посреди тёмного набора.",
    );
    const v = value(declared, "color-scheme");
    assert.match(v, /light/, "В объявлении нет светлого набора.");
    assert.match(v, /dark/, "В объявлении нет тёмного набора.");
  });
});

describe("тёмный набор — это значения", () => {
  test("у читателя спрашивают, а не предлагают", () => {
    assert.ok(
      sheet.mediaQueries().some((q) => q.includes(DARK)),
      "Тёмного набора нет. Эта настройка у читателя уже есть, и он её уже выбрал — " +
        "остаётся спросить.",
    );
  });

  test("добавка переобъявляет палитру", () => {
    const rules = sheet.insideMedia(DARK);
    const overridden = new Set();
    for (const rule of rules) {
      for (const property of Object.keys(rule.declarations)) if (property.startsWith("--")) overridden.add(property);
    }
    assert.ok(
      overridden.size >= 3,
      `В тёмной добавке переобъявлено ${overridden.size} значений палитры. Тёмный набор — ` +
        "не «фон почернее»: меняются и бумага, и набор, и линейки, и чернила.",
    );
  });

  test("добавка не трогает раскладку", () => {
    const layout = [];
    for (const rule of sheet.insideMedia(DARK)) {
      for (const property of Object.keys(rule.declarations)) {
        if (!property.startsWith("--")) layout.push(`${rule.selector} { ${property} }`);
      }
    }
    assert.deepEqual(
      layout,
      [],
      "Тема — это значения, а не другие правила. Всё, что объявлено в добавке помимо палитры, " +
        "придётся поддерживать дважды, и однажды одно из двух забудут.",
    );
  });

  test("тёмный набор не получен выворачиванием", () => {
    const inverted = painting()
      .filter((r) => /invert/.test(value(r, "filter") ?? ""))
      .map((r) => r.selector);
    assert.deepEqual(
      inverted,
      [],
      "Выворачивание меняет всё разом, включая изображения и фотографии: схема линии станет " +
        "негативом. И красный при этом становится голубым.",
    );
  });
});

describe("контраст посчитан, а не оценён на глаз", () => {
  const pairs = (palette) => {
    const paper = paperOf(palette);
    const found = [];
    for (const rule of painting()) {
      const own = resolve(value(rule, "background-color") ?? value(rule, "background"), palette);
      const ink = resolve(value(rule, "color"), palette);
      if (ink) found.push({ selector: rule.selector, ink, background: own ?? paper, kind: "набор" });
      for (const property of ["border", "border-inline-start", "border-block-start", "outline"]) {
        const line = resolve(value(rule, property), palette);
        if (line) found.push({ selector: rule.selector, ink: line, background: own ?? paper, kind: "линейка" });
      }
    }
    return found.filter((p) => p.background);
  };

  for (const { name, palette } of themes()) {
    test(`${name}: набор читается на своём фоне`, () => {
      for (const pair of pairs(palette).filter((p) => p.kind === "набор")) {
        const ratio = contrast(pair.ink, pair.background);
        assert.ok(
          ratio >= 4.5,
          `«${pair.selector}»: ${pair.ink} на ${pair.background} даёт ${ratio.toFixed(2)}. ` +
            "WCAG 1.4.3 требует 4,5 для основного текста. Это не вкус: при 3,0 текст читается " +
            "теми, у кого зрение как у автора, и не читается остальными.",
        );
      }
    });

    test(`${name}: линейки видны`, () => {
      for (const pair of pairs(palette).filter((p) => p.kind === "линейка")) {
        const ratio = contrast(pair.ink, pair.background);
        assert.ok(
          ratio >= 3,
          `«${pair.selector}»: линейка ${pair.ink} на ${pair.background} даёт ${ratio.toFixed(2)}. ` +
            "WCAG 1.4.11 требует 3 для линий, несущих смысл. Границы ячеек расписания смысл несут: " +
            "без них не видно, где кончается одна станция и начинается другая.",
        );
      }
    });
  }

  test("палитры двух наборов не совпадают", () => {
    const light = lightPalette();
    const dark = darkPalette();
    const same = Object.keys(light).filter((name) => {
      try {
        return parseColor(light[name]) && light[name] === dark[name];
      } catch {
        return false;
      }
    });
    assert.ok(
      same.length <= 1,
      `В обоих наборах одинаковы: ${same.join(", ")}. Тёмный набор переобъявляет цвета, ` +
        "а не часть из них.",
    );
  });
});

describe("цвет — не единственный признак", () => {
  test("ссылки видны не только цветом", () => {
    for (const rule of painting()) {
      if (!/(^|[\s,>])a([:.\[\s]|$)/.test(rule.selector)) continue;
      const decoration = value(rule, "text-decoration") ?? value(rule, "text-decoration-line");
      if (decoration && /none/.test(decoration)) {
        assert.fail(
          `«${rule.selector}» снимает подчёркивание. Ссылка, отличающаяся от текста одним ` +
            "цветом, не видна тем, кто цвет различает иначе, — а это каждый двенадцатый мужчина " +
            "(WCAG 1.4.1).",
        );
      }
    }
  });

  test("условные обозначения читаются буквами", () => {
    const legend = [...doc.walk()].find((n) => (doc.attr(n, "class") ?? "").split(/\s+/).includes("legend"));
    assert.ok(legend, "Условные обозначения из s02e07 на месте.");
    for (const item of doc.children(legend)) {
      assert.ok(
        doc.text(item).trim().length >= 3,
        "Обозначение, состоящее из одного цветного значка, нечитаемо вслух и неразличимо " +
          "при чёрно-белой печати.",
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

  test("прошлые серии целы", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.ok(doc.first("aside"));
    assert.ok(sheet.mediaQueries().some((q) => q.includes("width")), "Перелом из s02e10 на месте.");
    assert.ok(sheet.mediaQueries().includes("print"), "Печатный набор из s02e10 на месте.");
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
