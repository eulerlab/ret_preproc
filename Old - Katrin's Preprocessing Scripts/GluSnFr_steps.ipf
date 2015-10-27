#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function GluSnFr_1s()

/// FLAGS //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable save_stuff = 1
variable make_movie = 0

//// IMPORTING DATA  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

string traces_name = "wDataCh0_dis_QA_Nor" // traces
string Roi_name = "ROIs" // rois
string triggerchannel_name = "wDataCh2" // triggers
duplicate /o $traces_name traces
duplicate /o $Roi_name Roi
duplicate /o $triggerchannel_name triggerchannel

/// GET DATA DIMENSIONS ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable nF = Dimsize(traces,0)
variable nRois = Dimsize(traces,1)
variable nLines = Dimsize(triggerchannel,1) // nY

variable frame_duration = (nLines*2)/1000 // in s 

variable ff,rr,ll,tt

///// DETRENDING //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable Smoothingfactor = 2^15-1

duplicate /o traces traces_detrended

variable r
for (r=0;r<nRois;r+=1)
     make /o/n=(nF) currenttrace = traces[p][r]
     Smooth Smoothingfactor, currenttrace
     traces_detrended[][r]=traces[p][r]-currenttrace[p]
endfor

killwaves currenttrace,traces

/// GET ROI POSITIONS ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable ROInumber, Xcounter, Ycounter, number, xDim, yDim
imagestats /m= 1 ROi // calculates minimum
ROInumber = -v_min // minimum equal to roi number
xDim = dimsize(ROI,0) // nX of rois
yDim = dimsize(ROI,1) // nY of rois
make /o/n=(ROinumber, 3) data=0 // creates a wave to save roi positions
 for(Xcounter=0;Xcounter<xDim;Xcounter+=1) // goes through x values
 	 for(Ycounter=0;Ycounter<yDim;Ycounter+=1) // goes through y values
  		if(ROI[xcounter][ycounter] < 0) // if non zero = if there is a roi
  			number=-ROI[xcounter][ycounter]-1 // number of roi is identified
 			data[number][0]+=xcounter // x value of each pixel in roi is added
 			data[number][1]+=ycounter // y value of each pixel in roi is added
 			data[number][2]+=1 // Number of pixels in ROI needed to identify 
 		endif
 	endfor
 endfor
make /o/n=(ROinumber, 2) GeoC=0
SetScale d,0,1,WaveUnits(ROI,0) GeoC
	MultiThread GeoC[][0]=floor(data[p][0]/data[p][2])
	MultiThread GeoC[][1]=floor(data[p][1]/data[p][2])
killwaves /z data

/// TRIGGERING ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

make /o/n=1000 Triggertimes_accurate = 0
make /o/n=1000 Triggertimes_frame = 0
variable nTriggers = 0
variable skipframes = 2
for (ff=0; ff<nF; ff+=1)
	for (ll=0; ll<nLines; ll+=1)
		if (triggerchannel[0][ll][ff]>25000)
			triggertimes_frame[nTriggers]=ff
			triggertimes_accurate[nTriggers]=(ff*nLines)+ll
			ff+=skipframes
			ll=nLines
			nTriggers+=1
		endif
	endfor
endfor

variable nLoops = (nTriggers)
print "Stimulus loops: ",nLoops
variable nFrames_per_cycle = triggertimes_frame[1] - triggertimes_frame[0]
variable snippet_duration_pp = 500//triggertimes_accurate[1] - triggertimes_accurate[0]

/// SNIPPETING ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

make /o/n=(snippet_duration_pp,nLoops-1,nRois) Responses = 0
make /o/n=(snippet_duration_pp,nRois) Responses_average = 0

make /o/n=((nFrames_per_cycle)*nLines) currentwave = 0

variable AddFrames = 6

make/o/n=(nFrames_per_cycle+AddFrames) CurrentTrace = 0

