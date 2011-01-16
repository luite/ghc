# -----------------------------------------------------------------------------
#
# (c) 2009 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Modifying
#
# -----------------------------------------------------------------------------

# ToDo
ghc_USES_CABAL = YES
ghc_PACKAGE = ghc-bin

ghc_stage1_MORE_HC_OPTS = $(GhcStage1HcOpts)
ghc_stage2_MORE_HC_OPTS = $(GhcStage2HcOpts)
ghc_stage3_MORE_HC_OPTS = $(GhcStage3HcOpts)

ghc_stage2_CC_OPTS = -Iincludes
ghc_stage3_CC_OPTS = -Iincludes

ghc_stage1_C_FILES_NODEPS = ghc/hschooks.c

ghc_stage2_MKDEPENDC_OPTS = -DMAKING_GHC_BUILD_SYSTEM_DEPENDENCIES
ghc_stage3_MKDEPENDC_OPTS = -DMAKING_GHC_BUILD_SYSTEM_DEPENDENCIES

ifeq "$(GhcWithInterpreter)" "YES"
ghc_stage2_MORE_HC_OPTS += -DGHCI
ghc_stage3_MORE_HC_OPTS += -DGHCI
endif

ifeq "$(GhcDebugged)" "YES"
ghc_stage1_MORE_HC_OPTS += -debug
ghc_stage2_MORE_HC_OPTS += -debug
ghc_stage3_MORE_HC_OPTS += -debug
endif

ifeq "$(GhcDynamic)" "YES"
ghc_stage2_MORE_HC_OPTS += -dynamic
ghc_stage3_MORE_HC_OPTS += -dynamic
endif

ifeq "$(GhcThreaded)" "YES"
# Use threaded RTS with GHCi, so threads don't get blocked at the prompt.
ghc_stage2_MORE_HC_OPTS += -threaded
ghc_stage3_MORE_HC_OPTS += -threaded
endif

ifeq "$(GhcProfiled)" "YES"
ghc_stage2_MORE_HC_OPTS += -prof
endif

ghc_stage1_MODULES = Main

ghc_stage2_MODULES = $(ghc_stage1_MODULES)
ifeq "$(GhcWithInterpreter)" "YES"
ghc_stage2_MODULES += GhciMonad GhciTags InteractiveUI
endif
ghc_stage3_MODULES = $(ghc_stage2_MODULES)

ghc_stage1_C_SRCS = hschooks.c
ghc_stage2_C_SRCS = hschooks.c
ghc_stage3_C_SRCS = hschooks.c

ghc_stage1_PROG = ghc-stage1$(exeext)
ghc_stage2_PROG = ghc-stage2$(exeext)
ghc_stage3_PROG = ghc-stage3$(exeext)

# ToDo: perhaps use ghc-cabal to configure ghc-bin
ghc_stage1_MORE_HC_OPTS += -package $(compiler_PACKAGE)-$(compiler_stage1_VERSION)
ghc_stage2_MORE_HC_OPTS += -package $(compiler_PACKAGE)-$(compiler_stage2_VERSION)
ghc_stage3_MORE_HC_OPTS += -package $(compiler_PACKAGE)-$(compiler_stage3_VERSION)
ghc_stage2_MORE_HC_OPTS += -package haskeline
ghc_stage3_MORE_HC_OPTS += -package haskeline

ghc_language_extension_flags = -XCPP \
                               -XPatternGuards \
                               -XForeignFunctionInterface \
                               -XUnboxedTuples \
                               -XFlexibleInstances \
                               -XMagicHash
ghc_stage1_MORE_HC_OPTS += $(ghc_language_extension_flags)
ghc_stage2_MORE_HC_OPTS += $(ghc_language_extension_flags)
ghc_stage3_MORE_HC_OPTS += $(ghc_language_extension_flags)

ghc_stage1_SHELL_WRAPPER = YES
ghc_stage2_SHELL_WRAPPER = YES
ghc_stage3_SHELL_WRAPPER = YES
ghc_stage1_SHELL_WRAPPER_NAME = ghc/ghc.wrapper
ghc_stage2_SHELL_WRAPPER_NAME = ghc/ghc.wrapper
ghc_stage3_SHELL_WRAPPER_NAME = ghc/ghc.wrapper

ghc_stage$(INSTALL_GHC_STAGE)_INSTALL_SHELL_WRAPPER = YES
ghc_stage$(INSTALL_GHC_STAGE)_INSTALL_SHELL_WRAPPER_NAME = ghc-$(ProjectVersion)

