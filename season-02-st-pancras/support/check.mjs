// CRIMSON RAILS — библиотека проверок сезона 2.
//
// Общая на весь сезон: тесты серий пользуются ею и не разбирают разметку
// руками. Ничего из того, что здесь написано, студент не пишет — это
// инструмент проверки, а не предмет изучения.
//
// Разбор разметки — parse5, ровно по правилам браузера.
// Разбор стилей — css-tree.

import { readFileSync, existsSync } from "node:fs";
import { parse, parseFragment } from "parse5";
import * as csstree from "css-tree";

// ─── разметка ──────────────────────────────────────────────────────────

const VOID = new Set([
  "area", "base", "br", "col", "embed", "hr", "img", "input",
  "link", "meta", "source", "track", "wbr",
]);

const SECTIONING = new Set(["article", "aside", "nav", "section"]);
const LANDMARKS = new Set(["header", "footer", "main", "nav", "aside", "form", "section"]);

class Doc {
  constructor(tree, source) {
    this.tree = tree;
    this.source = source;
  }

  // Обход всех элементов в порядке документа.
  *walk(node = this.tree) {
    for (const child of node.childNodes ?? []) {
      if (child.tagName) {
        yield child;
        yield* this.walk(child);
      }
      if (child.nodeName === "template" && child.content) yield* this.walk(child.content);
    }
  }

  all(...tags) {
    const wanted = new Set(tags.map((t) => t.toLowerCase()));
    return [...this.walk()].filter((n) => wanted.has(n.tagName));
  }

  first(...tags) {
    return this.all(...tags)[0] ?? null;
  }

  count(...tags) {
    return this.all(...tags).length;
  }

  attr(node, name) {
    if (!node) return null;
    const found = (node.attrs ?? []).find((a) => a.name === name.toLowerCase());
    return found ? found.value : null;
  }

  hasAttr(node, name) {
    return this.attr(node, name) !== null;
  }

  tag(node) {
    return node?.tagName ?? null;
  }

  children(node) {
    return (node?.childNodes ?? []).filter((n) => n.tagName);
  }

  parent(node) {
    return node?.parentNode?.tagName ? node.parentNode : null;
  }

  ancestors(node) {
    const chain = [];
    let current = node?.parentNode;
    while (current?.tagName) {
      chain.push(current);
      current = current.parentNode;
    }
    return chain;
  }

  closest(node, ...tags) {
    const wanted = new Set(tags.map((t) => t.toLowerCase()));
    return this.ancestors(node).find((a) => wanted.has(a.tagName)) ?? null;
  }

  text(node = this.tree) {
    let out = "";
    const visit = (n) => {
      for (const child of n.childNodes ?? []) {
        if (child.nodeName === "#text") out += child.value;
        else if (child.tagName !== "script" && child.tagName !== "style") visit(child);
      }
    };
    visit(node);
    return out.replace(/\s+/g, " ").trim();
  }

  byId(id) {
    return [...this.walk()].find((n) => this.attr(n, "id") === id) ?? null;
  }

  // Заголовки в порядке документа: [{ level, text, node }]
  headings() {
    return this.all("h1", "h2", "h3", "h4", "h5", "h6").map((node) => ({
      level: Number(node.tagName[1]),
      text: this.text(node),
      node,
    }));
  }

  // Пропуск уровня: h2 → h4. Возвращает список нарушений.
  headingJumps() {
    const jumps = [];
    let previous = 0;
    for (const heading of this.headings()) {
      if (previous && heading.level > previous + 1) {
        jumps.push({ from: previous, to: heading.level, text: heading.text });
      }
      previous = heading.level;
    }
    return jumps;
  }

  landmarks() {
    return this.all(...LANDMARKS);
  }

  // Элемент внутри <template> считается объявлением, а не содержимым.
  isInTemplate(node) {
    return this.ancestors(node).some((a) => a.tagName === "template");
  }

  // ── формы ──
  // Поле считается подписанным, если есть label[for=id] или label-обёртка.
  labelFor(field) {
    const id = this.attr(field, "id");
    if (id) {
      const byFor = this.all("label").find((l) => this.attr(l, "for") === id);
      if (byFor) return byFor;
    }
    return this.closest(field, "label");
  }

  fields() {
    return this.all("input", "select", "textarea").filter(
      (n) => !["hidden", "submit", "reset", "button", "image"].includes(
        (this.attr(n, "type") ?? "text").toLowerCase(),
      ),
    );
  }

  // ── таблицы ──
  tables() {
    return this.all("table").map((table) => new Table(this, table));
  }
}

