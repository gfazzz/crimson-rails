# Одна поставка — одна выплата.
#
# Ключ выплаты — сама поставка, а не квитанция: квитанций на одну поставку
# может прийти две, тремя путями, под разными номерами, — платить казна
# должна один раз. Индекс держит это там, где его не обойдут ни второй
# работник, ни повтор задачи (s04e04).
class OneDisbursementPerDelivery < ActiveRecord::Migration[8.0]
  def change
    remove_index :disbursements, :delivery_id
    add_index :disbursements, :delivery_id, unique: true
  end
end
