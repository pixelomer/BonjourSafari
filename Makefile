TARGET = iphone:14.4:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BonjourSafari

BonjourSafari_FILES = Tweak.xm
BonjourSafari_CFLAGS = -fobjc-arc
BonjourSafari_FRAMEWORKS = WebKit UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
