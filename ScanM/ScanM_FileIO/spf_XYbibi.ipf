// -----------------------------------------------------------------------------------		
//	Project			: ScanMachine (ScanM)
//	Module type		: Scan path function/decoder file (spf_*.ipf):
//	Function		: XY bidirectional (both x and y)
//	Author			: Thomas Euler
//	Copyright		: (C) CIN/Uni Tübingen 2016-2018
//	History			: 2018-02-21	
//
// ---------------------------------------------------------------------------------- 
#pragma rtGlobals=1	

// ---> START OF USER SECTION
#pragma ModuleName	= spf_XYbibi
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
function xyBibi (wScanPathFuncParams)
	wave		wScanPathFuncParams

	variable	nPntsTotal, dXTotal, dY
	variable	nPntsRetrace, nPntsLineOffs
	variable	aspectRatioFr 
	variable	xVMax, yVMax, dxScan
	variable	nStimPerFr
	variable	iY, iX, noYScan, nB, iB, iP
	
	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	//
	nPntsTotal		= wScanPathFuncParams[0]	// = dx*dy*dz *nStimPerFr
	dXTotal			= wScanPathFuncParams[1]	// cp.dXPixels
	dY				= wScanPathFuncParams[2]	// cp.dYPixels	
	nPntsRetrace   = wScanPathFuncParams[3]	// cp.nPixRetrace, # of points per line used for retrace	
	nPntsLineOffs	= wScanPathFuncParams[4]	// cp.nXPixLineOffs, # of points per line before pixels are aquired
	noYScan			= wScanPathFuncParams[5]	// noYScan
	aspectRatioFr	= wScanPathFuncParams[6]	// cp.aspectRatioFrame
	nStimPerFr		= wScanPathFuncParams[7]	// cp.stimBufPerFr
//	dxFrDecoded		= wScanPathFuncParams[8]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
//	dyFrDecoded		= wScanPathFuncParams[9]	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
//	nImgPerFrame	= wScanPathFuncParams[10]	// cp.nImgPerFrame, # of images per frame
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

	// Initialise
	//
	dxScan			= dXTotal -nPntsRetrace
	if(dXTotal > dy)
		xVMax		= 0.5
		yVMax		= dy/(dxScan *aspectRatioFr) /2
	else	 
		xVMax		= (dxScan *aspectRatioFr)/dy /2
		yVMax		= 0.5
	endif	
	
	for(iY=0; iY<dy; iY+=1)
		// Define scan points
		//
		for(iX=0; iX<dXTotal; iX+=1)
			if(mod(iY, 2) == 0)
				StimX[iY*dXTotal +iX]	= 2*xVMax *iX/(dXTotal -1) -xVMax
			else
				StimX[iY*dXTotal +iX]	= 2*xVMax *(dXTotal -iX)/(dXTotal -1) -xVMax
			endif	
			StimY[iY*dXTotal +iX]		= 2*yVMax *(iY/(dy -1)) -yVMax				
			
			if((iX >= nPntsLineOffs) && (iX < (dXTotal -nPntsRetrace)))
				StimPC[iY*dXTotal +iX]	= ScM_TTLhigh
			endif	
		endfor
	endfor	
	
	nB		= nPntsTotal/nStimPerFr
	for(iB=1; iB<nStimPerFr; iB+=1)
		iP	= nB*iB
		StimX[iP, iP+nB-1]  		= StimX[p-iP]	
		StimY[iP, iP+nB-1]  		= StimY[p-iP]
		StimPC[iP, iP+nB-1] 		= StimPC[p-iP]
	endfor
	if(noYScan == 1)
		StimY = 0
	endif	
	
	Smooth/E=1/S=2 27, StimX
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
function xyBibi_prepareDecode(wStimBufData, wScanPathFuncParams)
	wave		wStimBufData, wScanPathFuncParams 

	// Nothing to do

	return SCM_PixDataResorted
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
function xyBibi_decode(wImgFrame, wImgFrameAv, wPixelDataBlock, sCurrConfPath, wParams)
	wave 	wImgFrame, wImgFrameAv, wPixelDataBlock
	string	sCurrConfPath
	wave	wParams

	variable	nAICh, iAICh, j, k
	variable	pixOffs, pixFrameLen, pixBlockPerChLen 
	variable	currNFrPerStep, isDispFullFrames
	variable	n, m, dXTotal, dY
	variable	iFr, nBufPerImg, offsInBuf, nImgPerFrame
	
	// Get access to waves within the current scan configuration data folder
	// using the provided path string
	//
	wave wScanPathFuncParams	= $(sCurrConfPath +"wScanPathFuncParams")
	
	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	//
