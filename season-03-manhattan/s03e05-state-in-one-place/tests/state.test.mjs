// CRIMSON RAILS — s03e05, проверка.
//
// Половина этой проверки не открывает страницу вовсе: состояние и то, что с
// ним делают, импортируется как обычный модуль и проверяется на месте. Это и
// есть то, ради чего затевалось деление — модуль, который можно спросить, не
// показывая ему дерева документа.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { openDocument } from "../../support/dom.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const pick = (name) => {
  const own = join(here, "..", "artifacts", name);
  return existsSync(own) && !process.env.FORCE_SOLUTION ? own : join(here, "..", "solution", name);
};

const htmlFile = pick("telegraph.html");
const moduleFile = pick("telegraph.js");
console.log(`Источник: ${htmlFile.includes("artifacts") ? "artifacts" : "solution"}/`);
if (!existsSync(join(here, "..", "artifacts", "telegraph.js"))) console.log("(модуля нет — проверяю эталон)");

const load = (name) => import(pathToFileURL(pick(name)).href);
const bare = () => openDocument(htmlFile);
const live = async () => {
  const page = bare();
  await page.run(moduleFile);
  return page;
};
const clone = (value) => JSON.parse(JSON.stringify(value));
const ids = (page) => page.$$("#entries li").filter((node) => !node.hidden).map((node) => node.dataset.id);

describe("состояние отделено от страницы", () => {
  test("состояние живёт в своём файле", async () => {
    let state;
    try {
      state = await load("state.js");
    } catch (error) {
      assert.fail(
        `state.js не импортируется: ${error.message}. Состояние выносят в отдельный модуль — ` +
          "тогда его можно проверить, не открывая страницы, и отрисовать не одним способом.",
      );
    }
    for (const name of ["read", "withFilter", "withChalk", "counts"]) {
      assert.equal(typeof state[name], "function", `state.js не отдаёт ${name}.`);
    }
  });

  test("отрисовка живёт в своём файле", async () => {
    const view = await load("render.js");
    assert.equal(typeof view.render, "function", "render.js не отдаёт render.");
  });

  test("состояние ничего не знает о дереве", async () => {
    const { withChalk, withFilter, counts, register, entry } = await load("state.js");
    const state = register({
      entries: [entry({ id: 1, state: "sent" }), entry({ id: 2, state: "held", hand: "Кейл" })],
    });
    // Ни одна из этих функций не получает узла — и не должна его хотеть.
    assert.doesNotThrow(() => withChalk(state, 1), "withChalk попросил дерево.");
    assert.doesNotThrow(() => withFilter(state, "held"), "withFilter попросил дерево.");
    assert.doesNotThrow(() => counts(state), "counts попросил дерево.");
  });

  test("начальное состояние читается из разметки", async () => {
    const { read } = await load("state.js");
    const page = bare();
    const state = read(page.need("main"));
    assert.equal(state.entries.length, 6, "В журнале шесть записей.");
    assert.equal(state.entries[0].id, "1");
    assert.equal(state.entries[2].state, "held");
    assert.equal(state.entries[3].hand, null, "У четвёртой записи почерка нет.");
    assert.ok(state.entries[0].text.length > 10, "Текст записи должен попасть в состояние.");
    page.close();
  });
});