class Table {
  constructor(doc, node) {
    this.doc = doc;
    this.node = node;
  }

  get caption() {
    return this.doc.children(this.node).find((c) => c.tagName === "caption") ?? null;
  }

  section(name) {
    return this.doc.children(this.node).find((c) => c.tagName === name) ?? null;
  }

  rows() {
    return [...this.doc.walk(this.node)].filter((n) => n.tagName === "tr");
  }

  // Строки шапки и строки тела — разные вещи: в шапке заголовки столбцов,
  // в теле первая ячейка обычно заголовок строки.
  headRows() {
    const head = this.section("thead");
    return head ? [...this.doc.walk(head)].filter((n) => n.tagName === "tr") : [];
  }

  bodyRows() {
    const body = this.section("tbody");
    if (body) return [...this.doc.walk(body)].filter((n) => n.tagName === "tr");
    const head = new Set(this.headRows());
    return this.rows().filter((r) => !head.has(r));
  }

  cells(row) {
    return this.doc.children(row).filter((c) => c.tagName === "th" || c.tagName === "td");
  }

  // Ширина строки с учётом colspan.
  widthOf(row) {
    return this.cells(row).reduce(
      (sum, cell) => sum + Number(this.doc.attr(cell, "colspan") ?? 1),
      0,
    );
  }

  widths() {
    return this.rows().map((row) => this.widthOf(row));
  }

  headerCells() {
    return [...this.doc.walk(this.node)].filter((n) => n.tagName === "th");
  }

  // Заголовки без scope и без headers — те, что не читаются вслух.
  unscopedHeaders() {
    return this.headerCells().filter(
      (th) => !this.doc.attr(th, "scope") && !this.doc.attr(th, "headers"),
    );
  }
}

export function readDocument(file) {
  if (!existsSync(file)) throw new Error(`нет файла ${file}`);
  const source = readFileSync(file, "utf8");
  return new Doc(parse(source), source);
}

export function documentFrom(html) {
  return new Doc(parse(html), html);
}

export function fragmentFrom(html) {
  return new Doc(parseFragment(html), html);
}

// ─── стили ─────────────────────────────────────────────────────────────

class Sheet {
  constructor(ast, source) {
    this.ast = ast;
    this.source = source;
    this.rules = [];
    this.#collect();
  }

  #collect() {
    // Обход с запоминанием, внутри какого @media лежит правило.
    const stack = [];
    csstree.walk(this.ast, {
      enter: (node) => {
        if (node.type === "Atrule" && node.name === "media") {
          stack.push(csstree.generate(node.prelude).trim());
        }
        if (node.type !== "Rule") return;

        const declarations = {};
        csstree.walk(node.block, {
          visit: "Declaration",
          enter: (decl) => {
            declarations[decl.property.toLowerCase()] = {
              value: csstree.generate(decl.value).trim(),
              important: Boolean(decl.important),
            };
          },
        });
        const media = stack.length ? stack[stack.length - 1] : null;
        // Список селекторов режется по узлам разбора, а не по запятым в строке:
        // запятая живёт и внутри :where(a, b), и там она ничего не разделяет.
        const list =
          node.prelude.type === "SelectorList"
            ? node.prelude.children.toArray().map((sel) => csstree.generate(sel).trim())
            : [csstree.generate(node.prelude).trim()];
        for (const selector of list) {
          if (selector) this.rules.push({ selector, declarations, media });
        }
      },
      leave: (node) => {
        if (node.type === "Atrule" && node.name === "media") stack.pop();
      },
    });
  }

  // Правила вне всяких медиазапросов — те, что действуют всегда.
  get base() {
    return this.rules.filter((r) => r.media === null);
  }

  selectors() {
    return this.rules.map((r) => r.selector);
  }

  // Правила, выбирающие ровно этот селектор (как написано).
  // По умолчанию — только вне медиазапросов: внутри них живёт переопределение,
  // и смешивать их в одну кучу значит потерять, что чем перекрыто.
  for(selector, { anyMedia = false } = {}) {
    const wanted = normalize(selector);
    return this.rules.filter(
      (r) => normalize(r.selector) === wanted && (anyMedia || r.media === null),
    );
  }

  // Последнее объявление свойства по селектору — то, что победит при равной
  // специфичности.
  valueOf(selector, property) {
    const found = this.for(selector)
      .map((r) => r.declarations[property.toLowerCase()])
      .filter(Boolean);
    return found.length ? found[found.length - 1].value : null;
  }

  declared(property) {
    return this.rules.filter((r) => r.declarations[property.toLowerCase()]);
  }

  important() {
    const found = [];
    for (const rule of this.rules) {
      for (const [property, decl] of Object.entries(rule.declarations)) {
        if (decl.important) found.push({ selector: rule.selector, property });
      }
    }
    return found;
  }

  mediaQueries() {
    const queries = [];
    csstree.walk(this.ast, {
      visit: "Atrule",
      enter: (atrule) => {
        if (atrule.name === "media") queries.push(csstree.generate(atrule.prelude).trim());
      },
    });
    return queries;
  }

  // Правила внутри конкретного медиазапроса (по подстроке условия).
  insideMedia(match) {
    return this.rules.filter((r) => r.media !== null && r.media.includes(match));
  }

  // Пользовательские свойства, объявленные у селектора.
  customProperties(selector) {
    const out = {};
    for (const rule of this.for(selector)) {
      for (const [property, decl] of Object.entries(rule.declarations)) {
        if (property.startsWith("--")) out[property] = decl.value;
      }
    }
    return out;
  }

  // Использованные пользовательские свойства: var(--x)
  usedCustomProperties() {
    const used = new Set();
    csstree.walk(this.ast, {
      visit: "Function",
      enter: (node) => {
        if (node.name !== "var") return;
        const first = node.children.first;
        if (first?.type === "Identifier" && first.name.startsWith("--")) used.add(first.name);
      },
    });
    return [...used];
  }
}

