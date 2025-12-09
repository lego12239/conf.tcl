VERSION := 2.1


test:
	cd tests && ./tests.tcl

dist:
	ln -s . conf-$(VERSION)
	git-ls-files | sed -nre '/^conf-$(VERSION)\/*$$/ b e; p; :e' | sed -re 's/^/conf-$(VERSION)\//' | tar -cT- | xz > ../conf-$(VERSION).tar.xz
	rm conf-$(VERSION)
