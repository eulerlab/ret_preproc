// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_ScanPathFuncs.ipf
//	Author		: Thomas Euler, Luke Rogerson
//	Copyright	: (C) MPImF/Heidelberg, CIN/Uni Tübingen 2009-2018
//	History		: 2010-10-22 	Creation
//	             2016-02-08	Added XYZScan1, allowing vertical slice scans
//				  2016-05-23	Added a simple line scan option 	
//				  2016-05-31	Started adding arbitrary trajectories
//				  2016-08-23	Cleaned up a bit, fixed the problem of multiple output
//								buffers per frame and added frame aspect ratio	  		
//				  2017-01-30	- Removing unused scan path functions		
//								- Added tht possibility to define external scan path
//								  functions that are loaded from files
//				  2018-05-24	Added banana scan parameter (Filip Janiak)
//								Optional: #ifdef isUseBananaScans ... 
//
// ----------------------------------------------------------------------------------
#pragma rtGlobals=1		// Use modern global access method.

#ifndef ScM_ipf_present
constant 		ScM_TTLlow					= 0
constant 		ScM_TTLhigh					= 5	

constant		SCM_indexScannerX			= 0        
constant		SCM_indexScannerY			= 1        
constant		SCM_indexLaserBlk			= 2        
constant		SCM_indexLensZ				= 3        
	
constant		SCM_PixDataResorted		= 0	
constant		SCM_PixDataDecoded			= 1

strconstant		SCM_ScanSeqParamWaveName	= "wScanSeqParams"
strconstant		SCM_ScanWarpParamWaveName	= "wScanWarpParams"
constant		SCM_ScanWarpParamWaveLen	= 13

constant		SCM_warpMode_None			= 0
constant		SCM_warpMode_Banana		= 1
constant		SCM_warpMode_Sector		= 2
constant		SCM_warpMode_gap			= 3
constant		SCM_warpMode_zBiCorrect	= 4
constant		SCM_warpMode_last			= 5
#endif

// ----------------------------------------------------------------------------------
function	ScM_ScanPathProtoFunc (wScanPathFuncParams)
	wave	wScanPathFuncParams
end

function 	ScM_ScanPathPrepDecodeProtoFunc (wFr, wScanPathFuncParams)
	wave 	wFr, wScanPathFuncParams
end	

function 	ScM_ScanPathDecodeProtoFunc (wFr, wFrAv, wIn, sCurrConfPath, wParams)
	wave 	wFr, wFrAv, wIn
	string	sCurrConfPath
	wave  	wParams
end

// ----------------------------------------------------------------------------------
// ##########################
// 2017-01-30 ADDED TE ==>
//
function	ScM_LoadExternalScanPathFuncs ()

	string		sFName, sFList, sDF
	variable	nFiles, jF

	// Create path to folder that contains additional scan function .ipf 
	// (in \UserProcedures\ScanM)
	//
	string		sPath	= SpecialDirPath(SCMIO_IgorProUserFilesStr, 0, 0, 0)
	NewPath/Q/O scmScanPathFuncs, (sPath +SCMIO_ScanPathFuncFilesStr)

	// Get a list of all .ipf files in that directory
	//
	sFList		= IndexedFile(scmScanPathFuncs, -1,".ipf")	
	nFiles		= 0
	for(jF=0; jF<ItemsInList(sFList); jF+=1)
		sFName	= StringFromList(jF, sFList)
		if(StringMatch(sFName, SCMIO_ScanPathFuncFileMask))
			// Add file as an #include and recompile
			//
			sFName	= sFName[0,strlen(sFName) -5]
			sDF		= sFName[5,INF]
			Execute/P/Q/Z "INSERTINCLUDE \"" +sFName +"\""		
			nFiles	+= 1
		endif	
	endfor	
	if(nFiles > 0)
		Execute/P/Q/Z "COMPILEPROCEDURES "	
		printf "### %d external scan path function files found and loaded\r", nFiles
	endif
