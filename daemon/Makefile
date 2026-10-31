ARCHS = arm64
TARGET = iphone:clang:latest:12.0
include $(THEOS)/makefiles/common.mk
TOOL_NAME = tomato-ocr-daemon
tomato-ocr-daemon_FILES = main.m
tomato-ocr-daemon_CFLAGS = -fobjc-arc
tomato-ocr-daemon_FRAMEWORKS = Foundation UIKit
tomato-ocr-daemon_LDFLAGS = -F../libs -framework TomatoOCR -rpath /Library/Frameworks -Wl,-no_dyld_chained_fixups
include $(THEOS_MAKE_PATH)/tool.mk
