// render.js — как состояние выглядит на странице.
//
// Одна функция и одно правило: **отрисовка приводит дерево к состоянию.**
// Не дописывает к прошлому, не помнит, что делала в прошлый раз, и не
// спрашивает у дерева, что там сейчас. Отсюда два свойства, которые и
// проверяются: отрисовать дважды — то же, что один раз; испортить дерево
// руками и отрисовать — вернуться к состоянию.
//
// Про состояние здесь знают только то, что у него есть записи, отбор и счёт.

import { counts, lastHand, shown } from "./state.js";

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

  for (const item of state.entries) {
    const node = need(register, `li[data-id="${item.id}"]`, () => makeEntry(register, item));

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

function makeEntry(register, item) {
  const document = register.ownerDocument;
  const node = document.createElement("li");
  node.dataset.id = item.id;
  const text = document.createElement("p");
  text.textContent = item.text;
  node.append(text);
  register.append(node);
  return node;
}

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