end
// <==	

// ----------------------------------------------------------------------------------
function	ScM_callScanPathFunc (sFunc)
	string		sFunc
	
	variable	j, n

	n	= ItemsInList(sFunc, "|")
	if((strlen(sFunc) > 0) && (n >= 2))
		Make/O/N=(n-1) wScanPathFuncParams
		for(j=1; j<n; j+=1)
			wScanPathFuncParams[j-1]		= str2num(StringFromList(j, sFunc, "|"))
		endfor	
		FUNCREF ScM_ScanPathProtoFunc f	= $(StringFromList(0, sFunc, "|"))
		f(wScanPathFuncParams)
	endif	
end	

// ---------------------------------------------------------------------------------- 
// X-Y image scans
// ---------------------------------------------------------------------------------- 
function 	XYScan2 (wFuncParams)
	wave		wFuncParams

	variable	dx, dxScan, dy, nPntsTotal, nPntsRetrace, iX, iY
	variable	yInc1, xInc1, yInc2, xInc2, yVLastLine, nPntsLineOffs
	variable	xVMax, yVMax, noYScan, aspectRatioFr
	
	nPntsTotal		= wFuncParams[0]	// = dx*dy
	dx				= wFuncParams[1]	// including nPntsRetrace
	dy				= wFuncParams[2]	
	nPntsRetrace	= wFuncParams[3]	// # of points per line used for retrace	
	nPntsLineOffs	= wFuncParams[4]	// # of points per line before pixels are aquired
										// (for allowing the scanner to "settle")
	noYScan       	= wFuncParams[5]	// if 1 deactivates y scanner
	aspectRatioFr	= wFuncParams[6]	// aspect ratio of frame		
								
	dxScan			= dx -nPntsRetrace
	if(dx > dy)
		xVMax		= 0.5
		yVMax		= dy/(dxScan *aspectRatioFr) /2
	else	 
		xVMax		= (dxScan *aspectRatioFr)/dy /2
		yVMax		= 0.5
	endif	
	xInc1			= 2*xVMax /(nPntsRetrace +1)
	yInc1			= 2*yVMax /(dy-1) /(nPntsRetrace +1)
	
	yInc2			= 2*yVMax /((nPntsRetrace +1) *2)
	xInc2			= xInc1 /2
	
	Make/O/N=(nPntsTotal) StimX, StimY, StimPC, StimZ
	StimPC			= ScM_TTLlow	
	StimZ			= 0
	
	for(iY=0; iY<dy; iY+=1)
		// Define scan points
		//
		for(iX=0; iX<dxScan; iX+=1)
			StimX[iY*dx +iX]		= 2*xVMax *iX/(dxScan -1) -xVMax
			StimY[iY*dx +iX]		= 2*yVMax *(iY/(dy -1)) -yVMax				
			if(iX >= nPntsLineOffs)
				StimPC[iY*dx +iX]	= ScM_TTLhigh
			endif	
		endfor
		if(nPntsRetrace <= 0)		
			continue
		endif	
		yVLastLine					= StimY[iY*dx +dxScan -1] 	
		
		// Define retrace points, if there is a retrace section
		// 
		if(iY < (dy-1))
			// Is not yet last line, thus line retrace
			//
			for(iX=dxScan; iX<dx; iX+=1)
				StimX[iY*dx +iX]	= xVMax -xInc1 *(ix -dxScan +1)
				StimY[iY*dx +iX]	= yVLastLine +yInc1 *(ix -dxScan +1)
			endfor
		else
			// Last line, thus retrace needs to go back to starting position
			//
			for(iX=dxScan; iX<dx; iX+=1)
				StimX[iY*dx +iX]	= xVMax -xInc2 *(ix -dxScan +1)
				StimY[iY*dx +iX]	= yVLastLine -yInc2 *(ix-dxScan +1)
			endfor
		endif	
	endfor	
	if(noYScan == 1)
		StimY = 0
	endif	
	
