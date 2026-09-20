# CRIMSON RAILS — s04e02
.PHONY: test solution clean
test:
	@../support/run.sh s04e02
solution:
	@../support/reference.sh s04e02
clean:
	@rm -f ../app/db/migrate/*_create_consignments.rb \
	 && echo "миграция серии убрана из app/ (пересобери: bin/rails db:migrate:reset)"
