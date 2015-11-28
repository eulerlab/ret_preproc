#pragma rtGlobals=3		// Use modern global access method and strict wave access.

/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Official ScanM Data Preprocessing Scripts - by Tom Baden    	///
/////////////////////////////////////////////////////////////////////////////////////////////////////
///	Requires detrended 3D data from "OS_DetrendStack" proc	///
///	Input Arguments - Channel (0,1,2..), Min_ampl, Min_corr		///
///	e.g.: "OS_AutoRoiByCorr(0,15,0.3)"							///
///   Uses image correlation to place ROIs						///
///   note primary flags below									///
///	Output is new wave called ROIs							///
/////////////////////////////////////////////////////////////////////////////////////////////////////

function OS_AutoRoiByCorr()

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

// flags from "OS_Parameters"
variable Display_RoiMask = OS_Parameters[%Display_Stuff]
variable correlation_minimum = OS_Parameters[%ROI_corr_min]
variable ROI_minsize  = OS_Parameters[%ROI_mindiameter]
variable ROI_maxsize = OS_Parameters[%ROI_maxdiameter]
variable ROI_minpx = OS_Parameters[%ROI_minpix] 
variable X_cut = OS_Parameters[%LightArtifact_cut]
variable LineDuration = OS_Parameters[%LineDuration]
variable nLifesLeft = OS_Parameters[%nRoiKillsAllowed]
variable nPxBinning = OS_Parameters[%ROI_PxBinning]

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

variable xx,yy,xxx,yyy,nn,rr,ww // initialise counters
if (nPxBinning==1)
else
	make /o/n=(ceil(nX/nPxBinning),ceil(nY/nPxBinning),nF) InputDataBinDiv
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			InputDataBinDiv[floor(xx/nPxBinning)][floor(yy/nPxBinning)][]+=InputData[xx][yy][r]/(nPxBinning^2)
		endfor
	endfor
	duplicate /o InputDataBinDiv InputData
	nX=ceil(nX/nPxBinning)
	nY=ceil(nY/nPxBinning)
endif
variable nRois_max = (nX-X_cut/nPxBinning)*nY


// calculate Pixel / ROI sizes in microns
variable zoom = wParamsNum(30) // extract zoom
variable px_Size = (0.65/zoom * 110)/nX // microns
variable MaxPixelRoi = floor((pi * (ROI_maxsize^2))/px_Size)
variable MinPixelRoi = floor((pi * (ROI_minsize^2))/px_Size)
if (MinPixelRoi<ROI_minpx) // exception handling - don't allow ROIs smaller than ROI_minpx pixels
	MinPixelRoi=ROI_minpx
endif
print "Pixel Size:", round(px_size*100)/100," microns"
print MinPixelRoi, "-", MaxPixelRoi, "pixels per ROI"
variable nPx_neighbours = floor(((ROI_maxsize/px_Size)-1)/2)
if (nPx_neighbours<1)
	nPX_neighbours = 1
endif
print "nPixels neighbours evaluated:", nPx_neighbours

// make correlation stack and Ave/SD stacks
make /o/n=(nX,nY) Stack_ave = 0 // Avg projection of InputData
make /o/n=(nX,nY) correlation_projection = 0
make /o/n=(nF) currentwave_main = 0
make /o/n=(nF) currentwave_comp = 0
make /o/n=1 W_Statslinearcorrelationtest = NaN
variable nCorr,Cumul_corr,corr_scale

