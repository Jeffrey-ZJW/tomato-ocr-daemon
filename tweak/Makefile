ARCHS = arm64
TARGET = iphone:clang:latest:12.0
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TomatoOCRTweak
TomatoOCRTweak_FILES = Tweak.xm
TomatoOCRTweak_CFLAGS = -fobjc-arc
TomatoOCRTweak_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
