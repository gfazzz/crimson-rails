// CRIMSON RAILS — s03e08, проверка.
//
// Проверяется не то, что в модуле нет слова innerHTML, а то, что чужой текст
// не стал разметкой: в строку кладут запись с тегами и смотрят, сколько
// элементов от неё завелось. Ноль — значит текст остался текстом, чем бы он
// ни был написан.
//
// Образец строки ищется тем же способом: проверка дописывает в <template>
// свою метку и смотрит, доехала ли она до новой строки. Доехала — строку
// действительно собрали из образца.

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

// Запись, которой пробуют вписать разметку через текст.
const PAYLOAD = '<b>сверка</b> <img src=x onerror="alert(1)"> <script>alert(2)<\/script>';

const SHIFT = [
  { id: 1, state: "sent", hand: "Дарнелл", text: "14-я улица: путь свободен." },
  { id: 2, state: "sent", hand: "Кейл", text: PAYLOAD },
  { id: 3, state: "held", hand: "Финнерти", text: "42-я улица: задержка две минуты.", source: "javascript:alert(1)" },
  { id: 5, state: "failed", hand: "Финнерти", text: "129-я улица: обрыв у эстакады.", source: "https://example.test/post/129" },
  { id: 7, state: "sent", hand: PAYLOAD, text: "59-я улица: отметка сверки за смену." },
];

const withOffice = async (work, options = {}) => {
  const office = await startOffice({ entries: SHIFT, ...options });
  try {
    return await work(office);
  } finally {
    await office.close();
  }
};

// Страница, открытая при живой конторе и дождавшаяся журнала. `prepare`
// позволяет тронуть разметку до запуска модуля — например, дописать метку
// в образец.
const withPage = async (work, { prepare = null, ...options } = {}) =>
  withOffice(async (office) => {
    const page = openDocument(htmlFile, { url: `${office.origin}/telegraph.html` });
    page.need("body").dataset.office = `${office.origin}/entries`;
    try {
      if (prepare) prepare(page);
      await page.run(moduleFile);
      await page.tick(6);
      await new Promise((resolve) => setTimeout(resolve, 150));
      return await work(page, office);
    } finally {
      page.close();
    }
  }, options);

const row = (page, id) => page.need(`#entries li[data-id="${id}"]`, `строка журнала №${id}`);
const part = (page, id, name) =>
  page.need(`#entries li[data-id="${id}"] [data-part="${name}"]`, `в строке №${id} — «${name}»`);

// ─── Образец лежит в разметке ─────────────────────────────────────────────

describe("образец строки", () => {
  test("лежит в разметке, а не в коде", async () => {
    await withPage((page) => {
      const template = page.need("template", "образец строки журнала");
      const sample = template.content.querySelector("li");
      assert.ok(sample, "Образец — это строка журнала: <li> внутри <template>.");
      assert.ok(
        sample.querySelector("[data-part='text']"),
        "В образце должно быть место под текст записи, помеченное data-part.",
      );
      assert.ok(
        sample.querySelector("[data-part='hand']"),
        "И место под почерк: иначе заполнять будет нечего.",
      );
    });
  });

  test("сам по себе читателю не показывается", async () => {
    await withPage((page) => {
      const template = page.need("template");
      assert.equal(
        template.closest("#entries"),
        null,
        "Образец не лежит в журнале: иначе он станет ещё одной записью.",
      );
      const empty = page.$$("#entries li[data-id]").filter((node) => !node.dataset.id);
      assert.equal(empty.length, 0, "Строки без номера в журнале взяться неоткуда.");
    });
  });

  test("новая строка собрана из образца", async () => {
    await withPage(
      (page) => {
        const seven = row(page, 7);
        assert.ok(
          seven.querySelector("[data-mark='проверка']"),
          "Метка, дописанная в образец, до новой строки не доехала: строку собрали не из образца, " +
            "а руками. Образец затем и нужен, чтобы разметку строки правил тот, кто правит разметку.",
        );
      },
      {
        prepare: (page) => {
          const template = page.need("template");
          const mark = page.window.document.createElement("span");
          mark.dataset.mark = "проверка";
          template.content.querySelector("li").append(mark);
        },
      },
    );
  });
});

// ─── Чужой текст ──────────────────────────────────────────────────────────

