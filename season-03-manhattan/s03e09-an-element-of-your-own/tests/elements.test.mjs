// CRIMSON RAILS — s03e09, проверка.
//
// Серия помечена NEEDS_BROWSER, и причин теперь три. Подъём своего тега
// (upgrade) jsdom изображает, но проверять его надо там, где разметку разбирал
// настоящий разборщик. Фокус в jsdom условный: узел, который сняли или
// спрятали, там не отнимает фокуса по-настоящему. И главный вопрос сезона —
// что видно без скрипта — можно задать только браузеру, у которого JavaScript
// выключен по-настоящему.
//
//   npx playwright install chromium
//   make test-visual SEASON=03

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { openSite } from "../../support/visual.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const own = join(here, "..", "artifacts");
const mine = existsSync(join(own, "telegraph.js")) && !process.env.FORCE_SOLUTION;
const directory = mine ? own : join(here, "..", "solution");
console.log(`Источник: ${mine ? "artifacts" : "solution"}/`);
if (!mine) console.log("(модуля нет — проверяю эталон)");

const ago = (ms) => new Date(Date.now() - ms).toISOString();

// Смена, как её отдаёт контора. Возраст записей важен: он и есть то, что
// показывает свой элемент.
const SHIFT = () => [
  { id: 1, state: "sent", hand: "Дарнелл", text: "14-я улица: путь свободен.", at: ago(12 * 60_000) },
  { id: 2, state: "sent", hand: "Кейл", text: "23-я улица: стрелка переведена.", at: ago(56_000) },
  { id: 3, state: "held", hand: "Финнерти", text: "42-я улица: задержка две минуты.", at: ago(3 * 3_600_000), source: "https://example.test/post/42" },
  { id: 4, state: "sent", hand: null, text: "59-я улица: отметка сверки за смену." },
  { id: 8, state: "sent", hand: "Дарнелл", text: "129-я улица: линия восстановлена.", at: ago(90 * 60_000), source: "https://example.test/post/129" },
];

// Браузер и контора закрываются, что бы ни случилось внутри: оставшийся
// открытым браузер не даёт прогону завершиться, и красная проверка
// превращается в зависший прогон.
const withSite = async (options, work) => {
  const view = await openSite(directory, { entries: SHIFT(), ...options });
  try {
    if (options.script !== false) await view.wait(250);
    return await work(view);
  } finally {
    await view.close();
  }
};

const at = (id) => `#entries li[data-id="${id}"] [data-part="at"]`;

// ─── Свой элемент ─────────────────────────────────────────────────────────

