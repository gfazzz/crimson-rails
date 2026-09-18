# CRIMSON RAILS — s03e05
.PHONY: test solution clean
test:
	@node --test tests/*.test.mjs
solution:
	@FORCE_SOLUTION=1 node --test tests/*.test.mjs
clean:
	@rm -f artifacts/*.js artifacts/*.html artifacts/*.css && echo "artifacts/ очищен."
