DEPS_DIR := $(CURDIR)/deps
START_DIR := $(DEPS_DIR)/pack/testing/start

.PHONY: test deps typecheck

test: deps
	nvim --headless -u tests/scripts/minimal_init.lua -c "lua MiniTest.run()"

typecheck:
	lua-language-server --check lua/zen/ --checklevel=Warning --configpath=$(CURDIR)/.luarc.json

deps: \
	$(START_DIR)/mini.nvim \
	$(START_DIR)/vim-fugitive \
	$(START_DIR)/fyler.nvim \
	$(START_DIR)/trouble.nvim \
	$(START_DIR)/neotest \
	$(START_DIR)/nvim-nio \
	$(START_DIR)/plenary.nvim \
	$(START_DIR)/fixcursorhold \
	$(START_DIR)/vim-dadbod \
	$(START_DIR)/vim-dadbod-ui \
	$(START_DIR)/nvim-dap \
	$(START_DIR)/nvim-dap-ui \
	$(START_DIR)/CopilotChat.nvim

$(START_DIR)/mini.nvim:
	git clone --depth 1 https://github.com/echasnovski/mini.nvim $@

$(START_DIR)/vim-fugitive:
	git clone --depth 1 https://github.com/tpope/vim-fugitive $@

$(START_DIR)/fyler.nvim:
	git clone --depth 1 https://github.com/A7Lavinraj/fyler.nvim $@

$(START_DIR)/trouble.nvim:
	git clone --depth 1 https://github.com/folke/trouble.nvim $@

$(START_DIR)/neotest:
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

$(START_DIR)/nvim-nio:
	git clone --depth 1 https://github.com/nvim-neotest/nvim-nio $@

$(START_DIR)/plenary.nvim:
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $@

$(START_DIR)/fixcursorhold:
	git clone --depth 1 https://github.com/antoinemadec/FixCursorHold.nvim $@

$(START_DIR)/vim-dadbod:
	git clone --depth 1 https://github.com/tpope/vim-dadbod $@

$(START_DIR)/vim-dadbod-ui:
	git clone --depth 1 https://github.com/kristijanhusak/vim-dadbod-ui $@

$(START_DIR)/nvim-dap:
	git clone --depth 1 https://github.com/mfussenegger/nvim-dap $@

$(START_DIR)/nvim-dap-ui:
	git clone --depth 1 https://github.com/rcarriga/nvim-dap-ui $@

$(START_DIR)/CopilotChat.nvim:
	git clone --depth 1 https://github.com/CopilotC-Nvim/CopilotChat.nvim $@
