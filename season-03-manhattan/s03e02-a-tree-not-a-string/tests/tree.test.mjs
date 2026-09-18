// CRIMSON RAILS — s03e02, проверка.
//
// Здесь проверяется, что модуль работает с деревом, а не со строкой. Отличить
// одно от другого можно ровно двумя способами, и оба честные: собранная
// строкой разметка пересоздаёт узлы (а значит, теряет всё, что на них было),
// и собранная строкой разметка исполняет то, что в данных было текстом.
//
// Ни одна проверка не читает твой код.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { openDocument } from "../../support/dom.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const pick = (name) => {
  const own = join(here, "..", "artifacts", name);
  return existsSync(own) && !process.env.FORCE_SOLUTION ? own : join(here, "..", "solution", name);
};

const htmlFile = pick("telegraph.html");
const moduleFile = pick("telegraph.js");
console.log(`Источник: ${htmlFile.includes("artifacts") ? "artifacts" : "solution"}/ (telegraph.html + telegraph.js)`);
if (!existsSync(join(here, "..", "artifacts", "telegraph.js"))) console.log("(модуля нет — проверяю эталон)");

const bare = () => openDocument(htmlFile);
// Журнал, набранный для проверки: столько записей и такие состояния, каких в
// разметке нет. Всё, что вписано в модуль, на этом наборе разойдётся с ним.
const compose = (page, rows) => {
  const register = page.need("#entries");
  register.replaceChildren();
  for (const row of rows) {
    const item = page.document.createElement("li");
    item.dataset.id = String(row.id);
    item.dataset.state = row.state;
    if (row.hand) item.dataset.hand = row.hand;
    const text = page.document.createElement("p");
    text.textContent = row.text ?? `запись ${row.id}`;
    item.append(text);
    register.append(item);
  }
  return page;
};
const tallyOf = (page) =>
  Object.fromEntries(page.$$("#tally [data-tally]").map((node) => [node.dataset.tally, page.text(node)]));

describe("сводка считается по дереву", () => {
  test("в разметке сводки нет — её делает модуль", async () => {
    const page = bare();
    assert.equal(
      page.$("#tally"),
      null,
      "Сводка лежит прямо в разметке. Значит она врёт всякий раз, когда записей станет другое " +
        "число, — а заметить это будет некому.",
    );
    await page.run(moduleFile);
    assert.ok(page.$("#tally"), "Модуль не собрал сводку.");
    page.close();
  });

  test("сводка стоит перед журналом, а не после него", async () => {
    const page = bare();
    await page.run(moduleFile);
    const tally = page.need("#tally");
    const register = page.need("#entries");
    assert.ok(
      tally.compareDocumentPosition(register) & 4,
      "Сводка оказалась ниже журнала. Читают её раньше записей — значит и стоять ей раньше.",
    );
    page.close();
  });

  test("в сводке по строке на состояние и строка про почерк", async () => {
    const page = bare();
    await page.run(moduleFile);
    const lines = page.$$("#tally [data-tally]");
    assert.ok(
      lines.length >= 4,
      `Строк в сводке ${lines.length}. Их четыре: переданные, задержанные, непрошедшие и кто принял последнюю.`,
    );
    const names = new Set(lines.map((node) => node.dataset.tally));
    for (const name of ["sent", "held", "failed", "hand"]) {
      assert.ok(names.has(name), `В сводке нет строки «${name}». Каждая помечена своим data-tally: ` +
        "по ней её потом и находят, а не по порядку.");
    }
    page.close();
  });

  test("числа считаются, а не вписаны", async () => {
    const page = compose(bare(), [
      { id: 11, state: "held", hand: "Дарнелл" },
      { id: 12, state: "held", hand: "Финнерти" },
      { id: 13, state: "held" },
      { id: 14, state: "failed", hand: "Дарнелл" },
      { id: 15, state: "sent", hand: "Кейл" },
    ]);
    await page.run(moduleFile);
    const tally = tallyOf(page);
    assert.match(tally.sent, /\b1\b/, `«${tally.sent}» при одной переданной записи.`);
    assert.match(tally.held, /\b3\b/, `«${tally.held}» при трёх задержанных.`);
    assert.match(tally.failed, /\b1\b/, `«${tally.failed}» при одной непрошедшей.`);
    page.close();
  });

  test("пустой журнал даёт нули, а не пустоту", async () => {
    const page = compose(bare(), []);
    await page.run(moduleFile);
    const tally = tallyOf(page);
    assert.match(tally.sent, /\b0\b/, "В пустом журнале переданных ноль, и это надо сказать.");
    assert.match(tally.hand ?? "", /—|нет|никто/i, "Принявшего нет — так и напиши, а не оставляй пусто.");
    page.close();
  });

  test("последнюю принявшую берут у последней подписанной записи", async () => {
    const page = compose(bare(), [
      { id: 21, state: "sent", hand: "Кейл" },
      { id: 22, state: "sent", hand: "Дарнелл" },
      { id: 23, state: "sent" },
    ]);
    await page.run(moduleFile);
    assert.match(
      tallyOf(page).hand,
      /Дарнелл/,
      "Последняя запись без почерка — значит последняя принятая не она. Брать надо последнюю, " +
        "у которой почерк есть.",
    );
    page.close();
  });
});

