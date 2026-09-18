// CRIMSON RAILS — s03e07, проверка.
//
// Запрос по проводу проверяется запросом по проводу: на свободном порту
// поднимается настоящий сервер на node:http, и модуль ходит к нему тем же
// fetch, что и в браузере.
//
// Подставного fetch здесь нет намеренно. Подставной fetch проверяет
// подставной fetch: он отвечает то, что ему велели, и все ошибки разбора
// ответа, кодов и заголовков остаются непроверенными.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";
import { openDocument } from "../../support/dom.mjs";
import { startOffice } from "../../support/server.mjs";

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

const SHIFT = [
  { id: 1, text: "14-я улица: путь свободен", state: "sent", hand: "Дарнелл" },
  { id: 2, text: "23-я улица: стрелка переведена", state: "held", hand: "Финнерти" },
  { id: 3, text: "42-я улица: задержка две минуты", state: "failed", hand: "Финнерти" },
];

// Контора и журнал — и закрыть всё, что бы ни случилось внутри.
const withOffice = async (work, options = {}) => {
  const office = await startOffice({ entries: SHIFT, ...options });
  try {
    return await work(office);
  } finally {
    await office.close();
  }
};

const withPage = async (work, options = {}) =>
  withOffice(async (office) => {
    const page = openDocument(htmlFile, { url: `${office.origin}/telegraph.html` });
    page.need("body").dataset.office = `${office.origin}/entries`;
    try {
      await page.run(moduleFile);
      await page.tick(4);
      await new Promise((resolve) => setTimeout(resolve, 120));
      return await work(page, office);
    } finally {
      page.close();
    }
  }, options);

describe("передача записи", () => {
  test("уходит методом POST и как JSON", async () => {
    await withOffice(async (office) => {
      const { send } = await load("office.js");
      await send({ from: "23", text: "путь свободен" }, { origin: office.origin });
      const calls = office.calls("POST", "/entries");
      assert.equal(calls.length, 1, "Запись передают одним запросом.");
      assert.match(
        calls[0].headers["content-type"] ?? "",
        /json/,
        "Тело — JSON, и сказать об этом надо заголовком: иначе контора разберёт его как форму.",
      );
      assert.deepEqual(JSON.parse(calls[0].body), { from: "23", text: "путь свободен" });
    });
  });

  test("контора возвращает заведённую запись с номером", async () => {
    await withOffice(async (office) => {
      const { send } = await load("office.js");
      const saved = await send({ from: "42", text: "обрыв у эстакады" }, { origin: office.origin });
      assert.ok(saved?.id, "Номер записи назначает контора — у неё их больше, чем на странице.");
      assert.equal(saved.text, "обрыв у эстакады");
    });
  });

  test("отказ по существу приходит с полем и объяснением", async () => {
    await withOffice(async (office) => {
      const { send, OfficeError } = await load("office.js");
      await assert.rejects(
        () => send({ from: "42", text: "" }, { origin: office.origin }),
        (error) => {
          assert.ok(error instanceof OfficeError, "Отказ конторы — своя ошибка, а не чужая.");
          assert.equal(error.status, 422, "422 — это «так нельзя», и его надо отличать от прочих.");
          assert.equal(error.field, "text", "Контора назвала поле; оно должно дойти до читателя.");
          assert.equal(error.retriable, false, "Повторять 422 бессмысленно: ответ не изменится.");
          return true;
        },
      );
    });
  });

  test("отказ по обстоятельствам помечен как повторяемый", async () => {
    await withOffice(
      async (office) => {
        const { send } = await load("office.js");
        await assert.rejects(
          () => send({ from: "14", text: "линия восстановлена" }, { origin: office.origin }),
          (error) => {
            assert.equal(error.status, 503);
            assert.equal(
              error.retriable,
              true,
              "Пятисотые — это «попробуйте позже». Отличать их от четырёхсотых обязательно: " +
                "первые повторяют, вторые нет.",
            );
            return true;
          },
        );
      },
      { failFirst: 10 },
    );
  });

  test("до конторы не достучаться — тоже отказ, а не падение", async () => {
    const { send, OfficeError } = await load("office.js");
    await assert.rejects(
      () => send({ from: "14", text: "проверка" }, { origin: "http://127.0.0.1:1" }),
      (error) => {
        assert.ok(error instanceof OfficeError, "Обрыв провода приходит как отказ обещания, а не как чужая ошибка.");
        assert.ok(error.cause, "Исходная причина обрыва должна сохраниться.");
        assert.equal(error.retriable, true, "Обрыв — повод попробовать ещё раз.");
        return true;
      },
    );
  });
});

