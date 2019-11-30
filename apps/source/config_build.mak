$(info ############################################################)
$(info ##                Running config_build.mak                ##)
$(info ############################################################)

# Determine, whether we are in a hosted environment or and ADK build,
# and calculate the path to the source or executable respectively of
# the tool config_build.

CURRENT_DIR = $(CURDIR)

SRC_DIR?=.

ifndef PYTHON_TOOLS
CURRENT_DIR_PATH = $(CURRENT_DIR:\=/)
# Try local branch
PYTHON_TOOLS = $(strip $(wildcard $(firstword $(subst /vm/,/ vm/,$(CURRENT_DIR_PATH)))tools/BuildConfigScripts/src))
endif 
ifeq ($(PYTHON_TOOLS),)
# Local branch dir didn't work... next look in the ADK
PYTHON_TOOLS = $(strip $(wildcard $(firstword $(subst /apps/,/ apps/,$(CURRENT_DIR_PATH)))tools/bin))
endif
ifeq ($(PYTHON_TOOLS),)
# If all else fails look in the DEVKIT
ifdef DEVKIT_ROOT
DEVKIT_ROOT_PATH = $(DEVKIT_ROOT:\=/)
PYTHON_TOOLS = $(strip $(wildcard $(DEVKIT_ROOT_PATH)/tools/bin))
endif
endif

ifndef PYTHON_TOOLS
  $(error Unknown Environment)
endif

PYTHON_TOOLS_LOCATION = $(subst \,/,$(PYTHON_TOOLS))
$(info $(PYTHON_TOOLS_LOCATION))

ifdef DEVKIT_ROOT
PYTHON=$(DEVKIT_ROOT)/tools/Python27/python
else
PYTHON=python
endif

RUN_CONFIG_BUILD_SRC:=$(PYTHON) $(PYTHON_TOOLS_LOCATION)/moduledef2configdef.py
RUN_CONFIG_BUILD_EXE:=$(PYTHON_TOOLS_LOCATION)/config_build.exe

ifdef DEVKIT_ROOT
CONFIG_BUILD_EXE_CMD:=$(RUN_CONFIG_BUILD_SRC)
else
CONFIG_BUILD_EXE_CMD:=$(if $(findstring src, $(PYTHON_TOOLS_LOCATION)),$(RUN_CONFIG_BUILD_SRC),$(RUN_CONFIG_BUILD_EXE))
endif

#Name for the config definition files
CONFIG_DEFINITION=config_definition

#Hardware revision for Hydra Core Builds
HYDRA_CORE_SDK_VARIANT:=csra68100_d01

#Name for the dir containing the module config definition files
MODULE_DEFINITION_DIR=$(SRC_DIR)/module_configurations

#Temp variables used to determine dependent modules
COMMON_IAS:=
INPUT_MGR:=

#All core modules xml config files should be listed here
USED_MODULES=source_aghfp_data_def.xml
USED_MODULES+=source_a2dp_module_def.xml
USED_MODULES+=source_avrcp_module_def.xml
USED_MODULES+=source_usb_data_def.xml
USED_MODULES+=source_private_data_module_def.xml
USED_MODULES+=source_power_manager_module_def.xml      

# Prepend the dir containing the module config defintions
MODULE_DEFINITIONS= $(USED_MODULES:%.xml=$(MODULE_DEFINITION_DIR)/%.xml)

# Get Python to print out a space-separated list of the Name attributes of all
# the root nodes of the module definitions we're using.  These are then easily
# translated into the names of the config headers that moduledef2configdef.py
# creates.
# Implementation note: this could be done with slightly less Python using a
# foreach loop in Make.  But that means multiple invocations of Python, which is
# noticeably slower.  
CONFIG_HEADERS = $(patsubst %, $(SRC_DIR)/%_config_def.h,$(shell $(PYTHON) -c \
'from xml.etree import cElementTree as ET; import sys; print " ".join([ET.parse(m).getroot().attrib["Name"].lower() for m in sys.argv[1:]])' \
$(MODULE_DEFINITIONS)))

ifeq (None, $(HW_VARIANT))
    $(error Hardware Variant must be set in project properties)
endif

ifeq (None, $(SW_VARIANT))
    $(error Software Variant must be set in project properties)
endif

ifneq (,$(findstring HYDRACORE,$(DEFS)))
    PLATFORM=HYDRACORE
else
    PLATFORM=BLUECORE
endif

INPUTS+=$(SRC_DIR)/$(CONFIG_DEFINITION).c

# Make the config_build target phony so that is always run.
# The script itself checks if any of the generated files differ from the
# exisiting files and will not overwrite them if they are the same.
.PHONY : config_build

$(SRC_DIR)/$(CONFIG_DEFINITION).c $(SRC_DIR)/$(CONFIG_DEFINITION).h $(CONFIG_HEADERS) : config_build

# Note: The first 5 user PS keys are reserved for persistent data stored at runtime - see sink_configmanager.h
config_build : $(SRC_DIR)/global_config.xml $(MODULE_DEFINITIONS)
	$(CONFIG_BUILD_EXE_CMD) -s $(PLATFORM) -g $(SRC_DIR)/global_config.xml -ocd $(CONFIG_DEFINITION) -o $(SRC_DIR)/ $(MODULE_DEFINITIONS) -vvv -psk 2-49,150-199 -pm $(SRC_DIR)/pskey_map.xml -hw $(HW_VARIANT) -sw $(SW_VARIANT) -l $(SRC_DIR)/config_build.log
ifeq (HYDRACORE,$(PLATFORM))
	@$(copyfile) $(SRC_DIR)/$(CONFIG_DEFINITION).gz $(SRC_DIR)/$(HYDRA_CORE_SDK_VARIANT)/customer_ro_filesystem/$(CONFIG_DEFINITION).gz
endif

config_clean :
	$(del) $(SRC_DIR)/*config_def.h
	$(del) $(SRC_DIR)/$(CONFIG_DEFINITION).*
ifeq (HYDRACORE,$(PLATFORM))
	$(del) $(SRC_DIR)/$(HYDRA_CORE_SDK_VARIANT)/customer_ro_filesystem/$(CONFIG_DEFINITION).gz
else ifeq (BLUECORE,$(PLATFORM))
	$(del) $(SRC_DIR)/image/$(CONFIG_DEFINITION).gz
endif

ifeq (HYDRACORE,$(PLATFORM)) # HYDRACORE uses single colon rules for these targets.

build: config_build

clean: config_clean

else # BLUECORE uses double colon rules for these targets.

build:: config_build

clean:: config_clean

# Config definition file
image/$(CONFIG_DEFINITION).gz : $(CONFIG_DEFINITION).gz
	$(copyfile) $< $@

image.fs : image/$(CONFIG_DEFINITION).gz

endif
