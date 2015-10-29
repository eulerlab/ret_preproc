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
variable SD_minimum = OS_Parameters[%ROI_SD_min]
variable correlation_minimum = OS_Parameters[%ROI_corr_min]
variable ROI_minsize  = OS_Parameters[%ROI_mindiameter]
variable ROI_maxsize = OS_Parameters[%ROI_maxdiameter]
variable ROI_minpx = OS_Parameters[%ROI_minpix] 
variable X_cut = OS_Parameters[%LightArtifact_cut]
variable LineDuration = OS_Parameters[%LineDuration]

// data handling
wave wParamsNum // Reads data-header
string input_name = "wDataCh"+Num2Str(Channel)+"_detrended"
duplicate /o $input_name InputData
variable nX = DimSize(InputData,0)
variable nY = DimSize(InputData,1)
variable nF = DimSize(InputData,2)
variable nRois_max = (nX-X_cut)*nY
variable Framerate = 1/(nY * LineDuration) // Hz 
variable Total_time = (nF * nX ) * LineDuration
print "Recorded ", total_time, "s @", framerate, "Hz"
variable xx,yy,xxx,yyy,nn,rr,ww // initialise counters

// calculate Pixel / ROI sizes in microns
variable zoom = wParamsNum(30) // extract zoom
variable px_Size = (0.65/zoom * 110)/nX // microns
variable MaxPixelRoi = floor((pi * (ROI_maxsize/2))/px_Size)
variable MinPixelRoi = ceil((pi * (ROI_minsize/2))/px_Size)
if (MinPixelRoi<ROI_minpx) // exception handling - don't allow ROIs smaller than ROI_minpx pixels
	MinPixelRoi=ROI_minpx
endif
variable nPx_neighbours = floor(((ROI_maxsize/px_Size)-1)/2)
print "Pixel Size:", round(px_size*100)/100," microns"
print MinPixelRoi, "-", MaxPixelRoi, "pixels per ROI"
print "nPixels neighbours evaluated:", nPx_neighbours

// make correlation stack and Ave/SD stacks
make /o/n=(nX,nY) Stack_ave = 0 // Avg projection of InputData
make /o/n=(nX,nY) Stack_SD = 0 // SD projection of InputData

make /o/n=(nX,nY,(nX-X_cut)*nY) correlation_stack = 0
make /o/n=(nX,nY) correlation_projection = 0
make /o/n=(nF) currentwave_main = 0
make /o/n=(nF) currentwave_comp = 0
make /o/n=1 W_Statslinearcorrelationtest = NaN
variable nCorr,Cumul_corr,corr_scale

for (xx=X_cut;xx<nX;xx+=1)
	for (yy=0;yy<nY;yy+=1)
		Multithread currentwave_main[]=InputData[xx][yy][p] // get trace from "reference pixel"
		Wavestats/Q currentwave_main
		Stack_ave[xx][yy]=V_Avg 
		Stack_SD[xx][yy]=V_SDev
		Cumul_corr = 0	
		for (xxx=xx-nPx_neighbours;xxx<xx+nPx_neighbours+1;xxx+=1)
			for (yyy=yy-nPx_neighbours;yyy<yy+nPx_neighbours+1;yyy+=1)
				if ((xxx>=X_cut)&&(xxx<nX)&&(yyy>=0)&&(yyy<nY))
			
					Multithread currentwave_comp[]=InputData[xxx][yyy][p] // get trace from "comparison pixel"
					statsLinearcorrelationtest/Q currentwave_comp,currentwave_main
					Multithread correlation_stack[xxx][yyy][nCorr]=W_Statslinearcorrelationtest[1] // get correlation coeficient from "reference vs comparison"
					W_Statslinearcorrelationtest[]=((yyy<0)||(yyy>=nY)||(xxx>=nX)||(xxx<X_cut))?(0):(W_Statslinearcorrelationtest[p]) // exception handling: if goes off screen the correlation is not counted
					Cumul_corr+=W_Statslinearcorrelationtest[1]
				endif
			endfor
		endfor
		Cumul_corr-=1 // 
		correlation_projection[xx][yy] = Cumul_corr / (((2*nPx_neighbours+1)^2)-1 ) 
		nCorr+=1
	endfor
endfor
// correct edge effects 
for (nn=0;nn<nPx_neighbours;nn+=1)
	correlation_projection[][nn]/=((nPx_neighbours*2)/(nPx_neighbours*2+1))^(nPx_neighbours-nn) // bottom in Y
	correlation_projection[][nY-nn-1]/=((nPx_neighbours*2)/(nPx_neighbours*2+1))^(nPx_neighbours-nn) // top in Y	
	correlation_projection[nX-nn-1][]/=((nPx_neighbours*2)/(nPx_neighbours*2+1))^(nPx_neighbours-nn) // right in X	
endfor
stack_sd[nX-1,nX-2][] = 0
stack_sd[][0] = 0
stack_sd[][nY-1,nY-2] = 0
stack_sd[0,X_cut][] = 0