describe("чужой текст", () => {
  test("доезжает до страницы дословно", async () => {
    await withPage((page) => {
      assert.equal(
        part(page, 2, "text").textContent,
        PAYLOAD,
        "Запись показывают такой, какой её передали. Выбрасывать из чужого текста куски — " +
          "не защита, а порча: пост написал то, что написал.",
      );
    });
  });

  test("не заводит на странице ни одного элемента", async () => {
    await withPage((page) => {
      const text = part(page, 2, "text");
      assert.equal(
        text.children.length,
        0,
        "Из текста записи завелись элементы. Значит, текст положили как разметку, и разметку " +
          "теперь пишет тот, кто прислал запись.",
      );
      assert.equal(page.$$("#entries b, #entries img, #entries script, #entries iframe").length, 0);
    });
  });

  test("чужое имя тоже остаётся текстом", async () => {
    await withPage((page) => {
      const hand = part(page, 7, "hand");
      assert.equal(hand.children.length, 0, "Почерк приходит оттуда же, откуда текст, и проверяется так же.");
      assert.match(hand.textContent, /сверка/, "Имя должно быть видно — как имя, а не как разметка.");
    });
  });

  test("сводка о чужом тексте тоже собрана текстом", async () => {
    await withPage((page) => {
      const tally = page.need("#tally", "сводка над журналом");
      assert.equal(
        tally.querySelectorAll("b, img, script").length,
        0,
        "Сводка берёт последний почерк из записей — значит, это тоже чужой текст.",
      );
    });
  });

  test("вторая отрисовка не удваивает строки", async () => {
    await withPage(async (page) => {
      const before = page.$$("#entries li[data-id]").length;
      const { render } = await load("render.js");
      const { read } = await load("state.js");
      const root = page.need("main");
      render(root, read(root));
      assert.equal(
        page.$$("#entries li[data-id]").length,
        before,
        "Отрисовка приводит дерево к состоянию, а не дописывает к прошлому разу.",
      );
      assert.equal(part(page, 2, "text").children.length, 0);
    });
  });
});

// ─── Чужой адрес ──────────────────────────────────────────────────────────

describe("чужой адрес", () => {
  test("обычный адрес проходит", async () => {
    const { safeHref } = await load("render.js");
    assert.ok(safeHref("https://example.test/post/14"));
    assert.ok(safeHref("http://example.test/post/14"));
    assert.ok(safeHref("mailto:dispatch@example.test"));
  });

  test("адрес разбирают, а не сверяют по началу строки", async () => {
    const { safeHref } = await load("render.js");
    assert.ok(
      safeHref("posts/14"),
      "Относительный адрес — тоже адрес, и схема у него та же, что у страницы. " +
        "Сравнение по началу строки этого не знает: оно видит строку, а не адрес.",
    );
    assert.ok(
      safeHref("  https://example.test/post/14  "),
      "Чужие данные приходят с пробелами по краям. Разбор их переживает, сравнение строк — нет.",
    );
  });

  test("схема, которой нет в списке разрешённого, не проходит", async () => {
    const { safeHref } = await load("render.js");
    for (const address of [
      "javascript:alert(1)",
      "JaVaScRiPt:alert(1)",
      "  javascript:alert(1)",
      "data:text/html,<script>alert(1)<\/script>",
      "vbscript:msgbox(1)",
      "wyciwyg://0/http://example.test",
    ]) {
      assert.equal(
        safeHref(address),
        null,
        `Адрес «${address}» прошёл. Список должен быть списком разрешённого: перечислять запрещённое ` +
          "значит перечислять то, что уже придумали, и пропускать то, что придумают завтра.",
      );
    }
  });

  test("пустого адреса не бывает", async () => {
    const { safeHref } = await load("render.js");
    assert.equal(safeHref(""), null);
    assert.equal(safeHref("   "), null);
    assert.equal(safeHref(null), null);
    assert.equal(safeHref(undefined), null);
  });

  test("свой адрес остаётся своим", async () => {
    const { safeHref } = await load("render.js");
    assert.equal(safeHref("#register"), "#register");
    assert.equal(safeHref("/entries/14"), "/entries/14");
  });

  test("опасный источник не оставляет после себя атрибут", async () => {
    // В разметке у этой строки адрес был — и был свой. Из конторы пришёл чужой
    // и негодный. Прежний обязан уйти: страница отражает состояние, а не сумму
    // всего, что на ней когда-либо стояло.
    await withPage(
      (page) => {
        const source = part(page, 3, "source");
        assert.equal(
          source.getAttribute("href"),
          null,
          "Спрятать ссылку мало: атрибут остался, а значит однажды её покажут — из отладки, " +
            "из чужого стиля, из следующей правки.",
        );
        assert.equal(source.hidden, true, "И показывать ссылку, которая никуда не ведёт, незачем.");
      },
      {
        prepare: (page) => {
          const link = page.need('#entries li[data-id="3"] [data-part="source"]');
          link.setAttribute("href", "/entries/42");
          link.hidden = false;
        },
      },
    );
  });

  test("безопасный источник виден и ведёт куда сказано", async () => {
    await withPage((page) => {
      const source = part(page, 5, "source");
      assert.equal(source.hidden, false, "Проверка адреса — не повод прятать все адреса.");
      assert.equal(new URL(source.getAttribute("href")).href, "https://example.test/post/129");
    });
  });

  test("записи без источника — без пустой ссылки", async () => {
    await withPage((page) => {
      const source = part(page, 1, "source");
      assert.equal(source.getAttribute("href"), null);
      assert.equal(source.hidden, true, "Ссылка, за которой ничего нет, читателю только мешает.");
    });
  });
});

