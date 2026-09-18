// telegraph.js — точка входа.
//
// Редакция десятая, последняя в сезоне: у вида появился адрес.
//
// Отбор больше не живёт в памяти вкладки. Он приходит из адреса при загрузке,
// уходит в адрес при смене и возвращается из адреса, когда читатель нажал
// «назад». Ссылкой на вид можно поделиться, и она откроет тот же вид — со
// скриптом и без.
//
// Здесь наконец появляется то, чем можно заменить отправку формы, — и потому
// здесь же впервые отменяется её отправка. До этой серии отменять было
// нечем, и обещание из s03e04 держалось ровно по этой причине.
//
// Журнал теперь берут из конторы, а не из разметки: у конторы записей больше,
// и она источник. Разметка остаётся тем, что видит читатель, у которого
// провод не дотянулся.
//
// Зачем деление. В четвёртой редакции состояние журнала жило в дереве: мел —
// в атрибуте, отбор — в hidden, счёт — в тексте сводки. Пока страница одна,
// это работает; как только состояние придёт не из разметки, а по проводу
// (s03e07), спрашивать «а что у нас сейчас» станет некого.
//
// Теперь наоборот: состояние знает всё, страница — его отражение. Всякое
// изменение проходит по одному пути:
//
//     событие → новое состояние → отрисовка
//
// Обратного пути нет: отрисовка не принимает решений, а обработчик не трогает
// дерево.

import "./elements.js"; // теги определяются до первой отрисовки
import { read, withChalk, withEntries, withEntry, withFilter } from "./state.js";
import { render } from "./render.js";
import { load, OfficeError, send, withRetry } from "./office.js";
import { onAddress, readAddress, showAddress } from "./address.js";

document.documentElement.dataset.script = "on";

for (const node of document.querySelectorAll("[data-without-script]")) {
  node.hidden = true;
}

// Адрес конторы объявлен в разметке. Модуль его не выдумывает: завтра контора
// переедет, и переезд — дело разметки, а не кода.
const office = document.body.dataset.office ?? "/entries";

const root = document.querySelector("main");
const register = document.querySelector("#entries");
const compose = document.querySelector("form.compose");
const composeText = compose.querySelector("[name='text']");
const sift = document.querySelector("form.sift");
// Живая область смены: лежит в разметке, объявлена живой до первого сообщения.
const shift = document.querySelector("shift-notice");

// Отбор берут из адреса, а не из разметки: разметка говорит, что в журнале,
// адрес — как на него смотрят.
const stateField = sift.querySelector("[name='state']");

let state = withFilter(read(root), readAddress(location.search).filter);
// Управление приводят к виду, а не наоборот: читатель мог прийти по ссылке.
stateField.value = state.filter;

// Единственное место, где меняется состояние и перерисовывается страница.
function update(next) {
  state = next;
  render(root, state);
}

// ─── Слушатели ────────────────────────────────────────────────────────────

once(register, "wiredChalk", () => {
  register.addEventListener("click", (event) => {
    const node = event.target.closest("li[data-id]");
    if (!node || !register.contains(node)) return;
    if (event.target.closest("a, button, input, select, textarea")) return;
    update(withChalk(state, node.dataset.id));
  });
});

once(sift, "wiredSift", () => {
  sift.addEventListener("change", () => look(stateField.value));
  sift.addEventListener("submit", (event) => {
    event.preventDefault();
    look(stateField.value);
  });
});

// Единственное место, где меняется вид: состояние и адрес переставляются
// вместе. Порознь они разойдутся в первый же день.
function look(filter) {
  const next = withFilter(state, filter);
  update(next);
  showAddress(next);
}

// «Назад» — это не отмена действия, а другой вид. Его применяют, но не пишут
// обратно в историю: запись в ответ на чтение — это петля, из которой
// читатель не выберется кнопкой.
onAddress(({ filter }) => {
  stateField.value = filter;
  update(withFilter(state, filter));
});

// ─── Подача ───────────────────────────────────────────────────────────────

compose.noValidate = true;

const notice = need("#compose-notice", () => {
  const made = document.createElement("p");
  made.id = "compose-notice";
  made.className = "notice";
  made.setAttribute("role", "status");
  made.hidden = true;
  compose.prepend(made);
  return made;
});