//	nPntsTotal		= wScanPathFuncParams[0]	// = dx*dy*dz *nStimPerFr
	dXTotal			= wScanPathFuncParams[1]	// cp.dXPixels
	dY				= wScanPathFuncParams[2]	// cp.dYPixels
//	dZTotal			= wScanPathFuncParams[3]	// cp.dZPixels
//	nPntsRetrace   = wScanPathFuncParams[4]	// cp.nPixRetrace, # of points per line used for retrace	
//	nPntsLineOffs	= wScanPathFuncParams[5]	// cp.nXPixLineOffs, # of points per line before pixels are aquired
//	nPntsLineOffs	= wScanPathFuncParams[6]	// cp.nYPixLineOffs, ...
//	nPntsLineOffs	= wScanPathFuncParams[7]	// cp.nZPixLineOffs, ...
//	aspectRatioFr	= wScanPathFuncParams[8]	// cp.aspectRatioFrame
//	iChFastScan		= wScanPathFuncParams[9]	// cp.iChFastScan
//	zVMinDef		= wScanPathFuncParams[10]	// cp.minDefAO_Lens_V
//	zVMaxDef		= wScanPathFuncParams[11]	// cp.maxDefAO_Lens_V
//	nStimPerFr		= wScanPathFuncParams[12]	// cp.stimBufPerFr
//	dxFrDecoded		= wScanPathFuncParams[13]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
//	dyFrDecoded		= wScanPathFuncParams[14]	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
	nImgPerFrame	= wScanPathFuncParams[15]	// cp.nImgPerFrame, # of images per frame
	
	// Retrieve more parameters
	//
	nAICh				= wParams[0]
	iAICh				= wParams[1]
	pixOffs				= wParams[2]
	pixFrameLen			= wParams[3] 
	pixBlockPerChLen	= wParams[4]
	currNFrPerStep		= wParams[5]
	isDispFullFrames	= wParams[6]
	// <---

//	if(wParams[2] < 5000)
//		print wParams
//	//	print WaveInfo(wImgFrame, 0)
//	//	print WaveInfo(wPixelDataBlock, 0)
//	endif	 

	// Decoding	 ...
	//
	iFr			= trunc(pixOffs /pixFrameLen)
	nBufPerImg	= pixFrameLen /pixBlockPerChLen
	offsInBuf	= pixBlockPerChLen *iAICh	
	
	Duplicate/O/FREE/R=[offsInBuf, offsInBuf +pixBlockPerChLen -1] wPixelDataBlock, wPixelDataBlockTemp
	
	if(mod(iFr, nImgPerFrame) == 0)
		// Keep pixel order as is
		//
		m		= mod(pixOffs, pixFrameLen)	 			
		n		= m +pixBlockPerChLen -1
	else
		// Mirror pixels along y axis
		//	
		m		= mod(pixOffs +pixBlockPerChLen, pixFrameLen)	 			
		n		= m +pixBlockPerChLen -1
		Redimension/E=1/N=(dXTotal, dY /nBufPerImg) wPixelDataBlockTemp				
		ImageTransform flipCols wPixelDataBlockTemp
		Redimension/E=1/N=(pixBlockPerChLen) wPixelDataBlockTemp
	endif
	
