// CRIMSON RAILS — s02e02, проверка.
//
// Таблица проверяется так, как её читает голосовой браузер: может ли он для
// каждой ячейки назвать станцию и поезд. Ни одного сравнения с эталоном.

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
const tables = doc.tables();
const table = tables[0];

const STATIONS = ["Дерби", "Ноттингем", "Колвик-Сайдингс", "Лестер", "Бедфорд", "Лондон"];

describe("таблица есть и стоит где надо", () => {
  test("ровно одна таблица", () => {
    assert.equal(tables.length, 1, "Расписание на полосе одно.");
  });

  test("таблица внутри основного содержания", () => {
    assert.ok(doc.closest(table.node, "main"), "Расписание — это и есть содержание полосы.");
  });

  test("таблица не вложена в другую таблицу", () => {
    assert.equal(
      [...doc.walk(table.node)].filter((n) => n.tagName === "table").length,
      0,
      "Таблица в таблице — почти всегда попытка сделать раскладку таблицей.",
    );
  });
});

describe("подпись", () => {
  test("у таблицы есть caption", () => {
    assert.ok(table.caption, "Без <caption> таблица безымянна: в списке таблиц её не отличить от других.");
  });

  test("caption — первый ребёнок таблицы", () => {
    assert.equal(
      doc.children(table.node)[0]?.tagName,
      "caption",
      "По стандарту <caption> идёт первым. Иначе разметка незаконна, а подпись может уехать.",
    );
  });

  test("подпись говорит, что это за расписание", () => {
    const text = doc.text(table.caption);
    assert.ok(text.length >= 10, "Подпись из одного слова ничего не сообщает.");
    assert.ok(/1891/.test(text), "В подписи должен быть период: расписание без срока действия бесполезно.");
  });
});

describe("шапка и тело разделены", () => {
  test("есть thead и tbody", () => {
    assert.ok(table.section("thead"), "Шапка таблицы — <thead>: она повторяется при печати на каждой странице.");
    assert.ok(table.section("tbody"), "Тело — <tbody>.");
  });

  test("в шапке две строки: группы поездов и сами поезда", () => {
    assert.equal(table.headRows().length, 2, "Утренние и дневные — это группа столбцов над столбцами.");
  });

  test("в теле столько строк, сколько станций", () => {
    assert.equal(table.bodyRows().length, STATIONS.length, `Станций на линии ${STATIONS.length}.`);
  });
});

describe("каждая ячейка знает своё место", () => {
  test("все заголовки объявляют, к чему относятся", () => {
    const unscoped = table.unscopedHeaders();
    assert.deepEqual(
      unscoped.map((th) => doc.text(th)),
      [],
      "Заголовок без scope не привязан ни к строке, ни к столбцу: " +
        "голосовой браузер прочтёт ячейку как число без названия.",
    );
  });

  test("заголовки столбцов объявлены столбцами", () => {
    const head = table.headRows();
    const scopes = head.flatMap((row) => table.cells(row))
      .filter((c) => c.tagName === "th")
      .map((th) => doc.attr(th, "scope"));
    assert.ok(scopes.every((s) => s === "col" || s === "colgroup"), "В шапке бывает только col и colgroup.");
    assert.ok(scopes.includes("colgroup"), "Утренние и дневные накрывают по два столбца — это colgroup.");
    assert.ok(scopes.filter((s) => s === "col").length >= 5, "Столбцов пять: станция и четыре поезда.");
  });

  test("первая ячейка каждой строки тела — заголовок строки", () => {
    for (const row of table.bodyRows()) {
      const first = table.cells(row)[0];
      assert.equal(
        first?.tagName,
        "th",
        `Строка «${doc.text(row).slice(0, 30)}»: название станции — заголовок строки, а не данные.`,
      );
      assert.equal(doc.attr(first, "scope"), "row", "И объявлено как заголовок строки.");
    }
  });

  test("группа столбцов накрывает ровно два столбца", () => {
    const groups = table.headerCells().filter((th) => doc.attr(th, "scope") === "colgroup");
    assert.equal(groups.length, 2, "Групп две: утренние и дневные.");
    for (const group of groups) {
      assert.equal(doc.attr(group, "colspan"), "2", `Группа «${doc.text(group)}» накрывает два поезда.`);
    }
  });
});

