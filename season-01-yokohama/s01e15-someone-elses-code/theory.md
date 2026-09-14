# Теория — s01e15

## 1. Что происходит при `include`

```ruby
class Shipment
  include Weighable
end
```

1. `Weighable.append_features(Shipment)` — вставка в цепочку предков;
2. `Weighable.included(Shipment)` — уведомление.

Оба метода — обычные, и оба переопределяемы. Разница принципиальная: первый
**делает**, второй **сообщает**. Отменить включение можно только в первом.

Симметрично устроены `extend` (`extend_object` + `extended`) и `prepend`
(`prepend_features` + `prepended`).

## 2. Почему обычный модуль не справляется

```ruby
module Weighable
  def self.included(base) = base.extend(ClassMethods)
  module ClassMethods; def unit_name = "кг"; end
end

module Billable
  include Weighable       # base здесь — Billable, а не будущий класс
end

class Shipment
  include Billable
end

Shipment.unit_name        # NoMethodError
```

`Weighable.included` получил `Billable`. Методы класса достались модулю
`Billable` — то есть никому: у модуля нет экземпляров, и в `Shipment` они не
попадают.

Это не изъян Ruby, а следствие того, что `include` — операция немедленная.
Лечится отсрочкой.

## 3. Отсрочка

```ruby
def append_features(base)
  if base.instance_variable_defined?(:@_dependencies)
    base.instance_variable_get(:@_dependencies) << self
    false
  else
    @_dependencies.each { |dep| base.include(dep) }
    super
    base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
    base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
  end
end
```

Четыре решения в девяти строках:

| Строка | Решение |
|---|---|
| `instance_variable_defined?` | как отличить примесь от класса: по наличию, а не по типу |
| `false` | «ничего не делал» — Ruby на этом успокаивается |
| `base.include(dep)` | зависимость идёт в **класс**, а не в примесь |
| `super` после зависимостей | порядок предков: зависящий ближе к классу |

Возврат `false` из `append_features` — редкий случай, когда метод Ruby
используют как «отказаться от операции». Документировано это скупо, и узнать об
этом можно ровно так, как ты сегодня: прочитав чужой код.

## 4. `const_defined?`, `const_get`, `const_set`

```ruby
const_defined?(:ClassMethods, false)   # false — не искать у предков!
const_get(:ClassMethods)
const_set(:ClassMethods, Module.new)
```

Второй аргумент `false` существенен: без него `const_defined?` найдёт
`ClassMethods` у предка, и `const_get` вернёт **чужой** модуль. Две примеси
начнут дописывать методы в один и тот же `ClassMethods`, и поведение
перепутается.

Общее правило работы с константами через API: почти всегда нужен
`inherit = false`.

## 5. Почему настоящий Concern сравнивает `source_location`

В Rails второй блок `included` разрешён, если у него **то же** место
объявления:

```ruby
if @_included_block.source_location != block.source_location
  raise MultipleIncludedBlocks
end
```

Причина прозаическая: в разработке файлы перезагружаются, и один и тот же
`included do` может выполниться дважды. Сравнение места позволяет отличить
повторную загрузку того же кода от настоящей ошибки — двух разных блоков.

Деталь, которую не придумаешь из общих соображений: она из опыта эксплуатации.
Такие места в чужом коде стоит замечать — они обычно объясняют, почему решение
выглядит странно.

## 6. Границы приёма

Примесь-с-зависимостями удобна и имеет цену:

- **порядок подключения становится значимым**, а видно его только в
  `ancestors`;
- **`included do` — это код, выполняющийся при загрузке класса**, и ошибки в
  нём приходят с трассой, указывающей внутрь примеси;
- **соблазн**: concern превращается в место, куда складывают всё, что не
  поместилось в модель. Тогда это не роль, а свалка, и `Shipment.ancestors`
  вырастает до двадцати строк.

Правило из `s01e09` остаётся в силе: примесь описывает **роль**. Если она
тащит состояние и зависит от внутренностей хозяина — это половина класса, и ей
лучше стать отдельным объектом.

## 7. Что читать после этого

Одна из целей сезона — чтобы исходники Rails перестали быть закрытой книгой.
Файлы, которые теперь читаются:

| Файл | Что там из сезона |
|---|---|
| `active_support/concern.rb` | сегодняшняя серия |
| `active_support/core_ext/object/blank.rb` | простые примеси, `s01e09` |
| `active_model/attribute_methods.rb` | `define_method` по списку, `s01e13` |
| `active_record/dynamic_matchers.rb` | `method_missing`, `s01e12` |
| `active_support/callbacks.rb` | сохранённые вызываемые объекты, `s01e02` |

Читать чужой код — навык, который ставится практикой и ничем больше. Начинать
лучше с файлов, где уже знаешь, что увидишь.

## 8. Куда смотреть дальше

- **Исходник `ActiveSupport::Concern`** и комментарий в его шапке.
- **Perrotta P., «Metaprogramming Ruby», гл. 4–5**.
- **Black D. A., «The Well-Grounded Rubyist», гл. 13**.
- `ri Module#append_features`, `ri Module#const_defined?`, `ri Module#class_eval`.

## Спросить у ADA

- «Покажи на трёх модулях, как меняется `ancestors` при разном порядке
  `include` внутри concern.»
- «Что делает `extend_object` и когда его перехватывают?»
- «Почему `const_defined?(:X, false)` — почти всегда правильный вызов?»