// place ROIs
//print "placing ROIs..."
duplicate /o correlation_projection correlation_projection_sub
duplicate /o correlation_stack correlation_stack_sub
duplicate /o Stack_SD Stack_SD_Sub
make/o/n=(nRois_max) RoiSizes = nan
make /o/n=(nX,nY) current_corr_image
make /o/n=(nX,nY) ROIs = 1 // 1 means "no roi/ background"
duplicate/o correlation_stack AllRois
AllRois = 0
make/o/n=(nX, nY) CurrentRoi = 0
variable X_pos,Y_pos
variable max_corr 
variable pix_to_frame
variable nRois = 0
variable Roisize = 0


do // forever loop until "while", unless "break" is triggered
	Imagestats/Q Stack_SD_Sub
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 1: Setup the Seed pixel
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	if (V_max>SD_minimum) 
		nRois+=1
		X_pos = V_maxRowLoc// find peak - "seed pixel"
		Y_pos = V_maxColLoc // find peak - "seed pixel"
		ROIs[X_pos][Y_pos]=10 // placeholder // nRois-1 // set that Pixel in Rois mask to the  Roi number 
		Stack_SD_Sub[X_pos][Y_Pos]=0
		correlation_projection_sub[X_pos][Y_pos]=0 // get rid of that pixel in the correlation map
		correlation_stack_sub[X_pos][Y_pos][] = 0 // and also in sub stack
			// now find the highest correlation with this seed pixel in the original correlation stack
		pix_to_frame = nY*(X_pos-X_cut)  + Y_pos // find out into which frame in the corr stack array this pixel was placed
		Multithread current_corr_image[][]=correlation_stack_sub[p][q][pix_to_frame]
		AllRois[][][nRois-1]=0
		AllRois[X_pos][Y_pos][nRois-1]=1
		make /o/n=(nX,nY) currentRoi =AllRois[p][q][nRois-1] // all active pixels are == 1
		
		current_corr_image[X_pos][Y_pos]=0 // kill the main pixel which is alway corr = 1
		Roisize = 1
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 2: Flood-fill the ROI from seed pixel if Correlation minimum is exceeded, and if there is a non-diagonal face attached to seed or its outgrowths
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		do
			currentRoi[][]=AllRois[p][q][nRois-1] // all active pixels are == 1
			Imagestats/Q currentRoi
			variable nPx_before = V_Avg * nX*nY // how many pixels in old ROI
			Multithread AllRois[X_cut+1,nX-2][1,nY-2][nRois-1]=((current_corr_image[p][q]>correlation_minimum) && ((currentRoi[p+1][q]==1)||(currentRoi[p-1][q]==1)||(currentRoi[p][q+1]==1)||(currentRoi[p][q-1]==1)))?(1):(AllRois[p][q][nRois-1]) // if neigbor >corr min && == 1 go 1, else leave as is
			currentRoi[][]=AllRois[p][q][nRois-1]
			Imagestats/Q currentRoi
			variable nPx_after = V_Avg * nX*nY // how many pixels in "grown" ROI?
			if (nPx_after==nPx_before) // if no change, exit do-while loop
				break
			endif
		while(1)

		// here update all the other arrays according to that ROI
		Multithread ROIs[][]=(AllRois[p][q][nRois-1]==1)?(10):(ROIs[p][q]) // placeholder//nRois-1 // set that Pixel in Rois mask to the Roi number
		Multithread correlation_projection_sub[][]=(AllRois[p][q][nRois-1]==1)?(0):(correlation_projection_sub[p][q]) // get rid of that pixel in the correlation map
 		Multithread current_corr_image[][]=(AllRois[p][q][nRois-1]==1)?(0):(current_corr_image[p][q]) /// also get rid of that pixel in the correlation map		
		Multithread correlation_stack_sub[][][]=(AllRois[p][q][nRois-1]==1)?(0):(correlation_stack_sub[p][q][r])  // and also in sub stack			
		Multithread Stack_SD_Sub[][]=(AllRois[p][q][nRois-1]==1)?(0):(Stack_SD_Sub[p][q])  // and in SD image
		Roisize=nPx_after
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// Step 3: Kill ROIs that are too small, and relabel Rois as n*(-1) that are retained
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
		if (Roisize<MinPixelRoi) // if roi too small....
			ROIs[][] = (ROIs[p][q]==10)?(1):(ROIs[p][q]) 	// kill ROI in ROI image
			nRois-=1
		else	 // if ROI big enough...
			ROIs[][] = (ROIs[p][q]==10)?(((nROIs-1)*(-1))-1):(ROIs[p][q]) 	// define ROI in ROI image
			RoiSizes[nROIs-1] = Roisize
		endif 
	else
		break // finish when no more pixels respond well enough to exceed "SD_minimum"
	endif
while(1)
print nRois, " ROIs placed"

// setscale
setscale /p x,0,px_Size,"µm" Stack_SD, ROIs
setscale /p y,0,px_Size,"µm" Stack_SD, ROIs

// display
if (Display_RoiMask==1)
	display /k=1
	Appendimage /l=YAxis /b=XAxis1 Stack_SD
	Appendimage /l=YAxis /b=XAxis2 Stack_SD	
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
killwaves InputData,W_Statslinearcorrelationtest,currentwave_main,currentwave_comp, correlation_stack, correlation_projection_sub, allRois
killwaves correlation_projection, correlation_stack_sub,currentRoi,current_corr_image,Stack_ave,Stack_SD_sub,M_colors

end