describe("состояние не меняют — его заменяют", () => {
  test("withChalk не трогает то, что дали", async () => {
    const { register, entry, withChalk } = await load("state.js");
    const state = register({ entries: [entry({ id: 1 }), entry({ id: 2 })] });
    const before = clone(state);
    const next = withChalk(state, 1);
    assert.deepEqual(
      clone(state),
      before,
      "withChalk изменил переданное состояние. Тогда «как было» узнать уже негде: ни отменить, " +
        "ни сравнить, ни понять, что именно поменялось.",
    );
    assert.notEqual(next, state, "Вернуться должно новое состояние, а не то же самое.");
    assert.equal(next.entries[0].chalk, true, "Мел поставлен.");
    assert.equal(next.entries[1].chalk, false, "И только на той записи, которую назвали.");
  });

  test("мел — переключатель", async () => {
    const { register, entry, withChalk } = await load("state.js");
    const state = register({ entries: [entry({ id: 7 })] });
    assert.equal(withChalk(withChalk(state, 7), 7).entries[0].chalk, false, "Дважды — значит снято.");
  });

  test("withFilter меняет только отбор", async () => {
    const { register, entry, withFilter } = await load("state.js");
    const state = register({ entries: [entry({ id: 1, state: "held" })] });
    const next = withFilter(state, "held");
    assert.equal(next.filter, "held");
    assert.deepEqual(next.entries, state.entries, "Отбор — это взгляд на записи, а не изменение записей.");
    assert.equal(state.filter, "", "Исходное состояние не тронуто.");
  });

  test("отбор ничего не выбрасывает", async () => {
    const { register, entry, withFilter, shown } = await load("state.js");
    const state = withFilter(
      register({ entries: [entry({ id: 1, state: "sent" }), entry({ id: 2, state: "held" })] }),
      "held",
    );
    assert.equal(state.entries.length, 2, "Записи остаются все.");
    assert.deepEqual(shown(state).map((item) => item.id), ["2"], "Показывается — не все.");
  });

  test("счёт и последний почерк считаются по состоянию", async () => {
    const { register, entry, counts, lastHand } = await load("state.js");
    const state = register({
      entries: [
        entry({ id: 1, state: "held", hand: "Кейл" }),
        entry({ id: 2, state: "held" }),
        entry({ id: 3, state: "failed", hand: "Дарнелл" }),
        entry({ id: 4, state: "sent" }),
      ],
    });
    assert.deepEqual(counts(state), { sent: 1, held: 2, failed: 1 });
    assert.equal(lastHand(state), "Дарнелл", "Последняя запись без почерка — значит не она.");
  });
});

describe("отрисовка — функция состояния", () => {
  test("страница приводится к состоянию, а не дополняется", async () => {
    const { read, withChalk } = await load("state.js");
    const { render } = await load("render.js");
    const page = bare();
    const root = page.need("main");

    let state = read(root);
    render(root, state);
    state = withChalk(state, "2");
    render(root, state);
    assert.equal(page.attr('li[data-id="2"]', "data-chalk"), "yes", "Мел из состояния должен появиться на странице.");

    state = withChalk(state, "2");
    render(root, state);
    assert.equal(
      page.attr('li[data-id="2"]', "data-chalk"),
      null,
      "Мел сняли в состоянии, а на странице он остался. Значит отрисовка дописывает к прошлому, " +
        "а не приводит к нынешнему.",
    );
    page.close();
  });

  test("испорченное руками дерево возвращается к состоянию", async () => {
    const { read } = await load("state.js");
    const { render } = await load("render.js");
    const page = bare();
    const root = page.need("main");
    const state = read(root);
    render(root, state);

    const node = page.need('li[data-id="5"]');
    node.dataset.chalk = "yes";
    node.hidden = true;
    render(root, state);

    assert.equal(node.dataset.chalk, undefined, "Отрисовка не сняла мел, которого нет в состоянии.");
    assert.equal(node.hidden, false, "Отрисовка не показала запись, которую состояние показывает.");
    page.close();
  });

  test("пометка «почерка нет» снимается вместе с причиной", async () => {
    const { read } = await load("state.js");
    const { render } = await load("render.js");
    const page = bare();
    const root = page.need("main");
    let state = read(root);
    render(root, state);
    assert.ok(page.text('li[data-id="4"]').includes("почерка нет"), "s03e02: запись без почерка помечена.");

    state = {
      ...state,
      entries: state.entries.map((item) => (item.id === "4" ? { ...item, hand: "Дарнелл" } : item)),
    };
    render(root, state);
    const node = page.need('li[data-id="4"]');
    assert.equal(node.dataset.unsigned, undefined, "Почерк появился, а пометка осталась.");
    assert.ok(
      !page.text(node).includes("почерка нет"),
      "Видимая пометка осталась после того, как причина ушла. Отрисовка приводит страницу к " +
        "нынешнему состоянию — в том числе убирает то, что перестало быть верным.",
    );
    page.close();
  });

  test("отрисовать дважды — то же, что один раз", async () => {
    const { read } = await load("state.js");
    const { render } = await load("render.js");
    const page = bare();
    const root = page.need("main");
    const state = read(root);
    render(root, state);
    const once = page.snapshot("main");
    render(root, state);
    assert.equal(page.snapshot("main"), once, "Вторая отрисовка изменила страницу.");
    page.close();
  });

  test("отрисовка не пересоздаёт записи", async () => {
    const { read, withFilter } = await load("state.js");
    const { render } = await load("render.js");
    const page = bare();
    const root = page.need("main");
    let state = read(root);
    render(root, state);
    for (const [index, node] of page.$$("#entries li").entries()) node.crimsonMark = index;

    state = withFilter(state, "held");
    render(root, state);
    state = withFilter(state, "");
    render(root, state);

    for (const [index, node] of page.$$("#entries li").entries()) {
      assert.equal(node.crimsonMark, index, "s03e02: записи пересозданы.");
    }
    page.close();
  });

  test("новая запись из состояния появляется на странице", async () => {
    const { read, withEntry } = await load("state.js");
    const { render } = await load("render.js");
    const page = bare();
    const root = page.need("main");
    let state = read(root);
    render(root, state);
    state = withEntry(state, { id: 77, state: "failed", hand: "Кейл", text: "72-я улица: обрыв" });
    render(root, state);

    const node = page.$('li[data-id="77"]');
    assert.ok(node, "Записи, добавленной в состояние, на странице нет.");
    assert.equal(node.dataset.state, "failed", "Состояние записи берётся из состояния, а не придумывается.");
    assert.ok(page.text(node).includes("обрыв"), "И текст тоже.");
    assert.match(page.text("#tally [data-tally='failed']"), /\b2\b/, "Сводка обязана посчитать новую запись.");
    page.close();
  });
});

