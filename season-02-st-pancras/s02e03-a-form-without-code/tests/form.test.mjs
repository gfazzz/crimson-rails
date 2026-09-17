// CRIMSON RAILS — s02e03, проверка.
//
// Форма проверяется по тому, что она обещает браузеру: подписи, имена,
// типы значений и границы допустимого. Ни одного сравнения с эталоном.

import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readDocument } from "../../support/check.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const own = join(here, "..", "artifacts", "search.html");
const reference = join(here, "..", "solution", "search.html");
const source = existsSync(own) && !process.env.FORCE_SOLUTION ? own : reference;

console.log(`Источник: ${source.includes("artifacts") ? "artifacts" : "solution"}/search.html`);
if (!existsSync(own)) console.log("(артефакта нет — проверяю эталон)");

const doc = readDocument(source);
const form = doc.first("form");
const field = (id) => doc.byId(id);

describe("форма как таковая", () => {
  test("форма есть и она одна", () => {
    assert.equal(doc.count("form"), 1);
  });

  test("объявлено, куда и как отправлять", () => {
    assert.ok(doc.attr(form, "action"), "Без action форма отправится на текущий адрес — это случайность, а не решение.");
    const method = (doc.attr(form, "method") ?? "").toLowerCase();
    assert.ok(["get", "post"].includes(method), "method объявляют явно.");
    assert.equal(method, "get", "Поиск не меняет ничего на сервере: это get, и его результат можно положить в закладки.");
  });

  test("проверка браузера не отключена", () => {
    assert.ok(!doc.hasAttr(form, "novalidate"), "novalidate выключает всё, ради чего писалась эта форма.");
  });

  test("ни строки JavaScript", () => {
    assert.equal(doc.count("script"), 0, "В этом сезоне сценариев нет вовсе.");
    const inline = [...doc.walk()].filter((n) => (n.attrs ?? []).some((a) => a.name.startsWith("on")));
    assert.deepEqual(inline.map((n) => doc.tag(n)), [], "Обработчики в атрибутах — тот же JavaScript, только хуже.");
  });
});

describe("каждое поле подписано и названо", () => {
  test("подпись связана с полем", () => {
    const fields = doc.fields();
    assert.ok(fields.length >= 8, "Полей в форме не меньше восьми.");
    for (const control of fields) {
      const label = doc.labelFor(control);
      const id = doc.attr(control, "id") ?? doc.attr(control, "name") ?? doc.tag(control);
      assert.ok(label, `Поле «${id}» не подписано: нужен <label for> или label-обёртка.`);
      assert.ok(doc.text(label).length > 0, `Подпись поля «${id}» пуста.`);
    }
  });

  test("у каждого поля есть имя для отправки", () => {
    for (const control of doc.fields()) {
      const name = doc.attr(control, "name");
      assert.ok(name, `Поле «${doc.attr(control, "id")}» без name не отправится вовсе.`);
    }
  });

  test("подсказка не подменяет подпись", () => {
    for (const control of doc.fields()) {
      if (!doc.attr(control, "placeholder")) continue;
      assert.ok(
        doc.labelFor(control),
        "placeholder исчезает при вводе и не читается голосовым браузером как подпись. " +
          "Он дополняет label, а не заменяет его.",
      );
    }
  });

  test("пояснения привязаны к полям", () => {
    const described = doc.fields().filter((c) => doc.attr(c, "aria-describedby"));
    assert.ok(described.length >= 2, "Поля с ограничениями надо объяснить читателю, а не только браузеру.");
    for (const control of described) {
      for (const id of doc.attr(control, "aria-describedby").split(/\s+/)) {
        assert.ok(doc.byId(id), `Пояснение #${id} обещано, но его нет в документе.`);
      }
    }
  });
});

describe("тип поля выбран по смыслу значения", () => {
  test("день поездки — дата", () => {
    assert.equal(doc.attr(field("date"), "type"), "date", "Дату вводят датой: браузер сам даст календарь и проверит формат.");
  });

  test("время отправления — время", () => {
    assert.equal(doc.attr(field("after"), "type"), "time");
  });

  test("число мест — число", () => {
    assert.equal(doc.attr(field("seats"), "type"), "number");
  });

  test("станции выбирают из списка, а не набирают", () => {
    for (const id of ["from", "to"]) {
      assert.equal(doc.tag(field(id)), "select", `Станция «${id}» — выбор из указателя, а не свободный ввод.`);
    }
  });
});

