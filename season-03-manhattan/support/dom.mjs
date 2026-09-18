// CRIMSON RAILS — общая библиотека проверок сезона 3.
//
// Здесь одна мысль: файл, который грузит браузер, и файл, который импортирует
// проверка, — один и тот же. Никакой сборки между ними нет. Поэтому страница
// собирается в jsdom, модуль импортируется как модуль, а дальше спрашивают у
// дерева, что с ним стало.
//
// Чего тут нет намеренно: поиска подстрок в коде проходящего курс. Проверяется
// поведение — что появилось в дереве, какое событие дошло, сколько слушателей
// зарегистрировано и на чём.

import { copyFileSync, mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import { JSDOM } from "jsdom";

// Глобальные имена, которые модуль в браузере видит сам собой.
const GLOBALS = [
  "window", "document", "navigator", "location", "history", "customElements",
  "HTMLElement", "HTMLFormElement", "HTMLInputElement", "Element", "Node", "NodeFilter",
  "Event", "CustomEvent", "SubmitEvent", "KeyboardEvent", "MouseEvent", "PopStateEvent",
  "FormData", "URLSearchParams", "DOMParser", "MutationObserver", "getComputedStyle",
  "requestAnimationFrame", "cancelAnimationFrame", "AbortController", "AbortSignal",
];

class Page {
  constructor(dom, { listeners }) {
    this.dom = dom;
    this.window = dom.window;
    this.document = dom.window.document;
    this.listeners = listeners;
    this.errors = [];
    this.dom.window.addEventListener("error", (event) => this.errors.push(event.error ?? event.message));
  }

  // ─── дерево ──────────────────────────────────────────────────────────

  $(selector, root = this.document) {
    return root.querySelector(selector);
  }

  $$(selector, root = this.document) {
    return [...root.querySelectorAll(selector)];
  }

  // Узел, который обязан быть: иначе проверка падает с понятной причиной.
  need(selector, why = "") {
    const node = this.$(selector);
    if (!node) throw new Error(`на странице нет ${selector}${why ? ` — ${why}` : ""}`);
    return node;
  }

  text(selectorOrNode) {
    const node = typeof selectorOrNode === "string" ? this.$(selectorOrNode) : selectorOrNode;
    return (node?.textContent ?? "").replace(/\s+/g, " ").trim();
  }

  attr(selectorOrNode, name) {
    const node = typeof selectorOrNode === "string" ? this.$(selectorOrNode) : selectorOrNode;
    return node?.getAttribute(name) ?? null;
  }

  classes(selectorOrNode) {
    const node = typeof selectorOrNode === "string" ? this.$(selectorOrNode) : selectorOrNode;
    return [...(node?.classList ?? [])];
  }

  // Слепок дерева: чем сравнивать «до» и «после» без оглядки на пробелы.
  snapshot(selector = "body") {
    return this.$(selector).innerHTML.replace(/>\s+</g, "><").trim();
  }

  // ─── действия ────────────────────────────────────────────────────────

  async click(selectorOrNode, init = {}) {
    const node = typeof selectorOrNode === "string" ? this.need(selectorOrNode) : selectorOrNode;
    node.dispatchEvent(new this.window.MouseEvent("click", { bubbles: true, cancelable: true, ...init }));
    await this.tick();
  }

  async fill(selectorOrNode, value) {
    const node = typeof selectorOrNode === "string" ? this.need(selectorOrNode) : selectorOrNode;
    node.value = value;
    node.dispatchEvent(new this.window.Event("input", { bubbles: true }));
    node.dispatchEvent(new this.window.Event("change", { bubbles: true }));
    await this.tick();
  }

  // Отправка формы так, как её видит обработчик: событие всплывает и
  // отменяемо. Самой отправки на сервер jsdom не делает — и это честно:
  // проверять настоящую отправку надо в браузере (серии с NEEDS_BROWSER).
  async submit(selectorOrNode) {
    const form = typeof selectorOrNode === "string" ? this.need(selectorOrNode) : selectorOrNode;
    const event = new this.window.Event("submit", { bubbles: true, cancelable: true });
    form.dispatchEvent(event);
    await this.tick();
    return { prevented: event.defaultPrevented };
  }

  async press(selectorOrNode, key, init = {}) {
    const node = typeof selectorOrNode === "string" ? this.need(selectorOrNode) : selectorOrNode;
    node.dispatchEvent(new this.window.KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...init }));
    await this.tick();
  }

  async emit(target, type, detail) {
    const node = typeof target === "string" ? this.need(target) : target;
    node.dispatchEvent(new this.window.CustomEvent(type, { bubbles: true, cancelable: true, detail }));
    await this.tick();
  }

  // Дать делу дойти: микрозадачи, таймеры нулевой задержки и кадр отрисовки.
  async tick(times = 3) {
    for (let i = 0; i < times; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 0));
    }
  }

  // ─── слушатели ───────────────────────────────────────────────────────

  // Все зарегистрированные слушатели события — с указанием, на чём они висят.
  listenersOf(type) {
    return this.listeners.filter((item) => item.type === type);
  }

  // Слушатели, повешенные на узлы, отвечающие селектору.
  listenersOn(selector, type = null) {
    return this.listeners.filter(
      (item) =>
        item.target?.nodeType === 1 &&
        item.target.matches?.(selector) &&
        (type === null || item.type === type),
    );
  }

  // ─── загрузка модуля ─────────────────────────────────────────────────

  // Модуль импортируется свежим — и не он один. У каждой проверки своя
  // страница, а значит свои window, customElements и HTMLElement; модуль,
  // оставшийся в кэше от прошлой проверки, помнит прошлое окно и определяет
  // теги не там. Поэтому весь набор файлов копируется во временную папку и
  // импортируется оттуда: кэш разводится по путям, а не по строке запроса,
  // которая до соседних импортов всё равно не доезжает.
  async run(moduleFile, extraGlobals = {}) {
    install(this.window, extraGlobals);
    const fresh = copyModules(moduleFile);
    this.scratch = fresh.directory;
    await import(pathToUrl(fresh.entry));
    this.window.document.dispatchEvent(new this.window.Event("DOMContentLoaded", { bubbles: true }));
    await this.tick();
    return this;
  }

  close() {
    this.window.close();
    if (this.scratch) rmSync(this.scratch, { recursive: true, force: true });
    this.scratch = null;
  }
}

