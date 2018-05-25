#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Official ScanM Data Preprocessing Scripts - by Tom Baden    	///
/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Requires "ROIs", detrended data stack + trigger stack		///
///	Input Arguments - data Ch (0,1,2...?), Trigger Ch (0,1,2)     	///
///	e.g. "OS_TracesAndTriggers(0,2)"							///
///   --> reads wDataChX_detrended,wDataChY					///
///   --> generates 4 output waves								///
///   - TracesX: (per ROI, raw traces, by frames)					///
///   - TracesX_znorm: (per ROI, z-normalised traces, by frames)	///
///	- TracetimesX: for each frame (per ROI, 2 ms precision)		///
///   - Triggertimes: Timestamps of Triggers (2 ms precision)		///
///   - Triggervalue: Level of each Trigger  event							///
/////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_TracesAndTriggers()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
// 2 //  check for Detrended Data stack
variable DataChannel = OS_Parameters[%Data_Channel]
if (waveexists($"wDataCh"+Num2Str(DataChannel)+"_detrended")==0)
	print "Warning: wDataCh"+Num2Str(DataChannel)+"_detrended wave not yet generated - doing that now..."
	OS_DetrendStack()
endif
// 3 //  check for ROI_Mask
if (waveexists($"ROIs")==0)
	print "Warning: ROIs wave not yet generated - doing that now (using correlation algorithm)..."
	OS_AutoRoiByCorr()
	DoUpdate
endif

// flags from "OS_Parameters"
variable TriggerChannel = OS_Parameters[%Trigger_Channel]
variable Display_traces = OS_Parameters[%Display_Stuff]
variable trigger_threshold = OS_Parameters[%Trigger_Threshold] 
variable seconds_skip_after_trigger = OS_Parameters[%Trigger_after_skip_s] 
variable levelread_nY_after_trigger = OS_Parameters[%Trigger_levelread_after_lines]
variable nSeconds_prerun_reference = OS_Parameters[%Baseline_nSeconds]
variable TriggerHeight_Display = OS_Parameters[%Trigger_DisplayHeight] 
variable LineDuration = OS_Parameters[%LineDuration]
variable Ignore1stXseconds = OS_Parameters[%Ignore1stXseconds]
variable IgnoreLastXseconds = OS_Parameters[%IgnoreLastXseconds]
variable SkipLastTrigger = OS_Parameters[%Skip_Last_Trigger] // KF 20160310
variable TriggerMode = OS_Parameters[%Trigger_Mode]
variable StimulatorDelay = OS_Parameters[%StimulatorDelay]

// data handling
wave wParamsNum // Reads data-header
string input_name1 = "wDataCh"+Num2Str(DataChannel)+"_detrended"
string input_name2 = "wDataCh"+Num2Str(TriggerChannel)
string output_name1 = "Traces"+Num2Str(DataChannel)+"_raw"
string output_name2 = "Traces"+Num2Str(DataChannel)+"_znorm"
string output_name3 = "Tracetimes"+Num2Str(DataChannel)
string output_name4 = "Triggertimes"
string output_name5 = "Triggervalues"
string output_name6 = "Triggertimes_Frame"

duplicate /o $input_name1 InputData
duplicate /o $input_name2 InputTriggers
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
wave ROIs
variable nRois = Wavemin(ROIs)*(-1)
make /o/n=(nF,nRois) OutputTraces_raw = 0
make /o/n=(nF,nRois) OutputTraces_zscore = 0
make /o/n=(nF,nRois) OutputTraceTimes = 0
make /o/n=(nF) OutputTriggerTimes = NaN
make /o/n=(nF) OutputTriggerTimes_Frame = NaN
make /o/n=(nF) OutputTriggerValues = NaN
make /o/n=(nX,nY,nF) OutputPixelTimes = NaN
variable FrameDuration = nY * LineDuration

// call SARFIA function GeoC to get ROI positions
setscale x, 0, nX, ROIs // so that Geometric centre reads out pixel not microns KF 20160310
setscale y, 0, nY, ROIs
GeometricCenter(ROIs)
// calculate Pixel / ROI sizes in microns
variable zoom = wParamsNum(30) // extract zoom
variable px_Size = (0.65/zoom * 110)/nX // microns
setscale /p x,-nX/2*px_Size,px_Size,"�m" ROIs // scale ROIs back to what they were - related to KF 20160310 above - fix by Tom
setscale /p y,-nY/2*px_Size,px_Size,"�m"  ROIs

wave GeoC

variable ff,xx,yy,rr,tt

// find Triggers
variable lineskip_after_trigger = seconds_skip_after_trigger/LineDuration

variable nTriggers = 0
for (ff=0;ff<nF-1;ff+=1)
	for (yy=0;yy<nY;yy+=1)
		for (xx=0; xx<nX; xx+=1) // KF 20160310; trigger sometimes only few pixel long
			if (InputTriggers[xx][yy][ff]>trigger_threshold)
				yy+=1
				OutputTriggerTimes[nTriggers]=ff*nY*LineDuration+yy*LineDuration // triggertime in seconds, with line precision (2 ms)
				OutputTriggerTimes_Frame[nTriggers]=ff // KF 20160310
				if (yy+levelread_nY_after_trigger<nY)
					OutputTriggerValues[nTriggers]=InputTriggers[0][yy+levelread_nY_after_trigger][ff]
				else
					OutputTriggerValues[nTriggers]=InputTriggers[0][yy+levelread_nY_after_trigger-nY][ff+1]
				endif
			
				variable skiplines = lineskip_after_trigger
				do
					if (skiplines>nY)
						skiplines-=nY
						ff+=1
					else
						break
					endif
				while(1)
				yy+=round(skiplines)
				if (yy>nY-1)
					yy-=nY
					ff+=1
				endif			
				nTriggers+=1
			endif	
		endfor
	endfor
