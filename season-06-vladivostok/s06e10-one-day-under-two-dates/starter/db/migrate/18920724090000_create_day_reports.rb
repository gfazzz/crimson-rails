# Сводка за день — одна на день.
class CreateDayReports < ActiveRecord::Migration[8.0]
  def change
    create_table :day_reports do |t|
      t.date :day, null: false               # день по новому стилю, по Владивостоку
      t.integer :arrived, null: false        # пароходов у причала
      t.integer :receipts, null: false       # квитанций о приёмке за этот день
      t.integer :repeats, null: false        # поставок, у которых за день больше одной квитанции
      t.integer :paid_kopecks, null: false   # выплачено казной
      t.timestamps
    end
    # TODO: сводка за день — одна, сколько раз её ни поставь.
  end
end
