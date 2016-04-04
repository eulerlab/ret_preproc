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

function OS_STRFs()

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
variable Display_Stuff = OS_Parameters[%Display_Stuff]
variable use_znorm = OS_Parameters[%Use_Znorm]
variable LineDuration = OS_Parameters[%LineDuration]
variable Noise_PxSize = OS_Parameters[%Noise_PxSize_microns]
variable Compression = OS_Parameters[%Noise_Compression]
variable Event_SD = OS_Parameters[%Noise_EventSD]
variable FilterLength = OS_Parameters[%Noise_FilterLength_s]

// data handling
wave ROIs
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
string traces_name = "Traces"+Num2Str(Channel)+"_raw"
if (use_znorm==1)
	traces_name = "Traces"+Num2Str(Channel)+"_znorm"
endif
string tracetimes_name = "Tracetimes"+Num2Str(Channel)
duplicate /o $input_name InputStack
duplicate /o $traces_name InputTraces
duplicate /o $tracetimes_name InputTraceTimes
variable nF = DimSize(InputTraces,0)
variable nRois = DimSize(InputTraces,1)
variable nY = DimSize(InputStack,1)
variable LineRate = 1/LineDuration
variable FilterLength_Line = Filterlength/LineDuration
variable FilterLength_Real = floor(FilterLength_Line/Compression)

variable xx,yy,ff,rr,tt

wave Triggertimes
variable nTriggers = 0
for (tt=0;tt<Dimsize(triggertimes,0);tt+=1)
	if (Numtype(triggertimes[tt])==0)
		nTriggers+=1
	else
		break
	endif	
endfor
print nTriggers, "Triggers found"

wave NoiseArray3D
variable nX_Noise = Dimsize(NoiseArray3D,0)
variable nY_Noise = Dimsize(NoiseArray3D,1)

string output_name_SD = "STRF_SD"+Num2Str(Channel) // 3D wave (x/y/Roi)
string output_name_SVD_Time = "STRF_SVD_Time"+Num2Str(Channel) // 2D wave (t/Roi)
string output_name_SVD_Space = "STRF_SVD_Space"+Num2Str(Channel) // 3D wave (x/y/Roi)
string output_name_individual = "STRF"+Num2Str(Channel)+"_" 
make /o/n=(nX_Noise,nY_Noise,nRois) Filter_SDs = 0

// make Stim Array
printf "Upsampling Stimulus wave..."
make /o/n=(nX_Noise,nY_Noise,nF*nY/Compression) NoiseStimulus_Lineprecision = 0
for (tt=0;tt<nTriggers-1;tt+=1) // goes through all triggers
	Multithread NoiseStimulus_Lineprecision[][][triggertimes[tt]*LineRate/Compression,triggertimes[tt+1]*LineRate/Compression]=NoiseArray3D[p][q][tt]
endfor		
print "done."	

// Get Filters
printf "Calculating kernels for "
printf Num2Str(nRois)
printf " ROIs... "
make /o/n=(nRois) nEvents = 0
make /o/n=(nX_Noise*nY_Noise,FilterLength_Real,nRois) ST_Kernels = 0 // for SVD
make /o/n=(FilterLength_Real,nRois) SVDKernels_Time = 0
make /o/n=(nX_Noise,nY_Noise,nRois) SVDKernels_Space = 0
make /o/n=(nX_Noise*nY_Noise,nRois) SVDKernels_Space1D = 0
make /o/n=(1) W_W
make /o/n=(1) M_VT
make /o/n=(1) M_U	
make /o/n=(1) W_Statslinearcorrelationtest
variable firsttrigger_f = triggertimes[0] / (LineDuration*nY)
variable lasttrigger_f = triggertimes[nTriggers-1] / (LineDuration*nY)

