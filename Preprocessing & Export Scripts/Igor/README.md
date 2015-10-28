###Preprocessing ScanM imaging data (with IgorPRO)

####Prerequisites:

- the HDF5 Loader is installed (shortcuts to the files starting with ``...\Wavemetrics\...\More Extensions\File Loaders\HDF5`` need to be present in ``...\User\...\WaveMetrics\Igor Pro 6 User Files\Igor Extensions``)

- SARFIA is installed (see http://www.igorexchange.com/project/SARFIA)

- the ScanM file loader is installed (see ``ret_preprocessing/ScM/ScanM_FileIO``)

####Installation:

1. Take all "OS" scripts and dump them inside ``...\User\...\WaveMetrics\Igor Pro 6 User Files\User Procedures`` (a subfolder is fine)
   
2. Go to ``...\User\...\WaveMetrics\Igor Pro 6 User Files\Igor Procedures\Customstart.ipf`` and add the following line:

  ``#include "OS_GUI``

After restarting IgorPRO, you should now be able to call the GUI using ''OS_GUI()''
