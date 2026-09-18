// office.js — разговор с конторой.
//
// Подделка кончилась: здесь настоящий запрос по проводу. Ничего, кроме fetch,
// для этого не нужно — ни библиотеки, ни обёртки.
//
// Три вещи, которых у подделки не было и которые начинаются ровно здесь:
//   код ответа    контора отвечает числом, и число значит разное;
//   отмена        запрос можно оборвать, а не только перестать ждать;
//   повтор        отправить дважды — не то же, что завести две записи.

export class OfficeError extends Error {
  constructor(message, { status = null, field = null, cause = null, retriable = false } = {}) {
    super(message, { cause });
    this.name = "OfficeError";
    this.status = status;
    this.field = field;      // какое поле не понравилось конторе
    this.retriable = retriable; // имеет ли смысл повторять
  }
}

// Передать запись. Возвращает то, что завела контора, — с её номером.
//
// Ключ приёма (receipt) — против задвоения: сеть могла оборвать ответ уже
// после того, как контора записала. Повтор с тем же ключом контора узнаёт и
// второй записи не заводит. Это то же, что номер квитанции у Дарнелл.
export async function send(entry, { origin = "", signal, receipt } = {}) {
  const answer = await ask(`${origin}/entries`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(receipt ? { "x-receipt": receipt } : {}),
    },
    body: JSON.stringify(entry),
    signal,
  });

  const payload = await parse(answer);

  if (answer.status === 422) {
    throw new OfficeError(payload?.error ?? "контора не приняла запись", {
      status: 422,
      field: payload?.field ?? null,
    });
  }

  if (!answer.ok) {
    throw new OfficeError(`контора ответила ${answer.status}`, {
      status: answer.status,
      // Пятисотые — это «попробуйте позже». Четырёхсотые — «так нельзя».
      retriable: answer.status >= 500,
    });
  }

  return payload.entry;
}

// Забрать журнал. Отбор делает контора: у неё записей больше, чем на странице.
export async function load({ origin = "", state = "", signal } = {}) {
  const address = new URL(`${origin}/entries`, "http://localhost");
  if (state) address.searchParams.set("state", state);

  const answer = await ask(origin ? address.href : `${address.pathname}${address.search}`, { signal });
  const payload = await parse(answer);

  if (!answer.ok) {
    throw new OfficeError(`контора ответила ${answer.status}`, {
      status: answer.status,
      retriable: answer.status >= 500,
    });
  }

  return payload.entries ?? [];
}

// Повтор с выдержкой — и с тем же ключом приёма, иначе повтор заведёт вторую
// запись. Повторяют только то, что имеет смысл повторять.
export async function withRetry(work, { times = 3, pause = 50 } = {}) {
  let last;
  for (let attempt = 1; attempt <= times; attempt += 1) {
    try {
      return await work(attempt);
    } catch (error) {
      last = error;
      if (!error?.retriable || attempt === times) throw error;
      await new Promise((resolve) => setTimeout(resolve, pause * attempt));
    }
  }
  throw last;
}

// Сам поход. Отдельно — потому что обрыв провода и отмена выглядят
// одинаково (fetch отклоняется), а значат разное.
async function ask(address, options) {
  try {
    return await fetch(address, options);
  } catch (error) {
    if (error?.name === "AbortError") throw error; // отмену не переодевают
    throw new OfficeError("до конторы не достучаться", { cause: error, retriable: true });
  }
}

async function parse(answer) {
  const type = answer.headers.get("content-type") ?? "";
  if (!type.includes("json")) return null;
  try {
    return await answer.json();
  } catch {
    return null;
  }
}
