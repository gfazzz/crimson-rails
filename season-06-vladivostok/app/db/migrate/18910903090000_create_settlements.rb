# Расчёт: сколько Палата должна дороге за месяц.
#
# Первая ведомость сезона, которую не вводят с бланков, а **считают**. Отсюда
# и тема серии: счёт, который идёт по нескольким строкам, обязан лечь целиком
# или не лечь вовсе.
class CreateSettlements < ActiveRecord::Migration[8.0]
  def change
    create_table :settlements do |t|
      t.references :company, null: false, foreign_key: true

      # Период — «1891-08». Строкой, потому что это не дата, а название
      # месяца: сравнивать его будут на равенство, а сортировать он умеет
      # сам.
      t.string :period, null: false

      t.integer :pence, null: false

      # Состояние расчёта: посчитан или оплачен. Оплаченный не пересчитывают.
      t.integer :state, null: false, default: 0

      # Счётчик правок. Его ведёт Rails: при каждой записи он растёт, а при
      # записи из устаревшей копии не совпадает — и запись отвергается.
      # Имя `lock_version` не произвольное: по нему Rails и узнаёт столбец.
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    # Один расчёт на дорогу за месяц. То же правило, что в s04e04, и та же
    # причина: пересчёт, начатый дважды, не должен дать две строки.
    add_index :settlements, %i[company_id period], unique: true

    add_check_constraint :settlements, "pence > 0", name: "settlements_pence_positive"
    add_check_constraint :settlements, "state IN (0, 1)", name: "settlements_state_known"
  end
end
