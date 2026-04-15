NODE_MODULES := node_modules
TOUCH := node -e "import fs from 'fs'; const f=process.argv[1]; try{fs.utimesSync(f,new Date(),new Date())}catch{fs.closeSync(fs.openSync(f,'w'))}"

package-lock.json: package.json
	@echo "==> Updating lock file..."
	@npm install --package-lock-only

# Build node_modules with deps.
$(NODE_MODULES): package-lock.json
	@echo "==> Installing Node environment..."
	@npm install
	@$(TOUCH) $@

# Convenience target to build node_modules
.PHONY: setup
setup: $(NODE_MODULES)

.PHONY: check
check: $(NODE_MODULES)
	@echo "==> Linting docker compose files..."
	@npm run lint

.PHONY: clean
clean:
	@echo "==> Cleaning ignored files..."
	@git clean -Xfd

.DEFAULT_GOAL := test
