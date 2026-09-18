// CRIMSON RAILS — s03e06, проверка.
//
// Почти вся эта проверка обходится без страницы: обещание — это про время, а
// не про дерево. Линия здесь своя у каждой проверки — та, которая нужна:
// быстрая, отказывающая, молчащая. Подделкой это не делает: подделкой было бы
// подменить то, что проверяется.

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
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Линии на любой вкус.
const answers = (after = 20) => (entry) => wait(after).then(() => ({ id: entry.id, hand: "линия" }));
const refuses = (after = 20, why = "линия оборвана") =>
  () => wait(after).then(() => Promise.reject(new Error(why)));
const silent = () => () => new Promise(() => {});
const throws = (why = "провод не подключён") => () => {
  throw new Error(why);
};

describe("обещание одной записи", () => {
  test("acknowledge возвращает обещание", async () => {
    const { acknowledge } = await load("office.js");
    const answer = acknowledge({ id: 1 }, answers());
    assert.equal(typeof answer?.then, "function", "acknowledge обязан вернуть обещание, а не значение.");
    await answer;
  });

  test("линия ответила — запись передана", async () => {
    const { acknowledge } = await load("office.js");
    const answer = await acknowledge({ id: 7 }, answers());
    assert.equal(answer.id, "7");
    assert.equal(answer.state, "sent");
  });

  test("линия отказала — обещание отклонено своей ошибкой", async () => {
    const { acknowledge, LineError } = await load("office.js");
    await assert.rejects(
      () => acknowledge({ id: 5 }, refuses(10, "пост не отвечает")),
      (error) => {
        assert.ok(
          error instanceof LineError,
          "Отказ пришёл чужой ошибкой. Пойманная ошибка без записи, к которой она относится, " +
            "бесполезна: своя ошибка несёт и номер, и причину.",
        );
        assert.equal(error.id, "5", "В ошибке нет номера записи.");
        assert.ok(error.cause, "Исходная причина потеряна: cause существует ровно для этого.");
        assert.match(error.message, /пост не отвечает/, "Сообщение линии должно дойти до читающего.");
        return true;
      },
    );
  });

  test("линия молчит — ожидание кончается само", async () => {
    const { acknowledge } = await load("office.js");
    const started = Date.now();
    await assert.rejects(
      () => acknowledge({ id: 3 }, silent(), { timeout: 120 }),
      (error) => {
        assert.equal(error.id, "3");
        return true;
      },
      "Обещание, которое не разрешается, само по себе не ошибка: оно просто никогда не кончится, " +
        "и запись останется «передаётся» до перезагрузки. Ограничивают не линию, а ожидание.",
    );
    const spent = Date.now() - started;
    assert.ok(spent < 400, `Ожидание длилось ${spent} мс при сроке 120. Таймаут не сработал.`);
  });

  test("поздний ответ после срока ничего не ломает", async () => {
    const { acknowledge } = await load("office.js");
    await assert.rejects(() => acknowledge({ id: 9 }, answers(200), { timeout: 60 }));
    // Линия ответит на 200-й миллисекунде — когда ждать её уже перестали.
    // Ни второго разрешения, ни необработанного отказа быть не должно.
    await wait(250);
  });

  test("исключение внутри линии становится отказом, а не падением", async () => {
    const { acknowledge } = await load("office.js");
    await assert.rejects(
      () => acknowledge({ id: 2 }, throws()),
      (error) => {
        assert.equal(error.id, "2", "Синхронное исключение линии тоже должно прийти как отказ обещания.");
        return true;
      },
    );
  });
});

describe("несколько сразу", () => {
  const four = [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }];

  test("спрашивают параллельно, а не по очереди", async () => {
    const { acknowledgeAll } = await load("office.js");
    const started = Date.now();
    await acknowledgeAll(four, answers(80));
    const spent = Date.now() - started;
    assert.ok(
      spent < 240,
      `Четыре записи по 80 мс заняли ${spent} мс. По очереди вышло бы 320: линия одна, но ждать ` +
        "её можно всем сразу. Последовательное ожидание — самая дорогая ошибка этой серии.",
    );
  });

  test("один отказ не отменяет остальных", async () => {
    const { acknowledgeAll } = await load("office.js");
    const mixed = (entry) => (entry.id === 2 ? refuses(10)() : answers(10)(entry));
    const report = await acknowledgeAll(four, mixed);
    assert.equal(report.sent.length, 3, "Promise.all бросил бы всё при первом отказе — нужен отчёт по каждой.");
    assert.equal(report.failed.length, 1);
    assert.equal(report.failed[0].id, "2");
    assert.ok(report.failed[0].reason?.length > 3, "В отчёте должна быть причина, а не просто отказ.");
  });

  test("порядок отчёта — порядок записей", async () => {
    const { acknowledgeAll } = await load("office.js");
    // Линия отвечает вразнобой: четвёртая раньше первой.
    const shuffled = (entry) => wait(Number(entry.id) === 4 ? 5 : 60).then(() => ({ id: entry.id }));
    const report = await acknowledgeAll(four, shuffled);
    assert.deepEqual(
      report.sent.map((item) => item.id),
      ["1", "2", "3", "4"],
      "Отчёт собран в порядке ответов. Линия отвечает как придётся, а журнал ведут по порядку.",
    );
  });

  test("о каждом ответе сообщают сразу, а не в конце", async () => {
    const { acknowledgeAll } = await load("office.js");
    const heard = [];
    const uneven = (entry) => (Number(entry.id) === 3 ? new Promise(() => {}) : answers(10)(entry));
    const done = acknowledgeAll(four, uneven, {
      timeout: 300,
      onSettled: (answer) => heard.push([answer.id, Date.now()]),
    });
    await wait(120);
    assert.ok(
      heard.length >= 3,
      `Через 120 мс пришло ${heard.length} ответов из четырёх. Один молчащий пост задержал весь ` +
        "журнал на весь срок ожидания: быстрые ответы надо применять по мере поступления.",
    );
    const report = await done;
    assert.equal(report.failed.length, 1, "Молчащий пост попадает в отчёт как непрошедший.");
    const counted = new Map();
    for (const [id] of heard) counted.set(id, (counted.get(id) ?? 0) + 1);
    assert.deepEqual(
      [...counted.values()].filter((times) => times > 1),
      [],
      "О какой-то записи сообщили дважды. Подписчик применяет ответ к состоянию: второе " +
        "сообщение перепишет то, что уже поправили.",
    );
  });

  test("пустой список — пустой отчёт, без похода на линию", async () => {
    const { acknowledgeAll } = await load("office.js");
    let asked = 0;
    const report = await acknowledgeAll([], () => {
      asked += 1;
      return Promise.resolve({});
    });
    assert.deepEqual(report, { sent: [], failed: [] });
    assert.equal(asked, 0, "Спрашивать было не про что.");
  });
});

