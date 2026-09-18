// CRIMSON RAILS — s03e04, проверка.
//
// Серия помечена NEEDS_BROWSER, и на то одна причина: jsdom не умеет
// отправлять формы. «Работает ли журнал без скрипта» — главный вопрос сезона,
// и задать его можно только настоящему браузеру, у которого JavaScript
// выключен по-настоящему.
//
//   npx playwright install chromium
//   make test-visual SEASON=03

import { test, describe, before, after } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { openSite } from "../../support/visual.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const own = join(here, "..", "artifacts");
const mine = existsSync(join(own, "telegraph.js")) && !process.env.FORCE_SOLUTION;
const directory = mine ? own : join(here, "..", "solution");
console.log(`Источник: ${mine ? "artifacts" : "solution"}/`);
if (!mine) console.log("(модуля нет — проверяю эталон)");

const site = (script) => openSite(directory, { script });

// Открыть журнал, поработать с ним и закрыть — что бы ни случилось внутри.
// Браузер и сервер, оставшиеся открытыми после упавшей проверки, не дают
// прогону завершиться, и красная проверка превращается в зависший прогон.
const withSite = async (script, work) => {
  const view = await site(script);
  try {
    return await work(view);
  } finally {
    await view.close();
  }
};

const markup = () => readFileSync(join(directory, "telegraph.html"), "utf8");

describe("без скрипта журнал остаётся журналом", () => {
  test("пустую форму браузер не пускает сам", async () => {
    await withSite(false, async (view) => {
      const moved = await view.submitAndSettle("form.compose button[type=submit]");
      assert.equal(
        moved,
        false,
        "Пустая форма ушла на сервер. Значит с полей снят required — и единственная проверка, " +
          "которая работает без скрипта, отменена.",
      );
      assert.equal(view.site.entries().length, 0, "В контору ничего не уехало.");
    });
  });

  test("заполненная форма уходит и страница переходит", async () => {
    await withSite(false, async (view) => {
      await view.select("#from", "23");
      await view.fill("#text", "путь свободен, состав прошёл");
      const moved = await view.submitAndSettle("form.compose button[type=submit]");
      assert.ok(
        moved,
        "Форма не ушла. Без скрипта у неё один путь — на сервер; если она им не идёт, журнал " +
          "при погашенном свете становится бумагой без карандаша.",
      );
      assert.equal(view.site.entries().length, 1, "В конторе должна появиться запись.");
      assert.equal(view.site.entries()[0].text, "путь свободен, состав прошёл");
      assert.match(view.path(), /sent=1/, "Контора отвечает переходом обратно на журнал.");
    });
  });

  test("кнопка отбора без скрипта видна", async () => {
    await withSite(false, async (view) => {
      assert.ok(
        await view.tab.isVisible("[data-without-script]"),
        "s03e01: без скрипта отбирать записи больше нечем — кнопка обязана быть видна.",
      );
    });
  });
});

