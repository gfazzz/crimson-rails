// address.js — вид журнала и его адрес.
//
// Последняя редакция сезона. Состояние журнала уже лежит в одном месте
// (s03e05), приходит из конторы (s03e07) и показывается своими элементами
// (s03e09). Осталось одно: часть этого состояния — не наша.
//
// Отбор — это не то, что читатель выбрал в этой вкладке. Это то, на что он
// сейчас смотрит, и у этого есть имя снаружи: адрес страницы. Пока отбор
// живёт только в памяти вкладки, ссылка не работает, «назад» не работает,
// перезагрузка теряет вид, а тот же вид у соседа собрать невозможно.
//
// Правило, из которого следует весь файл:
//
//     вид, который нельзя назвать адресом, нельзя ни показать другому,
//     ни вернуть себе.
//
// И второе, про доверие: адрес пишет кто угодно. Ссылку присылают. Всё, что
// пришло из адреса, — чужой текст (s03e08), и разбирают его так же: по списку
// разрешённого.

const FILTERS = new Set(["", "sent", "held", "failed"]);

// Вид журнала. Поле пока одно, и всё равно это отдельная вещь: у вида есть
// адрес, а у состояния журнала — нет.
export function view({ filter = "" } = {}) {
  return { filter: FILTERS.has(filter) ? filter : "" };
}

// Что сказано в адресе. Неизвестное значение — это не ошибка и не повод
// падать: это просто не отбор.
export function readAddress(search = "") {
  return view({ filter: new URLSearchParams(search).get("state") ?? "" });
}

// Адрес вида. Пустой отбор вопроса не оставляет: «все записи» — это та же
// страница, и лишний `?state=` в ссылке означал бы, что вид выбран, когда он
// не выбран.
export function addressOf(shown, here) {
  const address = new URL(here);
  if (shown.filter) address.searchParams.set("state", shown.filter);
  else address.searchParams.delete("state");
  return address.pathname + address.search + address.hash;
}

// Записать вид в историю. Два способа, и разница между ними — это и есть
// «останется ли след»:
//   pushState     новый след: «назад» вернёт прошлый вид;
//   replaceState  тот же след: годится для приведения адреса в порядок.
//
// Адрес, совпадающий с нынешним, не пишется вовсе: иначе одно и то же
// нажатие копило бы историю из одинаковых видов, и «назад» перестал бы
// работать для читателя, хотя формально работал бы.
export function showAddress(shown, { replace = false, where = window } = {}) {
  const now = where.location;
  const address = addressOf(shown, now.href);
  if (address === now.pathname + now.search + now.hash) return false;
  where.history[replace ? "replaceState" : "pushState"]({}, "", address);
  return true;
}

// Читатель нажал «назад». Вид берут из адреса, а не из history.state:
// состояние записи в истории может быть чужим, устаревшим или отсутствовать
// вовсе — у первой записи оно null всегда. Адрес есть всегда.
export function onAddress(handler, where = window) {
  const listener = () => handler(readAddress(where.location.search));
  where.addEventListener("popstate", listener);
  return () => where.removeEventListener("popstate", listener);
}