describe("журнал ждёт честно", () => {
  const live = async () => {
    const page = openDocument(htmlFile);
    await page.run(moduleFile);
    return page;
  };
  const states = (page) =>
    Object.fromEntries(page.$$("#entries li").map((node) => [node.dataset.id, node.dataset.state]));

  test("пока ждём, запись не передана и не потеряна", async () => {
    const page = await live();
    const now = states(page);
    assert.ok(
      Object.values(now).includes("sending"),
      "Сразу после загрузки ни одна запись не помечена «передаётся». Между «спросили» и " +
        "«ответили» проходит время, и журнал обязан показывать это время, а не врать в одну " +
        "из двух сторон.",
    );
    const waiting = page.$$('#entries li[data-state="sending"]')[0];
    assert.equal(waiting.getAttribute("aria-busy"), "true", "Ожидание должно быть слышно, а не только видно.");
    page.close();
  });

  test("быстрые ответы приходят раньше медленных", async () => {
    const page = await live();
    await page.tick(2);
    await new Promise((resolve) => setTimeout(resolve, 150));
    const now = states(page);
    assert.equal(now["1"], "sent", "Первая запись подтверждается за 40 мс — ждать её нечего.");
    assert.equal(now["3"], "sending", "Третий пост молчит: пока срок не вышел, запись ещё в пути.");
    page.close();
  });

  test("к концу срока каждая запись получает ответ", async () => {
    const page = await live();
    await new Promise((resolve) => setTimeout(resolve, 700));
    const now = states(page);
    assert.deepEqual(
      now,
      { 1: "sent", 2: "sent", 3: "failed", 4: "sent", 5: "failed", 6: "failed" },
      "Молчащие посты (кратные трём) обязаны стать непрошедшими, отказавшие (кратные пяти) — " +
        "тоже, остальные — переданными.",
    );
    assert.equal(page.$$('#entries li[aria-busy]').length, 0, "Занятых записей не осталось — пометку снимают.");
    page.close();
  });

  test("итог смены сообщён живой областью", async () => {
    const page = await live();
    await new Promise((resolve) => setTimeout(resolve, 700));
    const shift = page.$("#shift-notice, [role='status']:not(form.compose [role='status'])");
    assert.ok(shift, "Итог подтверждения некому сообщить: нужна живая область смены.");
    assert.match(page.text(shift), /\d/, `«${page.text(shift)}» не говорит, сколько записей без подтверждения.`);
    page.close();
  });

  test("ни одна ошибка не осталась без присмотра", async () => {
    const page = await live();
    await new Promise((resolve) => setTimeout(resolve, 700));
    assert.deepEqual(
      page.errors,
      [],
      "Страница получила ошибку. Обещание без .catch и без try — это ошибка, о которой никто не " +
        "узнает, пока она не всплывёт целиком.",
    );
    page.close();
  });

  test("прежние редакции в силе", async () => {
    const page = await live();
    await new Promise((resolve) => setTimeout(resolve, 700));
    assert.equal(page.document.documentElement.dataset.script, "on", "s03e01.");
    assert.ok(page.$("#tally"), "s03e02.");
    assert.equal(page.need("form.compose").noValidate, true, "s03e04.");
    const node = page.need('li[data-id="2"]');
    await page.click(node.querySelector("p"));
    assert.equal(node.dataset.chalk, "yes", "s03e03: мел.");
    await page.fill("#state", "failed");
    assert.deepEqual(
      page.$$("#entries li").filter((item) => !item.hidden).map((item) => item.dataset.id),
      ["3", "5", "6"],
      "s03e05: отбор идёт по состоянию — в том числе по тому, которое поменяла линия.",
    );
    page.close();
  });
});