# We override the program name to be ghc, rather than ghc-stage2.
# This means the right program name is used in error messages etc.
define ghc_stage$(INSTALL_GHC_STAGE)_INSTALL_SHELL_WRAPPER_EXTRA
echo 'executablename="$$exedir/ghc"' >> "$(WRAPPER)"
endef

# if stage is set to something other than "1" or "", disable stage 1
ifneq "$(filter-out 1,$(stage))" ""
ghc_stage1_NOT_NEEDED = YES
endif
# if stage is set to something other than "2" or "", disable stage 2
ifneq "$(filter-out 2,$(stage))" ""
ghc_stage2_NOT_NEEDED = YES
endif
# stage 3 has to be requested explicitly with stage=3
ifneq "$(stage)" "3"
ghc_stage3_NOT_NEEDED = YES
endif
$(eval $(call build-prog,ghc,stage1,0))
$(eval $(call build-prog,ghc,stage2,1))
$(eval $(call build-prog,ghc,stage3,2))

ifneq "$(BINDIST)" "YES"

# ToDo: should we add these in the build-prog macro?
ghc/stage1/build/tmp/$(ghc_stage1_PROG) : $(compiler_stage1_v_LIB)
ghc/stage2/build/tmp/$(ghc_stage2_PROG) : $(compiler_stage2_v_LIB)
ghc/stage3/build/tmp/$(ghc_stage3_PROG) : $(compiler_stage3_v_LIB)

ifeq "$(GhcProfiled)" "YES"
ghc/stage2/build/tmp/$(ghc_stage2_PROG) : $(compiler_stage2_p_LIB)
ghc/stage2/build/tmp/$(ghc_stage2_PROG) : $(foreach lib,$(PACKAGES),$(libraries/$(lib)_dist-install_p_LIB))
endif

# Modules here import HsVersions.h, so we need ghc_boot_platform.h
$(ghc_stage1_depfile_haskell) : compiler/stage1/$(PLATFORM_H)
$(ghc_stage2_depfile_haskell) : compiler/stage2/$(PLATFORM_H)
$(ghc_stage3_depfile_haskell) : compiler/stage3/$(PLATFORM_H)

all_ghc_stage1 : $(GHC_STAGE1)
all_ghc_stage2 : $(GHC_STAGE2)
all_ghc_stage3 : $(GHC_STAGE3)

$(INPLACE_LIB)/extra-gcc-opts : extra-gcc-opts
	"$(CP)" $< $@

# The GHC programs need to depend on all the helper programs they might call
ifeq "$(GhcUnregisterised)" "NO"
$(GHC_STAGE1) : $(MANGLER) $(SPLIT)
$(GHC_STAGE2) : $(MANGLER) $(SPLIT)
$(GHC_STAGE3) : $(MANGLER) $(SPLIT)
endif

$(GHC_STAGE1) : $(INPLACE_LIB)/extra-gcc-opts
$(GHC_STAGE2) : $(INPLACE_LIB)/extra-gcc-opts
$(GHC_STAGE3) : $(INPLACE_LIB)/extra-gcc-opts

ifeq "$(Windows)" "YES"
$(GHC_STAGE1) : $(TOUCHY)
$(GHC_STAGE2) : $(TOUCHY)
$(GHC_STAGE3) : $(TOUCHY)
endif

ifeq "$(BootingFromHc)" "YES"
$(GHC_STAGE2) : $(ALL_STAGE1_LIBS)
ghc_stage2_OTHER_OBJS += $(compiler_stage2_v_LIB) $(ALL_STAGE1_LIBS) $(ALL_STAGE1_LIBS) $(ALL_STAGE1_LIBS) $(ALL_RTS_LIBS) $(libffi_STATIC_LIB)
endif

endif

INSTALL_LIBS += extra-gcc-opts

ifeq "$(Windows)" "NO"
install: install_ghc_link
.PNONY: install_ghc_link
install_ghc_link: 
	"$(RM)" $(RM_OPTS) "$(DESTDIR)$(bindir)/ghc"
	$(LN_S) ghc-$(ProjectVersion) "$(DESTDIR)$(bindir)/ghc"
else
# On Windows we install the main binary as $(bindir)/ghc.exe
# To get ghc-<version>.exe we have a little C program in driver/ghc
install: install_ghc_post
.PHONY: install_ghc_post
install_ghc_post: install_bins
	"$(RM)" $(RM_OPTS) $(DESTDIR)$(bindir)/ghc.exe
	"$(MV)" -f $(DESTDIR)$(bindir)/ghc-stage$(INSTALL_GHC_STAGE).exe $(DESTDIR)$(bindir)/ghc.exe
endif