function normalize(selector) {
  return selector.replace(/\s+/g, " ").replace(/\s*([>+~,])\s*/g, "$1").trim();
}

// Специфичность селектора: [идентификаторы, классы/атрибуты/псевдоклассы, теги].
export function specificity(selector) {
  let ids = 0;
  let classes = 0;
  let types = 0;
  const ast = csstree.parse(selector, { context: "selector" });
  csstree.walk(ast, (node) => {
    if (node.type === "IdSelector") ids += 1;
    else if (node.type === "ClassSelector" || node.type === "AttributeSelector") classes += 1;
    else if (node.type === "PseudoClassSelector") {
      if (!["not", "is", "where", "has"].includes(node.name)) classes += 1;
      if (node.name === "where") return csstree.walk.skip;
    } else if (node.type === "TypeSelector") types += 1;
    else if (node.type === "PseudoElementSelector") types += 1;
    return undefined;
  });
  return [ids, classes, types];
}

export function compareSpecificity(a, b) {
  const left = specificity(a);
  const right = specificity(b);
  for (let i = 0; i < 3; i += 1) {
    if (left[i] !== right[i]) return left[i] - right[i];
  }
  return 0;
}

export function readStylesheet(file) {
  if (!existsSync(file)) throw new Error(`нет файла ${file}`);
  const source = readFileSync(file, "utf8");
  return new Sheet(csstree.parse(source, { positions: false }), source);
}

export function stylesheetFrom(css) {
  return new Sheet(csstree.parse(css), css);
}

// ─── цвет и контраст ───────────────────────────────────────────────────

export function parseColor(input) {
  const value = String(input).trim().toLowerCase();
  const named = { white: [255, 255, 255], black: [0, 0, 0] };
  if (named[value]) return named[value];

  const hex = value.match(/^#([0-9a-f]{3,8})$/);
  if (hex) {
    let digits = hex[1];
    if (digits.length === 3 || digits.length === 4) {
      digits = [...digits].map((d) => d + d).join("");
    }
    return [0, 2, 4].map((i) => parseInt(digits.slice(i, i + 2), 16));
  }

  const rgb = value.match(/^rgba?\(([^)]+)\)$/);
  if (rgb) {
    const parts = rgb[1].split(/[\s,/]+/).filter(Boolean).slice(0, 3);
    return parts.map((p) => (p.endsWith("%") ? Math.round(parseFloat(p) * 2.55) : Number(p)));
  }

  throw new Error(`не умею разбирать цвет ${input}`);
}

function channel(value) {
  const c = value / 255;
  return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
}

export function relativeLuminance(color) {
  const [r, g, b] = parseColor(color);
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
}

// Коэффициент контраста по WCAG 2: от 1 до 21.
export function contrast(foreground, background) {
  const a = relativeLuminance(foreground);
  const b = relativeLuminance(background);
  const [light, dark] = a > b ? [a, b] : [b, a];
  return (light + 0.05) / (dark + 0.05);
}

export const VOID_ELEMENTS = VOID;
export const SECTIONING_ELEMENTS = SECTIONING;
