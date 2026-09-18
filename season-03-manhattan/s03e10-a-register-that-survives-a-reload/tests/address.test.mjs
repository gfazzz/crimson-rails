// CRIMSON RAILS — s03e10, проверка. Финал сезона.
//
// Половина проверок здесь — про адрес: ссылка открывает тот же вид, «назад»
// возвращает прошлый, перезагрузка ничего не теряет. Вторая половина —
// приёмка сезона: всё, что было построено с первой серии, обязано быть целым
// в последней.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { openDocument } from "../../support/dom.mjs";
import { startOffice } from "../../support/server.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const own = join(here, "..", "artifacts");
const mine = existsSync(join(own, "telegraph.js")) && !process.env.FORCE_SOLUTION;
const directory = mine ? own : join(here, "..", "solution");
const pick = (name) => join(directory, name);
console.log(`Источник: ${mine ? "artifacts" : "solution"}/`);
if (!mine) console.log("(модуля нет — проверяю эталон)");

const load = (name) => import(pathToFileURL(pick(name)).href);
const ago = (ms) => new Date(Date.now() - ms).toISOString();

const SHIFT = () => [
  { id: 1, state: "sent", hand: "Дарнелл", text: "14-я улица: путь свободен.", at: ago(12 * 60_000) },
  { id: 3, state: "held", hand: "Финнерти", text: "42-я улица: задержка две минуты.", at: ago(60_000) },
  { id: 5, state: "failed", hand: "Финнерти", text: "129-я улица: обрыв у эстакады.", at: ago(3 * 3_600_000) },
  { id: 6, state: "sent", hand: "Дарнелл", text: "14-я улица: линия восстановлена.", at: ago(4 * 60_000) },
];

const withOffice = async (work, options = {}) => {
  const office = await startOffice({ serve: directory, entries: SHIFT(), ...options });
  try {
    return await work(office);
  } finally {
    await office.close();
  }
};

// Журнал, открытый по заданному адресу и дождавшийся конторы. Второй вызов
// `open` — это перезагрузка: та же страница, тот же адрес, новая вкладка.
const withPage = async (work, { search = "", ...options } = {}) =>
  withOffice(async (office) => {
    const opened = [];
    const open = async (address = search) => {
      const page = openDocument(pick("telegraph.html"), {
        url: `${office.origin}/telegraph.html${address}`,
      });
      page.need("body").dataset.office = `${office.origin}/entries`;
      await page.run(pick("telegraph.js"));
      await page.tick(6);
      await new Promise((resolve) => setTimeout(resolve, 150));
      opened.push(page);
      return page;
    };
    try {
      return await work(await open(), office, open);
    } finally {
      for (const page of opened) page.close();
    }
  }, options);

const shown = (page) =>
  page.$$("#entries li[data-id]").filter((node) => !node.hidden).map((node) => node.dataset.id);
const where = (page) => page.window.location.search;
const settle = async (page) => {
  await page.tick(3);
  await new Promise((resolve) => setTimeout(resolve, 60));
};

// ─── Вид ──────────────────────────────────────────────────────────────────

