DEBUG = 0
FINALPACKAGE = 1
ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HPlus

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation AudioToolbox MediaPlayer QuartzCore CoreGraphics ImageIO

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -I$(CURDIR)/FLEX $(shell find $(CURDIR)/FLEX -type d -exec echo -I{} ;)

$(TWEAK_NAME)_FILES = $(wildcard Files/*.x) $(wildcard FLEX/*.m) $(wildcard FLEX/**/*.m)

$(TWEAK_NAME)_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
