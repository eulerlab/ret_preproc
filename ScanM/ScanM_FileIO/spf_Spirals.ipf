// -----------------------------------------------------------------------------------		
//	Project			: ScanMachine (ScanM)
//	Module type		: Scan path function/decoder file (spf_*.ipf):
//	Function		: Arbitrary trajectory scans
//	Author			: Luke Rogerson
//	Copyright		: (C) CIN/Uni Tübingen 2016-2017
//	History			: 2017-01-30	Moved into separate file
//
// ---------------------------------------------------------------------------------- 
#pragma rtGlobals=1	

// ---> START OF USER SECTION
#pragma ModuleName	= spf_Spirals
// <--- END OF USER SECTION 

// -----------------------------------------------------------------------------------		
// 	Function that generates the scan paths. 
//	Note: The name of this function has to be unique.
//
//	Input	: 
//		wScanPathFuncParams[]	:= 	Scan function parameter wave 
//									(for details on content, see comments in function)
//
//	Output	: Generates in the current data folder 4 temporary waves (float) containing 
//			  the control voltages for all 4 AO channels for the duration of one frame.
//			  These 4 waves need to be created here and named as follows.
//		StimX[]					:= 	AO channel 0, x scanner
//		StimY[]					:=	AO channel 1, y scanner
//		StimPC[]				:=	AO channel 2, laser blanking signal (TTL levels)
//		StimZ[]					:= 	AO channel 3, z axis (i.e. ETL)
// ---------------------------------------------------------------------------------- 
function radialScan(wScanPathFuncParams)
	wave		wScanPathFuncParams

	variable	numberOfPoints, flyback, MaxAO_V, dxFrDecoded, dyFrDecoded
	variable   noAOCh3_Z, nLayers, minDefAO_lens, maxDefAO_lens
	variable   nOffsets, stepSize, coilFactor, earlyRetrace, pauseRetrace
	variable 	totalSize, normFactor, angle, away, itx
	
	variable	awayStep, theta, delta
	variable 	x_max, y_max
	
	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	// a) General parameters for arbitrary scans
	//
	numberOfPoints		= wScanPathFuncParams[0]	// cp.dXDataPixels, number of pixels per line (w/o retrace)
	flyback        	= wScanPathFuncParams[1]	// cp.nPixRetrace, number of pixels for retrace
	totalsize      	= wScanPathFuncParams[2]	// cp.trajDefaultVRange, default total voltage range 
	MaxAO_V				= wScanPathFuncParams[3]	// cp.maxAO_V, maximal AO voltage
	dxFrDecoded			= wScanPathFuncParams[4]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
	dyFrDecoded			= wScanPathFuncParams[5] 	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
	//
	// b) Function-specific, user-defined parameters
	//    with the number of parameters defined in cp.nTrajParams and the parameters
	//    in cp.trajParams[]
	//
	nOffsets	    	= wScanPathFuncParams[6]	// Number of rotated offsets
	stepSize			= wScanPathFuncParams[7]	// Step size	
	coilFactor			= wScanPathFuncParams[8]	// Tightness of coils	
	earlyRetrace		= wScanPathFuncParams[9]	// nPixels before end of spiral to start blanking
	pauseRetrace		= wScanPathFuncParams[10]	// nPixels pause in the centre before spiral start
	
	// Layer-wise scan parameters
	noAOCh3_Z			= wScanPathFuncParams[11] // cp.noAOCh3_Z, whether the Z channel is being used
	nLayers				= wScanPathFuncParams[12] // How many layers there are in the Z-axis
	minDefAO_lens		= wScanPathFuncParams[13] // How many layers there are in the Z-axis
	maxDefAO_lens		= wScanPathFuncParams[14] // How many layers there are in the Z-axis
	
	// <---

	// Initialize 
	//
 	numberOfPoints		+= flyback
	awayStep 			= 1 /(coilFactor *2 *pi)
	theta 				= stepSize /coilFactor
 	
 	// ---> OUTPUT
	// Generate the 4 waves that will contain the scan path data for one full frame
	// (here, "nOffsets" of the spirals)
	//
	make /o /n=(NumberofPoints * nOffsets * nLayers) 	StimX 	= 0
	make /o /n=(NumberofPoints * nOffsets * nLayers) 	StimY 	= 0
	make /o /n=(NumberofPoints * nOffsets * nLayers) 	StimZ	= 0
	make /o /n=(NumberofPoints * nOffsets * nLayers) 	StimPC	= ScM_TTLhigh
	// <---
 	
	// Generate temporary waves that will contain one spiral trajectory
	// (here none for Z because these spirals are only in xy plane)
	//
	make /o /n=(NumberofPoints) StimX1Offs 	= 0
	make /o /n=(NumberofPoints) StimY1Offs 	= 0
	make /o /n=(NumberofPoints) StimPC1Offs	= ScM_TTLhigh

	// Generate trajectory
	//
	itx = 0
	do
		away = awayStep * theta
		StimX1Offs[itx] = cos(theta) *away
		StimY1Offs[itx] = sin(theta) *away    		
		
		delta = (-2 *away + sqrt(4 *away *away +8 *awayStep *stepSize))/(2*awayStep)
		theta += delta 
		itx +=1
	    if (itx > NumberOfPoints -flyback -earlyRetrace)
	    	StimPC1Offs[itx] = ScM_TTLlow
	    endif
	while (itx < NumberOfPoints)
	   
	x_max = wavemax(StimX1Offs)
	y_max = wavemax(StimY1Offs)
	normFactor = Totalsize/(2*max(x_max,y_max))
	StimX1Offs	*= normFactor
	StimY1Offs	*= normFactor

	for (itx=0; itx<flyback; itx+=1)
		if (itx > pauseRetrace)
		//	angle = (itx-pauseRetrace)/flyback*pi/2
			angle = (itx-pauseRetrace)/(flyback-pauseRetrace)*pi/2
			StimX1Offs[Numberofpoints-itx]	*= sin(angle)
			StimY1Offs[Numberofpoints-itx]	*= sin(angle)
		else
			StimX1Offs[Numberofpoints-itx]	= 0
			StimY1Offs[Numberofpoints-itx]	= 0
		endif
		StimPC1Offs[Numberofpoints-itx] 		= ScM_TTLlow
	endfor
	
	// Copy "nOffsets" trajectories, each slighly rotated into the scan stimulus 
	// buffers
 	// ##########################
	// 2017-01-30 CHANGED TE ==>
	// Moved copying into the scan buffer out to the calling ScanM part
	//
	make /o /n=(NumberofPoints) pix_x, pix_y, pix_r, pix_theta
	for(itx = 0; itx < nOffsets; itx += 1)
		// Convert to polar coordinates; offset; return to cartesian
		pix_r = sqrt(StimX1Offs ^ 2 + StimY1Offs ^ 2)
		pix_theta = atan2(StimY1Offs, StimX1Offs) + 2 * pi * mod(itx, nOffsets) / nOffsets
		pix_x = pix_r * cos(pix_theta)
		pix_y = pix_r * sin(pix_theta)
		
		StimX[itx * NumberofPoints, (itx + 1) * NumberofPoints - 1]	= pix_x[p - itx * NumberofPoints]
		StimY[itx * NumberofPoints, (itx + 1) * NumberofPoints - 1]  = pix_y[p - itx * NumberofPoints]
		StimPC[itx * NumberofPoints,(itx + 1) * NumberofPoints - 1] = StimPC1Offs[p - itx * NumberofPoints] * maxAO_V			
	endfor
	
	// Copy spiral trajectory to each layer
	for(itx = 0; itx < nLayers; itx += 1)
	
		StimX[itx * NumberofPoints * nOffsets, (itx + 1) * NumberofPoints  * nOffsets - 1]	= StimX[p - itx * NumberofPoints  * nOffsets]
		StimY[itx * NumberofPoints * nOffsets, (itx + 1) * NumberofPoints  * nOffsets - 1]  = StimY[p -itx * NumberofPoints  * nOffsets]
		StimPC[itx * NumberofPoints * nOffsets,(itx + 1) * NumberofPoints  * nOffsets - 1] = StimPC[p - itx * NumberofPoints  * nOffsets]			
		StimZ[itx * NumberofPoints * nOffsets, (itx + 1) * NumberofPoints  * nOffsets - 1] = itx * (maxDefAO_lens - minDefAO_lens) / nLayers

	endfor
	
