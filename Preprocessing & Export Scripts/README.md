###hdf5.IO

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
