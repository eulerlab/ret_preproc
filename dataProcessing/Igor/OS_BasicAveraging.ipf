#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_BasicAveraging()

// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
// 2 //  check for Detrended Data stack
variable Channel = OS_Parameters[%Data_Channel]
// Dont check for detrended stack, as it is not used here. KF
//if (waveexists($"wDataCh"+Num2Str(Channel)+"_detrended")==0)
//	print "Warning: wDataCh"+Num2Str(Channel)+"_detrended wave not yet generated - doing that now..."
//	OS_DetrendStack()
//endif
// 3 //  check for ROI_Mask
if (waveexists($"ROIs")==0)
	print "Warning: ROIs wave not yet generated - doing that now (using correlation algorithm)..."
	OS_AutoRoiByCorr()
	DoUpdate
endif
// 4 //  check if Traces and Triggers are there
if (waveexists($"Triggertimes")==0)
	print "Warning: Traces and Trigger waves not yet generated - doing that now..."
	OS_TracesAndTriggers()
	DoUpdate
endif

// flags from "OS_Parameters"
variable Display_averages = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration]
variable Triggermode = OS_Parameters[%Trigger_Mode]
variable Ignore1stXseconds = OS_Parameters[%Ignore1stXseconds]
variable IgnoreLastXseconds = OS_Parameters[%IgnoreLastXseconds]
variable AverageStack_make = OS_Parameters[%AverageStack_make]
variable AverageStack_rate = OS_Parameters[%AverageStack_rate]
variable AverageStack_dF = OS_Parameters[%AverageStack_dF]
variable X_cut = OS_Parameters[%LightArtifact_cut]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)//+"_detrended"
string traces_name = "Traces"+Num2Str(Channel)+"_raw"
if (use_znorm==1)
	traces_name = "Traces"+Num2Str(Channel)+"_znorm"
endif
string tracetimes_name = "Tracetimes"+Num2Str(Channel)
duplicate /o $input_name InputStack
duplicate /o $traces_name InputTraces
duplicate /o $tracetimes_name InputTraceTimes

wave Triggertimes
variable nF = DimSize(InputTraces,0)
variable nRois = DimSize(InputTraces,1)
variable nX = DimSize(InputStack,0)
variable nY = DimSize(InputStack,1)

string output_name1 = "Snippets"+Num2Str(Channel)
string output_name2 = "Averages"+Num2Str(Channel)
string output_name3 = "AverageStack"+Num2Str(Channel)
string output_name4 = "SnippetsTimes"+Num2Str(Channel) // andre addition 2016 04 13


variable tt,rr,ll,pp,xx,yy,ff

// Get Snippet Duration, nLoops etc..
variable nTriggers
variable Ignore1stXTriggers = 0
variable IgnoreLastXTriggers = 0
variable last_data_time_allowed = InputTraceTimes[nF-1][0]-IgnoreLastXseconds

for (tt=0;tt<Dimsize(triggertimes,0);tt+=1)
	if (NumType(Triggertimes[tt])==0)
		if (Ignore1stXseconds>Triggertimes[tt])
			Ignore1stXTriggers+=1
		endif
		if (Triggertimes[tt]<=last_data_time_allowed)
			nTriggers+=1
		endif
	else
		break
	endif
endfor
if (Ignore1stXTriggers>0)
	print "ignoring first", Ignore1stXTriggers, "Triggers"
endif
variable SnippetDuration = Triggertimes[TriggerMode+Ignore1stXTriggers]-Triggertimes[0+Ignore1stXTriggers] // in seconds


//variable Last_Snippet_Length = (Triggertimes[nTriggers-1]-triggertimes[nTriggers-TriggerMode])/SnippetDuration
variable Last_Snippet_Length = last_data_time_allowed-Triggertimes[nTriggers-1]

if (Last_Snippet_Length<SnippetDuration)
	//IgnoreLastXTriggers = TriggerMode // This cuts the last loop, delete. KF
endif
variable nLoops = floor((nTriggers-Ignore1stXTriggers-IgnoreLastXTriggers) / TriggerMode)

print nTriggers, "Triggers, ignoring 1st",  Ignore1stXTriggers, "and last", IgnoreLastXTriggers, "and skipping in", TriggerMode, "gives", nLoops, "complete loops"
print "Note: Last", IgnoreLastXseconds, "s are also clipped"

// make line precision timestamped trace arrays
variable FrameDuration = nY*LineDuration // in seconds
variable nPoints = (nF * FrameDuration) / LineDuration
make /o/n=(nPoints,nRois) OutputTracesUpsampled = 0 // in line precision - deafult 500 Hz
make /o/n=(nPoints,nRois) OutputTimesUpsampled = 0 // Andre 2016 04 13
for (rr=0;rr<nRois;rr+=1)
// for linear interpolation
	make /o/n=(nF*nY) CurrentTrace = NaN
	make /o/n=(nF*nY) CurrentTime = NaN	// Andre addition 2016 04 13
	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
	for (ff=0;ff<nF-1;ff+=1)
		for (yy=0;yy<nY; yy+=1)
			CurrentTrace[ff*nY+yy]=(InputTraces[ff+1][rr]*yy+InputTRaces[ff][rr]*(nY-yy))/nY
			CurrentTime[ff*nY+yy]=(InputTraceTimes[ff+1][rr]*yy+InputTraceTimes[ff][rr]*(nY-yy))/nY // andre addition 2016 04 13
		endfor
	endfor

