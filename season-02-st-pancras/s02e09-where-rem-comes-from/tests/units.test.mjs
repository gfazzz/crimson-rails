// CRIMSON RAILS — s02e09, проверка.
//
// Здесь проверяется, от чего считаются размеры на полосе: от настройки
// читателя или от числа, выбранного автором. Проверяются объявленные
// значения, а не вид страницы.

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

const ROOTS = [":root", "html"];
const weight = (s) => specificity(s);
const value = (rule, property) => rule.declarations[property]?.value ?? null;

// Единицы бумаги: на экране они означают не то, что думает автор.
const PAPER = /\b\d*\.?\d+\s*(pt|pc|cm|mm|in|q)\b/i;
// Размер в пикселях, кроме нуля.
const PIXELS = /\b(?!0px)\d*\.?\d+px\b/;
const RELATIVE_TO_FONT = /\b\d*\.?\d+\s*(rem|em|ch|ex|cap|lh)\b/;
const VIEWPORT = /\b\d*\.?\d+\s*(vw|vh|vi|vb|vmin|vmax|dv[whib])\b/;

// Свойства, которыми меряют полосу. Толщина линейки и тени сюда не входят.
const MEASURES =
  /^(margin|padding|gap|row-gap|column-gap|inset|top|left|right|bottom|(min-|max-)?(inline-size|block-size|width|height))/;

const hiddenRule = sheet.base.find((r) => r.declarations["clip-path"]);

// Шкала и подстановка: значение, спрятанное за var(), проверяется наравне с
// написанным на месте — иначе достаточно убрать число в шкалу, и его не видно.
const scale = () => Object.assign({}, sheet.customProperties("html"), sheet.customProperties(":root"));
const resolve = (v) => v.replace(/var\((--[\w-]+)[^)]*\)/g, (whole, name) => scale()[name] ?? whole);
const allDeclarations = function* () {
  for (const rule of sheet.rules) {
    for (const [property, declaration] of Object.entries(rule.declarations)) {
      yield { rule, property, value: declaration.value };
    }
  }
};

describe("кегль назначает читатель", () => {
  test("корневой кегль не переназначен числом", () => {
    for (const rule of sheet.rules.filter((r) => ROOTS.includes(r.selector))) {
      const size = value(rule, "font-size");
      if (!size) continue;
      assert.ok(
        /%|larger|smaller|medium/.test(size),
        `У «${rule.selector}» объявлен font-size: ${size}. Корневой кегль — настройка читателя: ` +
          "тот, кто увеличил шрифт в браузере, сделал это не случайно. Задав его числом, " +
          "свод отменяет настройку молча.",
      );
    }
  });

  test("ни один кегль не задан в пикселях", () => {
    const pixel = sheet
      .declared("font-size")
      .filter((r) => PIXELS.test(resolve(value(r, "font-size"))))
      .map((r) => `${r.selector} { font-size: ${value(r, "font-size")} }`);
    assert.deepEqual(
      pixel,
      [],
      "Кегль в пикселях не считается от настройки читателя — он её игнорирует.",
    );
  });

  test("ни одной бумажной единицы", () => {
    const paper = [];
    for (const { rule, property, value: v } of allDeclarations()) {
      if (PAPER.test(v)) paper.push(`${rule.selector} { ${property}: ${v} }`);
    }
    assert.deepEqual(
      paper,
      [],
      "Пункты, пики и миллиметры на экране означают не длину, а пересчёт по условному " +
        "разрешению. Мерить ими экран — притворяться, что это бумага.",
    );
  });

  test("каждый кегль взят из шкалы", () => {
    const loose = sheet
      .declared("font-size")
      .filter((r) => !value(r, "font-size").includes("var(--"))
      .map((r) => `${r.selector} { font-size: ${value(r, "font-size")} }`);
    assert.deepEqual(
      loose,
      [],
      "Кегль, выбранный на месте, — это ещё один размер, о котором шкала не знает. " +
        "Через год их двенадцать, и ни один не кратен соседнему.",
    );
  });
});