once(compose, "wiredCompose", () => {
  compose.addEventListener("submit", (event) => {
    const text = composeText.value.trim();
    composeText.setCustomValidity(
      text.length > 0 && text.length < 5 ? "Текст записи — не короче пяти знаков." : "",
    );

    if (compose.checkValidity()) {
      hideNotice();
      return;
    }

    event.preventDefault();
    const wrong = [...compose.elements].filter((field) => field.willValidate && !field.checkValidity());
    showNotice(wrong);
    wrong[0]?.focus();
  });

  compose.addEventListener("input", (event) => {
    if (event.target === composeText) composeText.setCustomValidity("");
    hideNotice();
  });
});

function showNotice(wrong) {
  notice.textContent = wrong.map((field) => `${labelOf(field)}: ${field.validationMessage}`).join(" ");
  notice.hidden = false;
}

function hideNotice() {
  notice.hidden = true;
  notice.textContent = "";
}

function labelOf(field) {
  const label = field.id ? document.querySelector(`label[for="${field.id}"]`) : null;
  return (label?.textContent ?? field.name).trim();
}

// Повесить однажды. Имя сменилось: слово «провод» теперь занято настоящим
// проводом, и путать их не стоит.
function once(node, mark, attach) {
  if (node.dataset[mark]) return;
  node.dataset[mark] = "yes";
  attach();
}

function need(selector, make, where = document) {
  return where.querySelector(selector) ?? make();
}

// Первая отрисовка: страница приводится к состоянию, прочитанному из неё же.
// Видимой разницы нет — и это хороший признак.
render(root, state);

// ─── Журнал из конторы ────────────────────────────────────────────────────

refresh().catch(showTrouble);

async function refresh() {
  try {
    const entries = await withRetry(() => load({ origin: originOf(office) }));
    update(withEntries(state, entries));
    notify(`Журнал получен из конторы: записей ${entries.length}.`);
  } catch (error) {
    // Контора недоступна — работаем по тому, что на странице. Это не отказ
    // журнала, а отказ провода, и сказать надо именно так.
    notify(`Контора недоступна: ${error.message}. Журнал показан по странице.`);
  }
}

// ─── Подача записи ────────────────────────────────────────────────────────
//
// Теперь есть чем заменить отправку формы — значит можно её отменить.

let sending = null;

once(compose, "wiredSend", () => {
  compose.addEventListener("submit", async (event) => {
    if (!compose.checkValidity()) return; // разбор ошибок — редакция четвёртая
    event.preventDefault();

    // Новая отправка отменяет незаконченную предыдущую: два нажатия подряд
    // не должны дать две записи.
    sending?.abort();
    const attempt = new AbortController();
    sending = attempt;

    const draft = {
      from: compose.querySelector("[name='from']").value,
      text: composeText.value.trim(),
    };
    // Ключ приёма один на попытку и все её повторы: иначе повтор заведёт
    // вторую запись.
    const receipt = newReceipt();

    compose.setAttribute("aria-busy", "true");
    try {
      const saved = await withRetry(() =>
        send(draft, { origin: originOf(office), signal: attempt.signal, receipt }),
      );
      update(withEntry(state, { ...saved, state: saved.state ?? "sent" }));
      compose.reset();
      notify(`Запись ${saved.id} принята конторой.`);
      // Смена продолжается: следующую запись передают, не трогая мышь.
      composeText.focus();
    } catch (error) {
      if (error?.name === "AbortError") return; // отменили сами, жаловаться не на что
      showTrouble(error);
    } finally {
      if (sending === attempt) {
        sending = null;
        compose.removeAttribute("aria-busy");
      }
    }
  });
});

function showTrouble(error) {
  if (error instanceof OfficeError && error.status === 422) {
    notify(`Контора не приняла запись: ${error.message}`);
    const field = error.field ? compose.querySelector(`[name="${error.field}"]`) : null;
    field?.focus();
    return;
  }
  notify(`Передать не удалось: ${error.message}. Введённое сохранено.`);
}

function originOf(address) {
  return address.startsWith("http") ? new URL(address).origin : "";
}

function newReceipt() {
  return globalThis.crypto?.randomUUID
    ? globalThis.crypto.randomUUID()
    : `r-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

// Живая область смены — отдельно от области формы: сообщение про контору к
// разбору формы отношения не имеет.
//
// Область лежит в разметке и умеет говорить сама. Модуль её не создаёт и не
// объявляет живой: то и другое случилось до него, и в этом весь смысл — иначе
// читающая машина не успевает заметить область, появившуюся вместе с текстом.
function notify(text) {
  // Сообщить — не значит увести. Фокус читателя остаётся там, где был:
  // живая область объявляет, а решение идти к ней принимает он.
  shift?.say(text);
}
