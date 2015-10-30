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
variable Display_averages = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration]
variable Triggermode = OS_Parameters[%Trigger_Mode]
variable Ignore1stXseconds = OS_Parameters[%Ignore1stXseconds]

// data handling
string traces_name = "Traces"+Num2Str(Channel)+"_raw"
if (use_znorm==1)
	traces_name = "Traces"+Num2Str(Channel)+"_znorm"
endif
string tracetimes_name = "Tracetimes"+Num2Str(Channel)
duplicate /o $traces_name InputTraces
duplicate /o $tracetimes_name InputTraceTimes
wave Triggertimes
variable nF = DimSize(InputTraces,0)
variable nRois = DimSize(InputTraces,1)

string output_name1 = "Snippets"+Num2Str(Channel)
string output_name2 = "Averages"+Num2Str(Channel)


variable tt,rr,ll,pp

// Get Snippet Duration, nLoops etc..
variable nTriggers
variable Ignore1stXTriggers = 0
for (tt=0;tt<Dimsize(triggertimes,0);tt+=1)
	if (NumType(Triggertimes[tt])==0)
		if (Ignore1stXseconds>Triggertimes[tt])
			Ignore1stXTriggers+=1
		endif
		nTriggers+=1
	else
		break
	endif
endfor
variable SnippetDuration = Triggertimes[TriggerMode+Ignore1stXTriggers]-Triggertimes[0+Ignore1stXTriggers] // in seconds
variable nLoops = floor((nTriggers-Ignore1stXTriggers) / TriggerMode)
print nTriggers, "Triggers, ignoring 1st",  Ignore1stXTriggers, "and skipping in", TriggerMode, "gives", nLoops, "complete loops"

// make line precision timestamped trace arrays
variable FrameDuration = InputTraceTimes[1][0]-InputTraceTimes[0][0] // in seconds
variable nPoints = (nF * FrameDuration) / LineDuration
make /o/n=(nPoints,nRois) OutputTracesUpsampled = 0 // in line precision - deafult 500 Hz
for (rr=0;rr<nRois;rr+=1)
	make /o/n=(nF) CurrentTrace = InputTraces[p][rr]
	setscale x,InputTraceTimes[0][rr],InputTraceTimes[nF-1][rr],"s" CurrentTrace
	Resample/RATE=(1/LineDuration) CurrentTrace
	variable lineshift = round(InputTraceTimes[0][rr] / LineDuration)
	OutputTracesUpsampled[lineshift,nPoints-4*FrameDuration/LineDuration][rr] = CurrentTrace[p-lineshift] // ignores last 4 frames of original recording to avoid Array overrun
endfor

// Snipperting and Averaging
make /o/n=(SnippetDuration * 1/LineDuration,nLoops,nRois) OutputTraceSnippets = 0 // in line precision
make /o/n=(SnippetDuration * 1/LineDuration,nRois) OutputTraceAverages = 0 // in line precision
setscale /p x,0,LineDuration,"s" OutputTraceSnippets,OutputTraceAverages

for (rr=0;rr<nRois;rr+=1)
	for (ll=0;ll<nLoops;ll+=1)
		OutputTraceSnippets[][ll][rr]=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]
		OutputTraceAverages[][rr]+=OutputTracesUpsampled[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/LineDuration][rr]/nLoops
	endfor
endfor

// export handling
duplicate /o OutputTraceSnippets $output_name1
duplicate /o OutputTraceAverages $output_name2

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
killwaves InputTraces, InputTraceTimes,CurrentTrace,OutputTracesUpsampled,OutputTraceSnippets,OutputTraceAverages


end