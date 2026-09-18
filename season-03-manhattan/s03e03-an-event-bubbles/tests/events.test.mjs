// CRIMSON RAILS — s03e03, проверка.
//
// Здесь проверяется то, ради чего вся эта серия: слушатель вешается один раз
// и работает на записи, которой не было при загрузке. Отличить делегирование
// от ста слушателей можно, не читая кода: достаточно добавить запись после
// того, как модуль отработал, и нажать на неё.

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

const live = async () => {
  const page = openDocument(htmlFile);
  await page.run(moduleFile);
  return page;
};
const visible = (page) => page.$$("#entries li").filter((node) => !node.hidden).map((node) => node.dataset.id);

// Запись, которой не было, когда модуль работал. Главный инструмент серии.
const arrive = (page, { id = 99, state = "sent", hand = "Кейл", text = "новая запись" } = {}) => {
  const item = page.document.createElement("li");
  item.dataset.id = String(id);
  item.dataset.state = state;
  if (hand) item.dataset.hand = hand;
  const line = page.document.createElement("p");
  line.textContent = text;
  item.append(line);
  page.need("#entries").append(item);
  return item;
};

describe("отбор работает на месте", () => {
  test("выбор состояния прячет остальные записи", async () => {
    const page = await live();
    await page.fill("#state", "held");
    assert.deepEqual(visible(page), ["3"], "При выборе «задержанные» видна одна запись — третья.");
    page.close();
  });

  test("возврат к «всем записям» показывает всё", async () => {
    const page = await live();
    await page.fill("#state", "failed");
    await page.fill("#state", "");
    assert.equal(visible(page).length, 6, "Отбор обратим: пустое значение показывает весь журнал.");
    page.close();
  });

  test("записи прячутся, а не удаляются", async () => {
    const page = await live();
    const before = page.$$("#entries li").length;
    await page.fill("#state", "failed");
    assert.equal(
      page.$$("#entries li").length,
      before,
      "Отбор удалил записи. Тогда «показать все» их уже не вернёт, а журнал за смену — это всё, " +
        "что за смену было.",
    );
    page.close();
  });

  test("отбор не уводит со страницы", async () => {
    const page = await live();
    const { prevented } = await page.submit("form.sift");
    assert.ok(
      prevented,
      "Форма отбора отправилась на сервер. Со скриптом отбор уже случился на месте — отправку " +
        "надо отменить, иначе Enter в списке перезагрузит страницу и потеряет всё, что на ней " +
        "было помечено.",
    );
    page.close();
  });

  test("отправку формы подачи модуль не трогает", async () => {
    const page = await live();
    const { prevented } = await page.submit("form.compose");
    assert.equal(
      prevented,
      false,
      "Модуль отменил отправку формы подачи, ничем её не заменив: запись просто не уйдёт. " +
        "Перехватывать отправку можно только тогда, когда есть чем её заменить (s03e04).",
    );
    page.close();
  });
});

describe("слушатель один, а не сто", () => {
  test("на записях нет слушателей", async () => {
    const page = await live();
    assert.deepEqual(
      page.listenersOn("li", "click").map((item) => item.target.dataset.id),
      [],
      "Слушатели повешены на каждую запись. Их столько же, сколько записей; на записи, которая " +
        "придёт следующей, их не будет вовсе — и она перестанет работать, ничего об этом не " +
        "сообщив.",
    );
  });

  test("слушателей нажатия немного", async () => {
    const page = await live();
    const clicks = page.listenersOf("click");
    assert.ok(
      clicks.length >= 1,
      "Нажатие по записи никто не слушает.",
    );
    assert.ok(
      clicks.length <= 3,
      `Слушателей нажатия ${clicks.length}. Их должно быть столько, сколько мест, где нажатие ` +
        "что-то значит, — а не столько, сколько узлов.",
    );
  });

  test("запись, которой не было при загрузке, работает", async () => {
    const page = await live();
    const fresh = arrive(page, { id: 101, text: "14-я улица: путь свободен" });
    await page.click(fresh.querySelector("p"));
    assert.equal(
      fresh.dataset.chalk,
      "yes",
      "Новая запись не откликнулась. Так себя ведёт слушатель, повешенный на каждый узел " +
        "по отдельности: узла не было — слушателя ему не досталось. Событие всплывает; " +
        "слушать надо выше, а на чём оно началось — спрашивать у самого события.",
    );
    page.close();
  });

  test("отбор тоже знает о новой записи", async () => {
    const page = await live();
    const late = arrive(page, { id: 102, state: "sent" });
    await page.fill("#state", "failed");
    assert.ok(
      late.hidden,
      "Запись, пришедшая после загрузки, осталась видна при отборе по другому состоянию: " +
        "список узлов был взят один раз и запомнен. Спрашивать дерево надо каждый раз — " +
        "оно меняется.",
    );
    assert.deepEqual(visible(page), ["5"], "Видна только непрошедшая.");
    await page.fill("#state", "sent");
    assert.ok(!late.hidden, "И обратно: при отборе по своему состоянию новая запись видна.");
    page.close();
  });
});

