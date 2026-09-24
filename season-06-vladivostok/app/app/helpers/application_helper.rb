# Помощники — то, что шаблоны спрашивают чаще одного раза.
module ApplicationHelper
  PENCE_IN_SHILLING = 12
  SHILLINGS_IN_POUND = 20

  # Деньги хранятся пенсами (сезон 4, s04e02), а читаются фунтами, шиллингами
  # и пенсами: 240 пенсов в фунте, 12 в шиллинге.
  #
  # Все три части — всегда, даже нулевые. «£801» и «£801 0s 0d» — одна сумма,
  # но вслух читается по-разному: во втором случае слышно, что шиллингов и
  # пенсов нет, а не что их забыли написать.
  def money(pence)
    shillings, pence = pence.divmod(PENCE_IN_SHILLING)
    pounds, shillings = shillings.divmod(SHILLINGS_IN_POUND)
    "£#{pounds} #{shillings}s #{pence}d"
  end

  # Во Владивостоке считают рублями: деньги хранятся копейками (s04e02) и
  # читаются «2 400 руб. 00 коп.» — копейки всегда двумя знаками, тысячи
  # отбиты пробелом, как в книге казначея.
  def roubles(kopecks)
    roubles, kopecks = kopecks.divmod(100)
    "#{roubles.to_s.reverse.scan(/\d{1,3}/).join(" ").reverse} руб. #{format("%02d", kopecks)} коп."
  end
end
