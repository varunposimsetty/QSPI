# Load the VCD file
gtkwave::loadDumpFile "WAVE_FILE"

# Add all top-level signals
set sigs [gtkwave::getTopLevelSigs]
foreach sig [lsort ] {
    gtkwave::addSignalsFromList 
}