describe("границы допустимого объявлены разметкой", () => {
  test("день поездки ограничен сроком действия выпуска", () => {
    const date = field("date");
    assert.equal(doc.attr(date, "min"), "1891-04-01", "Выпуск действует с первого апреля.");
    assert.equal(doc.attr(date, "max"), "1891-04-30", "И по тридцатое.");
  });

  test("число мест ограничено сверху и снизу", () => {
    const seats = field("seats");
    assert.equal(doc.attr(seats, "min"), "1", "Ноль мест не бывает.");
    assert.ok(Number(doc.attr(seats, "max")) > 1, "Верхняя граница тоже нужна: в купе не сядет сорок человек.");
  });

  test("код станции проверяется образцом", () => {
    const pattern = doc.attr(field("code"), "pattern");
    assert.ok(pattern, "Формат кода известен заранее — значит, объявляется, а не проверяется потом.");
    const re = new RegExp(`^(?:${pattern})$`);
    assert.ok(re.test("MID"), "Образец обязан принимать верный код MID.");
    assert.ok(!re.test("mid"), "И отвергать строчные.");
    assert.ok(!re.test("MIDL"), "И отвергать четыре буквы.");
  });

  test("обязательные поля помечены обязательными", () => {
    for (const id of ["from", "to", "date"]) {
      assert.ok(doc.hasAttr(field(id), "required"), `Без «${id}» подобрать поезд нельзя.`);
    }
    assert.ok(!doc.hasAttr(field("after"), "required"), "А время отправления — пожелание, а не условие.");
  });
});

describe("группы полей", () => {
  test("форма разбита на группы, у каждой своё название", () => {
    const sets = doc.all("fieldset");
    assert.ok(sets.length >= 3, "Три группы: поездка, класс вагона, прочее.");
    for (const set of sets) {
      const legend = doc.children(set).find((c) => c.tagName === "legend");
      assert.ok(legend, "У каждой группы полей должен быть <legend>.");
      assert.ok(doc.text(legend).length > 0, "И он не пустой.");
    }
  });

  test("переключатели класса — одна группа", () => {
    const radios = doc.all("input").filter((i) => doc.attr(i, "type") === "radio");
    assert.equal(radios.length, 3, "Классов вагона три.");
    const names = new Set(radios.map((r) => doc.attr(r, "name")));
    assert.equal(names.size, 1, "У переключателей одной группы одно имя — иначе они не исключают друг друга.");
    const values = radios.map((r) => doc.attr(r, "value"));
    assert.equal(new Set(values).size, 3, "А значения разные, иначе выбор не различить.");
  });

  test("переключатели лежат в своей группе с названием", () => {
    const radios = doc.all("input").filter((i) => doc.attr(i, "type") === "radio");
    for (const radio of radios) {
      const set = doc.closest(radio, "fieldset");
      assert.ok(set, "Переключатели без <fieldset> читаются вслух как три отдельных вопроса.");
    }
  });

  test("один класс выбран заранее", () => {
    const checked = doc.all("input")
      .filter((i) => doc.attr(i, "type") === "radio" && doc.hasAttr(i, "checked"));
    assert.equal(checked.length, 1, "Из переключателей ровно один должен быть выбран по умолчанию.");
  });
});

describe("список станций", () => {
  test("в списке все станции указателя", () => {
    const options = doc.children(field("from")).filter((o) => o.tagName === "option");
    const real = options.filter((o) => doc.attr(o, "value"));
    assert.equal(real.length, 5, "В указателе пять станций.");
    for (const option of real) {
      assert.ok(doc.text(option).length > 0, "У каждого пункта списка есть название.");
    }
  });

  test("первый пункт — приглашение, а не станция", () => {
    const first = doc.children(field("from")).find((o) => o.tagName === "option");
    assert.equal(doc.attr(first, "value"), "", "Пустое значение первого пункта заставит required сработать.");
  });
});

describe("отправка", () => {
  test("кнопка отправки — кнопка с текстом", () => {
    const button = doc.all("button").find((b) => (doc.attr(b, "type") ?? "submit") === "submit");
    assert.ok(button, "Нужна кнопка отправки.");
    assert.ok(doc.text(button).length > 3, "Текст кнопки говорит, что произойдёт: «Подобрать поезд», а не «ОК».");
  });
});
