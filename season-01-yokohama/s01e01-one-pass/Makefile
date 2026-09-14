# CRIMSON RAILS — s01e01
# make test | make solution | make clean

.PHONY: test solution clean

test:
	@ruby tests/test_ledger.rb

solution:
	@FORCE_SOLUTION=1 ruby tests/test_ledger.rb

clean:
	@rm -f artifacts/*.rb
	@echo "artifacts/ очищен."