describe("шкала объявлена один раз", () => {
  test("шкала объявлена у корня", () => {
    const root = ROOTS.find((selector) => Object.keys(sheet.customProperties(selector)).length > 0);
    assert.ok(
      root,
      "Шкалы нет. Пользовательские свойства наследуются: объявленные у корня, они доступны " +
        "всей полосе и меняются в одном месте.",
    );
    const declared = Object.keys(sheet.customProperties(root));
    assert.ok(
      declared.length >= 5,
      `В шкале ${declared.length} значений. На полосе пять кеглей: мелкий, основной и три ` +
        "ступени заголовков.",
    );
  });

  test("каждое объявленное свойство используется", () => {
    const declared = new Set();
    for (const selector of ROOTS) for (const name of Object.keys(sheet.customProperties(selector))) declared.add(name);
    const used = new Set(sheet.usedCustomProperties());
    assert.deepEqual(
      [...declared].filter((name) => !used.has(name)),
      [],
      "Эти значения объявлены и никем не взяты — шкала, о которой не знает полоса.",
    );
  });

  test("каждое использованное свойство объявлено", () => {
    const declared = new Set();
    for (const selector of ROOTS) for (const name of Object.keys(sheet.customProperties(selector))) declared.add(name);
    assert.deepEqual(
      sheet.usedCustomProperties().filter((name) => !declared.has(name)),
      [],
      "Эти значения берутся, но нигде не объявлены. var() без запасного значения даёт " +
        "не ошибку, а пустоту: свойство становится недействительным, и его наследует родитель.",
    );
  });
});

describe("кегль течёт, не ломая увеличение", () => {
  const clamps = () =>
    [...allDeclarations()].filter((d) => d.value.includes("clamp("));

  test("в шкале есть текучие ступени", () => {
    assert.ok(
      clamps().length >= 1,
      "Ни одной ступени через clamp(). Текучий кегль растёт вместе с окном и не требует " +
        "ни одного медиазапроса.",
    );
  });

  test("в каждом clamp() середина зависит и от шрифта, и от окна", () => {
    for (const { rule, property, value: v } of clamps()) {
      const inside = v.slice(v.indexOf("clamp(") + 6, v.lastIndexOf(")"));
      const parts = inside.split(",");
      assert.equal(parts.length, 3, `clamp() в «${rule.selector} { ${property} }» не о трёх членах.`);
      const middle = parts[1];
      assert.ok(
        VIEWPORT.test(middle),
        `Середина clamp() в «${rule.selector} { ${property} }» не зависит от окна — тогда это ` +
          "просто число, а не текучий размер.",
      );
      assert.ok(
        RELATIVE_TO_FONT.test(middle),
        `Середина clamp() в «${rule.selector} { ${property} }» состоит из одних долей окна. ` +
          "Такой размер перестаёт расти при увеличении шрифта в браузере: читатель жмёт «крупнее», " +
          "и ничего не происходит. Слагаемое в rem возвращает ему управление.",
      );
    }
  });

  test("ни один кегль не задан голой долей окна", () => {
    const naked = sheet
      .declared("font-size")
      .filter((r) => {
        const v = resolve(value(r, "font-size"));
        return VIEWPORT.test(v) && !v.includes("clamp(");
      })
      .map((r) => r.selector);
    assert.deepEqual(naked, [], "Кегль в долях окна без границ: на узком экране нечитаемо, на широком огромно.");
  });
});

