// render.js — как состояние выглядит на странице.
//
// Редакция восьмая: текст записей пишут посты, а посты — не мы. Всё, что
// пришло из конторы, здесь считается чужим: чужой текст остаётся текстом,
// чужой адрес проверяется, чужие имена не становятся разметкой.
//
// Одна функция и одно правило: **отрисовка приводит дерево к состоянию.**
// Не дописывает к прошлому, не помнит, что делала в прошлый раз, и не
// спрашивает у дерева, что там сейчас. Отсюда два свойства, которые и
// проверяются: отрисовать дважды — то же, что один раз; испортить дерево
// руками и отрисовать — вернуться к состоянию.
//
// Про состояние здесь знают только то, что у него есть записи, отбор и счёт.

import { counts, lastHand, shown } from "./state.js";

// TODO: safeHref(value, base) — адрес из чужих данных, годный для href,
//       или null.
//         · список разрешённых схем, а не запрещённых: перечислять запрещённое
//           значит перечислять только то, что уже придумали;
//         · адрес разбирают (new URL), а не сверяют по началу строки:
//           «  JaVaScRiPt:alert(1)» начинается не с "javascript:";
//         · пустой адрес — не адрес;
//         · свой адрес (# или /) годен как есть: он никуда не уводит.

export function render(root, state) {
  renderTally(root, state);
  renderEntries(root, state);
}

function renderTally(root, state) {
  const register = need(root, "#entries");
  const list = need(root, "#tally", () => {
    const made = root.ownerDocument.createElement("ul");
    made.id = "tally";
    made.className = "tally";
    register.before(made);
    return made;
  });

  const tally = counts(state);
  const hand = lastHand(state);
  line(list, "sent", `переданных: ${tally.sent}`);
  line(list, "held", `задержанных: ${tally.held}`);
  line(list, "failed", `непрошедших: ${tally.failed}`);
  line(list, "hand", `последняя принята: ${hand ?? "—"}`);
}

function renderEntries(root, state) {
  const register = need(root, "#entries");
  const visible = new Set(shown(state).map((item) => item.id));
  const known = new Set(state.entries.map((item) => item.id));

  // Строка, которой нет в состоянии, со страницы уходит совсем. Это не то же,
  // что отбор: спрятанная запись есть, её просто не показывают; удалённой —
  // нет. Пока журнал брали из разметки, разницы не было; теперь источник —
  // контора, и всё, чего в ней нет, на странице оказалось неизвестно откуда.
  for (const node of register.querySelectorAll("li[data-id]")) {
    if (!known.has(node.dataset.id)) node.remove();
  }

  for (const item of state.entries) {
    const node = need(register, `li[data-id="${item.id}"]`, () => makeEntry(register, item));

    fill(node, item);
    node.dataset.state = item.state;
    // Пока ждём ответа линии, запись объявлена занятой: это слышно, а не
    // только видно.
    if (item.state === "sending") {
      node.setAttribute("aria-busy", "true");
    } else {
      node.removeAttribute("aria-busy");
    }
    node.hidden = !visible.has(item.id);
    setFlag(node, "chalk", item.chalk ? "yes" : null);
    setFlag(node, "unsigned", item.hand ? null : "yes");

    const note = need(node, "[data-note='unsigned']", () => {
      const made = node.ownerDocument.createElement("p");
      made.dataset.note = "unsigned";
      made.className = "hand";
      node.append(made);
      return made;
    });
    note.textContent = item.hand ? "" : "почерка нет";
    note.hidden = Boolean(item.hand);
  }
}

// TODO: makeEntry(register, item) — новая строка журнала. Собрать её из
//       образца, лежащего в разметке: template.content и cloneNode(true).
//       Образец — разметка, которую писали мы; данные — текст, который писали
//       не мы. Собирать строку строкой значит отдать решение о разметке
//       автору данных.

// TODO: fill(node, item) — положить в строку то, что пришло из конторы.
//         · текст и почерк — текстом, и только текстом, целиком, как прислали;
//         · источник — через safeHref: годен → href и показать;
//           не годен → **снять атрибут** и спрятать. Спрятать мало: адрес,
//           оставшийся в атрибуте, однажды покажут — из отладки, из чужого
//           стиля, из следующей правки.

function setFlag(node, name, value) {
  if (value === null) {
    delete node.dataset[name];
  } else {
    node.dataset[name] = value;
  }
}

function line(list, name, text) {
  const item = need(list, `[data-tally="${name}"]`, () => {
    const made = list.ownerDocument.createElement("li");
    made.dataset.tally = name;
    list.append(made);
    return made;
  });
  item.textContent = text;
}

function need(root, selector, make) {
  return root.querySelector(selector) ?? (make ? make() : null);
}
