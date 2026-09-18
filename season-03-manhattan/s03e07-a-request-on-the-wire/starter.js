// telegraph.js — точка входа.
//
// Редакция седьмая: настоящий провод.
//
// Здесь наконец появляется то, чем можно заменить отправку формы, — и потому
// здесь же впервые отменяется её отправка. До этой серии отменять было нечем,
// и обещание из s03e04 держалось ровно по этой причине.
//
// TODO: адрес конторы брать из разметки (data-office у body), а не выдумывать
// TODO: при загрузке забрать журнал из конторы и заменить им состояние;
//       контора недоступна — остаться на том, что в разметке, и сказать об
//       этом читателю
// TODO: state.js — withEntries(state, list): журнал конторы заменяет прежний,
//       мел переносится по номерам (он местный, конторе неизвестен)
// TODO: render.js — запись, которой нет в состоянии, уходит со страницы
//       совсем. Это не то же, что отбор: спрятанная запись есть, удалённой нет
// TODO: подача: отменить отправку формы, передать запись в контору,
//       добавить ответ конторы в состояние, очистить форму
// TODO: у каждой попытки свой ключ приёма, один на все её повторы
// TODO: новая отправка обрывает незаконченную предыдущую (AbortController):
//       два нажатия подряд — одна запись
// TODO: отказ конторы не стирает введённое; 422 — назвать поле и поставить
//       туда фокус
//
// Полное ТЗ — в mission.md.

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

once(register, "wiredChalk", () => {
  register.addEventListener("click", (event) => {
    const node = event.target.closest("li[data-id]");
    if (!node || !register.contains(node)) return;
    if (event.target.closest("a, button, input, select, textarea")) return;
    update(withChalk(state, node.dataset.id));
  });
});

once(sift, "wiredSift", () => {
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

// ─── Подтверждение приёма ─────────────────────────────────────────────────
//
// Кейл требует, чтобы каждая запись смены была подтверждена постом. Спросить
// линию — дело небыстрое, и пока она молчит, журнал показывает «передаётся».
//
// Обещание, у которого нет ни .catch, ни try, — ошибка, о которой никто не
// узнает. Поэтому отказ здесь ловится всегда, даже если делать с ним нечего.

confirmShift().catch((error) => {
  notify(`Подтверждение не прошло: ${error.message}`);
});

async function confirmShift() {
  const asking = state.entries.filter((item) => item.state !== "failed");
  if (asking.length === 0) return;

  for (const item of asking) update(withState(state, item.id, "sending"));

  // Каждый ответ применяется сразу, как пришёл: ждать самого медленного,
  // чтобы показать самого быстрого, незачем.
  const report = await acknowledgeAll(asking, wire, {
    timeout: 400,
    onSettled: ({ id, state: next }) => update(withState(state, id, next)),
  });

  notify(
    report.failed.length === 0
      ? "Все записи смены подтверждены."
      : `Постов без подтверждения: ${report.failed.length}.`,
  );
}

// Живая область смены — отдельно от области формы: сообщение про линию к
// форме подачи отношения не имеет.
function notify(text) {
  const shift = need("#shift-notice", () => {
    const made = document.createElement("p");
    made.id = "shift-notice";
    made.className = "notice";
    made.setAttribute("role", "status");
    made.hidden = true;
    root.querySelector("#tally")?.before(made) ?? root.prepend(made);
    return made;
  }, root);
  shift.textContent = text;
  shift.hidden = false;
}
