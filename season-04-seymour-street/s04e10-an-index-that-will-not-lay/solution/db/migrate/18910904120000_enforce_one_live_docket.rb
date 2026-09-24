# Теперь индекс ложится.
#
# Уникальность — не по всей таблице, а по её живой части: погашенных строк с
# одной парой «бланк + участок» сколько угодно, живая одна. Тот же приём, что
# в s04e08, и та же причина — уникальность нужна не всегда, а при условии.
class EnforceOneLiveDocket < ActiveRecord::Migration[8.0]
  def change
    add_index :entries, %i[docket position], unique: true, where: "voided_at IS NULL",
              name: "index_entries_on_live_leg"
  end
end
