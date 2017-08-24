// -----------------------------------------------------------------------------------		
//	Project			: ScanMachine (ScanM)
//	Module type		: Scan path function/decoder file (spf_*.ipf):
//	Function		: ZX slice
//	Author			: Thomas Euler
//	Copyright		: (C) CIN/Uni Tübingen 2016-2017
//	History			: 2017-02-17	
//
// ---------------------------------------------------------------------------------- 
#pragma rtGlobals=1	

// ---> START OF USER SECTION
#pragma ModuleName	= spf_ZX_slice
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
function zxSlice (wScanPathFuncParams)
	wave		wScanPathFuncParams

	variable	nPntsTotal, dX, dZ
	variable	nPntsRetrace, nPntsLineOffs
	variable	aspectRatioFr	, iChFastScan
	variable	zVMin, zVMax, zVMinDef, zVMaxDef, zVZero
	variable	xVMax, nB, iB, iP
	variable	nStimPerFr, zInc1, zInc2, iZ, iX2, iZ2, xVal
	variable	dZScan, iX, xVLastLine, xInc1, xInc2
	
	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	//
	nPntsTotal		= wScanPathFuncParams[0]	// = dx*dy*dz *nStimPerFr
	dX				= wScanPathFuncParams[1]	// cp.dXPixels
//	dY				= wScanPathFuncParams[2]	// cp.dYPixels
	dZ				= wScanPathFuncParams[3]	// cp.dZPixels
	nPntsRetrace   = wScanPathFuncParams[4]	// cp.nPixRetrace, # of points per line used for retrace	
//	nPntsLineOffs	= wScanPathFuncParams[5]	// cp.nXPixLineOffs, # of points per line before pixels are aquired
//	nPntsLineOffs	= wScanPathFuncParams[6]	// cp.nYPixLineOffs, ...
	nPntsLineOffs	= wScanPathFuncParams[7]	// cp.nZPixLineOffs, ...
	aspectRatioFr	= wScanPathFuncParams[8]	// cp.aspectRatioFrame
//	iChFastScan		= wScanPathFuncParams[9]	// cp.iChFastScan
	zVMinDef		= wScanPathFuncParams[10]	// cp.minDefAO_Lens_V
	zVMaxDef		= wScanPathFuncParams[11]	// cp.maxDefAO_Lens_V
	nStimPerFr		= wScanPathFuncParams[12]	// cp.stimBufPerFr
//	dxFrDecoded		= wScanPathFuncParams[13]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
//	dyFrDecoded		= wScanPathFuncParams[14]	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
//	nImgPerFrame	= wScanPathFuncParams[15]	// cp.nImgPerFrame, # of images per frame
	// <---

 	// ---> OUTPUT
	// Generate the 4 waves that will contain the scan path data for one full frame
	//
	Make/O/N=(nPntsTotal) StimX, StimY, StimPC, StimZ
	StimX			= 0
	StimY			= 0
	StimPC			= ScM_TTLlow	
	StimZ			= 0
	// <---

	// Initialize 
	//
	dZScan			= dZ -nPntsRetrace -nPntsLineOffs
	if(dz > dx)
		zVMax		= (zVMaxDef-zVMinDef) /2
		xVMax		= dx/(dzScan *aspectRatioFr) /2
	else	 
		zVMax		= (dzScan *aspectRatioFr)/dx /2
		xVMax		= 0.5
	endif		
	xInc1			= 2*xVMax /(dX-1) /(nPntsRetrace +1)
	xInc2			= 2*xVMax /((nPntsRetrace +1) *2)
	zInc1			= 2*zVMax /(nPntsRetrace +1)
	zInc2			= zInc1 /2
	iZ2				= 0
	xVal			= -xVMax
	
	for(iX=0; iX<dX; iX+=1)
		// Define scan points
		//
		for(iZ=0; iZ<dZ; iZ+=1)
			StimZ[iX*dz +iZ]		= 2*zVMax *sin(2*Pi/(dZ*2) *iZ2 -Pi/2)/2 
			if(iZ > dZ-nPntsRetrace)
				xVal				= 2*xVMax *((iX +1)/(dX -1)) -xVMax
			endif	
			StimX[iX*dz +iZ]		= xVal
			if((iZ >= nPntsLineOffs) && (iZ < dZ-nPntsRetrace))
				StimPC[iX*dz +iZ]	= ScM_TTLhigh
			endif	
			iZ2 += 1
			if(iZ2 >= dZ*2)
				iZ2	= 0
			endif	
		endfor
		if(nPntsRetrace <= 0)		
			continue
		endif	
		xVLastLine					= StimX[iX*dz +dzScan -1] 	
		
		if(iX == (dX-1))
			// Last line, thus retrace needs to go back to starting position
			//
			for(iZ=dZ-nPntsRetrace; iZ<dZ; iZ+=1)
			//	StimZ[iX*dz +iZ]	= zVMax -zInc2 *(iZ -(dZ -nPntsRetrace) +1)
				StimX[iX*dZ +iZ]	= xVLastLine -xInc2 *(iZ -(dZ -nPntsRetrace) +1)
			endfor
		endif	
	endfor	
	
	nB		= nPntsTotal/nStimPerFr
	for(iB=1; iB<nStimPerFr; iB+=1)
		iP	= nB*iB
		StimX[iP, iP+nB-1]  		= StimX[p-iP]	
		StimZ[iP, iP+nB-1]  		= StimZ[p-iP]
		StimPC[iP, iP+nB-1] 		= StimPC[p-iP]
	endfor
	
	// ***********
	// TODO: should be z=0..1V, asymmetrically, currently crashes the ScanDecoder
	//
