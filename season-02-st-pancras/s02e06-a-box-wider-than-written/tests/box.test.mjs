// CRIMSON RAILS — s02e06, проверка.
//
// Здесь проверяется, по какому краю меряется коробка, откуда берутся зазоры
// между блоками и осталась ли ссылка в обход доступной после того, как её
// спрятали. Проверяются объявленные свойства, а не вид страницы.

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

const ROOTS = [":root", "html", "body"];
const weight = (s) => specificity(s);
const heavier = (a, b) => {
  for (let i = 0; i < 3; i += 1) if (a[i] !== b[i]) return a[i] > b[i];
  return false;
};
const value = (rule, property) => rule.declarations[property]?.value ?? null;
const declaring = (...properties) =>
  sheet.base.filter((r) => properties.some((p) => r.declarations[p]));

// Ссылку в обход находим по разметке, а не по угаданному имени класса.
const skipClass = (doc.attr(doc.all("a")[0], "class") ?? "").split(/\s+/)[0];
const skipRules = () =>
  skipClass ? sheet.base.filter((r) => r.selector.includes(`.${skipClass}`)) : [];
const hiddenRule = () => skipRules().find((r) => !r.selector.includes(":"));
const focusRule = () => skipRules().find((r) => /:focus(-visible)?\b/.test(r.selector));

const BLOCK_SIZE = ["height", "block-size"];
const PHYSICAL = [
  "margin-top", "margin-bottom", "margin-left", "margin-right",
  "padding-top", "padding-bottom", "padding-left", "padding-right",
];
const UPWARDS = ["margin-top", "margin-block-start"];

describe("мера — по внешнему краю", () => {
  test("мера объявлена один раз и для всего", () => {
    const rules = sheet.declared("box-sizing");
    assert.ok(rules.length >= 1, "Без border-box ширина коробки — это ширина набора, а поля и рамка идут сверх неё.");
    const universal = rules.find((r) => r.selector.includes("*"));
    assert.ok(
      universal,
      "Мера объявляется сразу для всего, включая псевдоэлементы: коробка, померенная иначе, " +
        "найдётся ровно там, где её не ждали.",
    );
    assert.deepEqual(
      weight(universal.selector),
      [0, 0, 0],
      "Это правило основания. Оно обязано весить ноль, иначе начнёт спорить с остальным сводом.",
    );
  });

  test("никто не возвращает меру по набору", () => {
    const back = sheet.rules.filter((r) => value(r, "box-sizing") === "content-box");
    assert.deepEqual(
      back.map((r) => r.selector),
      [],
      "content-box посреди свода — это одна коробка, которая меряется не так, как все.",
    );
  });

  test("у полосы объявлена предельная мера", () => {
    const rules = declaring("max-inline-size", "max-width");
    assert.equal(
      rules.length >= 1,
      true,
      "Строка во всю ширину окна нечитаема: глаз теряет начало следующей. Полосе назначают предел.",
    );
    assert.ok(
      ROOTS.includes(rules[0].selector),
      `Предельная мера объявлена у «${rules[0].selector}». Её место — у корня полосы: ` +
        ROOTS.join(", ") + ".",
    );
    const size = value(rules[0], "max-inline-size") ?? value(rules[0], "max-width");
    assert.ok(
      !size.endsWith("%"),
      `Предел задан как ${size}. Доля от окна — не предел: в широком окне строка снова разъедется.`,
    );
  });

  test("высоту назначает содержимое", () => {
    for (const rule of declaring(...BLOCK_SIZE)) {
      if (rule === hiddenRule()) continue;
      const size = value(rule, "height") ?? value(rule, "block-size");
      assert.equal(
        size,
        "auto",
        `«${rule.selector}» назначает высоту (${size}). Текст в такой коробке не помещается молча: ` +
          "он вылезает наружу или обрезается, и заметно это не на твоём экране.",
      );
    }
  });
});

describe("поля не складываются", () => {
  test("поля объявлены только вниз", () => {
    for (const rule of sheet.base) {
      for (const property of UPWARDS) {
        assert.ok(
          !rule.declarations[property],
          `«${rule.selector}» объявляет ${property}. Верхнее поле одного блока и нижнее ` +
            "соседнего схлопываются в одно — большее из двух, а не сумму. Пока зазор объявляет " +
            "кто-то один и всегда вниз, схлопывать нечего.",
        );
      }
      const block = value(rule, "margin-block");
      if (block) {
        assert.equal(
          block.split(/\s+/).length,
          1,
          `«${rule.selector}» объявляет margin-block: ${block} — это и верхнее поле тоже.`,
        );
      }
      const shorthand = value(rule, "margin");
      if (shorthand) {
        assert.ok(
          /^0[a-z%]*$/.test(shorthand),
          `«${rule.selector}» объявляет margin: ${shorthand}. Сокращение задаёт все четыре ` +
            "стороны разом, включая верхнюю; в основании оно допустимо только нулём.",
        );
      }
    }
  });

  test("стороны названы логически", () => {
    const physical = [];
    for (const rule of sheet.base) {
      for (const property of PHYSICAL) if (rule.declarations[property]) physical.push(`${rule.selector} { ${property} }`);
    }
    assert.deepEqual(
      physical,
      [],
      "top, bottom, left, right — стороны экрана. block и inline — стороны текста. " +
        "Вторые переживут смену направления письма, первые нет.",
    );
  });

  test("поле полосы прекращает схлопывание", () => {
    const root = declaring("max-inline-size", "max-width")[0];
    const padding =
      value(root, "padding") ?? value(root, "padding-block") ?? value(root, "padding-block-start");
    assert.ok(
      padding && !/^0[a-z%]*$/.test(padding),
      `У «${root.selector}» нет внутреннего поля. Без него нижнее поле последнего блока ` +
        "схлопывается с полем родителя и выходит наружу — зазор появляется снаружи полосы, " +
        "а не внутри неё.",
    );
  });
});

