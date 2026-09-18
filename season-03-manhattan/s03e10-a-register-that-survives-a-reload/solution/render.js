// render.js — как состояние выглядит на странице.
//
// Редакция девятая: время приёма отдано своему элементу, а отрисовка следит
// за тем, чтобы читатель не потерял место. Строка, которая уходит со страницы
// или прячется отбором, может держать фокус; после неё фокус обязан
// приземлиться, а не пропасть.
//
// Одна функция и одно правило: **отрисовка приводит дерево к состоянию.**
// Не дописывает к прошлому, не помнит, что делала в прошлый раз, и не
// спрашивает у дерева, что там сейчас. Отсюда два свойства, которые и
// проверяются: отрисовать дважды — то же, что один раз; испортить дерево
// руками и отрисовать — вернуться к состоянию.
//
// Про состояние здесь знают только то, что у него есть записи, отбор и счёт.

import { counts, lastHand, shown } from "./state.js";

// Схемы, по которым ходит браузер. Всё остальное — javascript:, data:, vbscript: —
// это не адрес, а способ выполнить чужой код по нажатию.
const SAFE = new Set(["http:", "https:", "mailto:", "tel:"]);

// Адрес из чужих данных. Внутренняя ссылка (начинается с # или /) безопасна
// по определению: она никуда не уводит. Всё прочее разбирается и сверяется
// со списком — списком разрешённого, а не запрещённого.
export function safeHref(value, base = "http://localhost/") {
  const address = String(value ?? "").trim();
  if (address === "") return null;
  if (address.startsWith("#") || address.startsWith("/")) return address;
  try {
    const parsed = new URL(address, base);
    return SAFE.has(parsed.protocol) ? parsed.href : null;
  } catch {
    return null;
  }
}

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
  // Строка, которую снимают со страницы, может держать фокус читателя. Узел
  // уйдёт, фокус уйдёт вместе с ним — на <body>, то есть в начало документа.
  // Тот, кто читает страницу голосом, окажется в самом верху и без объяснения.
  const document = root.ownerDocument;
  let lost = false;

  for (const node of register.querySelectorAll("li[data-id]")) {
    if (known.has(node.dataset.id)) continue;
    lost ||= node.contains(document.activeElement);
    node.remove();
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
    const away = !visible.has(item.id);
    // Спрятанный узел фокус тоже теряет: `hidden` выводит его из порядка обхода.
    if (away && !node.hidden) lost ||= node.contains(document.activeElement);
    node.hidden = away;
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

  // Журнал объявлен местом, куда можно поставить фокус (`tabindex="-1"` в
  // разметке): он ближайшее осмысленное место к тому, что исчезло.
  if (lost) register.focus();
}

// Строка журнала собирается из образца, лежащего в разметке. Образец —
// разметка, которую писали мы; данные — текст, который писали не мы. Смешивать
// их строкой значит отдать решение о разметке автору данных.
function makeEntry(register, item) {
  const document = register.ownerDocument;
  const template = document.querySelector("#entry-template");
  const node = template
    ? template.content.firstElementChild.cloneNode(true)
    : document.createElement("li");
  node.dataset.id = item.id;
  register.append(node);
  return node;
}

// Всё, что пришло из данных, кладётся текстом — и только текстом.
function fill(node, item) {
  const text = node.querySelector("[data-part='text']");
  if (text) text.textContent = item.text ?? "";

  const hand = node.querySelector("[data-part='hand']");
  if (hand) hand.textContent = item.hand ? `принято: ${item.hand}` : "принято: —";

  // Время приёма своему элементу отдают атрибутом. Что он с ним сделает —
  // его дело: отрисовка про минуты и часы ничего не знает.
  const at = node.querySelector("[data-part='at']");
  if (at) {
    if (item.at) at.setAttribute("datetime", item.at);
    else at.removeAttribute("datetime");
  }

  const source = node.querySelector("[data-part='source']");
  if (source) {
    const href = safeHref(item.source);
    if (href) {
      source.setAttribute("href", href);
      source.hidden = false;
    } else {
      // Не просто спрятать: адрес, оставшийся в атрибуте, однажды покажут.
      source.removeAttribute("href");
      source.hidden = true;
    }
  }
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
