#!/bin/bash

WORK_DIR=work
WAVE_FILE=result.vcd
GTKPROJ_FILE=result.gtkw
TOP_MODULE=tb_QSPI_Master

mkdir -p "$WORK_DIR"

echo "Compiling sources..."
vlog -sv -work $WORK_DIR ../src/QSPI_Master.sv
vlog -sv -work $WORK_DIR ./tb_QSPI_Master.sv

echo "Running simulation, generating $WORK_DIR/$WAVE_FILE..."
vsim -c work.$TOP_MODULE -do "run 2 us; quit" -voptargs=+acc

echo "Launching GTKWave..."
if [ -f "$WORK_DIR/$GTKPROJ_FILE" ]; then
    gtkwave "$WORK_DIR/$WAVE_FILE" "$WORK_DIR/$GTKPROJ_FILE" &
else
    gtkwave "$WORK_DIR/$WAVE_FILE" &
    echo ">>> TIP: In GTKWave, arrange your signals once, then 'File -> Write Save File' to $WORK_DIR/$GTKPROJ_FILE for future runs."
fi

# Cleanup unnecessary files
echo "Cleaning up unnecessary files..."
rm -f "$WORK_DIR"/_info "$WORK_DIR"/*.qdb "$WORK_DIR"/*.qpg "$WORK_DIR"/*.qtl "$WORK_DIR"/_vmake  transcript
rm -f wl*
echo "Cleanup completed."