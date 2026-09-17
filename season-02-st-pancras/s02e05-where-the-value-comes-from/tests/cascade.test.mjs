// CRIMSON RAILS — s02e05, проверка.
//
// Здесь проверяется не то, как полоса выглядит, а то, откуда берётся итоговое
// значение: кто кого перебивает и почему. Ни одна проверка не ищет строку в
// твоём файле — все смотрят на разобранные правила.

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
const weight = (selector) => specificity(selector);
const heavier = (a, b) => {
  for (let i = 0; i < 3; i += 1) if (a[i] !== b[i]) return a[i] > b[i];
  return false;
};
// Ступени селектора: сколько раз надо спуститься, чтобы дойти до цели.
const steps = (selector) => selector.split(/\s*[>+~]\s*|\s+/).filter(Boolean).length;

const classesInMarkup = () => {
  const found = new Set();
  for (const node of doc.walk()) {
    for (const name of (doc.attr(node, "class") ?? "").split(/\s+/)) if (name) found.add(name);
  }
  return found;
};
const classesInSheet = () => {
  const found = new Set();
  for (const selector of sheet.selectors()) {
    for (const match of selector.matchAll(/\.([A-Za-z_][\w-]*)/g)) found.add(match[1]);
  }
  return found;
};

describe("оформление живёт отдельно", () => {
  test("полоса ссылается на свод правил", () => {
    const link = doc
      .all("link")
      .find((l) => (doc.attr(l, "rel") ?? "").split(/\s+/).includes("stylesheet"));
    assert.ok(link, "В <head> нет <link rel=\"stylesheet\">: полоса ничего не знает о своде правил.");
    assert.ok(doc.closest(link, "head"), "Ссылка на свод правил объявляется в <head>.");
    assert.ok(
      (doc.attr(link, "href") ?? "").endsWith(".css"),
      "Свод правил — отдельный файл, а не что-то встроенное.",
    );
  });

  test("в разметке не осталось частных распоряжений", () => {
    assert.equal(
      doc.count("style"),
      0,
      "<style> внутри полосы — правило, которое невозможно отменить из свода: " +
        "оно всегда ниже по порядку.",
    );
    const inline = [...doc.walk()].filter((n) => doc.hasAttr(n, "style"));
    assert.deepEqual(
      inline.map((n) => doc.tag(n)),
      [],
      "Атрибут style весит больше любого селектора и отменяется только восклицательным знаком. " +
        "Оформление объявляют в своде.",
    );
  });

  test("свод правил не пуст", () => {
    assert.ok(
      sheet.rules.length >= 12,
      `Правил в своде: ${sheet.rules.length}. Полосу надо одеть целиком: ` +
        "заголовки, текст, ссылки, таблицу, примечания.",
    );
  });
});

describe("спорят точностью, а не громкостью", () => {
  test("ни одного «в обязательном порядке»", () => {
    assert.deepEqual(
      sheet.important().map((i) => `${i.selector} { ${i.property} }`),
      [],
      "!important не выигрывает спор, а прекращает его: следующему придётся написать " +
        "то же самое, и так до конца свода.",
    );
  });

  test("ни один селектор не указывает на экземпляр", () => {
    const withIds = sheet.selectors().filter((s) => weight(s)[0] > 0);
    assert.deepEqual(
      withIds,
      [],
      "Идентификатор уникален по определению: правило для него нельзя ни переиспользовать, " +
        "ни перебить ничем, кроме другого идентификатора.",
    );
  });

  test("селекторы не длиннее трёх ступеней", () => {
    const deep = sheet.selectors().filter((s) => steps(s) > 3);
    assert.deepEqual(
      deep,
      [],
      "Длинный селектор привязывает правило к нынешней форме разметки: " +
        "переставишь узел — правило отвалится молча.",
    );
  });
});

describe("наследование вместо повторения", () => {
  for (const property of ["font-family", "line-height"]) {
    test(`${property} объявлен один раз`, () => {
      const rules = sheet.declared(property);
      assert.equal(
        rules.length,
        1,
        `${property} объявлен ${rules.length} раз(а): ` +
          rules.map((r) => r.selector).join(", ") +
          ". Это наследуемое свойство — хватит одного объявления у корня.",
      );
      assert.ok(
        ROOTS.includes(rules[0].selector),
        `${property} объявлен у «${rules[0].selector}». Наследование начинается с корня: ` +
          ROOTS.join(", ") + ".",
      );
    });
  }

  test("базовый цвет объявлен там же, где и шрифт", () => {
    const root = sheet.declared("font-family")[0].selector;
    assert.ok(
      sheet.valueOf(root, "color"),
      `У «${root}» не объявлен color. Цвет текста наследуется — объявлять его каждому ` +
        "потомку значит повторять одно и то же.",
    );
  });
});