describe("свой элемент", () => {
  test("тег из разметки поднимается сам", async () => {
    await withSite({}, async (view) => {
      assert.equal(
        await view.upgraded(at(1)),
        true,
        "Тег остался обычным элементом. Свой элемент определяют через " +
          "customElements.define, и имя обязано содержать дефис.",
      );
      assert.match(
        await view.text(at(1)),
        /12 минут назад/,
        "Элемент, стоявший в разметке до модуля, поведение получил задним числом — " +
          "в этом и смысл: строку никто не «подключал».",
      );
    });
  });

  test("строка, пришедшая из конторы, живая без всякого подключения", async () => {
    await withSite({}, async (view) => {
      assert.equal(await view.count(at(8)), 1, "Записи 8 в разметке не было — она из конторы.");
      assert.equal(await view.upgraded(at(8)), true);
      assert.match(await view.text(at(8)), /1 час назад/);
    });
  });

  test("точное время остаётся рядом", async () => {
    await withSite({}, async (view) => {
      const title = await view.attr(at(3), "title");
      assert.ok(title, "Относительное время удобно и неточно. Точное должно остаться — хотя бы в title.");
      assert.match(await view.text(at(3)), /3 часа назад/);
    });
  });

  test("без времени приёма элемент разметку не трогает", async () => {
    await withSite({}, async (view) => {
      assert.equal(
        await view.attr(at(4), "datetime"),
        null,
        "У записи 4 времени приёма нет: контора его не прислала.",
      );
      assert.equal(
        await view.text(at(4)),
        "—",
        "Считать нечего — значит остаётся то, что написано в разметке. Элемент улучшает, " +
          "а не замещает.",
      );
    });
  });

  test("смена времени приёма меняет то, что видно", async () => {
    await withSite({}, async (view) => {
      await view.evaluate(([selector, moment]) => {
        document.querySelector(selector).setAttribute("datetime", moment);
      }, [at(1), new Date(Date.now() - 2 * 86_400_000).toISOString()]);
      await view.wait(50);
      assert.match(
        await view.text(at(1)),
        /2 дня назад/,
        "Атрибут — вход элемента. Про смену наблюдаемых атрибутов браузер сообщает сам; " +
          "чего нет в observedAttributes, о том и не сообщат.",
      );
    });
  });

  test("снятый со страницы элемент не работает, возвращённый — снова работает", async () => {
    await withSite({}, async (view) => {
      // Записи 2 пятьдесят шесть секунд: это самый частый шаг обновления,
      // и за семь секунд молчания видно, погас ли таймер на самом деле.
      const result = await view.evaluate(async ([selector, moment]) => {
        const node = document.querySelector(selector);
        const home = node.parentElement;
        const before = node.textContent;
        node.remove();
        node.setAttribute("datetime", moment);
        await new Promise((resolve) => setTimeout(resolve, 100));
        const asked = node.textContent;
        await new Promise((resolve) => setTimeout(resolve, 7000));
        const waited = node.textContent;
        home.append(node);
        await new Promise((resolve) => setTimeout(resolve, 100));
        return { before, asked, waited, back: node.textContent };
      }, [at(2), new Date(Date.now() - 2 * 86_400_000).toISOString()]);

      assert.equal(
        result.asked,
        result.before,
        "Снятый элемент обновился по смене атрибута. Он ничей: показывать ему некому.",
      );
      assert.equal(
        result.waited,
        result.before,
        "Снятый элемент обновился сам, по своему таймеру. Сигнал, который сняли с мачты и не " +
          "отключили, — самая дорогая вещь на дороге: он ничего не показывает и всё равно работает.",
      );
      assert.match(
        result.back,
        /2 дня назад/,
        "Поставили обратно — элемент снова работает. Жизненный цикл на то и цикл.",
      );
    });
  });

  test("время идёт само", async () => {
    await withSite({}, async (view) => {
      assert.equal(
        await view.text(at(2)),
        "только что",
        "Записи 2 пятьдесят шесть секунд: это ещё «только что».",
      );
      await view.wait(7_000);
      assert.match(
        await view.text(at(2)),
        /минут/,
        "Прошла минута, а на странице ничего не изменилось: элемент не обновляет себя сам. " +
          "Запись минутной давности меняется каждые несколько секунд — в отличие от трёхдневной, " +
          "которой обновляться уже незачем.",
      );
    });
  });
});

// ─── Живая область ────────────────────────────────────────────────────────

describe("живая область смены", () => {
  test("объявлена живой до первого сообщения", async () => {
    await withSite({ script: false }, async (view) => {
      assert.equal(await view.count("shift-notice"), 1, "Область лежит в разметке, а не создаётся модулем.");
      const role = await view.attr("shift-notice", "role");
      const live = await view.attr("shift-notice", "aria-live");
      assert.ok(
        role === "status" || live === "polite",
        "Область, объявленную живой вместе с текстом, читающая машина не успевает заметить. " +
          "Объявить надо до.",
      );
      assert.equal((await view.text("shift-notice")) || "", "", "И пуста, пока говорить нечего.");
    });
  });

  test("сообщение доходит до области", async () => {
    await withSite({}, async (view) => {
      assert.match(
        (await view.text("shift-notice")) ?? "",
        /контор/i,
        "Журнал пришёл из конторы — читателю об этом сказано.",
      );
    });
  });

  test("область не забирает фокус", async () => {
    await withSite({}, async (view) => {
      await view.focusOn("#text");
      await view.evaluate(() => document.querySelector("shift-notice").say("смена продолжается"));
      await view.wait(50);
      const where = await view.focused();
      assert.equal(
        where?.id,
        "text",
        "Сообщить — не значит увести. Живая область объявляет; идти к ней или нет, решает читатель.",
      );
    });
  });
});

