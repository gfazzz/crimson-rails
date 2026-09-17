// CRIMSON RAILS — проверки раскладки в настоящем браузере.
//
// Нужны только двум сериям сезона — Flexbox и Grid. Они помечены файлом
// NEEDS_BROWSER и в основной прогон не входят: `make test-visual`.
//
// Разбор разметки отвечает на вопрос «что написано». Здесь спрашивают
// «что получилось»: настоящие координаты боксов и вычисленные значения,
// посчитанные тем же движком, что у читателя.

import { readFileSync } from "node:fs";
import { chromium } from "playwright";

export async function openPage(htmlFile, cssFile, { width = 1024, height = 768 } = {}) {
  const html = readFileSync(htmlFile, "utf8");
  const css = readFileSync(cssFile, "utf8");

  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width, height } });
  const page = await context.newPage();
  await page.setContent(html, { waitUntil: "load" });
  await page.addStyleTag({ content: css });

  return {
    page,

    // Прямоугольник элемента: x, y, width, height — в пикселях страницы.
    async box(selector) {
      const found = await page.$(selector);
      if (!found) throw new Error(`на странице нет ${selector}`);
      const box = await found.boundingBox();
      if (!box) throw new Error(`${selector} не отрисован (скрыт?)`);
      return box;
    },

    async boxes(selector) {
      return page.$$eval(selector, (nodes) =>
        nodes.map((n) => {
          const r = n.getBoundingClientRect();
          return { x: r.x, y: r.y, width: r.width, height: r.height };
        }),
      );
    },

    // Вычисленное значение — то, что браузер решил на самом деле.
    async computed(selector, property) {
      return page.$eval(
        selector,
        (node, prop) => getComputedStyle(node).getPropertyValue(prop),
        property,
      );
    },

    async count(selector) {
      return page.$$eval(selector, (nodes) => nodes.length);
    },

    // Сколько визуальных рядов образовали элементы: считаем по верхней грани.
    async rowsOf(selector, tolerance = 2) {
      const list = await this.boxes(selector);
      const tops = [];
      for (const item of list) {
        if (!tops.some((t) => Math.abs(t - item.y) <= tolerance)) tops.push(item.y);
      }
      return tops.length;
    },

    // Есть ли горизонтальная прокрутка у страницы целиком.
    async overflowsHorizontally() {
      return page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
      );
    },

    async resize(w, h = height) {
      await page.setViewportSize({ width: w, height: h });
    },

    async close() {
      await browser.close();
    },
  };
}
