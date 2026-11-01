INSTALL_TARGET_PROCESSES = SpringBoard

ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SlideyDock16
SlideyDock16_FILES = Tweak.xm
SlideyDock16_CFLAGS = -fobjc-arc -Wall -Wextra
SlideyDock16_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
