# Waypoint — Installation and Update
#
# Run from this directory (waypoint/) or from the project root:
#   make -C waypoint install
#
# All logic lives in ./bin/waypoint; these targets are thin wrappers so the
# familiar `make` entry points keep working. DEST is the project root and
# defaults to the parent of this directory.

DEST ?= ..
WP   := ./bin/waypoint

.PHONY: help install install-core install-cursor install-claude update update-skills migrate

# ─── Help ────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "  Waypoint"
	@echo ""
	@echo "  Targets:"
	@echo ""
	@echo "    install          Auto-detect tool and install"
	@echo "                     (Cursor if .cursor/ exists, otherwise Claude Code)"
	@echo "    install-cursor   Install with Cursor adapter"
	@echo "    install-claude   Install with Claude Code adapter"
	@echo "    install-core     Install templates and skills only (no adapter)"
	@echo ""
	@echo "    update           Migrate layout, refresh skills + adapter, check OPORD drift"
	@echo "    update-skills    Refresh core skills only"
	@echo "    migrate          Bring an older install up to the current layout"
	@echo ""
	@echo "  Variables:"
	@echo "    DEST=<path>      Project root  (default: $(abspath $(DEST)))"
	@echo ""

# ─── Install ─────────────────────────────────────────────────────────────────

install:
	@if [ -d "$(DEST)/.cursor" ]; then \
		$(WP) install-cursor "$(DEST)"; \
	else \
		$(WP) install-claude "$(DEST)"; \
	fi

install-core:
	@$(WP) install-core "$(DEST)"

install-cursor:
	@$(WP) install-cursor "$(DEST)"

install-claude:
	@$(WP) install-claude "$(DEST)"

# ─── Update / Migrate ────────────────────────────────────────────────────────

update:
	@$(WP) update "$(DEST)"

update-skills:
	@$(WP) update-skills "$(DEST)"

migrate:
	@$(WP) migrate "$(DEST)"
