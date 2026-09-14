# CRIMSON RAILS — s01e14
.PHONY: test solution clean
test:
	@ruby tests/test_packaging.rb
solution:
	@FORCE_SOLUTION=1 ruby tests/test_packaging.rb
clean:
	@rm -f artifacts/*.rb artifacts/*.gemspec && echo "artifacts/ очищен."
