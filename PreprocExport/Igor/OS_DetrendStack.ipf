#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Official ScanM Data Preprocessing Scripts - by Tom Baden    	///
/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Requires raw 3D data in 16 bits with no preprocessing			///
///	Input Arguments - which Channel (0,1,2...?)				     	///
///	e.g. "OS_DetrendStack(0)	"							     	///
///   --> reads wDataCh0,1,2...									///
///   --> for each pixel subtracts heavily smoothed version of itself   	///
///   --> ...and adds its own mean (to avoid going out of range)		///
///	Output is new wave called wDataCh..._detrended				///
/////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_DetrendStack()

// flags from "OS_Parameters"
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
variable Channel = OS_Parameters[%Data_Channel]
variable nSeconds_smooth = OS_Parameters[%Detrend_smooth_window]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)
string output_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
duplicate/o InputData OutputData

// calculate size of smoothing window
variable Framerate = 1/(nY * 0.002) // Hz
variable Smoothingfactor = Framerate * nSeconds_smooth
if (Smoothingfactor>2^15-1) // exception handling - limit smooth function to its largest allowed input
	Smoothingfactor = 2^15-1 
endif

// detrending
variable PercentDone = 0
variable PercentPerPixel = 100/(nX*nY)
variable xx,yy
printf "Detrend progress: "
for (xx=0; xx<nX; xx+=1)
	for (yy=0; yy<nY; yy+=1)
		make/o/n=(nF) CurrentTrace = InputData[xx][yy][p]
		Wavestats/Q CurrentTrace
		Smooth Smoothingfactor, CurrentTrace
		OutputData[xx][yy][]-=CurrentTrace[r]-V_Avg
		PercentDone+=PercentPerPixel
	endfor
	if (PercentDone>=10)
		PercentDone-=10
		printf "#"
	endif
endfor

// generate output
duplicate /o OutputData $output_name

// cleanup
killwaves CurrentTrace,InputData,OutputData

// outgoing dialogue
print "# complete..."

end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_DetrendRatiometric()

// flags from "OS_Parameters"
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
variable Channel = OS_Parameters[%Data_Channel]
variable Channel2 = OS_Parameters[%Data_Channel2]
variable nSeconds_smooth = OS_Parameters[%Detrend_smooth_window]
variable Detrend_Ratiometricdata = OS_Parameters[%Detrend_RatioMetricData]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)
string input_name2 = "wDataCh"+Num2Str(Channel2)
string output_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
duplicate /o $input_name2 InputData2
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
duplicate/o InputData OutputData

// Get RatioMetric Stack (after which everything is identical to DetrendStack routine)
make /o/n=(nX,nY) InputData2_frame2 = InputData2[p][q][1]
ImageStats/Q InputData2_frame2
variable InputData2_brightness = V_Avg
InputData[][][]/=InputData2[p][q][r]/InputData2_brightness


if (Detrend_RatiometricData==0)
	print "Complete... (no detrending done, only Channel division)"
	OutputData[][][]=InputData[p][q][r]
else

	// calculate size of smoothing window
	variable Framerate = 1/(nY * 0.002) // Hz
	variable Smoothingfactor = Framerate * nSeconds_smooth
	if (Smoothingfactor>2^15-1) // exception handling - limit smooth function to its largest allowed input
		Smoothingfactor = 2^15-1 
	endif
	
	// detrending
	variable PercentDone = 0
	variable PercentPerPixel = 100/(nX*nY)
	variable xx,yy
	printf "Detrend progress: "
	for (xx=0; xx<nX; xx+=1)
		for (yy=0; yy<nY; yy+=1)
			make/o/n=(nF) CurrentTrace = InputData[xx][yy][p]
			Wavestats/Q CurrentTrace
			Smooth Smoothingfactor, CurrentTrace
			OutputData[xx][yy][]-=CurrentTrace[r]-V_Avg
			PercentDone+=PercentPerPixel
		endfor
		if (PercentDone>=10)
			PercentDone-=10
			printf "#"
		endif
	endfor
	// outgoing dialogue
	print "# complete..."
endif	
	
// generate output
duplicate /o OutputData $output_name

// cleanup
killwaves CurrentTrace,InputData,OutputData,InputData2,InputData2_frame2
	

	
end