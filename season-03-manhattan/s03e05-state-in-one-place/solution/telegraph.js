// telegraph.js — точка входа.
//
// Редакция пятая: состояние отдельно, отрисовка отдельно, а этот файл их
// связывает. Больше он ничего не делает и знать ничего не должен.
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

import { read, withChalk, withFilter } from "./state.js";
import { render } from "./render.js";

document.documentElement.dataset.script = "on";

for (const node of document.querySelectorAll("[data-without-script]")) {
  node.hidden = true;
}

const root = document.querySelector("main");
const register = document.querySelector("#entries");
const compose = document.querySelector("form.compose");
const composeText = compose.querySelector("[name='text']");
const sift = document.querySelector("form.sift");

let state = read(root);

// Единственное место, где меняется состояние и перерисовывается страница.
function update(next) {
  state = next;
  render(root, state);
}

// ─── Слушатели ────────────────────────────────────────────────────────────

wire(register, "wiredChalk", () => {
  register.addEventListener("click", (event) => {
    const node = event.target.closest("li[data-id]");
    if (!node || !register.contains(node)) return;
    if (event.target.closest("a, button, input, select, textarea")) return;
    update(withChalk(state, node.dataset.id));
  });
});

wire(sift, "wiredSift", () => {
  sift.addEventListener("change", (event) => update(withFilter(state, event.target.value)));
  sift.addEventListener("submit", (event) => {
    event.preventDefault();
    update(withFilter(state, sift.querySelector("[name='state']").value));
  });
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

wire(compose, "wiredCompose", () => {
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

function wire(node, mark, attach) {
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
