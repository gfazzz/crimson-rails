// CRIMSON RAILS — s02e04, проверка.
//
// Здесь проверяется то, что слышно, а не то, что видно: может ли полоса быть
// прочитана вслух целиком и без догадок.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readDocument } from "../../support/check.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const own = join(here, "..", "artifacts", "bradshaw.html");
const reference = join(here, "..", "solution", "bradshaw.html");
const source = existsSync(own) && !process.env.FORCE_SOLUTION ? own : reference;

console.log(`Источник: ${source.includes("artifacts") ? "artifacts" : "solution"}/bradshaw.html`);
if (!existsSync(own)) console.log("(артефакта нет — проверяю эталон)");

const doc = readDocument(source);

describe("в обход оглавления", () => {
  test("первая ссылка страницы стоит раньше оглавления", () => {
    const first = doc.all("a")[0];
    assert.ok(first, "На полосе нет ни одной ссылки.");
    assert.ok(
      !doc.closest(first, "nav"),
      "Первое, на что попадает клавиша Tab, — оглавление. Значит, ссылки в обход нет: " +
        "читатель с клавиатуры проходит оглавление на каждой полосе заново.",
    );
    assert.ok(
      (doc.attr(first, "href") ?? "").startsWith("#"),
      "Ссылка в обход ведёт внутрь этой же полосы.",
    );
  });

  test("она ведёт в основное содержание", () => {
    const first = doc.all("a")[0];
    const id = doc.attr(first, "href").slice(1);
    const target = doc.byId(id);
    assert.ok(target, `Ссылка в обход ведёт на #${id}, а такого места на полосе нет.`);
    assert.ok(
      doc.tag(target) === "main" || doc.closest(target, "main"),
      "Обходить оглавление имеет смысл только в сторону содержания: " +
        `цель #${id} лежит вне <main>.`,
    );
  });

  test("у неё есть текст", () => {
    assert.ok(doc.text(doc.all("a")[0]).length >= 4, "Ссылку в обход надо назвать: её слышат, хотя и не видят.");
  });
});

describe("изображения", () => {
  test("у каждого изображения объявлено описание", () => {
    const images = doc.all("img");
    assert.ok(images.length >= 2, "На полосе схема линии и наборная линейка.");
    for (const image of images) {
      assert.ok(
        doc.attr(image, "alt") !== null,
        `У <img src="${doc.attr(image, "src")}"> нет alt. Отсутствующий alt и пустой alt — ` +
          "разные вещи: в первом случае голосовой браузер прочтёт имя файла.",
      );
    }
  });

  test("содержательное изображение описано словами", () => {
    const map = doc.all("img").find((i) => (doc.attr(i, "src") ?? "").includes("map"));
    assert.ok(map, "Схема линии на полосе должна быть.");
    const alt = doc.attr(map, "alt");
    assert.ok(alt.length > 20, "Описание схемы должно передавать то, что на ней видно, а не называть её «схемой».");
    for (const station of ["Дерби", "Лондон"]) {
      assert.ok(alt.includes(station), `В описании схемы нет станции «${station}».`);
    }
  });

  test("декоративное изображение описано пустотой", () => {
    const rule = doc.all("img").find((i) => (doc.attr(i, "src") ?? "").includes("rule"));
    assert.ok(rule, "Наборная линейка на полосе должна быть.");
    assert.equal(
      doc.attr(rule, "alt"),
      "",
      "Линейка ничего не сообщает. Пустой alt — это заявление «здесь нечего читать», " +
        "и голосовой браузер такое изображение пропустит.",
    );
  });

  test("у схемы есть подпись, и она не дублирует описание", () => {
    const figure = doc.first("figure");
    assert.ok(figure, "Схема с подписью — это <figure>.");
    const caption = doc.children(figure).find((c) => c.tagName === "figcaption");
    assert.ok(caption, "Подпись — <figcaption>.");
    const image = [...doc.walk(figure)].find((n) => n.tagName === "img");
    assert.notEqual(
      doc.text(caption).trim(),
      doc.attr(image, "alt").trim(),
      "Подпись и описание решают разные задачи: подпись видят все, описание слышат вместо картинки. " +
        "Совпадая дословно, они читаются дважды.",
    );
  });
});

describe("язык", () => {
  test("у полосы объявлен язык", () => {
    assert.equal(doc.attr(doc.first("html"), "lang"), "ru");
  });

  test("иноязычное вкрапление объявлено отдельно", () => {
    const foreign = [...doc.walk()].filter((n) => n.tagName !== "html" && doc.attr(n, "lang"));
    assert.ok(
      foreign.length >= 1,
      "Английское название справочника, прочитанное по-русски, не узнаётся на слух. " +
        "Вкрапление помечают своим lang.",
    );
    for (const node of foreign) {
      assert.notEqual(doc.attr(node, "lang"), "ru", "Помечать русским внутри русской полосы незачем.");
    }
  });
});

describe("порядок обхода", () => {
  test("порядок не переставлен вручную", () => {
    const positive = [...doc.walk()].filter((n) => Number(doc.attr(n, "tabindex") ?? 0) > 0);
    assert.deepEqual(
      positive.map((n) => doc.tag(n)),
      [],
      "Положительный tabindex вырывает элемент из естественного порядка и ставит перед всем " +
        "остальным на странице. Порядок задают разметкой, а не числами.",
    );
  });
});

describe("где читатель сейчас", () => {
  test("текущий раздел помечен в оглавлении", () => {
    const current = doc.all("a").filter((a) => doc.attr(a, "aria-current"));
    assert.equal(current.length, 1, "Ровно одна ссылка оглавления помечает текущее место.");
    assert.equal(doc.attr(current[0], "aria-current"), "page");
    assert.ok(doc.closest(current[0], "nav"), "И она в оглавлении.");
  });
});

describe("лишние объявления", () => {
  test("роли не повторяют то, что уже сказано тегом", () => {
    const redundant = { nav: "navigation", main: "main", header: "banner", footer: "contentinfo", table: "table" };
    for (const [tag, role] of Object.entries(redundant)) {
      for (const node of doc.all(tag)) {
        assert.notEqual(
          doc.attr(node, "role"),
          role,
          `<${tag} role="${role}"> — повтор: тег уже это значит. Лишние роли только мешают.`,
        );
      }
    }
  });

  test("подпись не подменяется атрибутом поверх видимого текста", () => {
    for (const link of doc.all("a")) {
      const text = doc.text(link);
      const label = doc.attr(link, "aria-label");
      if (!label || !text) continue;
      assert.ok(
        label.includes(text) || text.includes(label),
        `Ссылка «${text}» объявлена как «${label}». Голос прочтёт второе, глаз увидит первое — ` +
          "читатель услышит не то, что ему показали.",
      );
    }
  });
});

describe("прошлые серии не сломаны", () => {
  test("структура полосы и таблица на месте", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("div"), 0);
    const table = doc.tables()[0];
    assert.ok(table, "Расписание из s02e02 никуда не делось.");
    assert.deepEqual(table.unscopedHeaders().map((th) => doc.text(th)), []);
    assert.equal(new Set(table.widths()).size, 1);
  });

  test("все внутренние ссылки ведут куда-то", () => {
    for (const link of doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"))) {
      assert.ok(doc.byId(doc.attr(link, "href").slice(1)), `Ссылка на ${doc.attr(link, "href")} ведёт в пустоту.`);
    }
  });
});