describe("повтор и отмена", () => {
  test("повтор с тем же ключом не заводит вторую запись", async () => {
    await withOffice(async (office) => {
      const { send } = await load("office.js");
      const draft = { from: "59", text: "отметка сверки за смену" };
      const first = await send(draft, { origin: office.origin, receipt: "receipt-1" });
      const again = await send(draft, { origin: office.origin, receipt: "receipt-1" });
      assert.equal(
        office.entries().length,
        SHIFT.length + 1,
        "Повтор завёл вторую запись. Сеть обрывает ответ уже после того, как контора записала; " +
          "повтор без ключа приёма — это задвоение, которое никто не заметит.",
      );
      assert.equal(again.id, first.id, "Контора обязана вернуть ту же запись.");
    });
  });

  test("ключ приёма уезжает заголовком", async () => {
    await withOffice(async (office) => {
      const { send } = await load("office.js");
      await send({ from: "14", text: "движение по расписанию" }, { origin: office.origin, receipt: "receipt-7" });
      assert.equal(office.calls("POST", "/entries")[0].headers["x-receipt"], "receipt-7");
    });
  });

  test("повтор при отказе по обстоятельствам — с тем же ключом", async () => {
    await withOffice(
      async (office) => {
        const { send, withRetry } = await load("office.js");
        const saved = await withRetry(() =>
          send({ from: "14", text: "линия восстановлена" }, { origin: office.origin, receipt: "receipt-9" }),
        );
        assert.ok(saved?.id, "После двух отказов подряд третья попытка обязана пройти.");
        const keys = office.calls("POST", "/entries").map((call) => call.headers["x-receipt"]);
        assert.ok(keys.length >= 3, `Попыток было ${keys.length}: повтор не случился.`);
        assert.equal(new Set(keys).size, 1, "Каждая попытка ушла со своим ключом — это и есть задвоение.");
        assert.equal(office.entries().length, SHIFT.length + 1, "Записей завелось больше одной.");
      },
      { failFirst: 2 },
    );
  });

  test("повтор не трогает отказ по существу", async () => {
    await withOffice(async (office) => {
      const { send, withRetry } = await load("office.js");
      await assert.rejects(() =>
        withRetry(() => send({ from: "42", text: "" }, { origin: office.origin, receipt: "receipt-11" })),
      );
      assert.equal(
        office.calls("POST", "/entries").length,
        1,
        "422 повторили. Ответ не изменится, а контору побеспокоили трижды.",
      );
    });
  });

  test("отменённый запрос отклоняется отменой, а не ошибкой конторы", async () => {
    await withOffice(
      async (office) => {
        const { send } = await load("office.js");
        const stop = new AbortController();
        const asking = send({ from: "14", text: "долгая передача" }, { origin: office.origin, signal: stop.signal });
        stop.abort();
        await assert.rejects(
          () => asking,
          (error) => {
            assert.equal(
              error.name,
              "AbortError",
              "Отмену переодели в ошибку конторы. Отмена — это не сбой: жаловаться читателю не на что.",
            );
            return true;
          },
        );
      },
      { latency: 80 },
    );
  });
});

describe("журнал берут из конторы", () => {
  test("load приносит записи", async () => {
    await withOffice(async (office) => {
      const { load: fetchEntries } = await load("office.js");
      const entries = await fetchEntries({ origin: office.origin });
      assert.equal(entries.length, SHIFT.length);
      assert.equal(entries[0].id, 1);
    });
  });

  test("отбор делает контора, если её попросить", async () => {
    await withOffice(async (office) => {
      const { load: fetchEntries } = await load("office.js");
      const entries = await fetchEntries({ origin: office.origin, state: "held" });
      assert.deepEqual(entries.map((item) => item.id), [2]);
      assert.equal(office.calls("GET", "/entries").at(-1).query.get("state"), "held");
    });
  });

  test("страница показывает журнал конторы, а не разметки", async () => {
    await withPage(async (page, office) => {
      assert.deepEqual(
        page.$$("#entries li").map((node) => node.dataset.id),
        SHIFT.map((item) => String(item.id)),
        "На странице остались записи из разметки. Источник теперь контора: всё, чего в ней нет, " +
          "на странице оказалось неизвестно откуда — и уйти оно должно совсем, а не спрятаться.",
      );
      assert.ok(office.calls("GET", "/entries").length >= 1, "За журналом надо сходить.");
      assert.match(page.text("#shift-notice"), /\d/, "Читателю говорят, что журнал обновлён.");
    });
  });

  test("контора недоступна — работают по странице и говорят об этом", async () => {
    const page = openDocument(htmlFile, { url: "http://127.0.0.1:1/telegraph.html" });
    page.need("body").dataset.office = "http://127.0.0.1:1/entries";
    await page.run(moduleFile);
    await new Promise((resolve) => setTimeout(resolve, 400));
    assert.ok(
      page.$$("#entries li").length >= 5,
      "Контора недоступна — журнал опустел. Разметка остаётся тем, что видит читатель, у " +
        "которого провод не дотянулся.",
    );
    assert.match(
      page.text("#shift-notice"),
      /недоступ|не достуч|провод|контор/i,
      `«${page.text("#shift-notice")}» — читателю надо сказать, что показанное не из конторы.`,
    );
    assert.deepEqual(page.errors, [], "Недоступная контора не должна ронять страницу.");
    page.close();
  });
});