describe("основание ничего не весит", () => {
  test("сброс объявлен через :where()", () => {
    const groundwork = sheet.base.filter((r) => r.selector.includes(":where("));
    assert.ok(
      groundwork.length >= 2,
      "Основание пишут через :where(): оно обнуляет вес селектора, и любое правило ниже " +
        "перебивает его без борьбы.",
    );
    for (const rule of groundwork) {
      assert.deepEqual(
        weight(rule.selector),
        [0, 0, 0],
        `«${rule.selector}» весит больше нуля: :where() обнуляет только то, что внутри него.`,
      );
    }
  });

  test("сброс полей лежит в основании", () => {
    const rules = sheet.declared("margin");
    assert.ok(rules.length >= 1, "Собственные поля браузера надо снять — иначе они спорят с твоими.");
    for (const rule of rules) {
      assert.deepEqual(
        weight(rule.selector),
        [0, 0, 0],
        `Сброс полей объявлен у «${rule.selector}» весом ${weight(rule.selector)}. ` +
          "Сброс обязан быть самым лёгким правилом свода.",
      );
    }
  });
});

describe("свод читается сверху вниз", () => {
  test("переопределения стоят ниже и точнее", () => {
    const seen = new Map();
    for (const rule of sheet.base) {
      for (const property of Object.keys(rule.declarations)) {
        const previous = seen.get(property);
        if (previous) {
          assert.ok(
            !heavier(weight(previous), weight(rule.selector)),
            `Свойство ${property}: «${previous}» (вес ${weight(previous)}) объявлено выше, ` +
              `чем «${rule.selector}» (вес ${weight(rule.selector)}). Читающий сверху вниз решит, ` +
              "что побеждает нижнее, — а победит верхнее. Общее идёт первым, частное последним.",
          );
        }
        seen.set(property, rule.selector);
      }
    }
  });

  test("частное уточняет общее, а не заменяет его", () => {
    const refining = sheet.base.filter((r) => {
      const [ids, classes, types] = weight(r.selector);
      return ids === 0 && classes >= 1 && types >= 1;
    });
    assert.ok(
      refining.length >= 1,
      "В своде нет ни одного правила вида «класс + тег». Частный случай называют точнее " +
        "общего, оставаясь в тех же тегах: так видно, что именно уточняется.",
    );
  });
});

describe("классы называют роль", () => {
  test("каждый класс разметки упомянут в своде", () => {
    const orphans = [...classesInMarkup()].filter((c) => !classesInSheet().has(c));
    assert.deepEqual(
      orphans,
      [],
      "Эти классы стоят в разметке, но в своде о них ничего нет. Класс — не пометка на память, " +
        "а точка, за которую держится правило.",
    );
  });

  test("каждый класс свода есть в разметке", () => {
    const dead = [...classesInSheet()].filter((c) => !classesInMarkup().has(c));
    assert.deepEqual(
      dead,
      [],
      "Эти правила не относятся ни к чему на полосе. Правило, не находящее цели, " +
        "не ошибка и не предупреждение — оно просто молчит.",
    );
  });

  test("у расписания и примечаний свои классы", () => {
    const table = doc.first("table");
    assert.ok(doc.attr(table, "class"), "Расписание — не всякая таблица: у него своя роль и свой класс.");
    const marked = [...doc.walk()].filter((n) => doc.attr(n, "class")).length;
    assert.ok(marked >= 3, `Классов на полосе: ${marked}. Ролей на ней больше.`);
  });
});

describe("прошлые серии не сломаны", () => {
  test("структура полосы и таблица на месте", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    assert.equal(doc.attr(doc.first("html"), "lang"), "ru");
    const first = doc.all("a")[0];
    assert.ok(!doc.closest(first, "nav"), "Ссылка в обход оглавления из s02e04 никуда не делась.");
    const table = doc.tables()[0];
    assert.deepEqual(table.unscopedHeaders().map((th) => doc.text(th)), []);
    assert.equal(new Set(table.widths()).size, 1);
    for (const row of table.bodyRows()) {
      const first = table.cells(row)[0];
      assert.ok(
        doc.tag(first) === "th" && doc.attr(first, "scope") === "row",
        `Строка «${doc.text(first)}» осталась без заголовка — её нельзя прочесть вслух ` +
          "(s02e02, s02e04).",
      );
    }
  });

  test("все внутренние ссылки ведут куда-то", () => {
    for (const link of doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"))) {
      assert.ok(doc.byId(doc.attr(link, "href").slice(1)), `Ссылка на ${doc.attr(link, "href")} ведёт в пустоту.`);
    }
  });
});
