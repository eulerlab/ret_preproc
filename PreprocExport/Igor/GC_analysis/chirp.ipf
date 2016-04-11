#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function Chirp()

wave OS_Parameters

/// FLAGS /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable Experiment,Field // date,quadrant,x difference, y difference


variable save_stuff = 1


variable yoffset = 1.5 // of display
variable quality_criterion = 0.333 

variable Scale_factor = 1.640625 // Zoom 0.65 at 64*64, 105 um total field so 1 Px = 105/64 = 1.640625

variable Snippet_duration = (32*7.8+0) // frames ??
variable Smoothing_window = 200 // in 2 ms steps

//// IMPORTING DATA  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

string traces_name = "traces0_znorm" //traces_detrended
string Roi_name = "ROIs" //roi
string triggerchannel_name = "Triggertimes"
string traces_times = "Tracetimes0"
//string sizes_name = "Stack_ave_report" //"wDataCh0_ave_report"
string image_name = "stack_ave"//"wDataCh0_ave"
string raw_parameters = "wParamsNum"

duplicate /o $traces_name traces
duplicate /o $Roi_name Roi
duplicate /o $triggerchannel_name triggerInFrames
duplicate /o $traces_times tracestimes
//duplicate /o $sizes_name sizes
duplicate /o $image_name image
duplicate /o $raw_parameters parameters

//find x and y indices in the parameters wave
Variable xindx, yindx
xindx = FindDimLabel(parameters,0,"XCoord_um" )
yindx = FindDimLabel(parameters,0,"YCoord_um" )

variable FieldX = parameters[xindx]
//FieldX*=-1 // ??
variable Fieldy = parameters[yindx]

string stimulus_name = "Chirp_stim" 
//load stimulus wave if present.
if (waveexists($"ChirpStim"))
	duplicate /o $stimulus_name stimulus
else //if not present, create a random noise wave so that the script won't break
	wave stimulus
	make /O/N=(dimsize($"tracetimes0",0)), stimulus=gnoise(dimsize($"tracetimes",0))
	//stimulus = gnoise(dimsize($"tracetimes",0))
endif

	
/// GET DATA DIMENSIONS /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

variable nF = Dimsize(traces,0)
variable nRois = Dimsize(traces,1)
variable rr, ll

//ROI POSITIONS //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

string GeoC = "GeoC"
duplicate /o $GeoC Absolute_positions

//get the field absolute positions




make /o/n=(nRois,9) Cells = 0 // creates a wave with number of rois columns to save result parameters
for (rr=0; rr<nRois; rr+=1)
	Cells[rr][0] = Experiment // date
	Cells[rr][1] = Field // quadrant
	Cells[rr][2] = rr // roi number
	Cells[rr][3] = Absolute_positions[rr][0] // absolute X position in um for each cell
	Cells[rr][4] = Absolute_positions[rr][1] // absolute y position in um for each cell
	Cells[rr][5] = nan //sizes[rr][2] // roi size from dymitros script
	Cells[rr][7] = FieldX // absolute X position in um
	Cells[rr][8] = FieldY // absolute Y position in um
endfor
Cells[0][5] = scale_factor

/// TRIGGERING /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
variable periodIndx = FindDimLabel(OS_Parameters,0,"samp_period" )
variable FrameDuration = OS_Parameters[periodIndx]
 triggerInFrames/=FrameDuration
 triggerInFrames=round( triggerInFrames)

variable nLoops = 1

/// SNIPPETING //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

make /o/n=(Snippet_duration,nLoops,nRois) Responses = 0
make /o/n=(Snippet_duration,nRois) Responses_average = 0

make /o/n=(Snippet_duration) currentwave = 0
make /o/n=(Snippet_duration) currenttiming = 0

for (rr=0;rr<nRois;rr+=1) // nRois
	for (ll=0;ll<nLoops;ll+=1)
		currentwave[]=traces[p+ triggerInFrames[ll*2]][rr] // fills first loop of roi rr into currentwave
		currenttiming[]=tracestimes[p][rr]
		Interpolate2/T=1/N=(Snippet_duration)/Y=Currentwave_L Currenttiming,Currentwave
		Responses[][ll][rr]=currentwave_L[p] // interpolated snippets are filled in responses wave _L
		Responses_average[][rr]+=currentwave_L[p]/nLoops // individual snippets are added and divided by loop number _L
	endfor
endfor

/// SAVE STUFF //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

if (save_stuff==1)
	duplicate /o Responses Chirp_data
	duplicate /o Stimulus Chirp_stim
	Save/C Cells,Chirp_data,Chirp_stim,Image,Roi
endif

Killwaves traces, triggerInFrames


end