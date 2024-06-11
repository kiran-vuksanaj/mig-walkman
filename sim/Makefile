# Makefile

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES = 1

VERILOG_SOURCES += $(PWD)/../hdl/parse_wav.sv
# use VHDL_SOURCES for VHDL files

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = parse_wav

# MODULE is the basename of the Python test file
MODULE = wav_tb

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
