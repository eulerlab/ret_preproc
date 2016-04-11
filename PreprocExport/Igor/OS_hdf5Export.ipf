#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Export()
	Variable fileID
	Wave wParamsNum,wParamsStr
	NewPath targetPath
	string pathName = "targetPath"
	HDF5CreateFile/P=$pathName /O /Z fileID as GetDataFolder(0)
	if (waveexists($"Triggervalues")==0)
		print "No triggervalues detected, exporting raw data channels."
		WAVE wDataCh0, wDataCh1
		HDF5SaveData /O /Z wDataCh0, fileID
		HDF5SaveData /O /Z wDataCh1, fileID
		HDF5SaveData /O /Z wParamsNum, fileID
		HDF5SaveData /O /Z wParamsStr, fileID
		HDF5CloseFile fileID
	else
		print  "Triggervalues detected, exporting processed data."
		WAVE OS_Parameters,ROIs,Traces0_raw,Traces0_znorm,Tracetimes0,Triggertimes,Triggervalues
		WAVE stack_ave, stack_ave_report, wDataCh0, GeoC
		HDF5SaveData /O /Z /IGOR=8 OS_parameters, fileID
		HDF5SaveData /O /Z wParamsNum, fileID
		HDF5SaveData /O /Z wParamsStr, fileID
		HDF5SaveData /O /Z ROIs, fileID
		HDF5SaveData /O /Z Traces0_raw, fileID
		HDF5SaveData /O /Z Traces0_znorm, fileID
		HDF5SaveData /O /Z Tracetimes0, fileID
		HDF5SaveData /O /Z Triggertimes, fileID
		HDF5SaveData /O /Z Triggervalues, fileID

		//saving necessary things for RGC chirp analysis
		//wDataCh0 is necessary for the movie
		if (waveexists($"stack_ave"))			
			//HDF5SaveData /O /Z wDataCh0, fileID
			HDF5SaveData /O /Z GeoC, fileID
			HDF5SaveData /O /Z stack_ave, fileID
			//HDF5SaveData /O /Z stack_ave_report, fileID
		endif
		HDF5CloseFile fileID
	endif
end