describe("спрятана от глаза, и только от него", () => {
  test("у ссылки в обход есть своё правило", () => {
    assert.ok(skipClass, "У ссылки в обход должен быть класс — за него держится правило.");
    assert.ok(hiddenRule(), `В своде нет правила для «.${skipClass}».`);
  });

  test("она не убрана из дерева доступности", () => {
    const rule = hiddenRule();
    assert.notEqual(
      value(rule, "display"),
      "none",
      "display: none убирает элемент отовсюду, включая обход с клавиатуры, — то есть отменяет " +
        "ровно то, ради чего ссылка существует.",
    );
    assert.notEqual(value(rule, "visibility"), "hidden", "visibility: hidden делает то же самое.");
  });

  test("она вынута из потока и сжата до точки", () => {
    const rule = hiddenRule();
    assert.ok(
      ["absolute", "fixed"].includes(value(rule, "position")),
      "Оставшись в потоке, спрятанная ссылка всё равно займёт строку.",
    );
    for (const property of ["inline-size", "width"]) {
      if (value(rule, property)) assert.match(value(rule, property), /^1px$/, `${property} должен быть 1px.`);
    }
    assert.ok(
      value(rule, "inline-size") ?? value(rule, "width"),
      "Сжать надо обе меры: коробка нулевой ширины у части браузеров выпадает из дерева.",
    );
    assert.ok(value(rule, "block-size") ?? value(rule, "height"), "И высоту тоже.");
    assert.ok(
      value(rule, "overflow") === "hidden" || value(rule, "clip-path"),
      "Текст, не поместившийся в коробку 1×1, надо обрезать — иначе он виден.",
    );
  });

  test("есть правило, возвращающее её при фокусе", () => {
    const focus = focusRule();
    assert.ok(
      focus,
      `Ссылка спрятана навсегда: правила «.${skipClass}:focus» в своде нет. Тот, кто попал на неё ` +
        "клавишей, не увидит, где он находится.",
    );
    assert.ok(
      value(focus, "position") === "static" || value(focus, "clip-path") === "none",
      "Возвращать надо тем же, чем прятали: положением и обрезкой.",
    );
  });

  test("возвращающее правило стоит ниже и точнее", () => {
    const hidden = hiddenRule();
    const focus = focusRule();
    assert.ok(
      sheet.base.indexOf(focus) > sheet.base.indexOf(hidden),
      "Правило фокуса стоит выше правила сокрытия — при равном весе победит сокрытие.",
    );
    assert.ok(
      !heavier(weight(hidden.selector), weight(focus.selector)),
      "И весить оно должно не меньше.",
    );
  });
});

describe("свод остался сводом", () => {
  test("ни одного «в обязательном порядке»", () => {
    assert.deepEqual(sheet.important().map((i) => `${i.selector} { ${i.property} }`), []);
  });

  test("ни один селектор не указывает на экземпляр", () => {
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
            `Свойство ${property}: «${previous}» (вес ${weight(previous)}) стоит выше, чем ` +
              `«${rule.selector}» (вес ${weight(rule.selector)}), но весит больше.`,
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
    assert.deepEqual([...inMarkup].filter((c) => !inSheet.has(c)), [], "Классы разметки без правил.");
    assert.deepEqual([...inSheet].filter((c) => !inMarkup.has(c)), [], "Правила, не находящие цели.");
  });
});

describe("прошлые серии не сломаны", () => {
  test("полоса связана со сводом", () => {
    const link = doc
      .all("link")
      .find((l) => (doc.attr(l, "rel") ?? "").split(/\s+/).includes("stylesheet"));
    assert.ok(link && doc.closest(link, "head"), "В <head> нет ссылки на свод правил.");
  });

  test("структура полосы и таблица на месте", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.equal(doc.attr(doc.first("html"), "lang"), "ru");
    assert.ok(!doc.closest(doc.all("a")[0], "nav"), "Ссылка в обход оглавления из s02e04 никуда не делась.");
    const table = doc.tables()[0];
    assert.deepEqual(table.unscopedHeaders().map((th) => doc.text(th)), []);
    assert.equal(new Set(table.widths()).size, 1);
    for (const row of table.bodyRows()) {
      const first = table.cells(row)[0];
      assert.ok(
        doc.tag(first) === "th" && doc.attr(first, "scope") === "row",
        `Строка «${doc.text(first)}» осталась без заголовка.`,
      );
    }
  });

  test("все внутренние ссылки ведут куда-то", () => {
    for (const link of doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"))) {
      assert.ok(doc.byId(doc.attr(link, "href").slice(1)), `Ссылка на ${doc.attr(link, "href")} ведёт в пустоту.`);
    }
  });
});
