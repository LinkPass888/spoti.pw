# Entry points; the real work is in scripts/. IPA defaults to the first file in ipa/.
IPA ?= $(firstword $(wildcard ipa/*.ipa))

# What goes on the phone is the mod alone. FLEX is the inspector `make trees` reads the screens
# through, so it rides along only when it is asked for: make install FLEX=1. (A make target cannot
# take --flex; make would read that as an option of its own.)
FLEX ?= 0
FLEX_ARG := $(if $(filter 0,$(FLEX)),--no-flex,)

.PHONY: build release install trees log flags
build:    ## FLEX + glass IPA into out/
	./scripts/pipeline.sh $(IPA)
release:  ## glass only, no FLEX
	./scripts/pipeline.sh $(IPA) --no-flex
install:  ## build, sign with your certificate, push to the phone on USB (FLEX=1 to take FLEX too)
	./scripts/pipeline.sh $(IPA) --install $(FLEX_ARG)
trees:    ## record per-screen view trees into trees/ (needs a FLEX build on the phone)
	./scripts/record-trees.py
log:      ## stream the tweak's log lines from the phone
	./scripts/dump-log.sh
flags:    ## regenerate tweak/src/SGFlagList.m, Spotify's remote-config flags, from the IPA
	./scripts/extract-flags.py $(IPA)
