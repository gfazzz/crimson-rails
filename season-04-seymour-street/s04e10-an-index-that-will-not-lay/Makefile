# CRIMSON RAILS — s04e10
.PHONY: test solution clean
test:
	@../support/run.sh s04e10
solution:
	@../support/reference.sh s04e10
clean:
	@rm -f ../app/db/migrate/*_create_entries.rb ../app/db/migrate/*_add_voided_at_to_entries.rb ../app/db/migrate/*_void_duplicate_dockets.rb ../app/db/migrate/*_enforce_one_live_docket.rb && echo "слой серии убран из app/"