// Копия набора модулей на один прогон. Берутся только файлы кода: разметка и
// стили модулю не нужны, их читает страница.
function copyModules(moduleFile) {
  const from = dirname(moduleFile);
  const directory = mkdtempSync(join(tmpdir(), "crimson-"));
  for (const name of readdirSync(from)) {
    if (/\.(mjs|js|json)$/.test(name)) copyFileSync(join(from, name), join(directory, name));
  }
  return { directory, entry: join(directory, basename(moduleFile)) };
}

function pathToUrl(file) {
  return file.startsWith("file:") ? file : new URL(`file://${file}`).href;
}

// Часть глобальных имён у Node свои и объявлены только на чтение (navigator).
// Их приходится переопределять описанием свойства, а не присваиванием.
function put(name, value) {
  try {
    globalThis[name] = value;
  } catch {
    Object.defineProperty(globalThis, name, { value, configurable: true, writable: true });
  }
}

function install(window, extra) {
  for (const name of GLOBALS) {
    if (name in window) put(name, window[name]);
  }
  put("window", window);
  put("fetch", extra.fetch ?? fetch);
  for (const [name, value] of Object.entries(extra)) put(name, value);
}

// Страница из файла разметки. url важен: от него считаются ссылки, history
// и то, что увидит location.
export function openDocument(htmlFile, { url = "http://localhost/telegraph", state = "loading" } = {}) {
  const dom = new JSDOM(readFileSync(htmlFile, "utf8"), {
    url,
    pretendToBeVisual: true,
    contentType: "text/html",
  });

  // Учёт слушателей: не для того, чтобы читать чужой код, а чтобы спросить
  // «сколько их и на чём они висят». Один слушатель на список и сто на строки —
  // разное поведение, а не разный стиль.
  const listeners = [];
  const original = dom.window.EventTarget.prototype.addEventListener;
  dom.window.EventTarget.prototype.addEventListener = function record(type, handler, options) {
    listeners.push({ target: this, type, options });
    return original.call(this, type, handler, options);
  };

  if (state === "loading") {
    Object.defineProperty(dom.window.document, "readyState", { value: "loading", configurable: true });
  }
  return new Page(dom, { listeners });
}

// Разметка без единого модуля: что достанется читателю, у которого скрипт не
// доехал. Это основной вопрос сезона, и задают его именно так.
export function openWithoutScript(htmlFile, options = {}) {
  return openDocument(htmlFile, options);
}
