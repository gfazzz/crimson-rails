# Теория — s03e03

## 1. Путь события

Событие не «случается на узле». У него есть путь — от корня документа к цели и
обратно:

| Фаза | Что происходит | Константа |
|---|---|---|
| погружение | сверху вниз, до цели | `CAPTURING_PHASE` (1) |
| цель | на самом узле | `AT_TARGET` (2) |
| всплытие | снизу вверх, до корня | `BUBBLING_PHASE` (3) |

```js
node.addEventListener("click", handler);        // услышит на всплытии
node.addEventListener("click", handler, true);  // услышит на погружении
```

Погружение нужно редко: им перехватывают событие раньше всех (например, чтобы
закрыть всплывающее окно до того, как сработает что-то внутри).

Всплывают почти все события. Не всплывают: `focus`, `blur`, `load`, `error`,
`abort`, большинство событий медиа. У первых двух есть всплывающие двойники —
`focusin` и `focusout`.

## 2. Объект события

```js
event.type            "click"
event.target          узел, на котором началось
event.currentTarget   узел, на котором слушают (внутри обработчика)
event.eventPhase      1, 2 или 3
event.timeStamp       миллисекунды от загрузки страницы
event.isTrusted       true, если событие от читателя, а не от кода
event.composedPath()  весь путь списком, включая теневые деревья
```

`currentTarget` доступен **только пока идёт обработчик**: после него он `null`.
В асинхронном коде его надо сохранить в переменную заранее.

## 3. Отмена

```js
event.preventDefault();      отменить действие браузера
event.stopPropagation();     не пускать событие дальше по пути
event.stopImmediatePropagation();  и другим слушателям того же узла тоже
event.defaultPrevented;      отменял ли кто-нибудь уже
```

Что бывает действием по умолчанию: переход по ссылке, отправка формы,
прокрутка на пробел, выделение на двойное нажатие, ввод символа, контекстное
меню.

**Правило:** `preventDefault` уместен только там, где есть чем заменить.
Отменённая отправка формы без своей отправки — это форма, которая перестала
работать, и ошибки при этом не будет.

`stopPropagation` рвёт линию: слушатели выше перестают слышать. Почти всегда
это лечение симптома; настоящая причина — два обработчика, которые не должны
были пересечься.

Не работает: `return false` в обработчике, повешенном через
`addEventListener`. Это наследие атрибутов (`onclick="… ; return false"`), и
там оно значило `preventDefault` плюс `stopPropagation`.

## 4. Делегирование

```js
register.addEventListener("click", (event) => {
  const entry = event.target.closest("li[data-id]");
  if (!entry || !register.contains(entry)) return;
  if (event.target.closest("a, button, input, select, textarea")) return;
  …
});
```

Один слушатель вместо ста. Что это даёт:

- **работает на узлах, которых ещё нет.** Главное и единственное незаменимое
  свойство;
- слушателей не надо снимать, когда узлы уходят;
- памяти меньше, привязка одна.

Чего это стоит: обработчик обязан сам разбираться, кому адресовано. Отсюда
`closest` (найти запись от места нажатия), `contains` (запись точно наша) и
пропуск того, у чего своё дело.

Где делегирование не годится: события, которые не всплывают (`focus` — но есть
`focusin`), и случаи, когда слушателю нужен именно свой узел и ничего больше.

## 5. Снять слушатель

```js
const handler = () => {};
node.addEventListener("click", handler);
node.removeEventListener("click", handler);        // тот же объект функции

node.addEventListener("click", handler, { once: true });   // сам снимется

const stop = new AbortController();
node.addEventListener("click", handler, { signal: stop.signal });
stop.abort();                                      // снимет все со своим signal
```

`removeEventListener` требует **ту же функцию**: стрелка, написанная на месте,
снимается только через `AbortController` или `once`.

`{ passive: true }` обещает браузеру, что обработчик не позовёт
`preventDefault`, — и браузер не ждёт его, чтобы прокрутить страницу. Для
`scroll`, `touchstart` и `wheel` это разница между плавно и дёргано.

## 6. Двойные слушатели

Одинаковый слушатель на одном узле браузер не удвоит — но только если это
**буквально та же функция**:

```js
node.addEventListener("click", handler);
node.addEventListener("click", handler);   // второй раз не добавится
```

При повторном выполнении модуля функция создаётся заново — и удваивается.
Поэтому:

```js
if (!register.dataset.wired) {
  register.dataset.wired = "yes";
  register.addEventListener("click", …);
}
```

То же «найти или создать», что в `s03e02`, только про поведение.

## 7. Свои события

```js
const event = new CustomEvent("telegraph:sent", {
  detail: { id: 7 },
  bubbles: true,
  cancelable: true,
});
entry.dispatchEvent(event);
```

Своё событие — способ сказать «случилось вот это», не зная, кому это нужно.
Оно идёт по той же линии и подчиняется тем же правилам.

Имя принято писать с приставкой (`telegraph:sent`): так видно, чьё оно, и оно
не столкнётся с будущим стандартным.

`detail` — единственное место, куда кладут свои данные. Turbo пользуется этим
широко: `turbo:submit-start`, `turbo:frame-load`, `turbo:before-stream-render`
— все они всплывают, и на все можно подписаться, ничего не переписывая.

## 8. Где это в Rails

```erb
<div data-controller="register"
     data-action="click->register#chalk change->register#sift">
```

Stimulus вешает один слушатель на элемент контроллера и разбирает, на чём
началось. То есть делает то же, что написано выше, но объявлением в разметке —
и потому строка, пришедшая Turbo Stream'ом, работает сразу: контроллер о ней
не знает и знать не должен.

Из того же: `data-action="submit->register#send"` перехватывает отправку, и
`preventDefault` Stimulus вызывает сам.

## 9. Куда смотреть дальше

- **MDN: Introduction to events**, **Event bubbling**, **`addEventListener`**.
- **DOM Living Standard**, раздел Events — фазы и алгоритм доставки.
- **Stimulus Handbook**, разделы Actions и Lifecycle.
- **Turbo Handbook**, список событий — чем пользуются, когда нужно вмешаться.

## Спросить у ADA

- «Чем `target` отличается от `currentTarget`? Дай пример, где видно.»
- «Какие события не всплывают и чем их заменяют?»
- «Как снять стрелочный обработчик, написанный прямо в `addEventListener`?»