#ifdef isUseBananaScans	
	// ##########################
	// 2018-06-08 ADDED TE ==>
	//
	Warp(StimX, StimY, wFuncParams, xVMax, yVMax, "XYScan2")
	// <==
#endif
end	

// ---------------------------------------------------------------------------------- 
function 	XYScan3 (wFuncParams)
	wave		wFuncParams

	variable	dx, dxScan, dy, nPntsTotal, nPntsRetrace, iX, iY, iB, iP, nB
	variable	yInc1, xInc1, yInc2, xInc2, yVLastLine, nPntsLineOffs
	variable	xVMax, yVMax, nStimPerFr, noYScan, aspectRatioFr
	
	nPntsTotal		= wFuncParams[0]	// = dx*dy *nStimPerFr
	dx				= wFuncParams[1]	// including nPntsRetrace
	dy				= wFuncParams[2]	
	nPntsRetrace	= wFuncParams[3]	// # of points per line used for retrace	
	nPntsLineOffs	= wFuncParams[4]	// # of points per line before pixels are aquired
										// (for allowing the scanner to "settle")
	noYScan     	= wFuncParams[5]	// if 1 deactivates y scanner
	aspectRatioFr	= wFuncParams[6]	// aspect ratio of frame		
	nStimPerFr		= wFuncParams[7]	// # of stimulus buffers per frame
										
	dxScan			= dx -nPntsRetrace
	if(dx > dy)
		xVMax		= 0.5
		yVMax		= dy/(dxScan *aspectRatioFr) /2
	else	 
		xVMax		= (dxScan *aspectRatioFr)/dy /2
		yVMax		= 0.5
	endif	
	
	xInc1			= 2*xVMax /(nPntsRetrace +1)
	yInc1			= 2*yVMax /(dy-1) /(nPntsRetrace +1)
	
	yInc2			= 2*yVMax /((nPntsRetrace +1) *2)
	xInc2			= xInc1 /2
	
	Make/O/N=(nPntsTotal) StimX, StimY, StimPC, StimZ
	StimPC			= ScM_TTLlow	
	StimZ			= 0
	
	for(iY=0; iY<dy; iY+=1)
		// Define scan points
		//
		for(iX=0; iX<dxScan; iX+=1)
			StimX[iY*dx +iX]		= 2*xVMax *iX/(dxScan -1) -xVMax
			StimY[iY*dx +iX]		= 2*yVMax *(iY/(dy -1)) -yVMax	
			if(iX >= nPntsLineOffs)
				StimPC[iY*dx +iX]	= ScM_TTLhigh
			endif	
		endfor
		if(nPntsRetrace <= 0)		
			continue
		endif	
		yVLastLine					= StimY[iY*dx +dxScan -1] 	
		
		// Define retrace points, if there is a retrace section
		// 
		if(iY < (dy-1))
			// Is not yet last line, thus line retrace
			//
			for(iX=dxScan; iX<dx; iX+=1)
				StimX[iY*dx +iX]	= xVMax -xInc1 *(ix -dxScan +1)
				StimY[iY*dx +iX]	= yVLastLine +yInc1 *(ix -dxScan +1)
			endfor
		else
			// Last line, thus retrace needs to go back to starting position
			//
			for(iX=dxScan; iX<dx; iX+=1)
				StimX[iY*dx +iX]	= xVMax -xInc2 *(ix -dxScan +1)
				StimY[iY*dx +iX]	= yVLastLine -yInc2 *(ix-dxScan +1)
			endfor
		endif	
	endfor	
	
#ifdef isUseBananaScans	
	// ##########################
	// 2018-06-08 ADDED TE ==>
	//
	Warp(StimX, StimY, wFuncParams, xVMax, yVMax, "XYScan2")
	// <==
#endif
	
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
end	

