#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function Pix_averaging()

//Do some basic averaging on single pixel responses. An alternate to OS_BasicAveraging.

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
variable IgnoreLastXseconds = OS_Parameters[%IgnoreLastXseconds]
variable AverageStack_make = OS_Parameters[%AverageStack_make]
variable AverageStack_rate = OS_Parameters[%AverageStack_rate]
variable AverageStack_dF = OS_Parameters[%AverageStack_dF]
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
	//IgnoreLastXTriggers = TriggerMode
endif
variable nLoops = floor((nTriggers-Ignore1stXTriggers-IgnoreLastXTriggers) / TriggerMode)

print nTriggers, "Triggers, ignoring 1st",  Ignore1stXTriggers, "and last", IgnoreLastXTriggers, "and skipping in", TriggerMode, "gives", nLoops, "complete loops"
print "Note: Last", IgnoreLastXseconds, "s are also clipped"



// Snipperting and Averaging
variable FrameDuration = nY*LineDuration // in seconds
make /o/n=(nF,nRois) OutputTraces = InputTraces
make /o/n=(nF,nRois) OutputTimes = InputTraceTimes


make /o/n=(SnippetDuration * 1/FrameDuration,nLoops,nRois) OutputTraceSnippets = 0 // in frame precision
make /o/n=(SnippetDuration * 1/FrameDuration,nLoops,nRois) OutputTimeSnippets = 0 // 
make /o/n=(SnippetDuration * 1/FrameDuration,nRois) OutputTraceAverages = 0 // in frame precision

setscale /p x,0,FrameDuration,"s" OutputTraceSnippets,OutputTraceAverages

for (rr=0;rr<nRois;rr+=1)
	for (ll=0;ll<nLoops;ll+=1)
		OutputTraceSnippets[][ll][rr]=OutputTraces[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/FrameDuration] [rr]
		OutputTraceAverages[][rr]+=OutputTraces[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/FrameDuration][rr]/nLoops
		OutputTimeSnippets[][ll][rr] = OutputTimes[p+Triggertimes[ll*TriggerMode+Ignore1stXTriggers]/FrameDuration][rr]
	endfor
endfor


// export handling
duplicate /o OutputTraceSnippets $output_name1
duplicate /o OutputTraceAverages $output_name2
duplicate /o OutputTimeSnippets $output_name4

// cleanup
killwaves InputTraces, InputTraceTimes,OutputTraces,OutputTraceSnippets,OutputTraceAverages


end