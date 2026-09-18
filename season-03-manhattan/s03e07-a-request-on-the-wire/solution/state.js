// state.js — состояние журнала и всё, что с ним делают.
//
// Здесь нет ни одного обращения к странице. Это не аккуратность, а условие:
// пока состояние знает про дерево документа, проверить его можно только
// открыв страницу, а отрисовать — только одним способом.
//
// Все функции ниже **не меняют** то, что им дали. Они возвращают новое
// состояние. Причина та же, что у меловых пометок Кейла: пока прежнее
// состояние цело, есть куда вернуться.

// Состояние журнала: записи и то, как их сейчас смотрят.
export function register({ entries = [], filter = "" } = {}) {
  return { entries: entries.map(entry), filter };
}

export function entry({ id, state = "sent", hand = null, text = "", chalk = false }) {
  return { id: String(id), state, hand, text, chalk: Boolean(chalk) };
}

// Начальное состояние берётся из разметки: она пришла первой и она же —
// то, что читатель уже видит. Это единственная функция, которой отдают узел,
// и она только читает.
export function read(root) {
  const entries = [...root.querySelectorAll("li[data-id]")].map((node) =>
    entry({
      id: node.dataset.id,
      state: node.dataset.state,
      hand: node.dataset.hand ?? null,
      text: (node.querySelector("p")?.textContent ?? "").trim(),
      chalk: Boolean(node.dataset.chalk),
    }),
  );
  return register({ entries });
}

// Состояние записи меняется, когда линия ответила — или не ответила.
export function withState(state, id, next) {
  const wanted = String(id);
  return {
    ...state,
    entries: state.entries.map((item) => (item.id === wanted ? { ...item, state: next } : item)),
  };
}

// Пока ждём ответа, запись помечена: она не «передана» и не «не прошла».
export function pending(state) {
  return state.entries.filter((item) => item.state === "sending");
}

export function withFilter(state, filter) {
  return { ...state, filter: String(filter ?? "") };
}

export function withChalk(state, id) {
  const wanted = String(id);
  return {
    ...state,
    entries: state.entries.map((item) =>
      item.id === wanted ? { ...item, chalk: !item.chalk } : item,
    ),
  };
}

// Журнал, пришедший из конторы, заменяет прежний целиком: у конторы записей
// больше, и она — источник, а страница ему отражение. Мел при этом переносится
// по номерам: он местный и конторе неизвестен.
export function withEntries(state, list) {
  const chalked = new Set(state.entries.filter((item) => item.chalk).map((item) => item.id));
  return {
    ...state,
    entries: list.map((item) => entry({ ...item, chalk: chalked.has(String(item.id)) })),
  };
}

// Новая запись встаёт в конец, как встала бы в бумажном журнале.
export function withEntry(state, fresh) {
  return { ...state, entries: [...state.entries, entry(fresh)] };
}

// Что показывать при нынешнем отборе. Отбор — это взгляд на состояние,
// а не изменение состояния: записи никуда не деваются.
export function shown(state) {
  return state.filter === "" ? state.entries : state.entries.filter((item) => item.state === state.filter);
}

export function counts(state) {
  const tally = { sent: 0, held: 0, failed: 0 };
  for (const item of state.entries) {
    if (item.state in tally) tally[item.state] += 1;
  }
  return tally;
}

// Последняя запись, у которой есть почерк, — не просто последняя.
export function lastHand(state) {
  for (let index = state.entries.length - 1; index >= 0; index -= 1) {
    if (state.entries[index].hand) return state.entries[index].hand;
  }
  return null;
}