// ---------------------------------------------------------------------------------- 
// XYZ scans (slices)
// ---------------------------------------------------------------------------------- 
//function 	XYZScan1 (wFuncParams)
//	wave		wFuncParams
//
//	variable	dx, dxScan, dy, nPntsTotal, nPntsRetrace, nB, iY, iB, iP
//	variable	nPntsLineOffs
//	variable	xVMax, yVMax, nStimPerFr 
//	variable 	dz, nZPntsRetrace, nZPntsLineOffs, usesZFastScan
//	variable	dzScan, zVMax, iZ, lastVZ, iZFract, corr, direct
//	
//	nPntsTotal		= wFuncParams[0]	// = d_*dy *nStimPerFr
//	dx				= wFuncParams[1]	// including nPntsRetrace
//	dy				= wFuncParams[2]	
//	dz				= wFuncParams[3]		
//	nPntsRetrace	= wFuncParams[4]	// # of points per line used for retrace	
//	nZPntsRetrace	= wFuncParams[5]
//	nPntsLineOffs	= wFuncParams[6]	// # of points per line before pixels are aquired
//	nZPntsLineOffs	= wFuncParams[7]
//	usesZFastScan	= wFuncParams[7]	// 0=x, 1=z as fast scanner
//	nStimPerFr		= wFuncParams[8]	// # of stimulus buffers per frame
//
//	if(usesZFastScan)
//		dzScan		= dz -nZPntsRetrace -nZPntsLineOffs
//		if(dz > dy)
//			zVMax	= 0.5
//			yVMax	= dy/dzScan /2
//		else	 
//			zVMax	= dzScan/dy /2
//			yVMax	= 0.5
//		endif	
//	
//		Make/O/N=(nPntsTotal) StimX, StimY, StimPC, StimZ
//		StimPC		= ScM_TTLlow	
//		StimX		= 0
//	
//		for(iY=0; iY<dy; iY+=1)
//			// Define scan points
//			//
//			for(iZ=0; iZ<dz; iZ+=1)
//				if(iZ < nZPntsLineOffs)
//					if(iY == 0)
//						StimY[iY*dz +iZ]	= -yVMax *(iZ /nZPntsLineOffs)
//					else 
//						StimY[iY*dz +iZ]	= 2*yVMax *(iY/(dy -1)) -yVMax			
//					endif	
//					corr					= (zVMax*nZPntsLineOffs/dz) *((nZPntsLineOffs -mod(iZ, dz) -1)/nZPntsLineOffs)^2
//					direct					= (mod(iY, 2)*2 -1)
//					StimZ[iY*dz +iZ]		= direct *((2*zVMax *iZ/(dz-1) -zVMax) +corr)
//
//				elseif(iZ < nZPntsLineOffs +dzScan)
//					StimY[iY*dz +iZ]		= 2*yVMax *(iY/(dy -1)) -yVMax			
//					StimZ[iY*dz +iZ]		= (mod(iY, 2)*2 -1) *(2*zVMax *iZ/(dz-1) -zVMax)
//
//				else
//					if(iY < (dy-1))
//						StimY[iY*dz +iZ]	= 2*yVMax *(iY/(dy -1)) -yVMax			
//					else
//						// Last line, thus slow scanner (Y) needs to go back to 
//						// starting position
//						//
//						iZFract				= (iZ -nZPntsLineOffs -dzScan) /nZPntsRetrace
//						StimY[iY*dz +iZ]	= yVMax *(1 -iZFract) 
//					endif	
//					corr					= (zVMax*nZPntsRetrace/dz) *((nZPntsRetrace +mod(iZ, dz) -dz) /nZPntsRetrace)^2
//					direct					= (mod(iY, 2)*2 -1)
//					StimZ[iY*dz +iZ]		= direct *((2*zVMax *iZ/(dz-1) -zVMax) -corr)
//				endif
//				
//				if((iZ >= nZPntsLineOffs) && (iZ < nZPntsLineOffs +dzScan))
//					StimPC[iY*dz +iZ]	= ScM_TTLhigh
//				endif	
//			endfor
//		endfor
//		// Only positive values allowed for lens driver
//		//
//		StimZ	+= zVMax
//		
//		nB		= nPntsTotal/nStimPerFr
//		for(iB=1; iB<nStimPerFr; iB+=1)
//			iP	= nB*iB
//			StimX[iP, iP+nB-1]  		= StimX[p-iP]	
//			StimY[iP, iP+nB-1]  		= StimY[p-iP]
//			StimZ[iP, iP+nB-1]  		= StimZ[p-iP]			
//			StimPC[iP, iP+nB-1] 		= StimPC[p-iP]
//		endfor
//	endif	
//end	

