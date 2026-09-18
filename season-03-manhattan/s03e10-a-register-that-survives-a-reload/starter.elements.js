// elements.js — свои элементы.
//
// Сигнальный инженер Ролстон объяснил это лучше, чем справочник: автоматический
// блок-сигнал включается, когда его поставили, и выключается, когда сняли.
// Никто не приходит его заводить и никто не приходит его глушить. Сигнал,
// который сняли и забыли отключить, — самая дорогая вещь на дороге: он ничего
// не показывает и всё равно работает.
//
// Свой элемент — это поведение, привязанное к тегу, а не к строке кода,
// нашедшей этот тег. Разница видна ровно там, где тег появился позже модуля:
// строку журнала, пришедшую из конторы через час после загрузки, никто не
// «подключает» — она поднимается сама.
//
// Три правила жизненного цикла, из которых следует всё остальное:
//   конструктор   элемент ещё не в документе: детей нет, атрибутов может не
//                 быть, трогать нечего. Здесь только своё, внутреннее;
//   connected     поставили на страницу: завести таймер, подписаться;
//   disconnected  сняли: погасить таймер, отписаться. Обязательно.

// ─── <time-ago> ───────────────────────────────────────────────────────────
//
// Живое «сколько прошло». Запасное содержимое — точное время — уже лежит в
// разметке, и без модуля читатель видит именно его. Элемент ничего не
// заменяет собой: он улучшает то, что уже написано.

// Частота обновления зависит от возраста, и это не экономия, а смысл: запись
// минутной давности меняется каждые несколько секунд, трёхдневная не изменится
// уже никогда.
const STEPS = [
  { until: 60_000, every: 5_000 }, // моложе минуты
  { until: 3_600_000, every: 30_000 }, // моложе часа
  { until: 86_400_000, every: 600_000 }, // моложе суток
  { until: Infinity, every: null }, // старше — обновлять нечего
];

const RELATIVE = new Intl.RelativeTimeFormat("ru", { numeric: "always" });

export function sinceWords(at, now = Date.now()) {
  const moment = at instanceof Date ? at.getTime() : Date.parse(at);
  if (Number.isNaN(moment)) return null;

  const age = now - moment;
  if (age < 0) return "вот-вот";
  if (age < 60_000) return "только что";
  if (age < 3_600_000) return RELATIVE.format(-Math.floor(age / 60_000), "minute");
  if (age < 86_400_000) return RELATIVE.format(-Math.floor(age / 3_600_000), "hour");
  return RELATIVE.format(-Math.floor(age / 86_400_000), "day");
}

export class TimeAgo extends HTMLElement {
  // Список атрибутов, о смене которых элемент просит сообщать. Чего в нём
  // нет — о том и не сообщат: браузер не следит за всем подряд.
  static observedAttributes = ["datetime"];

  #timer = null;
  #fallback = null;

  connectedCallback() {
    // Запасное содержимое написано в разметке. Элемент его не выдумывает —
    // он его запоминает, чтобы было куда вернуться.
    this.#fallback ??= this.textContent;
    this.refresh();
  }

  // Сняли со страницы — погасить. Без этой строки снятая запись продолжает
  // тикать в памяти: её не видно, и она работает.
  disconnectedCallback() {
    this.#stop();
  }

  attributeChangedCallback() {
    // Элемент вне документа не обновляют: он ничей и ничего не показывает.
    if (this.isConnected) this.refresh();
  }

  refresh() {
    const at = this.getAttribute("datetime");
    if (!at) {
      // Нечего считать — вернуть то, что написано в разметке.
      this.#stop();
      if (this.#fallback !== null) this.textContent = this.#fallback;
      this.removeAttribute("title");
      return;
    }

    const words = sinceWords(at);
    if (words === null) return;

    this.textContent = words;
    this.title = at;
    this.#schedule(Date.now() - Date.parse(at));
  }

  #schedule(age) {
    this.#stop();
    const { every } = STEPS.find((step) => age < step.until);
    if (every === null) return;
    this.#timer = setTimeout(() => this.refresh(), every);
  }

  #stop() {
    if (this.#timer !== null) clearTimeout(this.#timer);
    this.#timer = null;
  }
}

// ─── <shift-notice> ───────────────────────────────────────────────────────
//
// Живая область смены. Живой она объявлена в разметке — до первого сообщения,
// а не вместе с ним: область, созданную вместе с текстом, читающая машина не
// успевает заметить. Это правило из s03e04, и здесь оно переезжает в элемент.
//
// Область сообщает. Она не забирает фокус: читатель остался там, где был, и
// решение, идти ли к сообщению, остаётся за ним.

export class ShiftNotice extends HTMLElement {
  say(text) {
    this.textContent = String(text ?? "");
    this.hidden = false;
  }

  clear() {
    this.textContent = "";
    this.hidden = true;
  }
}

// Имя своего тега обязано содержать дефис. Это не стиль, а договор: так
// браузер отличает наши теги от тех, которые он однажды добавит сам.
customElements.define("time-ago", TimeAgo);
customElements.define("shift-notice", ShiftNotice);