describe("точка входа только связывает", () => {
  test("нажатие меняет состояние, а страницу меняет отрисовка", async () => {
    const page = await live();
    const node = page.need('li[data-id="2"]');
    await page.click(node.querySelector("p"));
    assert.equal(node.dataset.chalk, "yes");
    await page.click(node.querySelector("p"));
    assert.equal(node.dataset.chalk, undefined);
    page.close();
  });

  test("отбор идёт через состояние", async () => {
    const page = await live();
    await page.fill("#state", "held");
    assert.deepEqual(ids(page), ["3"]);
    await page.fill("#state", "");
    assert.equal(ids(page).length, 6);
    page.close();
  });

  test("отбор живёт в состоянии, а не в дереве", async () => {
    const page = await live();
    await page.fill("#state", "held");
    assert.deepEqual(ids(page), ["3"], "Отбор применён.");

    // Любое следующее изменение перерисует страницу целиком. Если отбор был
    // только в дереве, отрисовка о нём не знает — и вернёт все записи.
    const node = page.need('li[data-id="3"]');
    await page.click(node.querySelector("p"));
    assert.deepEqual(
      ids(page),
      ["3"],
      "После следующей отрисовки отбор пропал. Значит он жил в дереве: отрисовка о нём не " +
        "знала, потому что в состоянии его не было.",
    );
    assert.equal(node.dataset.chalk, "yes", "И мел при этом поставился.");
    page.close();
  });

  test("решение принимается по состоянию, а не по дереву", async () => {
    const page = await live();
    const node = page.need('li[data-id="1"]');
    // Дерево испорчено мимо состояния: мел «поставлен» руками.
    node.dataset.chalk = "yes";
    await page.click(node.querySelector("p"));
    assert.equal(
      node.dataset.chalk,
      "yes",
      "Обработчик посмотрел на атрибут в дереве и решил, что мел уже стоит. Состояние знало " +
        "обратное — и в споре дерева с состоянием прав всегда второе: дерево ему отражение, " +
        "а не источник.",
    );
    page.close();
  });

  test("прежние редакции в силе", async () => {
    const page = await live();
    assert.equal(page.document.documentElement.dataset.script, "on", "s03e01.");
    assert.ok(page.$$("[data-without-script]").every((node) => node.hidden), "s03e01.");
    assert.ok(page.$("#tally"), "s03e02.");
    assert.equal(page.$$("#entries li[data-unsigned]").length, 1, "s03e02.");
    assert.equal(page.need("form.compose").noValidate, true, "s03e04.");
    assert.ok(page.$("form.compose [role='status']"), "s03e04.");
    const { prevented } = await page.submit("form.sift");
    assert.ok(prevented, "s03e03: отправка отбора отменяется.");
    assert.deepEqual(page.errors, []);
    page.close();
  });

  test("второй запуск ничего не удваивает", async () => {
    const page = await live();
    const once = page.snapshot();
    await page.run(moduleFile);
    assert.equal(page.snapshot(), once, "Второй запуск изменил страницу.");
    const node = page.need('li[data-id="3"]');
    await page.click(node.querySelector("p"));
    assert.equal(node.dataset.chalk, "yes", "Слушатели повесились второй раз.");
    page.close();
  });
});