// ==================================================================================
// Parmeterized warping of XY scans 
// ---------------------------------------------------------------------------------- 
// ##########################
// 2018-06-08 ADDED TE ==>
//
function 	Warp (StimX, StimY, wFuncParams, xVMax, yVMax, scanPFName)
	wave		StimX, StimY, wFuncParams
	variable	xVMax, yVMax
	string		scanPFName
	
	variable	iX, iLn, dx, dLn, dxScan_wOffs, dxScan, nPntsRetrace, nPntsLineOffs
	variable	sinParam
	variable	angRange_deg, dx_V, dLn_V, nBuf, rOffs_V, rCentre_V
	variable	dAng_deg, ang0_deg, ang_rad, r0_V, r_V, ang_deg
	variable	nPnts, xV, lnV, xVd, lnVd, iEnd, nEnds, iPnt, i0, i1
	variable	startLn, nLnsk
	variable	ln0Corr, nLnCorr, x0, x1, VOffs1, VOffs2, dV, VOffs3
//	string		sPath 			= ScM_getCurrConfigPathStr()
//	WAVE 		pwWarpParams	= $(sPath +SCM_ScanWarpParamWaveName)
	WAVE 		pwWarpParams	= $(SCM_ScanWarpParamWaveName)
	variable 	nn
	
	if(!WaveExists(pwWarpParams))
		print "### Warping parameters not applied when loading recorded data ..."
		return -1
	endif	
	
	if(pwWarpParams[%warpMode] ==	SCM_warpMode_None)
		// Nothing to do
		//
		return 0
	endif		
	
	// Get some parameters
	//
	if(WhichListItem(scanPFName, "XYScan2;XYScan2") >= 0)
		dx				= wFuncParams[1]	
		dLn				= wFuncParams[2]	
		nPntsRetrace	= wFuncParams[3]	
		nPntsLineOffs	= wFuncParams[4]
		dxScan_wOffs	= dx -nPntsRetrace
		dxScan			= dx -nPntsRetrace -nPntsLineOffs
		
	elseif(WhichListItem(scanPFName, "xzSlice;xzBiSlice") >= 0)
		dx				= wFuncParams[1]	
		dLn				= wFuncParams[3]	// cp.dZPixels
		nPntsRetrace	= wFuncParams[4]	
		nPntsLineOffs	= wFuncParams[5]
		dxScan_wOffs	= dx -nPntsRetrace
		dxScan			= dx -nPntsRetrace -nPntsLineOffs
