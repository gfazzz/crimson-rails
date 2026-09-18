// CRIMSON RAILS — проверки в настоящем браузере, сезон 3.
//
// Нужны там, где jsdom честно говорит «не умею»: настоящая отправка формы и
// переход по ней, фокус, живые области. Две серии сезона помечены файлом
// NEEDS_BROWSER и в основной прогон не входят: `make test-visual SEASON=03`.
//
// Страница открывается не из файла, а с сервера: иначе браузер не загрузит
// модуль (модули не грузятся по file://) и форме некуда будет отправляться.

import { chromium } from "playwright";
import { startOffice } from "./server.mjs";

export async function openSite(directory, { page = "telegraph.html", script = true, ...office } = {}) {
  const site = await startOffice({ serve: directory, ...office });
  const browser = await chromium.launch({
    // Браузер без лишних походов наружу: проверке нужен только наш сервер.
    args: ["--disable-background-networking", "--disable-component-update", "--no-first-run", "--disable-sync"],
  });
  const context = await browser.newContext({
    viewport: { width: 1024, height: 768 },
    javaScriptEnabled: script,
  });
  const tab = await context.newPage();
  const problems = [];
  tab.on("pageerror", (error) => problems.push(String(error)));
  await tab.goto(`${site.origin}/${page}`, { waitUntil: "load" });

  return {
    tab,
    site,
    problems,

    url: () => new URL(tab.url()),
    path: () => new URL(tab.url()).pathname + new URL(tab.url()).search,

    async text(selector) {
      return (await tab.textContent(selector))?.replace(/\s+/g, " ").trim() ?? null;
    },

    async count(selector) {
      return tab.$$eval(selector, (nodes) => nodes.length);
    },

    async attr(selector, name) {
      return tab.getAttribute(selector, name);
    },

    // Свой тег поднят или нет: до определения браузер даёт ему HTMLElement.
    async upgraded(selector) {
      return tab.$eval(selector, (node) => node.constructor.name !== "HTMLElement");
    },

    async focusOn(selector) {
      await tab.focus(selector);
    },

    // Прямой доступ к странице — там, где проверке нужно сделать то, что
    // делает не читатель: подменить атрибут, снять узел, позвать метод.
    async evaluate(work, argument) {
      return tab.evaluate(work, argument);
    },

    async wait(ms) {
      await tab.waitForTimeout(ms);
    },

    async fill(selector, value) {
      await tab.fill(selector, value);
    },

    async select(selector, value) {
      await tab.selectOption(selector, value);
    },

    async click(selector) {
      await tab.click(selector);
    },

    // Отправка формы так, как её отправляет читатель: нажатием кнопки.
    // Со скриптом переход не случится, без скрипта — случится; это и есть
    // главный вопрос сезона, и другого способа его задать нет.
    async submitAndSettle(selector = "button[type=submit], input[type=submit]") {
      const navigated = tab
        .waitForNavigation({ timeout: 1500 })
        .then(() => true)
        .catch(() => false);
      await tab.click(selector);
      const moved = await navigated;
      await tab.waitForTimeout(150);
      return moved;
    },

    // Отправка формы без нажатия на кнопку — так же, как её отправляет Enter
    // в поле. Нужна там, где кнопка спрятана: со скриптом кнопка отбора не
    // нужна, а форма всё равно может быть отправлена.
    async submitByCode(selector) {
      const navigated = tab
        .waitForNavigation({ timeout: 1500 })
        .then(() => true)
        .catch(() => false);
      await tab.evaluate((css) => document.querySelector(css).requestSubmit(), selector);
      const moved = await navigated;
      await tab.waitForTimeout(150);
      return moved;
    },

    async focused() {
      return tab.evaluate(() => {
        const node = document.activeElement;
        if (!node || node === document.body) return null;
        return {
          tag: node.tagName.toLowerCase(),
          id: node.id || null,
          name: node.getAttribute("name"),
          text: (node.textContent ?? "").trim().slice(0, 40),
        };
      });
    },

    async computed(selector, property) {
      return tab.$eval(selector, (node, name) => getComputedStyle(node).getPropertyValue(name), property);
    },

    async box(selector) {
      const found = await tab.$(selector);
      return found ? found.boundingBox() : null;
    },

    async close() {
      await browser.close();
      await site.close();
    },
  };
}
