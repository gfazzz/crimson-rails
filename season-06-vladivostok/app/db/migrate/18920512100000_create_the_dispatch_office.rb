# Контора отправлений торгового дома «Лэнг и К°», Владивосток.
#
# Четыре книги дома, переведённые на машину. Сезон 6 не про схему — её
# держат приёмы сезона 4, и они здесь уже стоят: обязательные поля,
# внешние ключи, CHECK на деньги. Один индекс намеренно не поставлен:
# «одна выплата на поставку». Его ставит s06e04.
class CreateTheDispatchOffice < ActiveRecord::Migration[8.0]
  def change
    # Поставка: пароход со шпалами для постройки. Деньги — копейками (s04e02).
    create_table :deliveries do |t|
      t.string :reference, null: false          # «NGS-0512»: номер отгрузки в Нагасаки
      t.string :steamer, null: false            # пароход
      t.integer :sleepers, null: false          # шпал, штук
      t.integer :kopecks, null: false           # цена поставки для казны
      t.date :arrived_on                        # у причала; пусто — ещё в море
      t.timestamps
    end
    add_index :deliveries, :reference, unique: true
    add_check_constraint :deliveries, "kopecks > 0", name: "deliveries_kopecks_positive"
    add_check_constraint :deliveries, "sleepers > 0", name: "deliveries_sleepers_positive"

    # Телеграмма, которую контора отдаёт на линию.
    #
    # `key` — наш номер отправления, по нему линия узнаёт повтор (s06e05).
    # `number` — номер, который даёт линия, приняв телеграмму.
    create_table :telegrams do |t|
      t.string :key, null: false
      t.string :addressee, null: false
      t.text :body, null: false
      t.string :state, null: false, default: "pending"
      t.string :number
      t.integer :attempts, null: false, default: 0
      t.text :error
      t.datetime :sent_at
      t.references :delivery, foreign_key: true
      t.timestamps
    end
    add_index :telegrams, :key, unique: true
    add_index :telegrams, :number, unique: true
    add_check_constraint :telegrams, "state IN ('pending', 'sent', 'failed')", name: "telegrams_state_known"

    # Квитанция о приёмке поставки — телеграмма, пришедшая дому.
    #
    # Номер линии и путь (`cable` — кабель через Нагасаки, `overland` —
    # сухопутная линия через Сибирь) — то, что пишет на бланке телеграфист.
    create_table :acceptances do |t|
      t.references :delivery, null: false, foreign_key: true
      t.string :line_number, null: false
      t.string :route, null: false
      t.string :signed_by, null: false
      t.date :accepted_on, null: false
      t.timestamps
    end
    add_index :acceptances, %i[route line_number], unique: true
    add_check_constraint :acceptances, "route IN ('cable', 'overland')", name: "acceptances_route_known"

    # Выплата казны по квитанции.
    create_table :disbursements do |t|
      t.references :delivery, null: false, foreign_key: true
      t.references :acceptance, null: false, foreign_key: true
      t.integer :kopecks, null: false
      t.datetime :paid_at, null: false
      t.timestamps
    end
    add_check_constraint :disbursements, "kopecks > 0", name: "disbursements_kopecks_positive"
  end
end
