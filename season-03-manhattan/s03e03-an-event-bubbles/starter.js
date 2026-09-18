// telegraph.js — улучшение журнала приёма.
//
// Редакция третья: живой отбор записей и меловые пометки Кейла.
//
// Правила прежних редакций в силе. Новое — про слушателей.
//
// TODO: отбор по состоянию на месте: change у формы отбора прячет записи,
//       у которых data-state не тот; пустое значение показывает все
// TODO: отправку формы отбора отменить — она уже отработала на месте.
//       Форму подачи не трогать: заменить её отправку пока нечем
// TODO: нажатие по записи ставит и снимает data-chalk — меловую пометку
//       Кейла. Слушатель один, на журнале, а не на каждой записи: запись,
//       которая придёт следующей, должна работать сама собой
// TODO: нажатие по ссылке или кнопке внутри записи мел не ставит
// TODO: слушатель тоже вешается дважды. Второе выполнение модуля не должно
//       давать вторую пару обработчиков
//
// Полное ТЗ — в mission.md.

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
