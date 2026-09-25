# Переплаты казны: выплаты по книге казначейства сверх одной на поставку.
#
# Строку заводит сверка (ReconcileJob) — и может завести её снова: сверку
# ставят по расписанию, руками, после сбоя. Ключ переплаты — поставка и
# квитанция казначейства, по которой платили: одна переплата на пару.
class CreateOverpayments < ActiveRecord::Migration[8.0]
  def change
    create_table :overpayments do |t|
      t.references :delivery, null: false, foreign_key: true
      t.string :receipt, null: false           # номер квитанции в книге казначейства
      t.string :month, null: false             # «1892-05»
      t.integer :kopecks, null: false
      t.timestamps
    end
    # TODO: одна переплата на пару «поставка + квитанция казначейства».
    add_check_constraint :overpayments, "kopecks > 0", name: "overpayments_kopecks_positive"
  end
end