for (rr=0;rr<nRois;rr+=1) // goes through all ROIs
	printf "#"
	variable current_lineOffset = InputTraceTimes[0][rr] 
	make /o/n=(nX_Noise,nY_Noise,FilterLength_Real) CurrentFilter = 0 
	make /o/n=(nF) CurrentTrace = InputTraces[p][rr] 
	duplicate /o CurrentTrace CurrentTrace_DIF
	differentiate CurrentTrace/D=CurrentTrace_DIF
	wavestats/Q CurrentTrace_DIF 
	variable threshold=V_SDev*Event_SD
	for (ff=firsttrigger_f;ff<lasttrigger_f;ff+=1) // goes through all frames
		if (CurrentTrace_DIF[ff]>threshold) // if trace is above threshold
			Multithread CurrentFilter[][][]+=(NoiseStimulus_Lineprecision[p][q][(r-((3*FilterLength_Real)/4))+((ff*nY+current_lineOffset)/Compression)])*(CurrentTrace_DIF[ff]-threshold) // x,y dimensions are filled according to stimulus, z dimension = filterlength
			nEvents[rr]+=1
		endif
	endfor
	CurrentFilter/=nEvents[rr]
	// calculating SD projections
	for (xx=0;xx<nX_Noise;xx+=1)
		for (yy=0;yy<nY_Noise;yy+=1)
			make /o/n=(FilterLength_Real) CurrentTrace = CurrentFilter[xx][yy][p]
			wavestats/Q CurrentTrace 
			Filter_SDs[xx][yy][rr]=V_SDev
		endfor
	endfor
	// SVD business
	for (yy=0;yy<nY_Noise;yy+=1) // reshape 2 space D into 1
		ST_Kernels[yy*nX_Noise,(yy+1)*nX_Noise-1][][rr]=CurrentFilter[p-yy*nX_Noise][yy][q]
	endfor
	make /o/n=(nX_Noise*nY_Noise,FilterLength_Real) CurrentMatrix = ST_Kernels[p][q][rr]
	MatrixSVD  CurrentMatrix
	SVDKernels_Time[][rr]=M_VT[1][p]
	SVDKernels_Space1D[][rr]=M_U[p][1]	
	for (yy=0;yy<nY_Noise;yy+=1) // reshape 1 space D into 2
		SVDKernels_Space[][yy][rr]=SVDKernels_Space1D[p+yy*nX_Noise][rr]
	endfor
		// check if SVD is flipped
	make /o/n=(nX_Noise,nY_Noise) CurrentImage = 0
	CurrentImage[][]=Filter_SDs[p][q][rr]
	Imagestats/Q CurrentImage
	make /o/n=(FilterLength_Real) CurrentSVDTimeKernel = SVDKernels_Time[p][rr]
	make /o/n=(FilterLength_Real) CurrentSDTimeKernel = CurrentFilter[V_MaxRowLoc][V_MaxColLoc][p]	
	Statslinearcorrelationtest/Q CurrentSVDTimeKernel, CurrentSDTimeKernel
	if (W_Statslinearcorrelationtest[1]<0) // ie. if opposite polarity
		SVDKernels_Time[][rr]*=-1
		SVDKernels_Space[][][rr]*=-1		
	endif


	// calculating SD projections
	for (xx=0;xx<nX_Noise;xx+=1)
		for (yy=0;yy<nY_Noise;yy+=1)
			make /o/n=(FilterLength_Real) CurrentTrace = CurrentFilter[xx][yy][p]
			wavestats/Q CurrentTrace 
			Filter_SDs[xx][yy][rr]=V_SDev
		endfor
	endfor
	
	// normalization of the filter in times SD
	//-- MISSING
	
	setscale z,-(3*(FilterLength_Real*Compression)/4)*2,((FilterLength_Real*Compression)/4)*2,"ms" CurrentFilter // scales z dimension in ms
	setscale/p x,-nX_Noise/2*Noise_PxSize,Noise_PxSize,"µm" CurrentFilter // scales x dimension in µm	
	setscale/p y,-nY_Noise/2*Noise_PxSize,Noise_PxSize,"µm" CurrentFilter // scales y dimension in µm		
	string filter_name = output_name_individual+Num2Str(rr) // creates a name for the filter of each ROI
	duplicate /o CurrentFilter $filter_name 
	
