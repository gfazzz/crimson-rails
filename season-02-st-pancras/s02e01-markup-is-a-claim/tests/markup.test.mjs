// CRIMSON RAILS — s02e01, проверка.
//
// Проверяется не текст файла, а то, что из него следует: какие утверждения
// о содержании делает разметка. Ни одно сравнение здесь не посимвольное.

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

describe("документ", () => {
  test("объявлен тип документа", () => {
    assert.match(
      doc.source.slice(0, 200).toLowerCase(),
      /<!doctype html>/,
      "Без <!doctype html> браузер переходит в режим совместимости с прошлым веком, " +
        "и часть правил начинает работать иначе.",
    );
  });

  test("объявлен язык страницы", () => {
    const lang = doc.attr(doc.first("html"), "lang");
    assert.equal(lang, "ru", "Атрибут lang говорит, на каком языке читать вслух и как переносить слова.");
  });

  test("объявлена кодировка", () => {
    const meta = doc.all("meta").find((m) => doc.hasAttr(m, "charset"));
    assert.ok(meta, "Без <meta charset> кириллица зависит от догадки браузера.");
    assert.equal(doc.attr(meta, "charset").toLowerCase(), "utf-8");
  });

  test("заголовок вкладки не пустой", () => {
    assert.ok(doc.text(doc.first("title")).length > 10, "<title> читают в закладках и в выдаче.");
  });
});

describe("заголовки", () => {
  test("ровно один h1", () => {
    assert.equal(doc.count("h1"), 1, "h1 — это заголовок страницы, и он один.");
  });

  test("уровни идут без пропусков", () => {
    const jumps = doc.headingJumps();
    assert.deepEqual(
      jumps,
      [],
      `Пропуск уровня: ${jumps.map((j) => `h${j.from} → h${j.to} («${j.text}»)`).join(", ")}. ` +
        "Уровень заголовка — это глубина в оглавлении, а не размер шрифта.",
    );
  });

  test("заголовков хватает на структуру полосы", () => {
    assert.ok(doc.count("h2") >= 3, "Разделы полосы: две линии и примечания.");
  });
});

describe("ориентиры", () => {
  test("есть шапка, основное содержание, оглавление и примечания", () => {
    for (const tag of ["header", "nav", "main", "footer"]) {
      assert.equal(doc.count(tag), 1, `<${tag}> должен быть ровно один.`);
    }
  });

  test("оглавление — перечень, а не три ссылки подряд", () => {
    const nav = doc.first("nav");
    const list = doc.children(nav).find((c) => c.tagName === "ul" || c.tagName === "ol");
    assert.ok(list, "Перечень линий — это список.");

    const links = doc.all("a").filter((a) => doc.closest(a, "nav"));
    assert.ok(links.length >= 3, "В оглавлении меньше трёх ссылок.");
    for (const link of links) {
      assert.ok(doc.closest(link, "li"), "Каждый пункт оглавления — отдельный <li>.");
    }
  });

  test("у оглавления есть имя", () => {
    const nav = doc.first("nav");
    assert.ok(
      doc.attr(nav, "aria-label") || doc.all("h2").some((h) => doc.closest(h, "nav")),
      "Когда ориентиров несколько, каждому нужно имя: заголовок внутри или aria-label.",
    );
  });
});

describe("бессмысленные обёртки", () => {
  test("ни одного div", () => {
    assert.equal(
      doc.count("div"),
      0,
      "На этой полосе нет ничего, для чего не нашлось бы своего тега. " +
        "div — признак того, что решение о смысле не принято.",
    );
  });

  test("нет b и i вместо strong и em", () => {
    assert.equal(doc.count("b") + doc.count("i"), 0, "b и i говорят о начертании, strong и em — о смысле.");
  });

  test("отступы не набраны переносами", () => {
    assert.equal(doc.count("br"), 0, "<br> — это перенос внутри строки, а не способ отодвинуть абзац.");
  });
});

describe("машиночитаемое", () => {
  test("дата выпуска размечена как дата", () => {
    const time = doc.first("time");
    assert.ok(time, "Дата выпуска — это дата, а не просто слова.");
    const value = doc.attr(time, "datetime");
    assert.ok(value, "У <time> должен быть datetime: человеку — текст, машине — атрибут.");
    assert.match(value, /^1891-04(-\d{2})?$/, "Апрель 1891 года в машинном виде — 1891-04.");
  });

  test("сокращение раскрыто", () => {
    const abbr = doc.first("abbr");
    assert.ok(abbr, "В расписаниях сокращают станции; abbr говорит, что это сокращение.");
    assert.ok(doc.attr(abbr, "title"), "И раскрывает его в title.");
  });
});

describe("примечания", () => {
  test("примечания — нумерованный перечень", () => {
    const list = doc.all("ol").find((ol) => doc.closest(ol, "footer"));
    assert.ok(list, "Примечания нумерованы, значит <ol>.");
    assert.ok(doc.children(list).length >= 2, "Примечаний в полосе два.");
  });

  test("каждая ссылка на примечание никуда не ведёт впустую", () => {
    const internal = doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"));
    assert.ok(internal.length >= 2, "Служебные остановки ссылаются на примечания.");
    for (const link of internal) {
      const id = doc.attr(link, "href").slice(1);
      assert.ok(doc.byId(id), `Ссылка на #${id} ведёт в пустоту: такого id в документе нет.`);
    }
  });

  test("каждое примечание кем-то вызвано", () => {
    const list = doc.all("ol").find((ol) => doc.closest(ol, "footer"));
    const targets = doc.all("a").map((a) => (doc.attr(a, "href") ?? "").slice(1));
    for (const item of doc.children(list)) {
      const id = doc.attr(item, "id");
      assert.ok(id, "У примечания должен быть id, иначе на него не сослаться.");
      assert.ok(targets.includes(id), `На примечание #${id} никто не ссылается — зачем оно в полосе?`);
    }
  });
});

describe("содержание полосы", () => {
  test("обе линии и обе служебные остановки на месте", () => {
    const text = doc.text();
    for (const required of ["Дерби", "Лондон", "Лестер", "Бедфорд", "Колвик-Сайдингс", "Тоттон-Юкцион"]) {
      assert.ok(text.includes(required), `В полосе нет упоминания «${required}» — данные из mission.md неполны.`);
    }
  });
});