//	StimZ	+= 	(zVMaxDef-zVMinDef) /2 +zVMinDef
	// ***********
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
//	Output	:
//		Must return "SCM_PixDataResorted" if pixel data is just resorted (w/o loss 
//		of information) by the scan decoder or "SCM_PixDataDecoded" if the 
//		reconstruction/decoding of the pixel data involves some kind of information 
//		loss. The return value determines if the ScanM file loader retains two sets 
//		of data waves (SCM_PixDataDecoded), one with the raw and one with the decoded 
//		pixed data, or just one set (SCM_PixDataResorted).
//
// ---------------------------------------------------------------------------------- 
function zxSlice_prepareDecode(wStimBufData, wScanPathFuncParams)
	wave		wStimBufData, wScanPathFuncParams 

	variable	dxFrDecoded, dyFrDecoded 

	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	// a) General parameters for arbitrary scans
	//    here only: the dimensions of the frame to reconstruct
	//
	dxFrDecoded			= wScanPathFuncParams[13]		// cp.dxFrDecoded, frame width for reconstructed/decoded frame
	dyFrDecoded			= wScanPathFuncParams[14] 	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
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
		// Make a copy of the stim buffer with x->y, z->x; this is what the
		// decoder expects
		//
		Make/O/N=(3, DimSize(wStimBufData, 1)) wStimBufData_temp
		wStimBufData_temp[0][] = wStimBufData[0][q]
		wStimBufData_temp[1][] = wStimBufData[3][q]
		wStimBufData_temp[2][] = wStimBufData[2][q]

		// Decode input using duplicate
		//
		ScanDecoder(countVector, wStimBufData_temp, countMatrix)
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
function zxSlice_decode(wImgFrame, wImgFrameAv, wPixelDataBlock, sCurrConfPath, wParams)
	wave 	wImgFrame, wImgFrameAv, wPixelDataBlock
	string	sCurrConfPath
	wave	wParams

	variable	dxFrDecoded, dyFrDecoded, nAICh, iAICh 
	variable 	dataLength, start, stop, nPoints
	variable	data_pixels, flyback, offset_pixel
	
	// Get access to waves within the current scan configuration data folder
	// using the provided path string
	//
	wave pCountMatrix			= $(sCurrConfPath + "countMatrix")
	wave pwStimBufData 		= $(sCurrConfPath + "wStimBufData")
	wave pwScanPathFuncParams	= $(sCurrConfPath + "wScanPathFuncParams")

	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	// a) General parameters 
	//
	data_pixels			= pwScanPathFuncParams[3]		// cp.dZDataPixels, number of pixels per line (w/o retrace)
	flyback        	= pwScanPathFuncParams[4]		// cp.nPixRetrace, number of pixels for retrace
	offset_pixel		= pwScanPathFuncParams[7]		// pwDescVal[%nZPixLineOffs]
	dxFrDecoded			= pwScanPathFuncParams[13]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
	dyFrDecoded			= pwScanPathFuncParams[14] 	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
	//
	// b) Additional parameters
	//
	nAICh				= wParams[0]					/// number of AI channels recorded (1..4)
	iAICh				= wParams[1] 					// index of AI channel to reconstruct (0..3)
	// <---
	
	// Initialize 
	//
	flyback		= flyback + offset_pixel
	data_pixels	= data_pixels - flyback
	dataLength 	= dimsize(wPixelDataBlock, 0) / nAICh
	start 		= iAICh * dataLength
	stop 		= (iAICh + 1) * dataLength - 1
	nPoints 	= data_pixels + flyback
	
	wImgFrame 	= 0
	Redimension/n=(dxFrDecoded, dyFrDecoded) wImgFrame
	Duplicate/o/r=(start, stop) wPixelDataBlock, wPixelDataBlockForCh
	Redimension/n=(stop-start+1, 1) wPixelDataBlockForCh
	
	// Decode 
	//
	// Make a copy of the stim buffer with x->y, z->x; this is what the
	// decoder expects
	//
	Make/O/N=(3, DimSize(pwStimBufData, 1)) wStimBufData_temp
	wStimBufData_temp[0][] = pwStimBufData[0][q]
	wStimBufData_temp[1][] = pwStimBufData[3][q]
	wStimBufData_temp[2][] = pwStimBufData[2][q]
	ScanDecoder(wPixelDataBlockForCh, wStimBufData_temp, wImgFrame)
	
	MatrixOp/o wImgFrame = wImgFrame / pCountMatrix
end

// ---------------------------------------------------------------------------------- 