endfor
setscale/p x,-nX_Noise/2*Noise_PxSize,Noise_PxSize,"µm" Filter_SDs,SVDKernels_Space // scales x dimension in µm	
setscale/p y,-nY_Noise/2*Noise_PxSize,Noise_PxSize,"µm" Filter_SDs,SVDKernels_Space // scales y dimension in µm	
setscale x,-(3*(FilterLength_Real*Compression)/4)*2,((FilterLength_Real*Compression)/4)*2,"ms"  SVDKernels_Time


print " done."	
// export handling
duplicate /o Filter_SDs $output_name_SD
duplicate /o SVDKernels_Time $output_name_SVD_Time
duplicate /o SVDKernels_Space $output_name_SVD_Space


// display

if (Display_Stuff==1)
	display /k=1 
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	Appendimage /l=SpaceY /b=SpaceX ROIs
	
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		string current_SVDName = "STRF_SVD_Space"+Num2Str(Channel)+"_"+Num2Str(rr)
		make /o/n=(nX_Noise,nY_Noise) currentSVD = SVDKernels_Space[p][q][rr]
		duplicate /o currentSVD $current_SVDName
		setscale/p x,-nX_Noise/2*Noise_PxSize,Noise_PxSize,"µm"  $current_SVDName
		setscale/p y,-nY_Noise/2*Noise_PxSize,Noise_PxSize,"µm" $current_SVDName
		AppendMatrixContour /l=SpaceY /b=SpaceX $current_SVDName
		ModifyContour $current_SVDName autoLevels= {*,*,1}, rgbLines=(M_Colors[colorposition][0]*255,M_Colors[colorposition][1]*255,M_Colors[colorposition][2]*255), labels=0
		AppendtoGraph /l=TimeY /b=TimeX $output_name_SVD_Time[][rr]
		string tracename = output_name_SVD_Time+"#"+Num2Str(rr)
		if (rr==0)
			tracename = output_name_SVD_Time
		endif
		ModifyGraph rgb($tracename)=(M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2])
		ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
	endfor
	ModifyGraph fSize=8,lblPos(TimeX)=47,axisEnab(SpaceY)={0.05,1};DelayUpdate
	ModifyGraph axisEnab(SpaceX)={0.05,0.45},axisEnab(TimeY)={0.05,1};DelayUpdate
	ModifyGraph axisEnab(TimeX)={0.65,1},freePos(SpaceY)={0,kwFraction};DelayUpdate
	ModifyGraph freePos(SpaceX)={0,kwFraction},freePos(TimeY)={0.6,kwFraction};DelayUpdate
	ModifyGraph freePos(TimeX)={0,kwFraction};DelayUpdate
	Label TimeX "\\Z10Time (\\U)"
	ModifyGraph lblPos(SpaceY)=47,lblPos(SpaceX)=47;DelayUpdate
	Label SpaceY "\\Z10\\U";DelayUpdate
	Label SpaceX "\\Z10\\U";DelayUpdate
	SetAxis SpaceX -nX_Noise/2*Noise_PxSize,nX_Noise/2*Noise_PxSize
	SetAxis SpaceY -nY_Noise/2*Noise_PxSize,nY_Noise/2*Noise_PxSize
	ModifyGraph width=600,height={Aspect,0.55}
	DoUpdate
	ModifyGraph width=0,height=0
endif	

// cleanup
killwaves NoiseStimulus_Lineprecision, CurrentFilter, CurrentTrace, CurrentTrace_DIF, nEvents, Filter_SDs, InputStack,InputTraces,InputTraceTimes,M_Colors
killwaves M_VT, M_U, CurrentMatrix, SVDKernels_Space1D, W_W,CurrentSVDTimeKernel,CurrentSDTimeKernel,W_Statslinearcorrelationtest,SVDKernels_Time,SVDKernels_Space,currentSVD

end