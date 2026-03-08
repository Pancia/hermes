BIN = ~/.local/bin/hermes

build:
	swift build -c release

install: build
	cp .build/release/Hermes $(BIN)
	xattr -cr $(BIN)
	codesign -s - $(BIN)

restart:
	@hs -c 'hs.alert.show("Hermes: rebuilding...")'
	@$(MAKE) install
	service restart hermes
	@hs -c 'hs.alert.show("Hermes: back up")'

.PHONY: build install restart