//	nPntsTotal		= wScanPathFuncParams[0]	// = dx*dy*dz *nStimPerFr
//	dX				= wScanPathFuncParams[1]	// cp.dXPixels
//	dZTotal			= wScanPathFuncParams[3]	// cp.dZPixels
//	nPntsRetrace   = wScanPathFuncParams[4]	// cp.nPixRetrace, # of points per line used for retrace	
//	nPntsLineOffs	= wScanPathFuncParams[5]	// cp.nXPixLineOffs, # of points per line before pixels are aquired
////	nPntsLineOffs	= wScanPathFuncParams[6]	// cp.nYPixLineOffs, ...
////	nPntsLineOffs	= wScanPathFuncParams[7]	// cp.nZPixLineOffs, ...
//	aspectRatioFr	= wScanPathFuncParams[8]	// cp.aspectRatioFrame
////	iChFastScan		= wScanPathFuncParams[9]	// cp.iChFastScan
//	zVMinDef		= wScanPathFuncParams[10]	// cp.minDefAO_Lens_V
//	zVMaxDef		= wScanPathFuncParams[11]	// cp.maxDefAO_Lens_V
//	nStimPerFr		= wScanPathFuncParams[12]	// cp.stimBufPerFr
//	dxFrDecoded		= wScanPathFuncParams[13]	// cp.dxFrDecoded, frame width for reconstructed/decoded frame
//	dyFrDecoded		= wScanPathFuncParams[14]	// cp.dyFrDecoded, frame height for reconstructed/decoded frame
//	nImgPerFrame	= wScanPathFuncParams[15]	// cp.nImgPerFrame, # of images per frame
	else
		return -2
	endif		

	// Do some warping dependent on mode
	//
	switch (pwWarpParams[%warpMode])
		case SCM_warpMode_Banana	:
			// ##########################	
			// 2018-05-24 ADDED, FKJ ==>
			sinParam	= pwWarpParams[%SinParam]
		
			// Generate sine dependent y-offset
			//
			Make/O/FREE/N=(dxScan_wOffs)	StimYY
			for(iX=0; iX<dxScan_wOffs; iX+=1)
				StimYY[iX]			= sinParam *sin(iX *pi/(dxScan_wOffs -1))
			endfor

			// Add offset to y coordinates
			//
			for(iLn=0; iLn<dLn; iLn+=1)
				for(iX=0; iX<dxScan_wOffs; iX+=1)
					StimY[iLn*dx +iX]	+= StimYY[iX]	
				endfor
			endfor		
			// <==		
			break
		
		
		case SCM_warpMode_Sector	:
			// ##########################	
			// 2018-06-14 ADDED, TE ==>
			//
			rOffs_V			= pwWarpParams[%rOffs_V]
			rCentre_V		= pwWarpParams[%rCentre_V]
			angRange_deg	= pwWarpParams[%angRange_deg]
			if((angRange_deg > 360) || (angRange_deg <= 0))
				angRange_deg	= 360
			endif
			dLn_V		= abs(2*yVMax) /dLn
			nBuf		= dx *dLn

			Make/O/N=(nBuf)	bufX = NaN, bufY = NaN, iBuf = NaN
			Make/O/N=(2 +2*dLn)	wEnds = NaN
			
			// Calculate starting angle and angle increment 
			// (~ former x axis, that is along the scan line)
			//
			dAng_deg	= angRange_deg /(dxScan -1)
		 	ang0_deg	= dAng_deg *dxScan/2 -angRange_deg +(mod(dxScan, 2) -1) *dAng_deg/2

			// Calculate start radius; the radius increment (in V) is already given
			// by the distance between individual scan lines
			// (~ former y axis)	
			//
			r0_V		= rCentre_V +(dLn_V *(dLn -1)/2)

			// Calculate coordinates during the pixel scannig part
			//
			nPnts		= 0
			nEnds		= 1
			r_V			= r0_V
			
			for(iLn=0; iLn<dLn; iLn+=1)
				ang_deg	= ang0_deg	
			//	nn		= 0
		
				for(ix=0; ix<dx; ix+=1)	
					if((ix >= nPntsLineOffs) && (ix < (dxScan +nPntsLineOffs)))
						// Within scanline ...
						//
						ang_rad		= ang_deg/360 *2*Pi
						bufX[nPnts]	= sin(ang_rad) *r_V
						bufY[nPnts]	= cos(ang_rad) *r_V +rOffs_V
						ang_deg		+= dAng_deg		
					endif	
			
					// Note point indices of all scanline beginnings and ends
					//
					if((nEnds < DimSize(wEnds, 0)) && ((ix == nPntsLineOffs) || (ix == (dxScan +nPntsLineOffs -1))))
						wEnds[nEnds]	= nPnts
						nEnds	+= 1
					endif	
			
					iBuf[nPnts]	= nPnts		
					nPnts	+= 1			
				endfor	
				r_V	-= dLn_V
			endfor
			bufX[0]	= 0
			bufY[0]	= 0				
	
			// Start first offset sequence at 0/0 and go after scanline to the 
			// beginning of the first
			//
			wEnds[0]		= 0		
			wEnds[INF]	= wEnds[1] +nBuf
	
			// Calculate points for offset and retrace; so far only simple linear 
			// interpolation is used ...
			// TODO: 	Use some smooth interpolation instead
			//			Ideally we have a function that takes a scanpath where the fixed 
			//			pixel scan segments have been defined and that fills the gap
			// 			between these segments with a smooth path w/o changing the 
			//			already existing data points
			//
			for(iEnd=0; iEnd<nEnds; iEnd+=2)
				nPnts	= wEnds[iEnd+1] -wEnds[iEnd]
				i0		= wEnds[iEnd]
				i1		= wEnds[iEnd+1]
		
				if(i1 > nBuf)
					// The last retrace need to go back to the start of the scanline
					// within the duration of a retrace (w/o offset), therefore deal
					// with this special case
					//
					i1		= mod(i1, nBuf)
					nPnts	= nPntsRetrace
				endif	
		
				// Determine starting coordinates (voltages) before the segment
				// to generate and increments
				//
				xV		= bufX[i0]
				lnV		= bufY[i0]
				xVd		= (bufX[i1] -xV) /nPnts
				lnVd	= (bufY[i1] -lnV) /nPnts
		
				// Interpolate the segment linearly
				//
				for(iPnt=1; iPnt<nPnts; iPnt+=1)
					bufX[iPnt +i0]	= xV +xVd*iPnt
					bufY[iPnt +i0]	= lnV +lnVd*iPnt
				endfor	
			endfor

			// Center ...
			//			
			WaveStats/M=1/Q/R=[1] bufX
			bufX	-= (V_max -V_min)/2 +V_min
			WaveStats/M=1/Q/R=[1] bufY
			bufY	-= (V_max -V_min)/2 +V_min
			
			// Return new stimulus buffers 
			//			
			StimX 	= bufX
			StimY 	= bufY
			// <==	
			break

		case SCM_warpMode_zBiCorrect	:
			// ##########################	
			// 2018-08-25 ADDED, TE ==>
			//
			if(WhichListItem(scanPFName, "xzBiSlice") < 0)
				break
			endif
				
			ln0Corr	= pwWarpParams[%xz_start_lines]
			nLnCorr	= pwWarpParams[%xz_len_lines]
			if((ln0Corr < 0) || (nLnCorr <= 0) || (ln0Corr+nLnCorr > dLn))
				break
			endif	

			VOffs1	= pwWarpParams[%xz_para1]
			VOffs2	= pwWarpParams[%xz_para2]
			VOffs3	= pwWarpParams[%xz_para3]		
		//	... 	= pwWarpParams[%xz_doRepeat]				
			if((VOffs1 == 0) && (VOffs2 == 0) && (VOffs3 == 0))
				break
			endif
			x0	= dx*ln0Corr
			x1	= x0 +dx*nLnCorr -1
			
			if(VOffs3 == 0)			
				if(VOffs1 == VOffs2)
					// one linear offset
					//
					StimY[x0, x1] += VOffs1
				else	
					// differential offsets; probably irrlevant because this changes
					// the corrected frame's magnification
					//
					dV	= (VOffs2 -VOffs1)/nLnCorr
					iLn	= 0
					for(iPnt=x0 -nPntsRetrace; iPnt<=x1-nPntsRetrace; iPnt+=dx)
						StimY[iPnt, iPnt+dx-1]	+= VOffs1 +dV*iLn
						iLn += 1
					endfor	
				endif
			elseif(VOffs1 == VOffs2)
				// add one linear offset and in addition skew each line a tad
				//
				dV	= VOffs3/dx
				for(iPnt=x0 -nPntsRetrace; iPnt<=x1-nPntsRetrace; iPnt+=dx)
					StimY[iPnt, iPnt+dx-1]	+= VOffs1
					for(ix=0; ix<dx; ix+=1)
						StimY[iPnt+ix]	+= dV*ix
					endfor
				endfor	
			else
				printf "### WARNING: NOT YET IMPLEMENTED\r"
			endif
			break
			// <==
			
		case SCM_warpMode_gap	:
			// ##########################	
			// 2018-07-09 ADDED, TE ==>
			//
