## ScanM FileIO - Stand-alone IgorPRO reader for ScanM data files

### Release notes

#### ScanM v2.04

* Added more scan configurations that use the ETL, such as:
  - xz-scans, with the x mirror as the fast scanner and the ETL moving the scan line step-wise vertically into
    the tissue (vertical "slice"). 
  - xz bi-directional scans, an improved version of the xz-scan, with the ETL not jumping back before the next frame
    but stepping back up. Should eliminate ETL vibration (?) artifact observed in xz-scans. Still to be tested. 
  - zx-scans, with the ETL modulated sinusoidally at 250 Hz and the x mirror slowly advancing across the tissue,
    allowing to trade spatial for temporal resolution by adjusting the number of z "lines". Still being 
    tested (Status: Image looks as if ETL cannot follow; need to check if indeed the ETL is too slow or if the 
    lens driver does not drive the lens correctly).
* Bug fix: ETL neutral voltage should now be kept in all phases of ScanM operation.
* ``.SMH`` files now also contain information about the ETL settings.
* Modification of ``ScM_FileIO.ipf``:
  Many changes to accommodate the new scan configuration while staying compatible to older ScanM data files. 
  Three cases of scan data are now considered:

     - scans that are easily to reconstruct w/o information loss (e.g. standard xy scans)

     - scans where the pixel data needs to be reordered but is loss-less (e.g. bidirectional xz scans)
       
     - scans that cannot be easily represented on the screen and that require a decoder to reconstruct an image,
        which represents an approximation (= down-sampled version) of the actually scan field. Here, the decoding 
        may involve information loss (e.g. spiral scans).

   As a consequence, when importing pixel data for scans of the last type, both the raw data is imported (e.g. 
   ``wDataCh0_raw``) and a reconstructed representation (``wDataCh0``) is generated, using the original scan
   path function. In addition, the ``ScM_FileIO.ipf`` regenerates the stimulus buffers and stores them in an own
   data folder; these are then accessible for analysis scripts, e.g. to determine the exact timing of each pixel.

### Installation

*IMPORTANT:* The stand-alone ScanM file reader also works with IgorPro 7, although currently only with the 32bit version.

Get the latest ret_preproc package as a ZIP file from GitHub and search for the folder where IgorPro keeps the the 
user-specific files (workspace). The path is usually something like: ```C:\User Documents\WaveMetrics\Igor Pro 6 User Files```.

*Note:* The following procedure can also be used for IgorPro 7 (32bit version only) by simple using the respective IgorPro 7 workspace. 

1. If not already present, create a new folder named ```ScanM\``` under ```...\Igor Pro 6 User Files\``` and copy the file 
   ```ScanDecoder.xop``` from the ZIP folder ```ret_preproc-master\ScaM\ScanM_FileIOScanM``` into that folder.

3. In ```...\Igor Pro 6 User Files\Igor Extensions``` make a shortcut to ```ScanDecoder.xop```.

4. Under ```...\Igor Pro 6 User Files\User Procedures``` create a new folder named ```ScanM``` and copy
   all files from the ZIP-folder ```ret_preproc-master\ScaM\ScanM_FileIO``` into that folder.

5. In ```...\Igor Pro 6 User Files\Igor Procedures``` make a shortcut to ```...\Igor Pro 6 User Files\User Procedures\ScanM\ScM_FileIO.ipf```. 

If an error related to the ScanDecoder function occurs on startup, check that ScanDecoder has been copied to the correct folder 
and that the shortcut has been made.
