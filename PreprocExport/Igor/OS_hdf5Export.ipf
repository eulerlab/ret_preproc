#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Export()
	Variable fileID
<<<<<<< HEAD
	Wave wParamsNum,wParamsStr
=======
>>>>>>> origin/master
	NewPath targetPath
	string pathName = "targetPath"
	HDF5CreateFile/P=$pathName /O /Z fileID as GetDataFolder(0)
	if (waveexists($"Triggervalues")==0)
		print "No triggervalues detected, exporting raw data channels."
		WAVE wDataCh0, wDataCh1
		HDF5SaveData /O /Z wDataCh0, fileID
		HDF5SaveData /O /Z wDataCh1, fileID
<<<<<<< HEAD
		HDF5SaveData /O /Z wParamsNum, fileID // Andre addition - saves header
		HDF5SaveData /O /Z wParamsStr, fileID // header 2
=======
>>>>>>> origin/master
		HDF5CloseFile fileID
	else
		print  "Triggervalues detected, exporting processed data."
		WAVE OS_Parameters,ROIs,Traces0_raw,Traces0_znorm,Tracetimes0,Triggertimes,Triggervalues
<<<<<<< HEAD
		WAVE stack_ave, stack_ave_report, wDataCh0, GeoC, Snippets0,SnippetsTimes0
=======
>>>>>>> origin/master
		HDF5SaveData /O /Z /IGOR=8 OS_parameters, fileID
		HDF5SaveData /O /Z wParamsNum, fileID // Andre addition - saves header
		HDF5SaveData /O /Z wParamsStr, fileID // header 2
		HDF5SaveData /O /Z ROIs, fileID
		HDF5SaveData /O /Z Traces0_raw, fileID
		HDF5SaveData /O /Z Traces0_znorm, fileID
		HDF5SaveData /O /Z Tracetimes0, fileID
		HDF5SaveData /O /Z Triggertimes, fileID
		HDF5SaveData /O /Z Triggervalues, fileID
		HDF5SaveData /O /Z GeoC, fileID // Andre - now also saves cell positions in the field
		HDF5SaveData /O /Z stack_ave, fileID // Andre - now also saves the mean image across the stack in the data channel 0

		if (waveexists($"SnippetsTimes"+num2str(OS_Parameters[%Data_channel]))) // Andre 2016 04 13
			HDF5SaveData /O /Z Snippets0, fileID
			HDF5SaveData /O /Z SnippetsTimes0, fileID
		endif
		HDF5CloseFile fileID
	endif
end