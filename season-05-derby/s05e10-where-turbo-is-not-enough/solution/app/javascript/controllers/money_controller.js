import { Controller } from "@hotwired/stimulus"

// Сумма фунтами, шиллингами и пенсами — пока кассир набирает пенсы.
//
// Это то место, где Turbo мало. Спросить сервер можно, но спрашивать его на
// каждую нажатую клавишу — абсурд: ответ на вопрос «сколько это в фунтах» не
// требует ничего, кроме числа в поле. Поэтому — здесь, в окне, никуда не
// запрашивая.
//
// И поэтому же — только показ. Правда о сумме — у сервера: модель проверит
// пенсы (s04e03), а то, что показано здесь, ничего не решает. У стола делают
// только то, что не нужно проверять.
export default class extends Controller {
  static targets = ["pence", "reading"]

  // Сколько пенсов в шиллинге и шиллингов в фунте — не пишутся здесь второй
  // раз, а приходят из разметки, от помощника на сервере (s05e03). Правило
  // чтения повторено в двух местах, числа — нет.
  static values = { penceInShilling: Number, shillingsInPound: Number }

  // `connect` зовётся каждый раз, когда элемент появился на странице: при
  // первой загрузке, после визита Turbo, после формы, вернувшейся с отказом.
  // `DOMContentLoaded` этого не умеет: для Turbo страница не загружается, а
  // подменяется (s05e07).
  connect() {
    this.show()
  }

  show() {
    const pence = Number(this.penceTarget.value)
    this.readingTarget.textContent =
      this.penceTarget.value !== "" && Number.isInteger(pence) && pence > 0 ? this.read(pence) : "—"
  }

  read(total) {
    const shillings = Math.floor(total / this.penceInShillingValue)
    const pence = total % this.penceInShillingValue
    const pounds = Math.floor(shillings / this.shillingsInPoundValue)
    return `£${pounds} ${shillings % this.shillingsInPoundValue}s ${pence}d`
  }
}