variable PercentDone = 0
variable PercentPerPixel = 100/((nX)*(nY))
printf "Correlation progress: "
for (xx=ceil(X_cut/nPxBinning);xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		Multithread currentwave_main[]=InputData[xx][yy][p] // get trace from "reference pixel"
		Wavestats/Q currentwave_main
		Stack_ave[xx][yy]=V_Avg 
		Cumul_corr = 0	
		for (xxx=xx-nPx_neighbours;xxx<xx+nPx_neighbours+1;xxx+=1)
			for (yyy=yy-nPx_neighbours;yyy<yy+nPx_neighbours+1;yyy+=1)
				if ((xxx>=X_cut/nPxBinning)&&(xxx<nX)&&(yyy>=0)&&(yyy<nY))
					Multithread currentwave_comp[]=InputData[xxx][yyy][p] // get trace from "comparison pixel"
					statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
					W_Statslinearcorrelationtest[]=((yyy<0)||(yyy>=nY)||(xxx>=nX)||(xxx<X_cut/nPxBinning))?(0):(W_Statslinearcorrelationtest[p]) // exception handling: if goes off screen the correlation is not counted
					Cumul_corr+=W_Statslinearcorrelationtest[1]
				endif
			endfor
		endfor
		Cumul_corr-=1 // 
		correlation_projection[xx][yy] = Cumul_corr / (((2*nPx_neighbours+1)^2)-1 ) 
		nCorr+=1
		PercentDone+=PercentPerPixel
	endfor
	if (PercentDone>=10)
		PercentDone-=10
		printf "#"
	endif
	Stack_Ave[0,X_cut][] = V_Min
endfor
print "# complete..."

// correct edge effects 
for (nn=0;nn<nPx_neighbours;nn+=1)
	correlation_projection[][nn]/=((nPx_neighbours*2)/(nPx_neighbours*2+1))^(nPx_neighbours-nn) // bottom in Y
	correlation_projection[][nY-nn-1]/=((nPx_neighbours*2)/(nPx_neighbours*2+1))^(nPx_neighbours-nn) // top in Y	
	correlation_projection[nX-nn-1][]/=((nPx_neighbours*2)/(nPx_neighbours*2+1))^(nPx_neighbours-nn) // right in X	
endfor
correlation_projection[nX-1,nX-2][] = 0
correlation_projection[][0] = 0
correlation_projection[][nY-1,nY-2] = 0
correlation_projection[0,X_cut/nPxBinning][] = 0

// place ROIs
//print "placing ROIs..."
duplicate /o correlation_projection correlation_projection_sub
make/o/n=(nRois_max) RoiSizes = nan
make /o/n=(nX,nY) ROIs = 1 // 1 means "no roi/ background"
make /o/n=(nX,nY,(nX-X_cut/nPxBinning)*nY) AllRois = 0

make/o/n=(nX, nY) CurrentRoi = 0
variable X_pos,Y_pos
variable max_corr 
variable nRois = 0
variable Roisize = 0
variable RoiKilled = 0

printf "Placing ROIs: "
do // forever loop until "while", unless "break" is triggered
	Imagestats/Q correlation_projection_sub//Stack_SD_Sub
	if (RoiKilled==1) // this bit closes the ROI placement if more than nLifesLeft ROIs were placed and subsequently killed due to min size criterion
		nLifesLeft-=1
		RoiKilled = 0
		if (nLifesLeft<=0) 
			break
		endif
	endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 1: Setup the Seed pixel
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	if (V_max>correlation_minimum)
		nRois+=1
		X_pos = V_maxRowLoc// find peak - "seed pixel"
		Y_pos = V_maxColLoc // find peak - "seed pixel"
		ROIs[X_pos][Y_pos]=10 // placeholder // nRois-1 // set that Pixel in Rois mask to the  Roi number 
		correlation_projection_sub[X_pos][Y_pos]=0 // get rid of that pixel in the correlation map
		// now find the highest correlation with this seed pixel in the original correlation stack
		AllRois[][][nRois-1]=0
		AllRois[X_pos][Y_pos][nRois-1]=1
		make /o/n=(nX,nY) currentRoi = 0
		Roisize = 1
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 2: Flood-fill the ROI from seed pixel if Correlation minimum is exceeded, and if there is a non-diagonal face attached to seed or its outgrowths
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		do
			currentRoi[][]=AllRois[p][q][nRois-1] // all active pixels are == 1
			Imagestats/Q currentRoi
			variable nPx_before = V_Avg * nX*nY // how many pixels in old ROI
			Multithread AllRois[X_cut/nPxBinning+1,nX-2][1,nY-2][nRois-1]=((correlation_projection_sub[p][q]>correlation_minimum) && ((currentRoi[p+1][q]==1)||(currentRoi[p-1][q]==1)||(currentRoi[p][q+1]==1)||(currentRoi[p][q-1]==1)))?(1):(AllRois[p][q][nRois-1]) // if neigbor >corr min && == 1 go 1, else leave as is
			currentRoi[][]=AllRois[p][q][nRois-1]
			Imagestats/Q currentRoi
			variable nPx_after = V_Avg * nX*nY // how many pixels in "grown" ROI?
			if (nPx_after==nPx_before || nPx_after >=MaxPixelRoi) // if no change, or if too big, exit do-while loop
				break
			endif
		while(1)

		// here update all the other arrays according to that ROI
		Multithread ROIs[][]=(AllRois[p][q][nRois-1]==1)?(10):(ROIs[p][q]) // placeholder//nRois-1 // set that Pixel in Rois mask to the Roi number
		Multithread correlation_projection_sub[][]=(AllRois[p][q][nRois-1]==1)?(0):(correlation_projection_sub[p][q]) // get rid of those pixels in the correlation map
 		Roisize=nPx_after
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 3: Kill ROIs that are too small, and relabel Rois as n*(-1) that are retained
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
		if (Roisize<MinPixelRoi) // if roi too small....
			ROIs[][] = (ROIs[p][q]==10)?(1):(ROIs[p][q]) 	// kill ROI in ROI image
			nRois-=1
			RoiKilled = 1
		else	 // if ROI big enough...
			ROIs[][] = (ROIs[p][q]==10)?(((nROIs-1)*(-1))-1):(ROIs[p][q]) 	// define ROI in ROI image
			RoiSizes[nROIs-1] = Roisize
		endif 
	else
		break // finish when no more pixels respond well enough to exceed "SD_minimum"
	endif
while(1)
print " total of", nRois

// upsample again if was Binned
if (nPxBinning==1)
else
	nX*=nPxBinning
	nY*=nPxBinning	
	make /o/n=(nX,nY) ROIs_new = 0
	for (xx=ceil(X_cut/nPxBinning);xx<floor(nX/nPxBinning);xx+=1)
		for (yy=0;yy<floor(nY/nPxBinning);yy+=1)
			ROIs_new[xx*nPxBinning,xx*nPxBinning+(nPxBinning-1)][yy*nPxBinning,yy*nPxBinning+(nPxBinning-1)]=ROIs[xx][yy]
		endfor
	endfor
	duplicate /o ROIs_new ROIs
	duplicate /o $input_name InputData
	make /o/n=(nX,nY) Stack_Ave = 0
	for (xx=X_cut;xx<nX;xx+=1)
		for (yy=0;yy<nY;yy+=1)
			Multithread currentwave_main[]=InputData[xx][yy][p] // get trace from "reference pixel"
			Wavestats/Q currentwave_main
			Stack_Ave[xx][yy]=V_Avg
		endfor
	endfor
	Stack_Ave[0,X_cut][] = V_Min		
		
endif


// setscale
setscale /p x,-nX/2*px_Size,px_Size,"µm" Stack_Ave, ROIs
setscale /p y,-nY/2*px_Size,px_Size,"µm" Stack_Ave, ROIs
setscale /p x,-nX/2*px_Size,px_Size*nPxBinning,"µm" Correlation_projection
setscale /p y,-nY/2*px_Size,px_Size*nPxBinning,"µm" Correlation_projection

// display
if (Display_RoiMask==1)
	display /k=1
	ModifyGraph width={Aspect,(nX/nY)*2}
	
	ModifyGraph height={Aspect,1/(2*nX/nY)}
	ModifyGraph width=800
	doUpdate
	ModifyGraph width=0
	
	Appendimage /l=YAxis /b=XAxis1 Correlation_projection
	Appendimage /l=YAxis /b=XAxis2 Stack_Ave	
	Appendimage /l=YAxis /b=XAxis2 ROIs
	ModifyGraph fSize=8,axisEnab(YAxis)={0.05,1},axisEnab(XAxis1)={0.05,0.5};DelayUpdate
	ModifyGraph axisEnab(XAxis2)={0.55,1},freePos(YAxis)={0,kwFraction};DelayUpdate
	ModifyGraph freePos(XAxis1)={0,kwFraction},freePos(XAxis2)={0,kwFraction}
	ModifyGraph lblPos=47
	make /o/n=(1) M_Colors
	Colortab2Wave Rainbow256
	for (rr=0;rr<nRois;rr+=1)
		variable colorposition = 255 * (rr+1)/nRois
		ModifyImage ROIs explicit=1,eval={-rr-1,M_Colors[colorposition][0],M_Colors[colorposition][1],M_Colors[colorposition][2]}
	endfor
endif


// cleanup
killwaves InputData,W_Statslinearcorrelationtest,currentwave_main,currentwave_comp, correlation_projection_sub, allRois
killwaves currentRoi,M_colors,InputDataBinDiv,ROIs_new

end