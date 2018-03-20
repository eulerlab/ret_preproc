// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_ScanPathFuncs.ipf
//	Author		: Thomas Euler, Luke Rogerson
//	Copyright	: (C) MPImF/Heidelberg, CIN/Uni Tübingen 2009-2017
//	History		: 2010-10-22 	Creation
//	             2016-02-08	Added XYZScan1, allowing vertical slice scans
//				  2016-05-23	Added a simple line scan option 	
//				  2016-05-31	Started adding arbitrary trajectories
//				  2016-08-23	Cleaned up a bit, fixed the problem of multiple output
//								buffers per frame and added frame aspect ratio	  		
//				  2017-01-30	- Removing unused scan path functions		
//								- Added tht possibility to define external scan path
//								  functions that are loaded from files
//
// ----------------------------------------------------------------------------------
#pragma rtGlobals=1		// Use modern global access method.

#ifndef ScM_ipf_present
constant 	ScM_TTLlow				= 0
constant 	ScM_TTLhigh				= 5	

constant	SCM_indexScannerX		= 0        
constant	SCM_indexScannerY		= 1        
constant	SCM_indexLaserBlk		= 2        
constant	SCM_indexLensZ			= 3        
	
constant	SCM_PixDataResorted	= 0	
constant	SCM_PixDataDecoded		= 1
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
function 	XYZScan1 (wFuncParams)
	wave		wFuncParams

	variable	dx, dxScan, dy, nPntsTotal, nPntsRetrace, nB, iY, iB, iP
	variable	nPntsLineOffs
	variable	xVMax, yVMax, nStimPerFr 
	variable 	dz, nZPntsRetrace, nZPntsLineOffs, usesZFastScan
	variable	dzScan, zVMax, iZ, lastVZ, iZFract, corr, direct
	
	nPntsTotal		= wFuncParams[0]	// = d_*dy *nStimPerFr
	dx				= wFuncParams[1]	// including nPntsRetrace
	dy				= wFuncParams[2]	
	dz				= wFuncParams[3]		
	nPntsRetrace	= wFuncParams[4]	// # of points per line used for retrace	
	nZPntsRetrace	= wFuncParams[5]
	nPntsLineOffs	= wFuncParams[6]	// # of points per line before pixels are aquired
	nZPntsLineOffs	= wFuncParams[7]
	usesZFastScan	= wFuncParams[7]	// 0=x, 1=z as fast scanner
	nStimPerFr		= wFuncParams[8]	// # of stimulus buffers per frame

	if(usesZFastScan)
		dzScan		= dz -nZPntsRetrace -nZPntsLineOffs
		if(dz > dy)
			zVMax	= 0.5
			yVMax	= dy/dzScan /2
		else	 
			zVMax	= dzScan/dy /2
			yVMax	= 0.5
		endif	
	
		Make/O/N=(nPntsTotal) StimX, StimY, StimPC, StimZ
		StimPC		= ScM_TTLlow	
		StimX		= 0
	
		for(iY=0; iY<dy; iY+=1)
			// Define scan points
			//
			for(iZ=0; iZ<dz; iZ+=1)
				if(iZ < nZPntsLineOffs)
					if(iY == 0)
						StimY[iY*dz +iZ]	= -yVMax *(iZ /nZPntsLineOffs)
					else 
						StimY[iY*dz +iZ]	= 2*yVMax *(iY/(dy -1)) -yVMax			
					endif	
					corr					= (zVMax*nZPntsLineOffs/dz) *((nZPntsLineOffs -mod(iZ, dz) -1)/nZPntsLineOffs)^2
					direct					= (mod(iY, 2)*2 -1)
					StimZ[iY*dz +iZ]		= direct *((2*zVMax *iZ/(dz-1) -zVMax) +corr)

				elseif(iZ < nZPntsLineOffs +dzScan)
					StimY[iY*dz +iZ]		= 2*yVMax *(iY/(dy -1)) -yVMax			
					StimZ[iY*dz +iZ]		= (mod(iY, 2)*2 -1) *(2*zVMax *iZ/(dz-1) -zVMax)

				else
					if(iY < (dy-1))
						StimY[iY*dz +iZ]	= 2*yVMax *(iY/(dy -1)) -yVMax			
					else
						// Last line, thus slow scanner (Y) needs to go back to 
						// starting position
						//
						iZFract				= (iZ -nZPntsLineOffs -dzScan) /nZPntsRetrace
						StimY[iY*dz +iZ]	= yVMax *(1 -iZFract) 
					endif	
					corr					= (zVMax*nZPntsRetrace/dz) *((nZPntsRetrace +mod(iZ, dz) -dz) /nZPntsRetrace)^2
					direct					= (mod(iY, 2)*2 -1)
					StimZ[iY*dz +iZ]		= direct *((2*zVMax *iZ/(dz-1) -zVMax) -corr)
				endif
				
				if((iZ >= nZPntsLineOffs) && (iZ < nZPntsLineOffs +dzScan))
					StimPC[iY*dz +iZ]	= ScM_TTLhigh
				endif	
			endfor
		endfor
		// Only positive values allowed for lens driver
		//
		StimZ	+= zVMax
		
		nB		= nPntsTotal/nStimPerFr
		for(iB=1; iB<nStimPerFr; iB+=1)
			iP	= nB*iB
			StimX[iP, iP+nB-1]  		= StimX[p-iP]	
			StimY[iP, iP+nB-1]  		= StimY[p-iP]
			StimZ[iP, iP+nB-1]  		= StimZ[p-iP]			
			StimPC[iP, iP+nB-1] 		= StimPC[p-iP]
		endfor
	endif	
end	

// ---------------------------------------------------------------------------------- 	