endfor
if (SkipLastTrigger == 1) // KF 20160310
	nTriggers-=1
endif
print nTriggers, " Triggers found"
if (TriggerMode>1)
	print "Skipping every",TriggerMode,",Triggers!"
endif	

//redimension OutputTriggerValues so it doesn't have trailing NaN's
redimension /N=(nTriggers) OutputTriggerValues // Andre 2016 04 14
redimension /N=(nTriggers) OutputTriggerTimes

// Calculate time of scan for each pixel in recording
for (xx=0;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		for (ff=0; ff<nF; ff+=1)
			// This function will need to be modified for more complex scan paths
			OutputPixelTimes[xx][yy][ff] = r*nY*2/1000 + p*LineDuration + q*LineDuration/wParamsNum[%User_dxPix] + StimulatorDelay/1000
		endfor 
	endfor
endfor

// extract traces according to ROIs
for (rr=0;rr<nRois;rr+=1)
	variable ROI_value = (rr+1)*-1 // ROIs in Mask are coded as negative starting from -1 (SARFIA standard)
	variable ROI_size = 0
	for (xx=0;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			if (ROIs[xx][yy]==ROI_value)
				ROI_size+=1
				OutputTraces_raw[][rr]+=InputData[xx][yy][p] // add up each pixel of a ROI
			endif
		endfor
	endfor
	OutputTraces_raw[][rr]/=ROI_size // now is average activity of ROI
	make /o/n=(nSeconds_prerun_reference/(nY*LineDuration)) BaselineTrace =OutputTraces_raw[p+Ignore1stXseconds/FrameDuration][rr]
	Wavestats/Q BaselineTrace
	OutputTraces_zscore[][rr]=(OutputTraces_raw[p][rr]-V_Avg)/V_SDev
	OutputTraceTimes[][rr]=p*nY*LineDuration + GeoC[rr][1]*LineDuration  + StimulatorDelay/1000 // correct each ROIs timestamp by it's Y position in the scan // use y values not x values KF 20160310 // and by stimulator delay!
endfor

// export handling
duplicate /o OutputTraces_raw $output_name1
duplicate /o OutputTraces_zscore $output_name2
duplicate /o OutputTraceTimes $output_name3
duplicate /o OutputTriggerTimes $output_name4
duplicate /o OutputTriggerValues $output_name5
duplicate/ o OutputTriggerTimes_Frame $output_name6

// Display
if (Display_traces==1)
	display /k=1
	// traces
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		Appendtograph /l=TracesY $output_name2[][rr] vs $output_name3[][rr]
		string CurrentTraceName = output_name2+"#"+Num2Str(rr)
		if (rr==0)
			CurrentTraceName = output_name2
		endif
		variable colorposition = 255 * (rr+1)/nRois
		ModifyGraph rgb($CurrentTraceName)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
	endfor

	ModifyGraph zero(TracesY)=2,fSize=8,lblPos(TracesY)=48,axisEnab(TracesY)={0.05,1};DelayUpdate
	ModifyGraph axisEnab(bottom)={0.05,1},freePos(TracesY)={0,kwFraction};DelayUpdate
	Label TracesY "\\Z10Amplitude (SD)";DelayUpdate
	Label bottom "\\Z10Time (s)"
	
	// triggers
	variable nTriggers_skip = TriggerMode // otherwise it takes ages to display things like noise triggers... now it only plots every 20th trigger
	if (nTriggers>100)
		nTriggers_skip = 20
		print "Note: displaying only one in 20 Triggers!"
	endif
	for (tt=0;tt<nTriggers;tt+=nTriggers_skip)
		ShowTools/A arrow
		SetDrawEnv xcoord= bottom,ycoord= TracesY,linefgc= (0,0,0);DelayUpdate
		DrawLine OutputTriggerTimes[tt],-TriggerHeight_Display,OutputTriggerTimes[tt],TriggerHeight_Display
		HideTools/A
	endfor
	
	// baseline window
	�ShowTools/A arrow
	�SetDrawEnv xcoord= bottom,ycoord= TracesY,linefgc= (65280,0,0),dash= 2,fillpat= 0;DelayUpdate
	�DrawRect Ignore1stXseconds,-TriggerHeight_Display,Ignore1stXseconds+nSeconds_prerun_reference,TriggerHeight_Display
	if (IgnoreLastXSeconds>0)
		�SetDrawEnv xcoord= bottom,ycoord= TracesY,linefgc= (0,0,65280),dash= 2,fillpat= 0;DelayUpdate
		�DrawRect OutputTraceTimes[nF-1][0]-IgnoreLastXseconds,-TriggerHeight_Display,OutputTraceTimes[nF-1][0],TriggerHeight_Display
	endif


	HideTools/A
endif

// cleanup
killwaves InputData, InputTriggers, OutputTraces_raw,OutputTraces_zscore,OutputTraceTimes,OutputTriggerTimes,BaselineTrace,M_Colors, OutputTriggerValues, OutputTriggerTimes_Frame

end