//	
//	m	= mod(pixOffs, pixFrameLen)	 			
//	n	= m +pixBlockPerChLen -1

	// Make pixel buffer copy for line mirroring
	//
	Make/FREE/O/N=(pixBlockPerChLen) pwChPixDBTemp

	// Mirror every 2nd line
	//
	pwChPixDBTemp[]	= wPixelDataBlock[p +pixBlockPerChLen *iAICh]
	for(j=dXTotal; j<pixBlockPerChLen; j+=dXTotal*2)
		k = j +dXTotal -1
	//	pwChPixDBTemp[j,k] = wPixelDataBlock[j +k +pixBlockPerChLen *iAICh -p] 
		pwChPixDBTemp[j,k] = wPixelDataBlock[j +1 +k +pixBlockPerChLen *iAICh -p] 
	endfor	
	
	if(currNFrPerStep > 1)
		// Is z-stack scan with frame averaging, make sure that display
		// reflects averaging
		//	
		if(mod(pixOffs/pixFrameLen, currNFrPerStep) == 0)
			wImgFrame[m,n]	= pwChPixDBTemp[p]
		else
			wImgFrame[m,n]	/= 2					
			wImgFrame[m,n]	+= pwChPixDBTemp[p]/2
		endif	
	else
		// No averaging, just show data
		//	
		if(isDispFullFrames)						
			wImgFrameAv[m,n]	= pwChPixDBTemp[p]									
			if(mod(pixOffs/pixFrameLen, currNFrPerStep) == 0)				
				wImgFrame	= wImgFrameAv
			endif	
		else	
			wImgFrame[m,n]	= pwChPixDBTemp[p]				
		endif	
	endif

//	// Decoding	 ...
//	//
//	iFr			= trunc(pixOffs /pixFrameLen)
//	nBufPerImg	= pixFrameLen /pixBlockPerChLen
//	offsInBuf	= pixBlockPerChLen *iAICh	
//	
//	Duplicate/O/FREE/R=[offsInBuf, offsInBuf +pixBlockPerChLen -1] wPixelDataBlock, wPixelDataBlockTemp
//		
//	if(mod(iFr, nImgPerFrame) == 0)
//		// Keep pixel order as is
//		//
//		m		= mod(pixOffs, pixFrameLen)	 			
//		n		= m +pixBlockPerChLen -1
//	else
//		// Mirror pixels along y axis
//		//	
//		m		= mod(pixOffs +pixBlockPerChLen, pixFrameLen)	 			
//		n		= m +pixBlockPerChLen -1
//		Redimension/E=1/N=(dxFrDecoded, dyFrDecoded /nBufPerImg) wPixelDataBlockTemp				
//		ImageTransform flipCols wPixelDataBlockTemp
//		Redimension/E=1/N=(pixBlockPerChLen) wPixelDataBlockTemp
//	endif
//	
////	if(pixOffs < 25000)
////		print pixOffs, iFr, m, n, "offsInBuf=",offsInBuf, iAICh, "flip=", mod(iFr, nImgPerFrame), nBufPerImg
////	//	print pixFrameLen, nImgPerFrame, pixBlockPerChLen 
//// 	//	print DimSize(wPixelDataBlock, 0), DimSize(wPixelDataBlock, 1)
////	//	print DimSize(wImgFrame, 0), DimSize(wImgFrame, 1)
////	//	print wParams
////	endif	
//	
//	if(currNFrPerStep > 1)
//		// Is z-stack scan with frame averaging, make sure that display
//		// reflects averaging
//		//	
//		if(mod(pixOffs/pixFrameLen, currNFrPerStep) == 0)
//			wImgFrame[m,n]		= wPixelDataBlockTemp[p -m]
//		else
//			wImgFrame[m,n]		/= 2					
//			wImgFrame[m,n]		+= wPixelDataBlockTemp[p -m]/2
//		endif	
//	else
//		// No averaging, just show data
//		//	
//		if(isDispFullFrames)						
//			wImgFrameAv[m,n]	= wPixelDataBlockTemp[p -m]											
//			if(mod(pixOffs/pixFrameLen, currNFrPerStep) == 0)				
//				wImgFrame		= wImgFrameAv
//			endif	
//		else	
//			wImgFrame[m,n]		= wPixelDataBlockTemp[p -m]											
//		endif	
//	endif
end

// ---------------------------------------------------------------------------------- 