describe("строки сходятся по ширине", () => {
  test("все строки одной ширины с учётом colspan", () => {
    const widths = table.widths();
    const unique = [...new Set(widths)];
    assert.equal(
      unique.length,
      1,
      `Ширины строк: ${widths.join(", ")}. Расходятся — значит, где-то пропущена ячейка ` +
        "или забыт colspan, и вся таблица ниже съезжает на столбец.",
    );
  });

  test("ширина — станция и четыре поезда", () => {
    assert.equal(table.widths()[0], 5);
  });
});

describe("содержание расписания", () => {
  test("все станции линии на месте", () => {
    const headers = table.bodyRows().map((row) => doc.text(table.cells(row)[0]));
    for (const station of STATIONS) {
      assert.ok(
        headers.some((h) => h.includes(station)),
        `В расписании нет строки станции «${station}».`,
      );
    }
  });

  test("время записано временем", () => {
    const times = table.bodyRows()
      .flatMap((row) => table.cells(row).slice(1))
      .map((cell) => doc.text(cell))
      .filter((text) => text.length > 0);

    assert.ok(times.length >= 18, "Времён в расписании должно быть больше восемнадцати.");
    for (const value of times) {
      assert.match(value, /^\d{1,2}:\d{2}$/, `«${value}» не похоже на время. Формат один на всю полосу: ч:мм.`);
    }
  });

  test("остановки, которых нет, оставлены пустыми, а не пропущены", () => {
    const colwick = table.bodyRows().find((row) => doc.text(table.cells(row)[0]).includes("Колвик"));
    assert.ok(colwick, "Колвик-Сайдингс — тоже строка расписания.");
    assert.equal(
      table.cells(colwick).length,
      5,
      "У служебной остановки нет времён, но ячейки есть: пропустить их — значит сдвинуть строку.",
    );
    assert.equal(
      table.cells(colwick).slice(1).map((c) => doc.text(c)).join(""),
      "",
      "И все четыре ячейки пусты.",
    );
  });

  test("почтовый не останавливается в Лестере", () => {
    const leicester = table.bodyRows().find((row) => doc.text(table.cells(row)[0]).includes("Лестер"));
    const cells = table.cells(leicester).slice(1).map((c) => doc.text(c));
    assert.equal(cells[3], "", "Из текста полосы: почтовый идёт без остановки в Лестере.");
    assert.ok(cells.slice(0, 3).every((c) => c.length > 0), "Прочие три поезда там останавливаются.");
  });
});

describe("сноски внутри таблицы", () => {
  test("ссылки из таблицы ведут в существующие примечания", () => {
    const links = [...doc.walk(table.node)].filter((n) => n.tagName === "a");
    assert.ok(links.length >= 2, "Служебная остановка и почтовый поезд помечены сносками.");
    for (const link of links) {
      const id = (doc.attr(link, "href") ?? "").replace(/^#/, "");
      assert.ok(doc.byId(id), `Сноска в таблице ведёт на #${id}, а такого примечания нет.`);
    }
  });

  test("сноска стоит в заголовке, а не в ячейке времени", () => {
    const colwick = table.bodyRows().find((row) => doc.text(table.cells(row)[0]).includes("Колвик"));
    const header = table.cells(colwick)[0];
    assert.ok(
      [...doc.walk(header)].some((n) => n.tagName === "a"),
      "Примечание относится к станции, значит стоит при названии станции.",
    );
  });
});

describe("прошлая серия не сломана", () => {
  test("структура полосы на месте", () => {
    assert.equal(doc.count("h1"), 1);
    assert.deepEqual(doc.headingJumps(), []);
    assert.equal(doc.count("main"), 1);
    assert.equal(doc.count("div"), 0, "Таблицу не заворачивают в div без причины.");
  });

  test("все ссылки внутри документа по-прежнему ведут куда-то", () => {
    const internal = doc.all("a").filter((a) => (doc.attr(a, "href") ?? "").startsWith("#"));
    for (const link of internal) {
      const id = doc.attr(link, "href").slice(1);
      assert.ok(doc.byId(id), `Ссылка на #${id} ведёт в пустоту — проверка из s02e01.`);
    }
  });
});
