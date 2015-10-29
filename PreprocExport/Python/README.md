#### Using Import scripts 

Python Module Dependencies: h5py, numpy, os, pandas, seaborn

Note: These scripts will work in both the iPython server and desktop GUIs, but the directory access will differ.

1. Change the target directory to the location of the file e.g. os.chdir('>directoryName')

2. Execute the function importPreprocessedData. This will return two waves:

  1. importedData: The raw hdf5 data as it was imported into Python

  2. preprocessedData: The data extracted from the hdf5 data, stored in a form usable in the Python environment. Key:values are as follows

    1. OS_Parameters: Pandas DataFrame, with index labels corresponding to the labels in the original Igor Table2

    2. ROIs: Numpy array

    3. Traces0_raw: Pandas DataFrame with indexs as `ROI###`

    4. Traces0_znorm: Pandas DataFrame with indexes as `ROI###`

    5. Tracestimes0: Numpy array

    6. Triggertimes: Numpy array

    7. Triggervalues: Numpy array

Numpy arrays can be used much like matrices in MATLAB.

DataFrame objects are very similiar to arrays, but are structured as tables with column and row labels.

-- For Pandas documentation, see: http://pandas.pydata.org/