//	make /o /n=(NumberofPoints) pix_x,pix_y,pix_r,pix_theta
//	wave pwStimBufData = $("wStimBufData")
//	for(itx=0; itx<nOffsets; itx+=1)
//		// Convert to polar coordinates; offset; return to cartesian
//		pix_r = sqrt(StimX1Offs^2 + StimY1Offs^2)
//		pix_theta = atan2(StimY1Offs,StimX1Offs) + 2*pi*mod(itx,nOffsets)/nOffsets
//		pix_x = pix_r*cos(pix_theta)
//		pix_y = pix_r*sin(pix_theta)
//		
//		pwStimBufData[SCM_indexScannerX][itx*NumberofPoints,(itx+1)*NumberofPoints-1]	= pix_x[q -itx*NumberofPoints]
//		pwStimBufData[SCM_indexScannerY][itx*NumberofPoints,(itx+1)*NumberofPoints-1] = pix_y[q -itx*NumberofPoints]
//		pwStimBufData[SCM_indexLaserBlk][itx*NumberofPoints,(itx+1)*NumberofPoints-1] = StimPC1Offs[q -itx*NumberofPoints]*maxAO_V			
//	endfor
	// <==
	
	// Cleaning up temporary waves
	// (this is important otherwise Igor/ScanM may run out of memory)
	//	
	killWaves/z StimX1Offs, StimY1Offs, StimPC1Offs
	killWaves/z pix_x, pix_y, pix_r, pix_theta