describe("вид и его адрес", () => {
  test("вид знает, какие отборы бывают", async () => {
    const { view } = await load("address.js");
    assert.equal(view({ filter: "held" }).filter, "held");
    assert.equal(view({}).filter, "");
    assert.equal(
      view({ filter: "всё подряд" }).filter,
      "",
      "Неизвестный отбор — это не отбор. Список разрешённого здесь тот же, что у адресов " +
        "в восьмой редакции, и по той же причине.",
    );
  });

  test("адрес читают, а не разбирают руками", async () => {
    const { readAddress } = await load("address.js");
    assert.equal(readAddress("?state=held").filter, "held");
    assert.equal(readAddress("").filter, "");
    assert.equal(readAddress("?page=2").filter, "");
    assert.equal(readAddress("?state=held&page=2").filter, "held");
  });

  test("адрес — тоже чужой текст", async () => {
    const { readAddress } = await load("address.js");
    assert.equal(
      readAddress("?state=%3Cscript%3Ealert(1)%3C/script%3E").filter,
      "",
      "Ссылку присылают. Всё, что пришло из адреса, написано не нами — и проверяется так же, " +
        "как текст записи.",
    );
  });

  test("пустой отбор вопроса в адресе не оставляет", async () => {
    const { addressOf, view } = await load("address.js");
    const address = addressOf(view({ filter: "" }), "http://localhost/telegraph.html?state=held");
    assert.equal(
      address,
      "/telegraph.html",
      "«Все записи» — это та же страница. Лишний ?state= в ссылке означал бы, что вид выбран, " +
        "когда он не выбран.",
    );
  });

  test("чужие части адреса не теряются", async () => {
    const { addressOf, view } = await load("address.js");
    const address = addressOf(view({ filter: "failed" }), "http://localhost/telegraph.html?page=2#register");
    assert.match(address, /page=2/, "Адрес принадлежит не только нам: в нём бывает чужое.");
    assert.match(address, /state=failed/);
    assert.match(address, /#register$/);
  });
});

// ─── История ──────────────────────────────────────────────────────────────

describe("история", () => {
  test("смена вида оставляет след", async () => {
    await withPage(async (page) => {
      const before = page.window.history.length;
      page.fill("#state", "held");
      await settle(page);
      assert.equal(where(page), "?state=held");
      assert.ok(
        page.window.history.length > before,
        "Новый вид — новый след. Иначе «назад» уведёт читателя со страницы вместо прошлого вида.",
      );
    });
  });

  test("тот же вид следа не оставляет", async () => {
    await withPage(async (page) => {
      page.fill("#state", "held");
      await settle(page);
      const before = page.window.history.length;
      page.fill("#state", "held");
      await settle(page);
      assert.equal(
        page.window.history.length,
        before,
        "Одно и то же нажатие копит историю из одинаковых видов: «назад» формально работает, " +
          "а для читателя нет.",
      );
    });
  });

  test("«назад» возвращает прошлый вид", async () => {
    await withPage(async (page) => {
      page.fill("#state", "held");
      await settle(page);
      page.fill("#state", "failed");
      await settle(page);
      assert.deepEqual(shown(page), ["5"]);

      page.window.history.back();
      await new Promise((resolve) => setTimeout(resolve, 150));
      await settle(page);

      assert.equal(where(page), "?state=held");
      assert.deepEqual(shown(page), ["3"], "Вид вернулся вместе с адресом.");
      assert.equal(
        page.need("#state").value,
        "held",
        "И управление приведено к виду: иначе в поле одно, на странице другое.",
      );
    });
  });

  test("«назад» в историю не пишет", async () => {
    await withPage(async (page) => {
      page.fill("#state", "held");
      await settle(page);
      page.fill("#state", "failed");
      await settle(page);
      const before = page.window.history.length;

      page.window.history.back();
      await new Promise((resolve) => setTimeout(resolve, 150));
      await settle(page);

      assert.equal(
        page.window.history.length,
        before,
        "Запись в ответ на чтение — петля: читатель нажимает «назад» и остаётся на месте.",
      );
    });
  });

  test("вид берут из адреса, а не из записи в истории", async () => {
    await withPage(async (page) => {
      page.fill("#state", "held");
      await settle(page);
      // Так выглядит запись, сделанная не нами: чужой страницей, прошлой
      // версией модуля, самим браузером при восстановлении вкладки.
      page.window.history.replaceState(null, "", "?state=failed");
      page.window.dispatchEvent(new page.window.PopStateEvent("popstate", { state: null }));
      await settle(page);
      assert.deepEqual(
        shown(page),
        ["5"],
        "У первой записи в истории состояние null всегда. Адрес есть всегда — читать надо его.",
      );
    });
  });
});

// ─── Ссылка ───────────────────────────────────────────────────────────────

describe("ссылка на вид", () => {
  test("открывает тот же вид", async () => {
    await withPage(
      async (page) => {
        assert.deepEqual(shown(page), ["3"], "Пришли по ссылке — увидели то, на что ссылались.");
        assert.equal(page.need("#state").value, "held");
      },
      { search: "?state=held" },
    );
  });

  test("переживает перезагрузку", async () => {
    await withPage(async (page, office, open) => {
      page.fill("#state", "failed");
      await settle(page);
      const address = where(page);

      const again = await open(address);
      assert.deepEqual(
        shown(again),
        ["5"],
        "Перезагрузка — это открыть тот же адрес заново. Вид, которого нет в адресе, она теряет.",
      );
      assert.equal(again.need("#state").value, "failed");
    });
  });

  test("неизвестный отбор в ссылке не ломает журнал", async () => {
    await withPage(
      async (page) => {
        assert.deepEqual(shown(page).sort(), ["1", "3", "5", "6"], "Не отбор — значит все записи.");
        assert.deepEqual(page.errors, [], "И никаких ошибок: ссылку прислали, а не мы её писали.");
      },
      { search: "?state=%D0%B2%D1%81%D1%91" },
    );
  });

  test("«все записи» убирают вопрос", async () => {
    await withPage(async (page) => {
      page.fill("#state", "held");
      await settle(page);
      page.fill("#state", "");
      await settle(page);
      assert.equal(where(page), "", "Вернулись ко всему журналу — вернулись к адресу страницы.");
    });
  });

  test("мел в адрес не пишут", async () => {
    await withPage(async (page) => {
      const before = where(page);
      page.click('#entries li[data-id="1"] [data-part="text"]');
      await settle(page);
      assert.equal(page.need('#entries li[data-id="1"]').dataset.chalk, "yes");
      assert.equal(
        where(page),
        before,
        "Мел местный: он не про то, на что смотрят, а про то, что читатель себе отметил. " +
          "Ссылка с чужим мелом — бессмыслица.",
      );
    });
  });
});

// ─── Без скрипта ──────────────────────────────────────────────────────────

describe("без скрипта тот же адрес даёт тот же вид", () => {
  test("форма отбора ведёт на страницу, а не в контору", async () => {
    await withPage(async (page) => {
      const sift = page.need("form.sift");
      assert.equal(sift.method, "get", "Отбор — это вопрос, а вопрос задают методом GET.");
      assert.equal(
        new URL(sift.action).pathname,
        "/telegraph.html",
        "Без скрипта форма отбора обязана вести на саму страницу: читателю нужен журнал, " +
          "а не ответ конторы.",
      );
      assert.equal(page.need("#state").name, "state", "Имя поля — это имя параметра в адресе.");
    });
  });

  test("сервер отдаёт по тому же адресу тот же вид", async () => {
    await withOffice(async (office) => {
      const answer = await fetch(`${office.origin}/telegraph.html?state=held`);
      const html = await answer.text();
      const states = [...html.matchAll(/<li data-id="[^"]*" data-state="([^"]*)"/g)].map((m) => m[1]);
      assert.deepEqual(
        [...new Set(states)],
        ["held"],
        "Адрес, который пишет модуль, — тот же, что читает сервер. В этом весь смысл: одна " +
          "ссылка, два читателя.",
      );
      assert.match(html, /<option value="held" selected/, "И управление приведено к виду.");
    });
  });
});

// ─── Приёмка сезона ───────────────────────────────────────────────────────

describe("приёмка сезона", () => {
  test("журнал приходит из конторы и заменяет разметочный", async () => {
    await withPage(async (page) => {
      assert.deepEqual(
        page.$$("#entries li[data-id]").map((node) => node.dataset.id).sort(),
        ["1", "3", "5", "6"],
      );
    });
  });

  test("чужой текст остаётся текстом", async () => {
    await withPage(
      async (page) => {
        const text = page.need('#entries li[data-id="9"] [data-part="text"]');
        assert.equal(text.children.length, 0);
        assert.match(text.textContent, /<b>сверка<\/b>/);
      },
      { entries: [{ id: 9, state: "sent", hand: "Кейл", text: "<b>сверка</b> <img src=x>", at: ago(60_000) }] },
    );
  });

  test("свой элемент поднят и показывает время", async () => {
    await withPage(async (page) => {
      const at = page.need('#entries li[data-id="1"] [data-part="at"]');
      assert.notEqual(at.constructor.name, "HTMLElement", "Тег определён и поднят.");
      assert.match(at.textContent, /12 минут назад/);
    });
  });

  test("живая область объявлена живой и говорит", async () => {
    await withPage(async (page) => {
      const notice = page.need("shift-notice");
      assert.ok(notice.getAttribute("role") === "status" || notice.getAttribute("aria-live"));
      assert.match(notice.textContent, /контор/i);
    });
  });

  test("отрисовать дважды — то же, что один раз", async () => {
    await withPage(async (page) => {
      const before = page.snapshot("#entries");
      const { render } = await load("render.js");
      const { read } = await load("state.js");
      const root = page.need("main");
      render(root, read(root));
      assert.equal(page.snapshot("#entries"), before, "Отрисовка приводит дерево к состоянию.");
    });
  });

  test("запись уходит в контору одним запросом и без задвоения", async () => {
    await withPage(async (page, office) => {
      page.fill("#from", "42");
      page.fill("#text", "задержка две минуты, впереди состав");
      const { prevented } = await page.submit("form.compose");
      await page.tick(6);
      await new Promise((resolve) => setTimeout(resolve, 200));

      assert.equal(prevented, true, "Со скриптом отправка формы перехвачена.");
      assert.equal(office.calls("POST", "/entries").length, 1, "Один запрос.");
      assert.ok(
        office.calls("POST", "/entries")[0].headers["x-receipt"],
        "И с ключом приёма: повтор не заводит вторую запись.",
      );
    });
  });

  test("страница работает без единой ошибки", async () => {
    await withPage(async (page) => {
      assert.deepEqual(page.errors, []);
    });
  });
});
