### ret_preproc
This repository contains the latest scripts for preprocessing data in Igor and exporting it to Python. The intention is that data which has gone through this pipeline can be uploaded directly to a MySQL database using the Datajoint module for Python. In addition, scripts for uploading electrophysiology data to Python are under development, making use of the stfio module.

The sister repository, located at Eulerlab/ret_datajoint will contain further scripts for interfacing Python with MySQL. Development for this is not yet underway.

Comments and suggestions should be directed to the developer associated with particular scripts, who are as follows:

1. ScanM Form Generator and ScaM IO (Igor) - Thomas Euler

2. Preprocessing scripts (Igor) - Tom Baden

3. Datajoint (Python) - Philipp Berens

4. Electrophysiology (Python) - Theresa Stadler

5. Hdf5 export (Igor) and import (Python) - Luke Rogerson

#### Further Information

Datajoint Homepage: https://datajoint.github.io/


## Installing Dependencies

In order to use the Igor Preprocessing Pipeline, you will need to set up the HDF5 Loader and SARFIA. 

### HDF5 Loader

The HDF5 Loader can be added to Igor by going to the Igor installation directory (typically under Program Files/Wavemetrics on your C: drive) and making a shortcut to the file: `\Wavemetrics\...\More Extensions\File Loaders\HDF5`

And copying this shortcut to: `\User\...\WaveMetrics\Igor Pro 6 User Files\Igor Extensions`

You can confirm that this has installed correctly by opening Igor and checking that the entry New HDF5 Browser is available under the menu Data:Load Waves. 

For more information, see:

www.wavemetrics.com/products/igorpro/dataaccess/hdf5.htm

www.wavemetrics.net/doc/igorman/II-09%20Data%20Import%20Export.pdf

### SARFIA

The scripts for SARFIA are available at: www.igorexchange.com/project/SARFIA

Installation instructions are available on that page.

## Installing Preprocessing Scripts

Downloading the Repository

The Igor Preprocessing scripts are available at: github.com/eulerlab/ret_preproc

There are two methods by which you can set up the repository. The easiest way is to download the repository as a zip file by clicking the green 'Clone or Download' button on the right side of the webpage, and selecting download zip. You can then unpack this file using, for example, Winrar archive manager.

Alternatively, you can download Github for Windows Desktop, from: desktop.github.com/

Once this is installed, sign in with a Github account (which you can create for free if you don't have one), click the '+' symbol in the corner, and then click 'clone repository'. From here it should be possible to enter a repository url; enter the preprocessing repository provided above. The convenience of this method is that you can update to the latest version of the repository by simply clicking 'Sync' in the Github Desktop GUI. Once you have cloned (i.e. copied) the repository, you will be able to find a copy of it in your My Documents, under: `My Documents/Github/Ret_Preproc`

In order for Igor to be able to access the scripts, they have to be copied to the appropriate directory. Check that you have a Wavemetrics folder in your My Documents (this should be set up automatically when you install Igor). Make a folder in User Procedures called OS, for the preprocessing scripts, and ScM, for the ScanM file loader and header file writer. 

From your downloaded copy of the repository, copy all the scripts under: `Ret_Preproc/ScM` to `/Wavemetrics/User Procedures/ScanM`, `Ret_Preproc/PreprocExport/Igor to /Wavemetrics/User Procedures/OS`.

> Note: _Please make sure that the respective **folders** under `/Wavemetrics` are called **`ScanM`** and not `ScM`._

In addition, you need to make shortcuts to : `OS/OS_GUI.ipf`, `ScanM/ScanM_FileIO/ScM_FileIO.ipf`, `ScanM/ScanM_formGenerator/ScM_formGenerator_GUI.ipf`. Copy these shortcuts to: `Wavemetrics/Igor Procedures`.

## Preprocessing Data

### Analysing Your Data

The scripts in your $OS$ folder provide the basic functionality required to do simple analysis on your data. Having loaded your data to the experiment using the loader provided in the ScanM menu ($Load ScanM data file...$), select the data folder for which you want to run the scripts. You can run the analysis scripts through the GUI, which is opened by selecting $Open OS GUI$ from the ScanM menu. 

The first button generates a parameter table, which allows you to modify some of the settings in the subsequent preprocessing scripts of the preprocessing scripts (the $OS\_Parameters$ wave). The raw data is then detrended using either the $One\ Channel$ or $Ratiometric$ button, to remove slow drifting effects. There are several options provided for drawing the ROI masks. While automated methods require less interaction from the user, their precision is quite limited. 

Having drawn a ROI mask, the $Traces\ and\ Triggers$ button will extract the traces according to the Triggers detected in the trigger channel, extracting one row to an output wave for each ROI in the mask. Several optional display functions are then provided for visualising the output. Keep in mind that the $RFs$ button will only work for data generated by noise stimuli. 

Once you have finished executing these scripts, export your data using the $Export$ button at the bottom of the GUI. This will pack the important waves from your preprocessing into a .h5 file, ready to be put on the server. Please ensure that you copy the file to the Euler Data folder's on the CIN server, and that they obey the correct naming conventions. 

### Creating a Header File

You can create a header file by selecting the option from the ScanM menu. If the option is not there, it is likely that the scripts have not been placed correctly within the Wavemetrics directory. When creating a new header file, you need to select the following template to generate the blank form: `experimentHeaderFile_template.txt`. The option will then be given to load a previously completed form as a template. This can make the process of filling these forms considerably quicker, and is recommended.

Most of the entries in the table are quite self-explanatory. Project names can be chosen at your discretion, but please keep them short. Please provide surnames when prompted for a name. Descriptions of some entries are included on the form, but is there is any ambiguity, please ask. Once you have completed the form, save it using the button at the bottom and copy the file to the appropriate Experiment folder on the server. If you need to close the header GUI, repeatedly clicking the cross in the corner will cause a prompt to come up which will allow you to do so.
