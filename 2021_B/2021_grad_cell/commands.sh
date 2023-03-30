#!/bin/bash

ncverilog -sv tb.sv geofence.v DW_sqrt.v +access+r +notimingchecks

dc_shell-t -f syn.tcl | tee syn.log

/usr/cad/synopsys/synthesis/cur/dw/

vcs tb.sv geofence.v DW_sqrt.v -full64 -R -debug_access+all +v2k +notimingchecks  -sverilog
vcs tb.sv geofence.v DW_sqrt.v -full64 -R -debug_access+all +v2k +maxdelays -sverilog
