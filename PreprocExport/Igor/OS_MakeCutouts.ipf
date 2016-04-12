#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_makeCutouts()
//this is the OS_BasicAveraging function adapted to only calculate cutouts of the data and generate
//two waves, one with the data cut according to triggers and another with time stamps cut according to trigger
// 1 // check for Parameter Table
if (waveexists($"OS_Parameters")==0)
	print "Warning: OS_Parameters wave not yet generated - doing that now..."
	OS_ParameterTable()
	DoUpdate
endif
wave OS_Parameters
// 2 //  check for Detrended Data stack
variable Channel = OS_Parameters[%Data_Channel]
if (waveexists($"wDataCh"+Num2Str(Channel)+"_detrended")==0)
	print "Warning: wDataCh"+Num2Str(Channel)+"_detrended wave not yet generated - doing that now..."
	OS_DetrendStack()
endif
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
//variable Display_averages = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration]
variable Triggermode = OS_Parameters[%Trigger_Mode]
variable Ignore1stXseconds = OS_Parameters[%Ignore1stXseconds]
variable IgnoreLastXseconds = OS_Parameters[%IgnoreLastXseconds]
variable X_cut = OS_Parameters[%LightArtifact_cut]

// data handling
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
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
string output_name4 = "SnippetsTimes"+Num2Str(Channel)
//string output_name2 = "Averages"+Num2Str(Channel)
//string output_name3 = "AverageStack"+Num2Str(Channel)


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

variable Last_Snippet_Length = (Triggertimes[nTriggers-1]-triggertimes[nTriggers-TriggerMode])/SnippetDuration
if (Last_Snippet_Length<SnippetDuration)
	IgnoreLastXTriggers = TriggerMode
endif
variable nLoops = floor((nTriggers-Ignore1stXTriggers-IgnoreLastXTriggers) / TriggerMode)

print nTriggers, "Triggers, ignoring 1st",  Ignore1stXTriggers, "and last", IgnoreLastXTriggers, "and skipping in", TriggerMode, "gives", nLoops, "complete loops"
print "Note: Last", IgnoreLastXseconds, "s are also clipped"

// make line precision timestamped trace arrays
variable FrameDuration = nY*LineDuration // in seconds
variable nPoints = (nF * FrameDuration) / LineDuration
make /o/n=(nPoints,nRois) OutputTracesUpsampled = 0 // in line precision - deafult 500 Hz
make /o/n=(nPoints,nRois) OutputTimesUpsampled = 0 // in line precision - deafult 500 Hz
for (rr=0;rr<nRois;rr+=1)
// for linear interpolation
	make /o/n=(nF*nY) CurrentTrace = NaN
	make /o/n=(nF*nY) CurrentTime = NaN
	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
	for (ff=0;ff<nF-1;ff+=1)
		for (yy=0;yy<nY; yy+=1)
			CurrentTrace[ff*nY+yy]=(InputTraces[ff+1][rr]*yy+InputTraces[ff][rr]*(nY-yy))/nY
			CurrentTime[ff*nY+yy]=(InputTraceTimes[ff+1][rr]*yy+InputTraceTimes[ff][rr]*(nY-yy))/nY
		endfor
	endfor

// for hanned interpolation
//	make /o/n=(nF) CurrentTrace = InputTraces[p][rr]
//	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
//	Resample/RATE=(1/LineDuration) CurrentTrace


	variable lineshift = round(InputTraceTimes[0][rr] / LineDuration)
	OutputTracesUpsampled[lineshift,nPoints-4*FrameDuration/LineDuration][rr] = CurrentTrace[p-lineshift] // ignores last 4 frames of original recording to avoid Array overrun
	OutputTimesUpsampled[lineshift,nPoints-4*FrameDuration/LineDuration][rr] = CurrentTime[p-lineshift] // ignores last 4 frames of original recording to avoid Array overrun
endfor

// Snipperting and Averaging

make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTraceSnippets = 0 // in line precision
make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTimeSnippets = 0 // in line precision
//make /o/n=(SnippetDuration * 1/LineDuration,nRois) OutputTraceAverages = 0 // in line precision
setscale /p x,0,LineDuration,"s" OutputTraceSnippets//,OutputTraceAverages

for (rr=0;rr<nRois;rr+=1)
	for (ll=0;ll<nLoops;ll+=1)
		OutputTraceSnippets[][ll][rr]=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]
		OutputTimeSnippets[][ll][rr] = OutputTimesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]
	endfor
endfor
print LineDuration
// export handling
duplicate /o OutputTraceSnippets $output_name1
duplicate /o OutputTimeSnippets $output_name4
end //function