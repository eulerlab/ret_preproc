# hdf5.IO
Import and export hdf5 files from Igor. Import files to Python.

Dependencies: SARFIA (essential), HDF5 XOP (essential, see below), ScanM IO (recommended).

Ensure that:
'constant        SCMIO_addCFDNote            = 1'
... is set correctly in the ScM script, or errors will be triggered.

Call all functions via `"OS_GUI()"`

The following waves are exported from Igor and imported to Python:

OS_Parameters (1D with labels) - Likely to change in future

ROIs (2D wave)

Traces0_raw // 2D

Traces0_znorm // 2D

Tracetimes0 // 2D in seconds

Triggertimes // 1D in seconds

Triggervalue // 1D

Other waves that may be of interest:

RoisSizes//1D

Stack_SD //2D

wDataCh0_detrended // (raw data detrended) (3D)

Note: Python does not currently export labels from OS_Parameters

Prerequistites:

1) HDF5 Loader initiated (make shortcut from ...Wavemetrics.../More Extensions/File Loaders/HDF5 and stick that shortcut into Igor Extensions)
2) SARFIA needs to be installed
3) ScanMLoader installed, in 64 bit config without Trigger channel merging option

- Now take all "OS" scripts and dump them inside User Procedures (subfolder is fine)
- Go to "Igor Procedures/Customstart.ipf" and add the following line:

`#include "OS_GUI"`

Done

If reload Igor, should now be able to call the GUI using "OS_GUI()"
