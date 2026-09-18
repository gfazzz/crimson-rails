// CRIMSON RAILS — s03e01, проверка.
//
// Здесь проверяется одно: журнал работает без скрипта, а модуль его улучшает.
// Половина проверок смотрит на страницу до импорта модуля — это и есть то,
// что достанется читателю, у которого скрипт не доехал.
//
// Ни одна проверка не читает твой код как текст. Модуль импортируется и
// работает; спрашивают у дерева, что с ним стало.

import { test, describe, before, after } from "node:test";
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
const source = htmlFile.includes("artifacts") ? "artifacts" : "solution";
console.log(`Источник: ${source}/ (telegraph.html + telegraph.js)`);
if (!existsSync(join(here, "..", "artifacts", "telegraph.js"))) console.log("(модуля нет — проверяю эталон)");

// Страница без единого модуля: ровно то, что видит читатель, у которого
// скрипт не доехал.
const bare = () => openDocument(htmlFile);

describe("журнал работает без скрипта", () => {
  let page;
  before(() => {
    page = bare();
  });
  after(() => page.close());

  test("у каждой формы объявлено, куда и чем она отправляется", () => {
    const forms = page.$$("form");
    assert.ok(forms.length >= 2, "На странице две формы: подать запись и отобрать записи.");
    for (const form of forms) {
      const action = form.getAttribute("action");
      const method = (form.getAttribute("method") ?? "get").toLowerCase();
      assert.ok(
        action,
        "У формы нет action. Без скрипта она отправится на текущий адрес — то есть перезагрузит " +
          "страницу и потеряет введённое.",
      );
      assert.ok(["get", "post"].includes(method), `method="${method}" браузер не знает.`);
    }
  });

  test("подача записи отправляется методом, который что-то меняет", () => {
    const compose = page.need("form.compose", "форма подачи записи");
    assert.equal(
      (compose.getAttribute("method") ?? "get").toLowerCase(),
      "post",
      "Подача записи меняет журнал. get для этого не годится: такой запрос повторяют " +
        "перезагрузкой, и запись задвоится.",
    );
  });

  test("у каждого поля есть имя и подпись", () => {
    const fields = page.$$("input:not([type=submit]), select, textarea");
    assert.ok(fields.length >= 3, "В форме подачи два поля, в фильтре одно.");
    for (const field of fields) {
      assert.ok(
        field.getAttribute("name"),
        `У поля #${field.id || field.tagName} нет name — на сервер оно не уедет (s02e03).`,
      );
      const label = field.id ? page.$(`label[for="${field.id}"]`) : field.closest("label");
      assert.ok(label && page.text(label).length > 1, `У поля #${field.id} нет связанной подписи (s02e03).`);
    }
  });

  test("кнопка отправки — кнопка", () => {
    for (const form of page.$$("form")) {
      const button = form.querySelector("button[type=submit], input[type=submit], button:not([type])");
      assert.ok(
        button,
        "В форме нет кнопки отправки. Нажать Enter в поле — не замена: так форму отправляют " +
          "не все и не везде.",
      );
    }
  });

  test("ссылки ведут куда-то", () => {
    const links = page.$$("a");
    assert.ok(links.length >= 1);
    for (const link of links) {
      const href = link.getAttribute("href");
      assert.ok(href && href !== "#" && href !== "", "Ссылка без адреса — это кнопка, притворяющаяся ссылкой.");
      assert.ok(!href.startsWith("javascript:"), "javascript: в адресе не работает без скрипта и не работает при строгой политике.");
      if (href.startsWith("#")) {
        assert.ok(page.document.getElementById(href.slice(1)), `Ссылка на ${href} ведёт в пустоту.`);
      }
    }
  });

  test("в разметке нет обработчиков", () => {
    const inline = [];
    for (const node of page.$$("*")) {
      for (const attribute of node.attributes) {
        if (attribute.name.startsWith("on")) inline.push(`<${node.tagName.toLowerCase()} ${attribute.name}>`);
      }
    }
    assert.deepEqual(
      inline,
      [],
      "Обработчик в атрибуте выполняется до того, как модуль загрузился, живёт вне модуля и " +
        "запрещается строгой политикой безопасности. Поведение объявляют в модуле.",
    );
    assert.equal(page.$$("script:not([src])").length, 0, "Встроенный скрипт — то же самое, только длиннее.");
  });

  test("записи журнала видны без скрипта", () => {
    const entries = page.$$(".register li, #entries li");
    assert.ok(entries.length >= 5, `Записей в журнале: ${entries.length}. Журнал за смену — это не пустой список.`);
    for (const entry of entries) {
      assert.ok(!entry.hasAttribute("hidden"), "Запись спрятана в разметке: без скрипта её никто не увидит.");
      assert.ok(entry.dataset.id, "У записи нет data-id — по чему её потом искать.");
      assert.ok(entry.dataset.state, "У записи нет data-state — состояние должно приходить из данных.");
      assert.ok(page.text(entry).length > 10, "Запись пуста.");
    }
  });
});