// ─── Фокус ────────────────────────────────────────────────────────────────

describe("фокус читателя", () => {
  test("после принятой записи возвращается в поле текста", async () => {
    await withSite({}, async (view) => {
      await view.select("#from", "23");
      await view.fill("#text", "путь свободен, состав прошёл");
      const moved = await view.submitAndSettle("form.compose button[type=submit]");
      assert.equal(moved, false, "Со скриптом отправка формы перехвачена: перехода нет.");
      const where = await view.focused();
      assert.equal(
        where?.id,
        "text",
        "Смена продолжается: следующую запись передают, не трогая мышь. Фокус, оставшийся " +
          "на кнопке очищенной формы, — потерянное место.",
      );
    });
  });

  test("спрятанная строка не уносит фокус в никуда", async () => {
    await withSite({}, async (view) => {
      await view.focusOn(`#entries li[data-id="8"] [data-part="source"]`);
      assert.equal((await view.focused())?.tag, "a", "Фокус стоит на ссылке внутри строки.");

      // Отбор меняет не читатель: он стоит в журнале и читает. Так бывает —
      // отбор приходит из адреса, из другой вкладки, из восстановленного вида.
      await view.evaluate(() => {
        const field = document.querySelector("#state");
        field.value = "held";
        field.dispatchEvent(new Event("change", { bubbles: true }));
      });
      await view.wait(80);

      const where = await view.focused();
      assert.ok(
        where,
        "Строку спрятали вместе с фокусом, и он упал на <body>. Тот, кто читает страницу " +
          "голосом, оказался в начале документа и без объяснения.",
      );
      assert.equal(
        where.id,
        "entries",
        "Фокус обязан приземлиться осмысленно: журнал — ближайшее место к тому, что исчезло. " +
          "Для этого он и объявлен принимающим фокус (tabindex=\"-1\").",
      );
    });
  });
});

// ─── Без скрипта ──────────────────────────────────────────────────────────

describe("без скрипта журнал остаётся журналом", () => {
  test("время приёма видно точным", async () => {
    await withSite({ script: false }, async (view) => {
      assert.equal(await view.count("#entries li[data-id]"), 6, "Все шесть строк разметки на месте.");
      assert.equal(
        await view.text(at(1)),
        "6:13",
        "Свой тег без скрипта — обычный элемент, и браузер показывает его содержимое. " +
          "Запасное содержимое пишут в разметку, а не в модуль.",
      );
      assert.equal(await view.count("shift-notice"), 1);
    });
  });

  test("форма по-прежнему уходит и страница переходит", async () => {
    await withSite({ script: false }, async (view) => {
      await view.select("#from", "42");
      await view.fill("#text", "задержка две минуты, впереди состав");
      const moved = await view.submitAndSettle("form.compose button[type=submit]");
      assert.equal(moved, true, "Без скрипта форма отправляется браузером и страница переходит.");
      assert.equal(view.site.calls("POST", "/entries").length, 1, "Запись доехала до конторы.");
    });
  });
});

// ─── Прежние свойства ─────────────────────────────────────────────────────

describe("прежние свойства держатся", () => {
  test("чужой текст остаётся текстом и в настоящем браузере", async () => {
    await withSite(
      {
        entries: [
          { id: 1, state: "sent", hand: "Кейл", text: '<b>сверка</b> <img src=x onerror="document.title=1">', at: ago(60_000) },
        ],
      },
      async (view) => {
        assert.equal(await view.count("#entries b, #entries img"), 0, "Из текста записи ничего не завелось.");
        assert.match(await view.text(`#entries li[data-id="1"] [data-part="text"]`), /<b>сверка<\/b>/);
        assert.equal(await view.evaluate(() => document.title !== "1"), true);
      },
    );
  });

  test("мел ставится щелчком", async () => {
    await withSite({}, async (view) => {
      await view.click(`#entries li[data-id="1"] [data-part="text"]`);
      await view.wait(50);
      assert.equal(await view.attr(`#entries li[data-id="1"]`, "data-chalk"), "yes");
    });
  });
});
