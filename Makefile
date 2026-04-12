DEPS_DIR := $(CURDIR)/deps

.PHONY: test deps

# Download mini.nvim if not present, then run all tests
test: deps
	nvim --headless -u tests/scripts/minimal_init.lua -c "lua MiniTest.run()"

# Clone mini.nvim into deps/
deps:
	@if [ ! -d "$(DEPS_DIR)/mini.nvim" ]; then \
		echo "Downloading mini.nvim..."; \
		mkdir -p "$(DEPS_DIR)"; \
		git clone --depth 1 https://github.com/echasnovski/mini.nvim "$(DEPS_DIR)/mini.nvim"; \
	fi