end	

// -----------------------------------------------------------------------------------		
// Function that prepares the decoding of the pixel data generated with the 
// respective scan path function. This will be called once when the stimulus 
// configuration is loaded. 
//	Note: This function's name must "<scan path function>_prepareDecode"
//
// It is meant to be used to create waves and variables (in the datafolder of that 
// particular scan configuration) that are needed for or accelerate decoding during
// the scan.
//
//	Input	: 
//		wStimBufData[nCh][]	:=	Scan stimulus buffer, containing AO voltage traces 
//									for the used number of AO channels (nCh)
//		wScanPathFuncParams	:= 	Scan function parameter wave 
//									(for details on content, see comments in function)
//  Output	:
//		Must return "SCM_PixDataResorted" if pixel data is just resorted (w/o loss 
//		of information) by the scan decoder or "SCM_PixDataDecoded" if the 
//		reconstruction/decoding of the pixel data involves some kind of information 
//		loss. The return value determines if the ScanM file loader retains two sets 
//		of data waves (SCM_PixDataDecoded), one with the raw and one with the decoded 
//		pixed data, or just one set (SCM_PixDataResorted).
//
// ---------------------------------------------------------------------------------- 
function radialScan_prepareDecode(wStimBufData, wScanPathFuncParams)
	wave		wStimBufData, wScanPathFuncParams 

	variable	dxFrDecoded, dyFrDecoded, noAOCh3_Z

	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	// a) General parameters for arbitrary scans
	//    here only: the dimensions of the frame to reconstruct
	//
	dxFrDecoded			= wScanPathFuncParams[4]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
	dyFrDecoded			= wScanPathFuncParams[5] 	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
	noAOCh3_Z			= wScanPathFuncParams[11] 	// cp.noAOCh3_Z, whether the Z channel is being used
	
	//
	// b) Function-specific, user-defined parameters
	// <---

	// If needed, generate and populate waves for the decoding of the scan 
	// during recordings (display) 
	//
	// Here, build frequency matrix for scan normalisation	
	//
	make/o/n=(dimsize(wStimBufData, 1), 1) countVector = 1
	make/o/n=(dxFrDecoded, dyFrDecoded) countMatrix = 0
	
	if (dimsize(countVector,0) == dimsize(wStimBufData,1))
		if (noAOCh3_Z == 1)
			ScanDecoder(countVector, wStimBufData, countMatrix)
		else
			// If the Z-channel is being used
			// Copy wStimBufData
			Duplicate/o wStimBufData, wStimBufData_temp
			
			// Remove the Z-channel from the duplicate
			DeletePoints/M=0 3, 1, wStimBufData_temp
			
			// Decode input using duplicate
			ScanDecoder(countVector, wStimBufData_temp, countMatrix)
		endif
	endif
	

	// Cleaning up temporary waves
	//	
	killWaves/z countVector
	
	return SCM_PixDataDecoded
end

