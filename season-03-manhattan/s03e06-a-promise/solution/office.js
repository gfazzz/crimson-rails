// office.js — разговор с линией.
//
// Этот модуль знает про линию ровно одно: ей дают запись, она возвращает
// обещание. Как она устроена — дело wire.js (в этой серии подделка, в s03e07
// настоящий провод).
//
// Всё остальное здесь — про то, что бывает с обещаниями: они разрешаются,
// отклоняются и не разрешаются вовсе. Третий случай самый неприятный, потому
// что ошибки при нём не происходит.

// Своя ошибка: по ней видно, что отказала именно линия, и видно, какая
// запись. Пойманная ошибка без записи, к которой она относится, бесполезна.
export class LineError extends Error {
  constructor(message, { id, cause } = {}) {
    super(message, { cause });
    this.name = "LineError";
    // Номер записи — строкой, как и в состоянии: сравнивать «5» с 5 однажды
    // перестанет получаться, и выяснится это не здесь.
    this.id = id === undefined || id === null ? null : String(id);
  }
}

// Подтверждение приёма одной записи.
//
// Таймаут не «ускоряет» линию — он ограничивает **ожидание**. Обещание,
// которое не разрешается, само по себе не ошибка: оно просто никогда не
// кончится, и запись останется в состоянии «передаётся» до перезагрузки.
export function acknowledge(entry, wire, { timeout = 2000 } = {}) {
  return new Promise((resolve, reject) => {
    let settled = false;

    const timer = setTimeout(() => {
      if (settled) return;
      settled = true;
      reject(new LineError("линия не ответила вовремя", { id: entry.id }));
    }, timeout);

    Promise.resolve()
      .then(() => wire(entry))
      .then(
        (answer) => {
          if (settled) return; // поздний ответ: ждать его уже перестали
          settled = true;
          clearTimeout(timer);
          resolve({ id: String(entry.id), state: "sent", hand: answer?.hand ?? null });
        },
        (error) => {
          if (settled) return;
          settled = true;
          clearTimeout(timer);
          reject(new LineError(`подтверждение не пришло: ${error.message}`, { id: entry.id, cause: error }));
        },
      );
  });
}

// Подтверждение приёма нескольких записей.
//
// Сразу все, а не по очереди: линия одна, но ждём мы параллельно — иначе шесть
// записей по две секунды дают двенадцать секунд ожидания вместо двух.
//
// Ни один отказ не отменяет остальных: Promise.all при первом же отказе
// бросает всё, а нам нужен отчёт по каждой записи.
//
// И ещё одно, из-за чего здесь не просто allSettled: отчёт готов, когда
// ответил последний. Один молчащий пост задержал бы весь журнал на весь
// таймаут. Поэтому о каждом ответе сообщают сразу, как он пришёл, — onSettled,
// — а отчёт возвращают в конце, для тех, кому нужен итог.
export async function acknowledgeAll(entries, wire, { onSettled, ...options } = {}) {
  const answers = await Promise.allSettled(
    entries.map(async (entry) => {
      try {
        const answer = await acknowledge(entry, wire, options);
        onSettled?.({ id: answer.id, state: "sent" });
        return answer;
      } catch (error) {
        onSettled?.({ id: String(entry.id), state: "failed", reason: error.message });
        throw error;
      }
    }),
  );

  const sent = [];
  const failed = [];
  answers.forEach((answer, index) => {
    if (answer.status === "fulfilled") {
      sent.push(answer.value);
    } else {
      failed.push({ id: String(entries[index].id), reason: answer.reason?.message ?? String(answer.reason) });
    }
  });

  // Порядок отчёта — порядок записей, а не порядок ответов: линия отвечает
  // как придётся, а журнал ведут по порядку.
  return { sent, failed };
}