//			startLn	= pwWarpParams[%start_lines]
//			nLns 	= pwWarpParams[%len_lines]
//			if(startLn >= dLn-1)
//				return -3
//			endif
//			dLn_V		= abs(2*yVMax) /dLn
//			i0			= startLn *dx
//			StimY[i0,INF]	+= dLn_V *nLns
			// <==	
			break
			
	endswitch			
end	

// ---------------------------------------------------------------------------------- 	
function 	createWarpParamWave (sValList)
	string		sValList

	variable	iStr, iItem
	string		sEntry, sKey

	if(!WaveExists($(SCM_ScanWarpParamWaveName)))
		// Create wave for warp parameters, ...
		//
		Make/O/S/N=(SCM_ScanWarpParamWaveLen) $(SCM_ScanWarpParamWaveName) = 0
		wave pwScWarpP	= $(SCM_ScanWarpParamWaveName)
		SetDimLabel 0,0, warpMode,		pwScWarpP	// 0=None, 1=Banana, 2=sector warp, ...		
		SetDimLabel 0,1, SinParam,		pwScWarpP	// for "Banana" ...
		SetDimLabel 0,2, rCentre_V,		pwScWarpP	// for sector warp ...
		SetDimLabel 0,3, rOffs_V,			pwScWarpP	//
		SetDimLabel 0,4, angRange_deg,	pwScWarpP	//
		SetDimLabel 0,5, start_lines,		pwScWarpP	// for gap ...
		SetDimLabel 0,6, len_lines,		pwScWarpP	//
		SetDimLabel 0,7, xz_start_lines,	pwScWarpP	// for x-z bi correction ...
		SetDimLabel 0,8, xz_len_lines,	pwScWarpP	//
		SetDimLabel 0,9, xz_doRepeat,		pwScWarpP	//
		SetDimLabel 0,10, xz_para1,		pwScWarpP	//						
		SetDimLabel 0,11, xz_para2,		pwScWarpP	//								
		SetDimLabel 0,12, xz_para3,		pwScWarpP	//										
	else
		WAVE pwScWarpP	= $(SCM_ScanWarpParamWaveName)
	endif
	
	if(strlen(sValList) > 0)
		// Fill wave entries from string list
		//
		for(iStr=0; iStr<ItemsInList(sValList, SCMIO_subEntrySep); iStr+=1)
			sEntry	= StringFromList(iStr, sValList, SCMIO_subEntrySep)
			sKey	= StringFromList(0, sEntry, SCMIO_keySubValueSep)
			if(strlen(sKey) > 0)
				iItem	= FindDimLabel(pwScWarpP, 0, sKey)
				if(iItem >= 0)
					pwScWarpP[iItem]	= Str2Num(StringFromList(1, sEntry, SCMIO_keySubValueSep))
				//	print sEntry
				endif	
			endif	
		endfor
	endif
end
// <==
// ---------------------------------------------------------------------------------- 	
