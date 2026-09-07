TARGET := iphone:clang:latest:16.0
ARCHS := arm64
FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := spotifyglass

SG_VERSION := $(shell sed -n 's/^Version: //p' control)

spotifyglass_FILES := $(wildcard src/*.m) $(wildcard src/*.x) $(wildcard src/ui/*.x)
spotifyglass_CFLAGS := -fobjc-arc -Isrc -DSG_VERSION=\"$(SG_VERSION)\"
spotifyglass_FRAMEWORKS := UIKit QuartzCore
# Runtime swizzling instead of Substrate so the dylib has no extra dependency inside the IPA.
spotifyglass_LOGOS_DEFAULT_GENERATOR := internal

include $(THEOS_MAKE_PATH)/tweak.mk
