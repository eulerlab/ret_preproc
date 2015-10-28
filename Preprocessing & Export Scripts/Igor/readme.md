Prerequistites:

1) HDF5 Loader initiated (make shortcut from ...Wavemetrics.../More Extensions/File Loaders/HDF5 and stick that shortcut into Igor Extensions)
2) SARFIA needs to be installed
3) ScanMLoader installed, in 64 bit config without Trigger channel merging option

- Now take all "OS" scripts and dump them inside User Procedures (subfolder is fine)
- Go to "Igor Procedures/Customstart.ipf" and add the following line:

#include "OS_GUI"

Done

If reload Igor, should now be able to call the GUI using "OS_GUI()"
