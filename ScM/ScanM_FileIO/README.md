# ScanM FileIO - Stand-alone IgorPRO reader for ScanM data files

## Installation

*IMPORTANT:* The stand-alone ScanM file reader also works with IgorPro 7, although currently only with the 32bit version.

Get the latest ret_preproc package as a ZIP file from GitHub and search for the folder where IgorPro keeps the the 
user-specific files (workspace). The path is usually something like: ```C:\User Documents\WaveMetrics\Igor Pro 6 User Files```.

*Note:* The following procedure can also be used for IgorPro 7 (32bit version only) by simple using the respective IgorPro 7 workspace. 

1. If not already present, create a new folder named ```ScanM\``` under ```...\Igor Pro 6 User Files\``` and copy the file 
   ```ScanDecoder.xop``` from the ZIP folder ```ret_preproc-master\ScaM\ScanM_FileIOScanM``` into that folder.

3. In ```...\Igor Pro 6 User Files\Igor Extensions``` make a shortcut to ```ScanDecoder.xop```.

4. Under ```...\Igor Pro 6 User Files\User Procedures``` create a new folder named ```ScanM``` and copy
   all files from the ZIP-folder ```ret_preproc-master\ScaM\ScanM_FileIOScanM``` into that folder.

5. In ```...\Igor Pro 6 User Files\Igor Procedures``` make a shortcut to ```...\Igor Pro 6 User Files\User Procedures\ScanM\ScM_FileIO.ipf```. 

If an error related to the ScanDecoder function occurs on startup, check that ScanDecoder has been copied to the correct folder 
and that the shortcut has been made.
