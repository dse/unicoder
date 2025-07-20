.PHONY: FORCE
default:
	@echo "make aglfn.txt"
aglfn.txt: FORCE
	curl -s https://raw.githubusercontent.com/adobe-type-tools/agl-aglfn/master/aglfn.txt >"$@.tmp"
	mv "$@.tmp" "$@"