// -----------------------------------------------------------------------------------		
// Function that decodes the pixel data on the fly. It is called during a scan for
// each retrieved pixel buffer (for each recorded AI channel). It is responsible for 
// populating the display wave.
//	Note: This function's name must "<scan path function>_decode"
// 
// Note that the function should be very fast; it should not take more than a few 
// milliseconds per call, otherwise the display will more and more lag behind the 
// recoding.
//
//	Input	: 
//		wImgFrame[dx*dy]		:=	linearized display wave for the current AI channel
//		wImgFrameAv[dx*dy]		:=  copy of display wave to be used e.g. for averaging 
//		wPixelDataBlock[]		:= 	new pixel data block (for all recorded AI channels)
//		sCurrConfPath			:=	string with path to current scan configuration
//									folder in case waves need to be accessed there
//		wParams[0]				:= 	nAICh, number of AI channels recorded (1..4)
//		wParams[1]				:=	iAICh, index of AI channel to decode (0..3)
//		wParams[2]				:= 	pixOffs
//		wParams[3]				:=	pixFrameLen
//		wParams[4]				:= 	pixBlockPerChLen
//		wParams[5]				:=	currNFrPerStep
//		wParams[6]				:= 	isDispFullFrames
//
//	Output	:
//		wImgFrame[][]
// ---------------------------------------------------------------------------------- 
function radialScan_decode(wImgFrame, wImgFrameAv, wPixelDataBlock, sCurrConfPath, wParams)
	wave 	wImgFrame, wImgFrameAv, wPixelDataBlock
	string	sCurrConfPath
	wave	wParams
	
	variable	dxFrDecoded, dyFrDecoded, nAICh, iAICh, noAOCh3_Z
	variable 	dataLength, start, stop
	variable 	nPoints, nOffsets, offset_pixel, data_pixels
	variable	flyback 
	
	// Get access to waves within the current scan configuration data folder
	// using the provided path string
	//
	wave pCountMatrix			= $(sCurrConfPath +"countMatrix")
	wave pwStimBufData 		= $(sCurrConfPath +"wStimBufData")
	wave pwScanPathFuncParams	= $(sCurrConfPath +"wScanPathFuncParams")

	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	// a) General parameters for arbitrary scans
	//    here: the dimensions of the frame to reconstruct, how many AI channels were 
	//    recorded and which AI channel to reconstruct	
	//
	data_pixels			= pwScanPathFuncParams[0]	// cp.dXDataPixels, number of pixels per line (w/o retrace)
	flyback        	= pwScanPathFuncParams[1]	// cp.nPixRetrace, number of pixels for retrace
	dxFrDecoded			= pwScanPathFuncParams[4]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
	dyFrDecoded			= pwScanPathFuncParams[5] // cp.dyFrDecoded, frame height for reconstructed/decoded frame
	//
	// b) Function-specific, user-defined parameters
	//    with the number of parameters defined in cp.nTrajParams and the parameters
	//    in cp.trajParams[]
	//
	nOffsets	    	= pwScanPathFuncParams[6]	// Number of rotated offsets
	offset_pixel		= pwScanPathFuncParams[9]	// nPixels before end of spiral to start blanking
	//
	// c) Additional parameters
	//
	nAICh				= wParams[0]	// number of AI channels recorded (1..4)
	iAICh				= wParams[1] 	// index of AI channel to reconstruct (0..3)
	noAOCh3_Z			= pwScanPathFuncParams[11] 	// cp.noAOCh3_Z, whether the Z channel is being used
	// <---
	
//	if(wParams[2] < 5000)
//		print wParams
//	//	print WaveInfo(wImgFrame, 0)
//	//	print WaveInfo(wPixelDataBlock, 0)
//	endif	 
	

	// Initialize 
	//
	dataLength 	= dimsize(wPixelDataBlock, 0)/nAICh
	start = iAICh * dataLength
	stop = (iAICh + 1) * dataLength - 1
	nPoints = data_pixels + flyback
	
//	variable timerRefNum,microSeconds
//	timerRefNum = startMSTimer
	
	wImgFrame = 0
	Redimension/n=(dxFrDecoded, dyFrDecoded) wImgFrame
	Duplicate/o/r=(start, stop) wPixelDataBlock, wPixelDataBlockForCh
	Redimension/n=(stop - start + 1,1) wPixelDataBlockForCh
	
	// Offset failsafe
	wPixelDataBlockForCh	= wPixelDataBlockForCh[mod(p+offset_pixel,nPoints*nOffsets)][q]
	wPixelDataBlockForCh	= (mod(p,nPoints) < data_pixels)?(wPixelDataBlockForCh[p][q]):(0)
	
	// Decode Spiral 
	
	// Previous decoder was simply:
	// ScanDecoder(wPixelDataBlockForCh, pwStimBufData, wImgFrame)
	
	// Additional code below allows handling of z-axis:
	if (noAOCh3_Z == 1)
		ScanDecoder(wPixelDataBlockForCh, pwStimBufData, wImgFrame)
	else
		// If the Z-channel is being used; Copy wStimBufData
		Duplicate/o pwStimBufData, wStimBufData_temp
		
		// Remove the Z-channel from the duplicate
		// (Seems to alter memory address, causing the decoder confusion)
		DeletePoints/M=0 3, 1, wStimBufData_temp
		
		// Decode input using duplicate
		ScanDecoder(wPixelDataBlockForCh, wStimBufData_temp, wImgFrame)
	endif
	
	MatrixOp/o wImgFrame = wImgFrame / pCountMatrix
	
//	microSeconds = stopMSTimer(timerRefNum)
//	Print microSeconds/1000
end

// ---------------------------------------------------------------------------------- 