describe("мел ставится и снимается", () => {
  test("нажатие ставит пометку, второе снимает", async () => {
    const page = await live();
    const entry = page.need('#entries li[data-id="2"]');
    await page.click(entry.querySelector("p"));
    assert.equal(entry.dataset.chalk, "yes", "Первое нажатие ставит мел.");
    await page.click(entry.querySelector("p"));
    assert.equal(entry.dataset.chalk, undefined, "Второе снимает. Пометка — переключатель, а не прибавление.");
    page.close();
  });

  test("нажатие внутри записи считается нажатием по записи", async () => {
    const page = await live();
    const entry = page.need('#entries li[data-id="1"]');
    await page.click(entry.querySelector(".hand"));
    assert.equal(
      entry.dataset.chalk,
      "yes",
      "Нажали по вложенному абзацу, и запись не откликнулась. Событие началось на абзаце — " +
        "искать надо ближайшую запись вверх по дереву, а не сравнивать цель со списком.",
    );
    page.close();
  });

  test("нажатие мимо записей ничего не портит", async () => {
    const page = await live();
    await page.click("h1");
    await page.click("#tally");
    assert.deepEqual(page.$$("#entries li[data-chalk]"), [], "Нажатие вне журнала пометило запись.");
    assert.deepEqual(page.errors, [], "Нажатие вне журнала уронило обработчик.");
    page.close();
  });

  test("по ссылке внутри записи мел не ставится", async () => {
    const page = await live();
    const entry = page.need('#entries li[data-id="6"]');
    const link = page.document.createElement("a");
    link.href = "#register";
    link.textContent = "подробности";
    entry.append(link);
    await page.click(link);
    assert.equal(
      entry.dataset.chalk,
      undefined,
      "Нажатие по ссылке внутри записи поставило мел. У ссылки своё дело; обработчик записи " +
        "должен пропускать то, что и без него что-то значит.",
    );
    page.close();
  });

  test("мел переживает отбор", async () => {
    const page = await live();
    const entry = page.need('#entries li[data-id="3"]');
    await page.click(entry.querySelector("p"));
    await page.fill("#state", "sent");
    await page.fill("#state", "");
    assert.equal(
      entry.dataset.chalk,
      "yes",
      "Отбор стёр мел. Значит он не прячет записи, а пересоздаёт их (s03e02).",
    );
    page.close();
  });
});

describe("прежние редакции в силе", () => {
  test("сводка и пометка без почерка на месте", async () => {
    const page = await live();
    assert.ok(page.$("#tally"), "s03e02: сводка.");
    assert.equal(page.$$("#entries li[data-unsigned]").length, 1, "s03e02: запись без почерка помечена.");
    assert.equal(page.document.documentElement.dataset.script, "on", "s03e01: пометка «скрипт доехал».");
    page.close();
  });

  test("второй запуск ничего не удваивает", async () => {
    const page = await live();
    const once = page.snapshot();
    await page.run(moduleFile);
    assert.equal(page.snapshot(), once, "Второй запуск изменил страницу.");
    const entry = page.need('#entries li[data-id="2"]');
    await page.click(entry.querySelector("p"));
    assert.equal(
      entry.dataset.chalk,
      "yes",
      "После двух запусков нажатие сработало дважды и вернуло всё как было: слушатели " +
        "повесились второй раз.",
    );
    page.close();
  });

  test("журнал без модуля остаётся журналом", async () => {
    const page = openDocument(htmlFile);
    for (const form of page.$$("form")) {
      assert.ok(form.getAttribute("action") && form.getAttribute("method"), "s03e01: форма знает, куда отправляться.");
    }
    assert.equal(page.$$("#entries li").filter((node) => node.hidden).length, 0, "Без скрипта видны все записи.");
    page.close();
  });
});
