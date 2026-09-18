// CRIMSON RAILS — настоящий сервер для проверок сезона 3.
//
// Запрос по проводу проверяется запросом по проводу: node:http поднимает
// сервер на свободном порту, модуль ходит к нему тем же fetch, что и в
// браузере. Подставного fetch в этом сезоне нет — подставной fetch проверяет
// подставной fetch.

import { createServer } from "node:http";
import { existsSync, readFileSync, statSync } from "node:fs";
import { extname, join, normalize } from "node:path";

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
};

// Журнал приёмной конторы: то немногое, что нужно сериям про запросы.
export async function startOffice({ entries = [], latency = 0, failFirst = 0, serve = null } = {}) {
  const log = [];
  let failures = failFirst;
  let nextId = entries.reduce((max, entry) => Math.max(max, entry.id ?? 0), 0) + 1;
  const store = entries.map((entry) => ({ ...entry }));
  const receipts = new Map();

  const server = createServer(async (request, response) => {
    const url = new URL(request.url, "http://127.0.0.1");
    const body = await readBody(request);
    log.push({ method: request.method, path: url.pathname, query: url.searchParams, headers: request.headers, body });

    if (latency) await new Promise((resolve) => setTimeout(resolve, latency));

    const send = (status, payload, headers = {}) => {
      response.writeHead(status, { "content-type": "application/json; charset=utf-8", ...headers });
      response.end(payload === undefined ? "" : JSON.stringify(payload));
    };

    if (failures > 0 && request.method !== "GET") {
      failures -= 1;
      return send(503, { error: "линия занята" });
    }

    // Раздача файлов: нужна там, где страницу открывает настоящий браузер, —
    // он сам должен сходить и за разметкой, и за модулем.
    if (serve && request.method === "GET" && url.pathname !== "/entries") {
      const file = join(serve, normalize(url.pathname).replace(/^(\.\.[/\\])+/, ""));
      if (existsSync(file) && statSync(file).isFile()) {
        response.writeHead(200, { "content-type": TYPES[extname(file)] ?? "application/octet-stream" });
        const body = readFileSync(file);
        // Страница отдаётся так, как её отдал бы Rails: отбор взят из адреса
        // и применён до отправки. Читателю без скрипта этого достаточно —
        // и ровно этот же адрес потом пишет в историю модуль.
        if (extname(file) === ".html" && url.searchParams.has("state")) {
          return response.end(sift(body.toString("utf8"), url.searchParams.get("state")));
        }
        return response.end(body);
      }
    }

    if (request.method === "GET" && url.pathname === "/entries") {
      const state = url.searchParams.get("state");
      const found = state ? store.filter((entry) => entry.state === state) : store;
      return send(200, { entries: found });
    }

    if (request.method === "POST" && url.pathname === "/entries") {
      // Форма без скрипта присылает поля кодировкой формы и ждёт перехода.
      // Модуль присылает JSON и ждёт ответа. Контора отвечает по тому, чем
      // спросили, — так же, как это делает Rails.
      const asForm = (request.headers["content-type"] ?? "").includes("x-www-form-urlencoded");
      let parsed;
      if (asForm) {
        parsed = Object.fromEntries(new URLSearchParams(body));
      } else {
        try {
          parsed = JSON.parse(body || "{}");
        } catch {
          return send(400, { error: "не разобрать" });
        }
      }
      if (!parsed.text) {
        if (asForm) {
          response.writeHead(303, { location: "/telegraph.html?error=text" });
          return response.end();
        }
        return send(422, { error: "текст пуст", field: "text" });
      }

      // Ключ приёма: повторная отправка того же не заводит вторую запись.
      const receipt = request.headers["x-receipt"];
      if (receipt && receipts.has(receipt)) return send(200, receipts.get(receipt));

      const entry = { id: nextId, state: "sent", ...parsed };
      nextId += 1;
      store.push(entry);
      if (receipt) receipts.set(receipt, { entry });
      if (asForm) {
        response.writeHead(303, { location: `/telegraph.html?sent=${entry.id}` });
        return response.end();
      }
      return send(201, { entry }, { location: `/entries/${entry.id}` });
    }

    return send(404, { error: "нет такого" });
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();

  return {
    origin: `http://127.0.0.1:${port}`,
    log,
    entries: () => store.map((entry) => ({ ...entry })),
    // Запросы одного вида: чем считать, сколько раз спросили и с чем.
    calls: (method, path) => log.filter((item) => item.method === method && item.path === path),
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

// Отбор на стороне сервера: то немногое из Rails, что нужно финалу сезона.
// Строки не подходящего состояния из разметки убираются, выбор в форме
// отмечается — страница приходит уже в нужном виде.
function sift(html, wanted) {
  const kept = wanted
    ? html.replace(
        /\n\s*<li data-id="[^"]*" data-state="([^"]*)"[\s\S]*?<\/li>/g,
        (block, state) => (state === wanted ? block : ""),
      )
    : html;
  return kept.replace(
    new RegExp(`<option value="${wanted.replace(/[^\w-]/g, "")}"`),
    (tag) => `${tag} selected`,
  );
}

function readBody(request) {
  return new Promise((resolve) => {
    let text = "";
    request.on("data", (chunk) => {
      text += chunk;
    });
    request.on("end", () => resolve(text));
  });
}