// for hanned interpolation
//	make /o/n=(nF) CurrentTrace = InputTraces[p][rr]
//	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
//	Resample/RATE=(1/LineDuration) CurrentTrace


	variable lineshift = round(InputTraceTimes[0][rr] / LineDuration)
	OutputTracesUpsampled[lineshift,nPoints-4*FrameDuration/LineDuration][rr] = CurrentTrace[p-lineshift] // ignores last 4 frames of original recording to avoid Array overrun
	OutputTimesUpsampled[lineshift,nPoints-4*FrameDuration/LineDuration][rr] = CurrentTime[p-lineshift] // andre additino 2016 04 13
endfor

// Snipperting and Averaging

make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTraceSnippets = 0 // in line precision
make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTimeSnippets = 0 // Andre 2016 04 13
make /o/n=(SnippetDuration * 1/LineDuration,nRois) OutputTraceAverages = 0 // in line precision

setscale /p x,0,LineDuration,"s" OutputTraceSnippets,OutputTraceAverages

for (rr=0;rr<nRois;rr+=1)
	for (ll=0;ll<nLoops;ll+=1)
		OutputTraceSnippets[][ll][rr]=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]
		OutputTraceAverages[][rr]+=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]/nLoops
		OutputTimeSnippets[][ll][rr] = OutputTimesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]		// Andre 2016 04 13
	endfor
endfor

// Make Average Stack (optional)

if (AverageStack_make==1)
	print "Generating AverageStack"
	make /o/n=(nX-X_Cut,nY) OutputStack_avg = 0
	variable stack_downsample = AverageStack_rate / (1/LineDuration)
	make /o/n=(nX-X_cut,nY,nPoints*stack_downsample) OutputStackUpsampled = 0 // in line precision - deafult 500 Hz
	for (xx=0;xx<nX-X_Cut;xx+=1) // make Upsampled raw stack
		for (yy=0;yy<nY;yy+=1)
			make /o/n=(nF) CurrentTrace = InputStack[xx+X_Cut][yy][p]
			WaveStats/Q CurrentTrace
			OutputStack_avg[xx][yy]=V_avg
			setscale x,InputTraceTimes[0][0],InputTraceTimes[nF-1][0],"s" CurrentTrace // uses trace timestamps from ROI 0
			Resample/RATE=(AverageStack_rate) CurrentTrace
			Multithread OutputStackUpsampled[xx][yy][0,nPoints*stack_downsample-4*nY] = CurrentTrace[r] // ignores last 4 frames of original recording to avoid Array overrun
		endfor
	endfor
	make /o/n=(nX-X_Cut,nY,(SnippetDuration * 1/LineDuration) * stack_downsample) OutputStack = 0
	for (ll=0;ll<nLoops;ll+=1)	// aveage across loops
		for (xx=0;xx<nX-X_Cut;xx+=1)
			for (yy=0;yy<nY;yy+=1)
				Multithread OutputStack[xx][yy][]+=OutputStackUpsampled[xx][yy][r+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/(LineDuration/stack_downsample)]/nLoops
			endfor
		endfor
	endfor
	
	if (AverageStack_dF==1)
		OutputStack[][][]-=OutputStack_avg[p][q]
	endif
	
	duplicate /o OutputStack $output_name3

endif

// export handling
duplicate /o OutputTraceSnippets $output_name1
duplicate /o OutputTraceAverages $output_name2
duplicate /o OutputTimeSnippets $output_name4
	
// display

if (Display_averages==1)
	display /k=1
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		string YAxisName = "YAxis_Roi"+Num2Str(rr)
		string tracename
		for (ll=0;ll<nLoops;ll+=1)
			tracename = output_name1+"#"+Num2Str(rr*nLoops+ll)
			if (ll==0 && rr==0)
				tracename = output_name1
			endif
			Appendtograph /l=$YAxisName $output_name1[][ll][rr]
			ModifyGraph rgb($tracename)=(52224,52224,52224)
		endfor	
		tracename = output_name2+"#"+Num2Str(rr)
		if (rr==0)
			tracename = output_name2
		endif
		Appendtograph /l=$YAxisName $output_name2[][rr]
		variable colorposition = 255 * (rr+1)/nRois
		ModifyGraph rgb($tracename)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
		ModifyGraph lsize($tracename)=1.5
		
		variable plotfrom = 1-((rr+1)/nRois)
		variable plotto = 1-(rr/nRois)
		
		ModifyGraph fSize($YAxisName)=8,axisEnab($YAxisName)={plotfrom,plotto};DelayUpdate
		ModifyGraph freePos($YAxisName)={0,kwFraction};DelayUpdate
		Label $YAxisName "\\Z10"+Num2Str(rr)
		ModifyGraph noLabel($YAxisName)=1,axThick($YAxisName)=0;DelayUpdate
		ModifyGraph lblRot($YAxisName)=-90
	endfor
	ModifyGraph fSize(bottom)=8,axisEnab(bottom)={0.05,1};DelayUpdate
	Label bottom "\\Z10Time (\U)"
endif


// cleanup
killwaves InputTraces, InputTraceTimes,CurrentTrace,OutputTracesUpsampled,OutputTraceSnippets,OutputTraceAverages,OutputStack,OutputStackUpsampled,OutputStack_avg


end