describe("форму наконец перехватили", () => {
  test("подача не уводит со страницы и запись появляется", async () => {
    await withPage(async (page, office) => {
      await page.fill("#from", "42");
      await page.fill("#text", "72-я улица: обрыв у эстакады");
      const { prevented } = await page.submit("form.compose");
      assert.ok(
        prevented,
        "Отправка не отменена. Теперь есть чем её заменить — значит пора: обещание из s03e04 " +
          "держалось ровно до этой серии.",
      );
      await new Promise((resolve) => setTimeout(resolve, 200));
      assert.equal(office.calls("POST", "/entries").length, 1, "Запись ушла в контору.");
      assert.equal(page.$$("#entries li").length, SHIFT.length + 1, "И появилась в журнале без перезагрузки.");
      assert.equal(page.need("#text").value, "", "После удачной передачи форму очищают.");
    });
  });

  test("неверную форму по проводу не отправляют", async () => {
    await withPage(async (page, office) => {
      const { prevented } = await page.submit("form.compose");
      assert.ok(prevented === false || office.calls("POST", "/entries").length === 0);
      assert.equal(
        office.calls("POST", "/entries").length,
        0,
        "Пустая форма ушла в контору. Разбор на месте из s03e04 существует ровно для этого.",
      );
    });
  });

  test("отказ конторы не стирает введённое", async () => {
    await withPage(
      async (page, office) => {
        await page.fill("#from", "59");
        await page.fill("#text", "отметка сверки за смену");
        await page.submit("form.compose");
        await new Promise((resolve) => setTimeout(resolve, 600));
        assert.equal(
          page.need("#text").value,
          "отметка сверки за смену",
          "После отказа конторы форма очистилась. Читатель вводил это руками, а запись не ушла.",
        );
        assert.match(page.text("#shift-notice"), /не удалось|отказ|контор/i, "И сказать об отказе надо словами.");
        assert.deepEqual(page.errors, []);
      },
      { failFirst: 99 },
    );
  });

  test("два нажатия подряд дают одну запись", async () => {
    await withPage(
      async (page, office) => {
        await page.fill("#from", "14");
        await page.fill("#text", "движение по расписанию");
        page.need("form.compose").dispatchEvent(new page.window.Event("submit", { bubbles: true, cancelable: true }));
        page.need("form.compose").dispatchEvent(new page.window.Event("submit", { bubbles: true, cancelable: true }));
        await new Promise((resolve) => setTimeout(resolve, 400));
        assert.equal(
          office.entries().length,
          SHIFT.length + 1,
          "Двойное нажатие завело две записи. Новая отправка обязана оборвать незаконченную " +
            "предыдущую — для этого и существует AbortController.",
        );
        assert.deepEqual(page.errors, []);
      },
      { latency: 60 },
    );
  });

  test("повтор со страницы не заводит вторую запись", async () => {
    await withPage(
      async (page, office) => {
        await page.fill("#from", "14");
        await page.fill("#text", "линия восстановлена");
        await page.submit("form.compose");
        await new Promise((resolve) => setTimeout(resolve, 900));
        const keys = office.calls("POST", "/entries").map((call) => call.headers["x-receipt"]);
        assert.ok(keys.length >= 2, `Попыток было ${keys.length}: повтор при отказе конторы не случился.`);
        assert.equal(
          new Set(keys).size,
          1,
          "Каждая попытка ушла со своим ключом приёма. Ключ один на попытку и все её повторы — " +
            "иначе повтор заводит вторую запись именно тогда, когда связь и без того плохая.",
        );
        assert.equal(office.entries().length, SHIFT.length + 1, "Записей завелось больше одной.");
      },
      { failFirst: 2 },
    );
  });

  test("мел переживает журнал конторы", async () => {
    const { register, entry, withChalk, withEntries } = await load("state.js");
    let state = register({ entries: [entry({ id: 1 }), entry({ id: 2 })] });
    state = withChalk(state, 2);
    const next = withEntries(state, [
      { id: 2, state: "sent", text: "из конторы" },
      { id: 3, state: "held", text: "тоже из конторы" },
    ]);
    assert.equal(
      next.entries.find((item) => item.id === "2")?.chalk,
      true,
      "Мел стёрся журналом из конторы. Он местный: контора о нём не знает и знать не должна, " +
        "а диспетчер ставил его руками.",
    );
    assert.equal(next.entries.find((item) => item.id === "3")?.chalk, false);
    assert.equal(next.entries.length, 2, "Журнал конторы заменяет прежний целиком.");
  });

  test("прежние редакции в силе", async () => {
    await withPage(async (page) => {
      assert.equal(page.document.documentElement.dataset.script, "on", "s03e01.");
      assert.ok(page.$("#tally"), "s03e02.");
      assert.equal(page.need("form.compose").noValidate, true, "s03e04.");
      const node = page.need('#entries li[data-id="2"]');
      await page.click(node.querySelector("p"));
      assert.equal(node.dataset.chalk, "yes", "s03e03: мел.");
      await page.fill("#state", "held");
      assert.deepEqual(
        page.$$("#entries li").filter((item) => !item.hidden).map((item) => item.dataset.id),
        ["2"],
        "s03e05: отбор по состоянию.",
      );
      assert.equal(node.dataset.chalk, "yes", "s03e07: мел местный — он переживает журнал из конторы.");
    });
  });
});
