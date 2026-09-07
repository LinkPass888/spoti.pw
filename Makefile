# Entry points; the real work is in scripts/. IPA defaults to the first file in ipa/.
IPA ?= $(firstword $(wildcard ipa/*.ipa))

.PHONY: build release install trees log
build:    ## FLEX + glass IPA into out/
	./scripts/pipeline.sh $(IPA)
release:  ## glass only, no FLEX
	./scripts/pipeline.sh $(IPA) --no-flex
install:  ## build, sign with your certificate, push to the phone on USB
	./scripts/pipeline.sh $(IPA) --install
trees:    ## record per-screen view trees into trees/
	./scripts/record-trees.py
log:      ## stream the tweak's log lines from the phone
	./scripts/dump-log.sh
