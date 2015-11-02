#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Export()
	if (waveexists($"Triggervalues")==0)
		print "Warning: Triggervalues wave not yet generated - doing nothing..."
		DoUpdate
	else
		Variable fileID
		WAVE OS_Parameters,ROIs,Traces0_raw,Traces0_znorm,Tracetimes0,Triggertimes,Triggervalues
		NewPath targetPath
		string pathName = "targetPath"
		HDF5CreateFile/P=$pathName /O /Z fileID as "preprocessedData.h5"
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