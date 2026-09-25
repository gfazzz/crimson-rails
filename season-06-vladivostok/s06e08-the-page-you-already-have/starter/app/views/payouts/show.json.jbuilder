json.month @month
json.payouts @disbursements do |payout|
  json.delivery payout.delivery.reference
  json.receipt payout.acceptance.line_number
  json.kopecks payout.kopecks
  json.paid_at payout.paid_at.iso8601
end
