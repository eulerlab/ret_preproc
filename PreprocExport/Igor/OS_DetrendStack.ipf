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
variable xx,yy
for (xx=0; xx<nX; xx+=1)
	for (yy=0; yy<nY; yy+=1)
		make/o/n=(nF) CurrentTrace = InputData[xx][yy][p]
		Wavestats/Q CurrentTrace
		Smooth Smoothingfactor, CurrentTrace
		OutputData[xx][yy][]-=CurrentTrace[r]-V_Avg
	endfor
endfor

// generate output
duplicate /o OutputData $output_name

// cleanup
killwaves CurrentTrace,InputData,OutputData

// outgoing dialogue
print "Detrending complete..."

end