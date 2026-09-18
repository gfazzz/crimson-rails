// telegraph.js — улучшение журнала приёма.
//
// Редакция третья: живой отбор записей и меловые пометки Кейла.
//
// Правила прежних редакций в силе. Новое — про слушателей: их вешают не на
// каждую запись, а один раз, выше по дереву. Событие всплывает само; узнать,
// на чём оно началось, можно у него самого. Иначе слушателей становится
// столько же, сколько записей, — и на каждой новой записи их нет.

document.documentElement.dataset.script = "on";

for (const node of document.querySelectorAll("[data-without-script]")) {
  node.hidden = true;
}

const register = document.querySelector("#entries");
const entries = () => [...register.querySelectorAll("li[data-id]")];

// Сводка. Создаётся, если её нет, и обновляется, если есть, — поэтому второй
// запуск даёт одну сводку, а не две.
function tally() {
  const list = need("#tally", () => {
    const made = document.createElement("ul");
    made.id = "tally";
    made.className = "tally";
    register.before(made);
    return made;
  });

  const counted = { sent: 0, held: 0, failed: 0 };
  let lastHand = null;
  for (const entry of entries()) {
    const state = entry.dataset.state;
    if (state in counted) counted[state] += 1;
    if (entry.dataset.hand) lastHand = entry.dataset.hand;
  }

  line(list, "sent", `переданных: ${counted.sent}`);
  line(list, "held", `задержанных: ${counted.held}`);
  line(list, "failed", `непрошедших: ${counted.failed}`);
  line(list, "hand", `последняя принята: ${lastHand ?? "—"}`);
}

// Строка сводки: узел с собственной пометкой. Текст кладётся textContent —
// значит останется текстом, чем бы он ни оказался.
function line(list, name, text) {
  const item = need(`#tally [data-tally="${name}"]`, () => {
    const made = document.createElement("li");
    made.dataset.tally = name;
    list.append(made);
    return made;
  });
  item.textContent = text;
}

// Записи без почерка. Помечаются атрибутом данных — состояние приходит из
// данных, пусть и в разметке остаётся данными, — и получают видимую пометку.
function markUnsigned() {
  for (const entry of entries()) {
    const signed = Boolean(entry.dataset.hand);
    if (signed) {
      delete entry.dataset.unsigned;
      entry.querySelector("[data-note='unsigned']")?.remove();
      continue;
    }
    entry.dataset.unsigned = "yes";
    const note = need("[data-note='unsigned']", () => {
      const made = document.createElement("p");
      made.dataset.note = "unsigned";
      made.className = "hand";
      entry.append(made);
      return made;
    }, entry);
    note.textContent = "почерка нет";
  }
}

// Найти или создать: единственный способ написать модуль, который можно
// выполнить дважды.
function need(selector, make, root = document) {
  return root.querySelector(selector) ?? make();
}

tally();
markUnsigned();

// ─── Отбор ────────────────────────────────────────────────────────────────
//
// Без скрипта фильтр отправляется на сервер и страница перезагружается.
// Со скриптом он отрабатывает на месте — но форма остаётся формой: её
// отправку надо отменить, иначе Enter в списке уведёт со страницы.

const sift = document.querySelector("form.sift");
const state = sift.querySelector("[name='state']");

// Слушатель — тоже то, что вешается дважды. Второе выполнение модуля (возврат
// страницы из кеша, повторное подключение) повесит второй такой же, и каждое
// нажатие станет двумя. Поэтому узел помечается, а пометка проверяется.
function wire(node, mark, attach) {
  if (node.dataset[mark]) return;
  node.dataset[mark] = "yes";
  attach();
}

wire(sift, "wiredSift", () => {
  sift.addEventListener("submit", (event) => {
    event.preventDefault();
    applyFilter();
  });
  sift.addEventListener("change", applyFilter);
});

function applyFilter() {
  const wanted = state.value;
  for (const entry of entries()) {
    entry.hidden = wanted !== "" && entry.dataset.state !== wanted;
  }
}

// ─── Мел ──────────────────────────────────────────────────────────────────
//
// Один слушатель на весь журнал. Запись, которой не было при загрузке,
// получает поведение сама собой: событие всплывает до списка, а список
// спрашивает у события, на чём оно началось.

wire(register, "wiredChalk", () => {
  register.addEventListener("click", (event) => {
    const entry = event.target.closest("li[data-id]");
    if (!entry || !register.contains(entry)) return;
    if (event.target.closest("a, button, input, select, textarea")) return;

    if (entry.dataset.chalk) {
      delete entry.dataset.chalk;
    } else {
      entry.dataset.chalk = "yes";
    }
  });
});

applyFilter();
