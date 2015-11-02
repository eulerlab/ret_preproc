#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Import()
	variable fileID
	HDF5OpenFile/R/Z fileID as "preprocessedData.h5"
	HDF5LoadData /O /Z /IGOR=8 fileID, "OS_Parameters"
	HDF5LoadData /O /Z fileID, "ROIs" 
	HDF5LoadData /O /Z fileID, "Traces0_raw"
	HDF5LoadData /O /Z fileID, "Traces0_znorm"
	HDF5LoadData /O /Z fileID, "Tracetimes0"
	HDF5LoadData /O /Z fileID, "Triggertimes"
	HDF5LoadData /O /Z fileID, "Triggervalues"
	HDF5CloseFile fileID
end