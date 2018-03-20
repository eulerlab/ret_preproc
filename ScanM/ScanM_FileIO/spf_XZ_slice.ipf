// -----------------------------------------------------------------------------------		
//	Project			: ScanMachine (ScanM)
//	Module type		: Scan path function/decoder file (spf_*.ipf):
//	Function		: XZ slice
//	Author			: Thomas Euler
//	Copyright		: (C) CIN/Uni Tübingen 2016-2017
//	History			: 2017-02-17	
//
// ---------------------------------------------------------------------------------- 
#pragma rtGlobals=1	

// ---> START OF USER SECTION
#pragma ModuleName	= spf_XZ_slice
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
function xzSlice (wScanPathFuncParams)
	wave		wScanPathFuncParams

	variable	nPntsTotal, dX, dZ
	variable	nPntsRetrace, nPntsLineOffs
	variable	aspectRatioFr	, iChFastScan
	variable	zVMin, zVMax, zVMinDef, zVMaxDef, zVZero
	variable	xVMax, nB, iB, iP
	variable	nStimPerFr, xInc1, xInc2, iX
	variable	dXScan, iZ, zVLastLine, zInc1, zInc2
	
	// ---> INPUT
	// Retrieve parameters about the scan configuration 
	//
	nPntsTotal		= wScanPathFuncParams[0]	// = dx*dy*dz *nStimPerFr
	dX				= wScanPathFuncParams[1]	// cp.dXPixels
//	dY				= wScanPathFuncParams[2]	// cp.dYPixels
	dZ				= wScanPathFuncParams[3]	// cp.dZPixels
	nPntsRetrace   = wScanPathFuncParams[4]	// cp.nPixRetrace, # of points per line used for retrace	
	nPntsLineOffs	= wScanPathFuncParams[5]	// cp.nXPixLineOffs, # of points per line before pixels are aquired
//	nPntsLineOffs	= wScanPathFuncParams[6]	// cp.nYPixLineOffs, ...
//	nPntsLineOffs	= wScanPathFuncParams[7]	// cp.nZPixLineOffs, ...
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
	dXScan			= dX -nPntsRetrace
	if(dx > dz)
		xVMax		= 0.5
		zVMax		= dZ/(dxScan *aspectRatioFr) *(zVMaxDef-zVMinDef) /2
	else	 
		xVMax		= (dxScan *aspectRatioFr)/dz /2
		zVMax		= (zVMaxDef-zVMinDef) /2
	endif	
	xInc1			= 2*xVMax /(nPntsRetrace +1)
	xInc2			= xInc1 /2
	zInc1			= 2*zVMax /(dZ-1) /(nPntsRetrace +1)
	zInc2			= 2*zVMax /((nPntsRetrace +1) *2)
	
	for(iZ=0; iZ<dZ; iZ+=1)
		// Define scan points
		//
		for(iX=0; iX<dxScan; iX+=1)
			StimX[iZ*dx +iX]		= 2*xVMax *iX/(dxScan -1) -xVMax
			StimZ[iZ*dx +iX]		= 2*zVMax *(iZ/(dZ -1)) -zVMax				
			if(iX >= nPntsLineOffs)
				StimPC[iZ*dx +iX]	= ScM_TTLhigh
			endif	
		endfor
		if(nPntsRetrace <= 0)		
			continue
		endif	
		zVLastLine					= StimZ[iZ*dx +dxScan -1] 	
		
		// Define retrace points, if there is a retrace section
		// 
		if(iZ < (dZ-1))
			// Is not yet last line, thus line retrace
			//
			for(iX=dxScan; iX<dx; iX+=1)
				StimX[iZ*dx +iX]	= xVMax -xInc1 *(ix -dxScan +1)
				StimZ[iZ*dx +iX]	= zVLastLine +zInc1 *(ix -dxScan +1)
			endfor
		else
			// Last line, thus retrace needs to go back to starting position
			//
			for(iX=dxScan; iX<dx; iX+=1)
				StimX[iZ*dx +iX]	= xVMax -xInc2 *(ix -dxScan +1)
				StimZ[iZ*dx +iX]	= zVLastLine -zInc2 *(ix-dxScan +1)
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
	StimZ	+= 	(zVMaxDef-zVMinDef) /2 +zVMinDef
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
function xzSlice_prepareDecode(wStimBufData, wScanPathFuncParams)
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
function xzSlice_decode(wImgFrame, wImgFrameAv, wPixelDataBlock, sCurrConfPath, wParams)
	wave 	wImgFrame, wImgFrameAv, wPixelDataBlock
	string	sCurrConfPath
	wave	wParams
	
	variable	nAICh, iAICh
	variable	pixOffs, pixFrameLen, pixBlockPerChLen 
	variable	currNFrPerStep, isDispFullFrames
	variable	n, m
	
	// Retrieve nescessary parameters 
	//
	nAICh				= wParams[0]
	iAICh				= wParams[1]
	pixOffs				= wParams[2]
	pixFrameLen			= wParams[3]
	pixBlockPerChLen	= wParams[4]
	currNFrPerStep		= wParams[5]
	isDispFullFrames	= wParams[6]

//	if(wParams[2] < 5000)
//		print wParams
//	//	print WaveInfo(wImgFrame, 0)
//	//	print WaveInfo(wPixelDataBlock, 0)
//	endif	 

	// Decoding	 ...
	//
	m	= mod(pixOffs, pixFrameLen)	 			
	n	= m +pixBlockPerChLen -1
	if(currNFrPerStep > 1)
		// Is z-stack scan with frame averaging, make sure that display
		// reflects averaging
		//	
		if(mod(pixOffs/pixFrameLen, currNFrPerStep) == 0)
			wImgFrame[m,n]	= wPixelDataBlock[p -m +pixBlockPerChLen *iAICh]
		else
			wImgFrame[m,n]	/= 2					
			wImgFrame[m,n]	+= wPixelDataBlock[p -m +pixBlockPerChLen *iAICh]/2
		endif	
	else
		// No averaging, just show data
		//	
		if(isDispFullFrames)						
			wImgFrameAv[m,n]	= wPixelDataBlock[p -m +pixBlockPerChLen *iAICh]									
			if(mod(pixOffs/pixFrameLen, currNFrPerStep) == 0)				
				wImgFrame	= wImgFrameAv
			endif	
		else	
			wImgFrame[m,n]	= wPixelDataBlock[p -m +pixBlockPerChLen *iAICh]				
		endif	
	endif
end

// ---------------------------------------------------------------------------------- 
