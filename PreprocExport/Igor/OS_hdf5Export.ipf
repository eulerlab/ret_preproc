#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Export()
	Variable fileID
	NewPath targetPath
	string pathName = "targetPath"
	HDF5CreateFile/P=$pathName /O /Z fileID as GetDataFolder(0)
	if (waveexists($"Triggervalues")==0)
		print "No triggervalues detected, exporting raw data channels."
		WAVE wDataCh0, wDataCh1
		HDF5SaveData /O /Z wDataCh0, fileID
		HDF5SaveData /O /Z wDataCh1, fileID
		HDF5CloseFile fileID
	else
		print  "Triggervalues detected, exporting processed data."
		WAVE OS_Parameters,ROIs,Traces0_raw,Traces0_znorm,Tracetimes0,Triggertimes,Triggervalues
		HDF5SaveData /O /Z /IGOR=8 OS_parameters, fileID
		HDF5SaveData /O /Z ROIs, fileID
		HDF5SaveData /O /Z Traces0_raw, fileID
		HDF5SaveData /O /Z Traces0_znorm, fileID
		HDF5SaveData /O /Z Tracetimes0, fileID
		HDF5SaveData /O /Z Triggertimes, fileID
		HDF5SaveData /O /Z Triggervalues, fileID
		HDF5CloseFile fileID
	endif
end