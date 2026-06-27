# Waypoint — Installation and Update
#
# Run from this directory (waypoint/) or from the project root:
#   make -C waypoint install
#
# DEST is the project root. Defaults to the parent of this directory.

# Run every recipe through a POSIX shell as a single script.
#
# On Windows, GNU Make's native port has a "fast path" that executes recipe
# lines with no shell metacharacters directly via CreateProcess instead of
# through the shell. Lines like `mkdir -p ...` and `cp src dst` then fail,
# because mkdir/cp are shell tools, not Windows executables ("CreateProcess(...)
# failed ... The system cannot find the file specified"). .ONESHELL feeds the
# whole recipe to $(SHELL) at once, which keeps these POSIX recipes working on
# Windows (with sh.exe from Git for Windows / MSYS2 / scoop on PATH) while
# remaining a no-op on Linux and macOS. -e preserves fail-fast error semantics.
SHELL       := sh
.ONESHELL:
.SHELLFLAGS := -ec

DEST        ?= ..
WP          := $(DEST)/.waypoint
SKILLS_SRC  := ./skills
TMPL_SRC    := ./templates

# Core skill filenames shipped by the framework.
# Used by update-skills to know which files to refresh.
CORE_SKILLS := new-project.md new-feature.md new-skill.md onboarding.md resume.md debug.md

.PHONY: help install install-core install-cursor install-claude update update-skills

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
	@echo "    update           Refresh core skills and the installed adapter"
	@echo "    update-skills    Refresh core skills only"
	@echo ""
	@echo "  Variables:"
	@echo "    DEST=<path>      Project root  (default: $(abspath $(DEST)))"
	@echo ""

# ─── Install ─────────────────────────────────────────────────────────────────

install:
	@if [ -d "$(DEST)/.cursor" ]; then \
		$(MAKE) install-cursor; \
	else \
		$(MAKE) install-claude; \
	fi

install-core:
	@echo ""
	@echo "→ Creating .waypoint/ directory structure..."
	@mkdir -p $(WP)/design $(WP)/plan $(WP)/features $(WP)/skills
	@echo ""
	@echo "→ Installing templates..."
	@for f in opord project memory; do \
		dest="$(WP)/$$f.md"; \
		if [ ! -f "$$dest" ]; then \
			cp $(TMPL_SRC)/$$f.md "$$dest"; \
			echo "  + .waypoint/$$f.md"; \
		else \
			echo "  ~ .waypoint/$$f.md  (exists, skipped)"; \
		fi; \
	done
	@if [ ! -f "$(WP)/conops-template.md" ]; then \
		cp $(TMPL_SRC)/conops.md $(WP)/conops-template.md; \
		echo "  + .waypoint/conops-template.md"; \
	else \
		cp $(TMPL_SRC)/conops.md $(WP)/conops-template.md; \
		echo "  ✓ .waypoint/conops-template.md  (updated)"; \
	fi
	@echo ""
	@echo "→ Installing skills..."
	@for f in $(CORE_SKILLS); do \
		dest="$(WP)/skills/$$f"; \
		if [ ! -f "$$dest" ]; then \
			cp $(SKILLS_SRC)/$$f "$$dest"; \
			echo "  + .waypoint/skills/$$f"; \
		else \
			echo "  ~ .waypoint/skills/$$f  (exists, skipped)"; \
		fi; \
	done
	@echo ""
	@echo "  Next: produce your CONOPS."
	@echo "  Open your AI assistant and say:"
	@echo "    Read .waypoint/skills/new-project.md and follow it."
	@echo ""

install-cursor: install-core
	@echo "→ Installing Cursor adapter..."
	@mkdir -p $(DEST)/.cursor/rules
	@cp adapters/cursor/rules/session-briefing.mdc $(DEST)/.cursor/rules/session-briefing.mdc
	@echo "  + .cursor/rules/session-briefing.mdc"
	@echo ""
	@echo "✓ Done. Open a new Cursor agent session — the agent should respond with 'Ready.'"
	@echo ""

install-claude: install-core
	@echo "→ Installing Claude Code adapter..."
	@if [ -f "$(DEST)/CLAUDE.md" ]; then \
		echo "  CLAUDE.md exists — appending Waypoint session briefing..."; \
		echo "" >> $(DEST)/CLAUDE.md; \
		cat adapters/claude/CLAUDE.md >> $(DEST)/CLAUDE.md; \
		echo "  ~ CLAUDE.md  (appended)"; \
	else \
		cp adapters/claude/CLAUDE.md $(DEST)/CLAUDE.md; \
		echo "  + CLAUDE.md"; \
	fi
	@echo ""
	@echo "✓ Done. Open a new Claude Code session — the agent should respond with 'Ready.'"
	@echo ""

# ─── Update ──────────────────────────────────────────────────────────────────

update: update-skills
	@echo "→ Updating adapter..."
	@if [ -f "$(DEST)/.cursor/rules/session-briefing.mdc" ]; then \
		cp adapters/cursor/rules/session-briefing.mdc $(DEST)/.cursor/rules/session-briefing.mdc; \
		echo "  ✓ .cursor/rules/session-briefing.mdc"; \
	fi
	@if [ -f "$(DEST)/CLAUDE.md" ]; then \
		echo "  ! CLAUDE.md exists but may contain custom content — update manually if needed."; \
		echo "    New adapter content is in: adapters/claude/CLAUDE.md"; \
	fi
	@echo ""
	@echo "✓ Update complete."
	@echo ""

update-skills:
	@echo ""
	@echo "→ Updating core skills..."
	@if [ ! -d "$(WP)/skills" ]; then \
		echo "  Error: $(WP)/skills does not exist. Run 'make install' first."; \
		exit 1; \
	fi
	@for f in $(CORE_SKILLS); do \
		cp $(SKILLS_SRC)/$$f $(WP)/skills/$$f; \
		echo "  ✓ .waypoint/skills/$$f"; \
	done
	@echo ""
