# runs the simulations

# MODE can be app or compliance
MODE ?= app

ifeq ($(MODE),app)

	TOPMOD := core_with_mem
	IMEMFILE := ""
	DMEMFILE := ""
	DEFINES := -GIMEMFILE=\"$(IMEMFILE)\" -GDMEMFILE=\"$(DMEMFILE)\" -GINIT_DDR3_MEMORY=$(INIT_DDR3_MEMORY) \
		-GDDR3_MEMFILE=\"$(DDR3_MEMFILE)\"
	DO_FILE := run_gui.tcl

else ifeq ($(MODE),compliance)

	TOPMOD := riscv_tests

	# signature start and end
	begin_signature ?= 0
	end_signature ?= 0
	sig_filename_o ?= ""

	DEFINES := +begin_signature=${begin_signature} +end_signature=${end_signature} +sig_filename_o=${sig_filename_o} -GMEMFILE=\"$(MEMFILE)\"
	DO_FILE := run_gui_compliance.tcl
else
	$(error MODE $(MODE) not supported. Supported modes are app and compliance)
endif

# simulation definitions
MEMFILE := ""
CURRENT_DIR=$(shell pwd)

SRC_DIR = $(CURRENT_DIR)/../src
$(info SRC_DIR is $(SRC_DIR))
SIMPROG := tb
SIMFILE := $(SIMPROG).cpp
VDIRFB  := ./obj_dir
TOP_PARAMS := $(DEFINES)

VIVADO_SIM_FILES_PATH := /home/robin/workdir/xilinx_sims
VIVADO_INSTALL_DIR_SRC_PATH := /home/robin/Tools/Xilinx/Vivado/2023.1
VIVADO_COMPILE_COMMAND := -reflib $(VIVADO_SIM_FILES_PATH)/unisims_ver -reflib $(VIVADO_SIM_FILES_PATH)/secureip -reflib $(VIVADO_SIM_FILES_PATH)/unifast_ver \
	-reflib $(VIVADO_SIM_FILES_PATH)/simprims_ver -reflib $(VIVADO_SIM_FILES_PATH)/unimacro_ver $(VIVADO_INSTALL_DIR_SRC_PATH)/data/verilog/src/glbl.v -top glbl

PRJ_DIR := $(SRC_DIR)
export PRJ_DIR
export SIM_TOP = $(TOPMOD)
export OBJCACHE = ccache

TIMESCALE := -timescale "1ps/1ps"

#verilator arguments
VERILATOR=verilator
VFLAGS= -cc --timing -f files.tcl $(TOP_PARAMS) --top-module $(TOPMOD) -O3 --noassert --x-assign fast --x-initial fast --timescale "1ns/1ps" --trace-fst

IS_GUI ?= 1

VERILATOR_CFLAGS := `sdl2-config --cflags` -O3
VERILATOR_LDFLAGS := `sdl2-config --libs`
VERILATOR_CPP_FILES := $(CURRENT_DIR)/verilator_src/tb_clock.cpp $(CURRENT_DIR)/verilator_src/main_$(TOPMOD).cpp

verilator: V$(TOPMOD)

V$(TOPMOD): obj_dir/V$(TOPMOD).mk
	$(MAKE) -C ./obj_dir -f $(notdir $<)
	mv obj_dir/V$(TOPMOD) V$(TOPMOD)

obj_dir/V$(TOPMOD).mk: $(PRJ_DIR)/testbenches/$(TOPMOD).sv
	$(VERILATOR) $(VFLAGS) --exe $(VERILATOR_CPP_FILES) -CFLAGS "${VERILATOR_CFLAGS}" \
	-LDFLAGS "${VERILATOR_LDFLAGS}"

run_sim:
	obj_dir/V$(TOPMOD) +trace

# QUESTASIM ARGUMENTS
LIB_NAME ?= work
# TOP_PARAMS += +begin_signature=${begin_signature} +end_signature=${end_signature} +sig_filename_o=${sig_filename_o} -GMEMFILE=\"$(MEMFILE)\"

ifeq ($(IS_GUI), 1)
	TOP_PARAMS += -gui=interactive 
else
	DO_FILE := run.tcl
endif

VIVODO_LIBS_COMMAND := 

questa:
	qrun -64 +acc -modelsimini modelsim.ini -f files.tcl -sv -sv12compat $(TIMESCALE) -O5 -outdir questa_work -top $(TOPMOD) $(TOP_PARAMS) -do $(DO_FILE) $(VIVADO_COMPILE_COMMAND)

questa_clean:
	qrun -clean

clean:
	rm -rf $(VDIRFB)/

.PHONY: questa questa_clean clean run_sim verilator