describe("полоса меряется в знаках и кеглях", () => {
  test("мера строки объявлена в знаках", () => {
    const inChars = [...allDeclarations()].filter(
      (d) => /^(max-)?(inline-size|width)$/.test(d.property) && /\bch\b/.test(d.value),
    );
    const scale = Object.entries(sheet.customProperties("html")).concat(
      Object.entries(sheet.customProperties(":root")),
    );
    const measureVar = scale.find(([, v]) => /\d+ch\b/.test(v));
    assert.ok(
      inChars.length >= 1 || measureVar,
      "Меры строки нет. Строка длиной в полосу нечитаема: глаз теряет начало следующей. " +
        "Меряют её не в пикселях, а в знаках — единица ch и есть ширина знака текущего шрифта.",
    );
    const declared = measureVar ? measureVar[1] : inChars[0].value;
    const chars = Number.parseFloat(declared.match(/([\d.]+)ch/)[1]);
    assert.ok(
      chars >= 40 && chars <= 80,
      `Мера строки ${chars} знаков. Читаемый диапазон — от сорока пяти до семидесяти пяти; ` +
        "за его краями глаз либо прыгает по строке, либо теряет следующую.",
    );
  });

  test("предел полосы объявлен от кегля", () => {
    const rules = sheet.base.filter((r) => r.declarations["max-inline-size"] || r.declarations["max-width"]);
    const root = rules.find((r) => ["body", ...ROOTS].includes(r.selector));
    assert.ok(root, "У полосы нет предела ширины (s02e06).");
    const declared = value(root, "max-inline-size") ?? value(root, "max-width");
    const resolved = declared.includes("var(--")
      ? Object.assign({}, sheet.customProperties("html"), sheet.customProperties(":root"))[
          declared.match(/--[\w-]+/)[0]
        ] ?? declared
      : declared;
    assert.ok(
      RELATIVE_TO_FONT.test(resolved),
      `Предел полосы задан как ${resolved}. В пикселях он не считается от кегля: читатель ` +
        "увеличил шрифт — полоса осталась прежней, и в неё стало влезать вдвое меньше слов.",
    );
  });

  test("интерлиньяж объявлен без единиц", () => {
    for (const rule of sheet.declared("line-height")) {
      const v = value(rule, "line-height");
      assert.ok(
        /^[\d.]+$/.test(v) || v === "normal",
        `«${rule.selector} { line-height: ${v} }». Интерлиньяж с единицей наследуется как ` +
          "готовая длина: потомок с другим кеглем получит чужие межстрочные расстояния. " +
          "Без единицы наследуется множитель, и каждый считает от своего кегля.",
      );
    }
  });

  test("отступы считаются от кегля, а не от экрана", () => {
    const pixel = [];
    for (const { rule, property, value: v } of allDeclarations()) {
      if (rule === hiddenRule) continue;
      if (!MEASURES.test(property)) continue;
      if (PIXELS.test(v)) pixel.push(`${rule.selector} { ${property}: ${v} }`);
    }
    assert.deepEqual(
      pixel,
      [],
      "Отступ в пикселях не растёт вместе с текстом: читатель увеличил шрифт, а воздух вокруг " +
        "него остался прежним, и полоса стала теснее, чем была.",
    );
  });
});

describe("полоса знает про экран", () => {
  test("объявлен размер области просмотра", () => {
    const meta = doc.all("meta").find((m) => doc.attr(m, "name") === "viewport");
    assert.ok(
      meta,
      "Без <meta name=\"viewport\"> телефон печатает полосу шириной около 980 условных " +
        "пикселей и уменьшает её целиком: текст становится нечитаем, а все меры — ложью.",
    );
    const content = doc.attr(meta, "content") ?? "";
    assert.match(content, /width\s*=\s*device-width/, "Ширина области просмотра — ширина устройства.");
    assert.match(content, /initial-scale\s*=\s*1/, "Начальный масштаб — единица.");
  });

  test("увеличение читателю не запрещено", () => {
    const content = doc.attr(doc.all("meta").find((m) => doc.attr(m, "name") === "viewport"), "content") ?? "";
    assert.ok(
      !/user-scalable\s*=\s*(no|0)/.test(content),
      "user-scalable=no отнимает у читателя щипок для увеличения. Это не настройка вида, " +
        "а отобранная возможность.",
    );
    const max = content.match(/maximum-scale\s*=\s*([\d.]+)/);
    assert.ok(
      !max || Number.parseFloat(max[1]) >= 2,
      `maximum-scale=${max?.[1]} ограничивает увеличение. Нижняя допустимая граница — двукратное.`,
    );
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

  test("структура полосы цела", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.ok(doc.first("aside"));
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
});