describe("со скриптом сообщает модуль", () => {
  let view;
  before(async () => {
    view = await site(true);
  });
  after(async () => {
    await view.close();
  });

  test("модуль объявил, что сообщает сам", async () => {
    assert.equal(
      await view.tab.getAttribute("form.compose", "novalidate"),
      "",
      'Модуль не выставил форме novalidate. Пока он не сказал «сообщаю я», браузер показывает ' +
        "своё всплывающее окно — и читатель получает два сообщения об одной ошибке.",
    );
    assert.ok(
      !/<form[^>]*\bnovalidate\b/i.test(markup()),
      "novalidate стоит прямо в разметке. Тогда без скрипта форма не проверяется вовсе: " +
        "браузеру сказали молчать, а сказать вместо него некому.",
    );
  });

  test("живая область создана заранее и пуста", async () => {
    const notice = await view.tab.$("form.compose [role='status'], form.compose [aria-live]");
    assert.ok(
      notice,
      "Сообщать об ошибке некуда. Область объявляется живой (role=\"status\" или aria-live) — " +
        "иначе появившийся текст останется невидимым для тех, кто слушает страницу.",
    );
    assert.equal(
      (await notice.textContent()).trim(),
      "",
      "Область создана с текстом внутри. Голосовой браузер объявляет то, что появилось в уже " +
        "существующей области; узел, вставленный вместе с текстом, он молча пропустит.",
    );
    assert.equal(await notice.isVisible(), false, "Пока ошибок нет, области не место на виду.");
  });

  test("пустая форма не уходит и объясняет почему", async () => {
    const moved = await view.submitAndSettle("form.compose button[type=submit]");
    assert.equal(moved, false, "Модуль отменил проверку браузера и пустил пустую форму на сервер.");
    const notice = await view.tab.$("form.compose [role='status'], form.compose [aria-live]");
    assert.ok((await notice.textContent()).trim().length > 5, "Сообщение пустое: отменили и не объяснили.");
    assert.ok(await notice.isVisible(), "Сообщение невидимо.");
    assert.equal(view.site.calls("POST", "/entries").length, 0, "В контору ничего не уехало.");
  });

  test("фокус встаёт в первое неверное поле", async () => {
    const focused = await view.focused();
    assert.ok(
      focused,
      "После отказа фокус остался на кнопке. Читателю с клавиатуры придётся искать неверное " +
        "поле самому, а читателю с экранным диктором — искать вслепую.",
    );
    assert.equal(
      focused.name,
      "from",
      `Фокус встал на «${focused.name}». Первое неверное поле в форме — пост отправления.`,
    );
  });

  test("своё правило: текст короче пяти знаков", async () => {
    await view.select("#from", "42");
    await view.fill("#text", "  ок ");
    const moved = await view.submitAndSettle("form.compose button[type=submit]");
    assert.equal(moved, false, "Текст из двух знаков уехал в контору.");
    const notice = await view.text("form.compose [role='status'], form.compose [aria-live]");
    assert.match(
      notice,
      /пят|5/i,
      `Сообщение «${notice}» не объясняет, что не так. Своё правило браузер не знает — ` +
        "объяснять его придётся своими словами.",
    );
  });

  test("введённое не пропало", async () => {
    assert.equal(
      await view.tab.inputValue("#from"),
      "42",
      "После отказа форма очистилась. Читатель вводил это руками; заставлять вводить заново — " +
        "наказание за ошибку, которую он ещё не понял.",
    );
  });

  test("поправил — сообщение ушло", async () => {
    await view.fill("#text", "линия восстановлена");
    const notice = await view.tab.$("form.compose [role='status'], form.compose [aria-live]");
    assert.equal(
      await notice.isVisible(),
      false,
      "Сообщение осталось после того, как ошибку исправили. Висящее сообщение об ошибке, " +
        "которой уже нет, хуже отсутствия сообщения.",
    );
  });

  test("правильная форма уходит на сервер", async () => {
    const moved = await view.submitAndSettle("form.compose button[type=submit]");
    assert.ok(
      moved,
      "Модуль отменил отправку правильной формы. Заменить её пока нечем — значит и отменять " +
        "нечего: проверка на месте не отменяет отправку, а предупреждает о ней.",
    );
    assert.equal(view.site.entries().length, 1, "Запись должна дойти до конторы.");
    assert.equal(view.site.entries()[0].from, "42");
  });
});

describe("прежние редакции живы в браузере", () => {
  test("отбор, мел и сокрытие работают", async () => {
    await withSite(true, async (view) => {
      assert.equal(
        await view.tab.isVisible("[data-without-script]"),
        false,
        "s03e01: со скриптом кнопка отбора не нужна и должна быть спрятана.",
      );
      assert.ok(await view.tab.isVisible("#tally"), "s03e02: сводка собрана.");

      await view.select("#state", "held");
      assert.equal(await view.tab.isVisible('#entries li[data-id="1"]'), false, "s03e03: отбор прячет чужие записи.");
      assert.ok(await view.tab.isVisible('#entries li[data-id="3"]'), "s03e03: своя запись остаётся видна.");

      await view.select("#state", "");
      await view.click('#entries li[data-id="2"] p');
      assert.equal(
        await view.tab.getAttribute('#entries li[data-id="2"]', "data-chalk"),
        "yes",
        "s03e03: нажатие по записи ставит мел.",
      );
      assert.deepEqual(view.problems, [], "Страница получила ошибку.");
    });
  });

  test("отбор не уводит со страницы", async () => {
    await withSite(true, async (view) => {
      await view.select("#state", "sent");
    // Кнопка отбора со скриптом спрятана — но форму всё ещё можно отправить
    // Enter'ом в поле. Отправка обязана быть отменена (s03e03).
      const moved = await view.submitByCode("form.sift");
      assert.equal(
        moved,
        false,
        "s03e03: форма отбора ушла на сервер. Отбор уже отработал на месте — отправку надо " +
          "отменить, иначе Enter в списке перезагрузит страницу.",
      );
      assert.equal(await view.tab.isVisible('#entries li[data-id="3"]'), false, "И отбор при этом работает.");
    });
  });
});
