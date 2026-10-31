ARCHS = arm64
TARGET = iphone:clang:latest:12.0
include $(THEOS)/makefiles/common.mk
ADDITIONAL_CFLAGS = -F$(SRCROOT)/daemon/libs
include $(THEOS_MAKE_PATH)/tool.mk
