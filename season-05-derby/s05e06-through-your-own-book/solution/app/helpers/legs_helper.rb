# Помощники страниц с участками.
module LegsHelper
  ROLES = { "collected" => "принял", "hauled" => "вёз", "delivered" => "сдал" }.freeze

  # Роль словом (s04e08): имена `enum` — для кода.
  def leg_role(leg) = ROLES.fetch(leg.role)
end