describe("скрипт подключён как улучшение", () => {
  let page;
  before(() => {
    page = bare();
  });
  after(() => page.close());

  test("скрипт один, внешний и объявлен модулем", () => {
    const scripts = page.$$("script");
    assert.equal(scripts.length, 1, `Скриптов на странице ${scripts.length}. Модуль один — он же точка входа.`);
    const [script] = scripts;
    assert.ok(script.getAttribute("src"), "Скрипт объявлен внешним файлом, а не телом в разметке.");
    assert.equal(
      script.getAttribute("type"),
      "module",
      'Без type="module" файл выполняется как обычный скрипт: без import, без своей области видимости ' +
        "и не отложенно.",
    );
  });

  test("модуль не блокирует разметку", () => {
    const [script] = page.$$("script");
    assert.ok(
      !script.hasAttribute("async"),
      "async у модуля отменяет порядок и отложенность: он выполнится, как только скачается, — " +
        "возможно, до того, как появится дерево, которое он собирается улучшать.",
    );
    assert.ok(
      (script.getAttribute("src") ?? "").startsWith("./") || !/^[a-z]+:/i.test(script.getAttribute("src") ?? ""),
      "Путь к модулю — относительный: тот же файл открывается и браузером, и проверкой.",
    );
  });

  test("модуль импортируется и не падает", async () => {
    const live = bare();
    await live.run(moduleFile);
    assert.deepEqual(live.errors, [], "При загрузке модуля страница получила ошибку.");
    live.close();
  });
});

describe("модуль улучшает, а не подменяет", () => {
  test("до модуля страница не помечена, после — помечена", async () => {
    const page = bare();
    assert.equal(
      page.document.documentElement.dataset.script,
      undefined,
      "Пометка «скрипт доехал» стоит прямо в разметке. Тогда она врёт ровно в том случае, " +
        "ради которого её ставили.",
    );
    await page.run(moduleFile);
    assert.equal(
      page.document.documentElement.dataset.script,
      "on",
      "Модуль не отметил, что доехал. Эта пометка — единственный честный способ отличить " +
        "журнал со скриптом от журнала без него.",
    );
    page.close();
  });

  test("то, что нужно только без скрипта, прячется", async () => {
    const page = bare();
    const onlyWithout = page.$$("[data-without-script]");
    assert.ok(onlyWithout.length >= 1, "Кнопка «Показать» нужна только без скрипта — пометь её в разметке.");
    for (const node of onlyWithout) {
      assert.ok(!node.hidden, "Без скрипта эта кнопка обязана быть видна: отбирать записи больше нечем.");
    }
    await page.run(moduleFile);
    for (const node of page.$$("[data-without-script]")) {
      assert.ok(node.hidden, "Модуль не спрятал то, что при нём не нужно.");
    }
    page.close();
  });

  test("модуль ничего не удаляет", async () => {
    const page = bare();
    const before = page.$$("*").length;
    await page.run(moduleFile);
    assert.ok(
      page.$$("*").length >= before,
      `Узлов было ${before}, стало ${page.$$("*").length}. Убрать с глаз — значит спрятать: ` +
        "удалённый узел не вернёшь, если дальше что-то пойдёт не так.",
    );
    page.close();
  });

  test("модуль ничего не отнимает у разметки", async () => {
    const page = bare();
    const before = page.$$("form").map((form) => [form.getAttribute("action"), form.getAttribute("method")]);
    await page.run(moduleFile);
    const after = page.$$("form").map((form) => [form.getAttribute("action"), form.getAttribute("method")]);
    assert.deepEqual(
      after,
      before,
      "Модуль снял с формы action или method. Пока он работает, разницы не видно; в тот день, " +
        "когда он не загрузится, форма отправится в никуда.",
    );
    page.close();
  });

  test("повторная загрузка ничего не портит", async () => {
    const page = bare();
    await page.run(moduleFile);
    const once = page.snapshot();
    await page.run(moduleFile);
    assert.equal(
      page.snapshot(),
      once,
      "Второй запуск модуля изменил страницу. В браузере это бывает: страницу возвращают из " +
        "кеша, модуль исполняется снова. Улучшение должно ложиться на уже улучшенное без следа.",
    );
    page.close();
  });
});
