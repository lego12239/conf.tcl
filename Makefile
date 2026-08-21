VERSION := 2.1.2


all:

test:
	cd tests && ./tests.tcl

install:
	install -d $(DESTDIR)/lib/conf $(DESTDIR)/bin
	install conf.tcl pkgIndex.tcl $(DESTDIR)/lib/conf/
	install -m 0555 conf_get.tcl $(DESTDIR)/bin/

dist:
	ln -s . conf-$(VERSION)
	git-ls-files | sed -nre '/^conf-$(VERSION)\/*$$/ b e; p; :e' | sed -re 's/^/conf-$(VERSION)\//' | tar -cT- | xz > ../conf-$(VERSION).tar.xz
	rm conf-$(VERSION)