// ─── Форма записи ─────────────────────────────────────────────────────────

describe("форма записи", () => {
  test("источник доезжает до состояния", async () => {
    const { entry } = await load("state.js");
    const made = entry({ id: 5, text: "обрыв", source: "https://example.test/post/129" });
    assert.equal(
      made.source,
      "https://example.test/post/129",
      "Поле есть в разметке и в конторе — значит оно должно быть и в состоянии, иначе " +
        "отрисовке брать его неоткуда.",
    );
  });

  test("поле, о котором не договаривались, в состояние не попадает", async () => {
    const { entry } = await load("state.js");
    const made = entry({ id: 9, text: "путь свободен", onclick: "alert(1)", hidden: true });
    assert.equal(
      made.onclick,
      undefined,
      "Контора завтра пришлёт поле, которого мы не ждали. У записи должна быть объявленная форма, " +
        "а не «всё, что пришло».",
    );
    assert.equal(made.hidden, undefined);
  });

  test("источник со страницы читается обратно", async () => {
    const page = openDocument(htmlFile);
    try {
      const { read } = await load("state.js");
      const link = page.need('#entries li[data-id="3"] [data-part="source"]');
      link.setAttribute("href", "/entries/42");
      link.hidden = false;
      const three = read(page.need("main")).entries.find((item) => item.id === "3");
      assert.equal(
        three.source,
        "/entries/42",
        "Разметка — первый источник состояния. Поле, которое в ней есть, читается оттуда же, " +
          "откуда текст и почерк.",
      );
    } finally {
      page.close();
    }
  });

  test("прочитанное со страницы и отрисованное совпадают", async () => {
    await withPage(async (page) => {
      const { read } = await load("state.js");
      const { render } = await load("render.js");
      const root = page.need("main");
      const before = read(root);
      render(root, before);
      assert.deepEqual(read(root), before, "Чтение и отрисовка — две стороны одного, и они сходятся.");
    });
  });
});

// ─── Прежние свойства ─────────────────────────────────────────────────────

describe("прежние свойства держатся", () => {
  test("журнал конторы заменяет разметочный", async () => {
    await withPage((page) => {
      const ids = page.$$("#entries li[data-id]").map((node) => node.dataset.id);
      assert.deepEqual(ids.sort(), ["1", "2", "3", "5", "7"]);
      assert.equal(
        page.window.document.querySelector('#entries li[data-id="4"]'),
        null,
        "Записи, которой нет в конторе, нет и на странице.",
      );
    });
  });

  test("мел ставится щелчком и переживает отрисовку", async () => {
    await withPage(async (page) => {
      page.click('#entries li[data-id="1"] [data-part="text"]');
      await page.tick();
      assert.equal(row(page, 1).dataset.chalk, "yes", "Щелчок по строке — мел, как в третьей редакции.");
      page.click('#entries li[data-id="5"] [data-part="text"]');
      await page.tick();
      assert.equal(row(page, 1).dataset.chalk, "yes", "Мел на одной строке не снимается щелчком по другой.");
    });
  });

  test("отбор прячет, а не удаляет", async () => {
    await withPage(async (page) => {
      page.fill("#state", "held");
      await page.tick();
      assert.equal(row(page, 1).hidden, true, "Отбор прячет.");
      assert.equal(row(page, 3).hidden, false);
      assert.ok(page.window.document.querySelector('#entries li[data-id="1"]'), "Но не удаляет.");
    });
  });
});