describe("дерево, а не строка", () => {
  test("модуль не пересоздаёт записи", async () => {
    const page = bare();
    const marks = page.$$("#entries li").map((node, index) => {
      node.crimsonMark = `метка-${index}`;
      return node;
    });
    assert.ok(marks.length >= 5);
    await page.run(moduleFile);
    const after = page.$$("#entries li");
    assert.equal(after.length, marks.length, "Записей стало другое число.");
    for (const [index, node] of after.entries()) {
      assert.equal(
        node.crimsonMark,
        `метка-${index}`,
        "Записи пересозданы. Так бывает от одного присваивания innerHTML списку: старые узлы " +
          "выбрасываются, новые выглядят так же — но на них нет ничего, что на старых висело. " +
          "Слушатели, состояние полей, фокус и прокрутка пропадают молча.",
      );
    }
    page.close();
  });

  test("чужой текст остаётся текстом", async () => {
    const page = compose(bare(), [
      { id: 31, state: "sent", hand: "<b>ЗЛО</b>" },
    ]);
    await page.run(moduleFile);
    const hand = page.need('#tally [data-tally="hand"]');
    assert.equal(
      hand.querySelector("b"),
      null,
      "Значение из данных стало разметкой. Так выглядит собранная строкой сводка: то, что было " +
        "текстом, браузер разобрал как теги. Сегодня это <b>, завтра — <script> (s03e08).",
    );
    assert.ok(
      hand.textContent.includes("<b>ЗЛО</b>"),
      "Текст должен остаться таким, каким пришёл: textContent кладёт его как есть.",
    );
    page.close();
  });

  test("состояние берут из данных, а не из вида", async () => {
    const page = compose(bare(), [
      { id: 41, state: "failed", hand: "Кейл" },
      { id: 42, state: "failed", hand: "Кейл" },
    ]);
    for (const node of page.$$("#entries li")) node.classList.add("sent");
    await page.run(moduleFile);
    assert.match(
      tallyOf(page).failed,
      /\b2\b/,
      "Сводка посчитала по классам. Класс — это вид; состояние приходит из данных и живёт в " +
        "data-state.",
    );
    page.close();
  });
});

describe("записи без почерка помечены", () => {
  test("помечена та, у которой почерка нет", async () => {
    const page = bare();
    await page.run(moduleFile);
    const unsigned = page.$$("#entries li[data-unsigned]");
    assert.equal(unsigned.length, 1, `Помечено записей: ${unsigned.length}. Без почерка одна — четвёртая.`);
    assert.equal(unsigned[0].dataset.id, "4");
    assert.ok(
      page.text(unsigned[0]).includes("почерка нет"),
      "Пометка должна быть видна и читаема вслух, а не только в атрибуте: атрибут читателю не " +
        "покажут (s02e11 — цвет не единственный признак).",
    );
    page.close();
  });

  test("подписанные записи не тронуты", async () => {
    const page = bare();
    const before = page.$$("#entries li[data-hand]").map((node) => page.text(node));
    await page.run(moduleFile);
    const after = page.$$("#entries li[data-hand]").map((node) => page.text(node));
    assert.deepEqual(after, before, "Модуль дописал что-то к записям, у которых почерк есть.");
    page.close();
  });

  test("пометка снимается, когда почерк появился", async () => {
    const page = bare();
    await page.run(moduleFile);
    const entry = page.need("#entries li[data-unsigned]");
    entry.dataset.hand = "Дарнелл";
    await page.run(moduleFile);
    assert.equal(
      entry.dataset.unsigned,
      undefined,
      "Почерк появился, а пометка осталась. Отрисовка обязана приводить страницу к нынешнему " +
        "состоянию данных, а не только дописывать к прошлому.",
    );
    assert.ok(!page.text(entry).includes("почерка нет"), "И видимая пометка тоже должна уйти.");
    page.close();
  });
});

describe("правила первой редакции в силе", () => {
  test("второй запуск ничего не удваивает", async () => {
    const page = bare();
    await page.run(moduleFile);
    const once = page.snapshot();
    await page.run(moduleFile);
    assert.equal(page.snapshot(), once, "Второй запуск изменил страницу: сводка или пометка удвоились.");
    assert.equal(page.$$("#tally").length, 1);
    page.close();
  });

  test("журнал и без модуля остаётся журналом", async () => {
    const page = bare();
    for (const form of page.$$("form")) {
      assert.ok(form.getAttribute("action") && form.getAttribute("method"), "s03e01: форма знает, куда отправляться.");
    }
    assert.ok(page.$$("#entries li").length >= 5, "s03e01: записи видны без скрипта.");
    assert.equal(page.$$("script:not([src])").length, 0, "s03e01: встроенных скриптов нет.");
    page.close();
  });

  test("пометка и сокрытие из s03e01 на месте", async () => {
    const page = bare();
    await page.run(moduleFile);
    assert.equal(
      page.document.documentElement.dataset.script,
      "on",
      "s03e01: модуль отмечает, что доехал. Вторая редакция первую не отменяет.",
    );
    for (const node of page.$$("[data-without-script]")) {
      assert.ok(node.hidden, "s03e01: то, что нужно только без скрипта, при скрипте прячется.");
    }
    page.close();
  });

  test("модуль ничего не отнимает и не удаляет", async () => {
    const page = bare();
    const forms = page.$$("form").map((form) => [form.getAttribute("action"), form.getAttribute("method")]);
    const entries = page.$$("#entries li").length;
    await page.run(moduleFile);
    assert.deepEqual(page.$$("form").map((form) => [form.getAttribute("action"), form.getAttribute("method")]), forms);
    assert.equal(page.$$("#entries li").length, entries, "Записи из журнала не убирают — их прячут (s03e03).");
    assert.deepEqual(page.errors, []);
    page.close();
  });
});
