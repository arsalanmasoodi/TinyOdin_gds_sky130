# ──────────────────────────────────────────────────────────────────────────────
# TinyODIN Sky130 — Makefile
# ──────────────────────────────────────────────────────────────────────────────
DESIGN       := tinyODIN
OPENLANE_CFG := openlane/config.yaml
GDS_GZ       := gds/tinyODIN.klayout.gds.gz
GDS          := /tmp/tinyODIN_view.gds

.PHONY: all build view clean help

all: help

## help  — show this message
help:
	@grep -E '^##' Makefile | sed 's/^## /  make /'

## build — run the full OpenLane 2 flow (requires librelane container)
build:
	@echo "==> Running OpenLane 2 / librelane for $(DESIGN)"
	openlane $(OPENLANE_CFG)

## view  — open the GDS in KLayout (decompresses to /tmp first)
view: $(GDS_GZ)
	@echo "==> Decompressing GDS ..."
	gunzip -kf $(GDS_GZ)
	mv gds/tinyODIN.klayout.gds $(GDS)
	@echo "==> Opening in KLayout ..."
	klayout $(GDS) &

## clean — remove run artefacts (keeps gds/, docs/, rtl/, macros/)
clean:
	rm -rf runs/