for (rr=0;rr<nRois;rr+=1) // nRois
	for (ll=0;ll<(nLoops-1);ll+=1)
		variable response_delay = GeoC[rr][1] - ((triggertimes_accurate[ll] - ((floor(triggertimes_accurate[ll]/nLines))*nLines) // gives time offset (in 2ms steps) before triggertime scanning over cell of interest
		CurrentTrace[] = traces_detrended[p+(triggertimes_frame[ll]-(AddFrames/2))][rr]
		Interpolate2/T=1/N=((nFrames_per_cycle+AddFrames)*nLines)/Y=CurrentTrace_L CurrentTrace
		currentwave[]=CurrentTrace_L[p+((nLines*(AddFrames/2)) + (triggertimes_accurate[ll] - (triggertimes_frame[ll]*nLines))) - response_delay]
		Interpolate2/T=1/N=(snippet_duration_pp)/Y=currentwave_l currentwave
		Responses[][ll][rr]=currentwave_l[p]
		Responses_average[][rr]+=currentwave_l[p]/(nLoops-1)
		CurrentTrace = 0
		killwaves CurrentTrace_L
	endfor
endfor

Setscale x,0,(snippet_duration_pp*2)/1000,"s" responses
Setscale x,0,(snippet_duration_pp*2)/1000,"s" responses_average

make /o/n=(snippet_duration_pp) Stim = 0
Stim[snippet_duration_pp/4,(snippet_duration_pp/4)*3]=1
Setscale x,0,(snippet_duration_pp*2)/1000,"s" Stim

variable display_stuff = 1

/// MAKE MOVIE

if (make_movie==1)

	wave wDataCh0 // inputmovie
	make /o/n=(61,16,nFrames_per_cycle) outputmovie = 0
	for (ll=0;ll<nLoops;ll+=1)
		for (ff=0;ff<nFrames_per_cycle-1;ff+=1)
			outputmovie[][][ff]+=wDataCh0[p+3][q][ff+triggertimes_frame[ll]]
		endfor
	endfor
	outputmovie[][][nFrames_per_cycle]=outputmovie[p][q][nFrames_per_cycle-1]
	imagesave /f/s/t="tiff" outputmovie
endif


// DISPLAY

make /o/n=(snippet_duration_pp) stimulus = 0 //2000
stimulus[(snippet_duration_pp/4)+14,((snippet_duration_pp/4)*3)+14]=1
Setscale x,0,(snippet_duration_pp*2)/1000,"s" stimulus

if (display_stuff==1)
	make/o/n=(snippet_duration_pp) Average = 0
	for (r=0;r<nRois;r+=1)
		Average[]+=Responses_average[p][r]
	endfor
	Average/=nRois
	Wavestats/q Average
	Average-=V_min
	Average/=V_max-V_min
	setscale x,0,(snippet_duration_pp*2)/1000,"s" Average
	display/k=1
	appendtograph/l=yStim stimulus
	appendtograph/l=yTraces average
	ModifyGraph nticks(yTraces)=0,nticks(yStim)=0,noLabel(yTraces)=2,noLabel(yStim)=2;DelayUpdate
	ModifyGraph freePos(yTraces)={0,kwFraction},freePos(yStim)={0,kwFraction};DelayUpdate
	ModifyGraph axRGB(yTraces)=(65535,65535,65535),axRGB(yStim)=(65535,65535,65535)
	ModifyGraph mode(stimulus)=7,usePlusRGB(stimulus)=1,useNegPat(stimulus)=1,hBarNegFill(stimulus)=5;DelayUpdate
	ModifyGraph plusRGB(stimulus)=(65280,65280,0),lsize(Average)=2,rgb(Average)=(0,0,0)
	ModifyGraph hbFill(stimulus)=5
	ModifyGraph rgb(stimulus)=(65535,65535,65535)
	ModifyGraph nticks(bottom)=20
endif

make /o/n=(snippet_duration_pp) stim = 0 //2000
Stim[snippet_duration_pp/4,(snippet_duration_pp/4)*3]=1
Setscale x,0,(snippet_duration_pp*2)/1000,"s" Stim


if (save_stuff==1)
	duplicate/o Stim Step_stim
	duplicate /o Responses step_data
	Save/C step_data, step_stim
endif



end