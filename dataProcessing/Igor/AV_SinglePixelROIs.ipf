#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////
//Code to analyze imaging data on a pixel by pixel basis
//Creates a ROI mask to be used in the OS preprocessing scripts
//This can be used to do "Traces and Triggers" on single pixels

function SinglePixelROIs()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters

//reset some variables so later scripts know we're doing single pixel analysis
OS_Parameters[%ROI_minpix] = 1
OS_Parameters[%ROI_mindiameter] = 1
OS_Parameters[%ROI_maxdiameter] = 1

// 2 //  check for Detrended Data stack
variable Channel = OS_Parameters[%Data_Channel]
if (waveexists($"wDataCh"+Num2Str(Channel)+"_detrended")==0)
	print "Warning: wDataCh"+Num2Str(Channel)+"_detrended wave not yet generated - doing that now..."
	OS_DetrendStack()
endif

// flags from "OS_Parameters"
variable X_cut = OS_Parameters[%LightArtifact_cut]
variable LineDuration = OS_Parameters[%LineDuration]

// data handling
wave wParamsNum // Reads data-header
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
variable Framerate = 1/(nY * LineDuration) // Hz 
variable Total_time = (nF * nX ) * LineDuration
print "Recorded ", total_time, "s @", framerate, "Hz"
variable xx,yy,ff // initialise counters

// calculate Pixel / ROI sizes in microns
variable zoom = wParamsNum(30) // extract zoom
variable px_Size = (0.65/zoom * 110)/nX // microns
print "Pixel Size:", round(px_size*100)/100," microns"

// make SD average
make /o/n=(nX,nY) Stack_SD = 0 // Avg projection of InputData
make /o/n=(nX,nY) ROIs = 1 // empty ROI wave
make /o/n=(nF) currentwave = 0
for (xx=X_cut;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		Multithread currentwave[]=InputData[xx][yy][p] // get trace from "reference pixel"
		Wavestats/Q currentwave
		Stack_SD[xx][yy]=V_SDev
	endfor
endfor

StatsQuantiles/Q Stack_SD
variable SDthresh = V_Q75 //threshold standard deviation to include in analysis, normally V_Q25

variable countdown = -1

//Assigns pixels whose standard deviation is above threshold (25%ile) a negative integer index
for (yy=0; yy<nY; yy+=1)
	for (xx=X_cut; xx<nX;xx+=1)
		if (Stack_SD[xx][yy]>SDthresh)
			ROIs[xx][yy]=countdown
			countdown-=1
		endif
	endfor
endfor

// cleanup
killwaves currentwave,InputData
 
print "Done making ROIs"
print "There are",-1*countdown,"single pixel ROIs included in analysis, out of",nX*nY,"total pixels"
end