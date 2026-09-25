# Сводка за день — одна на день.
#
# Сводку ставит расписание в восемь утра, но её можно поставить и руками, и
# дважды — два надзирателя, повтор после сбоя. День — ключ: сводка за
# 23 июля бывает одна, сколько раз её ни считай (s06e04).
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
    add_index :day_reports, :day, unique: true
  end
end
