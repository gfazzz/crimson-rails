# CRIMSON RAILS — s04e01
.PHONY: test solution clean
test:
	@../support/run.sh s04e01
solution:
	@../support/reference.sh s04e01
clean:
	@rm -f ../app/db/migrate/*_create_companies.rb ../app/db/migrate/*_add_registered_on_to_companies.rb \
	 && echo "миграции серии убраны из app/ (схему пересобери: bin/rails db:prepare)"
