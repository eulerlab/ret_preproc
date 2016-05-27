// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_ScanPathFuncs.ipf
//	Author		: Thomas Euler, Tom Baden, Le Chang
//	Copyright	: (C) MPImF/Heidelberg, CIN/Uni Tübingen 2009-2016
//	History		: 2010-10-22 	Creation
//	             2016-02-08	Added XYZScan1, allowing vertical slice scans
//				  2016-05-23	Added a simple line scan option 	
//
// ----------------------------------------------------------------------------------
#pragma rtGlobals=1		// Use modern global access method.

#ifndef ScM_ipf_present
constant 	ScM_TTLlow		= 0
constant 	ScM_TTLhigh	= 5	
#endif

// ----------------------------------------------------------------------------------
function	ScM_callScanPathFunc (sFunc)
	string		sFunc
	
	variable	j, n

	n	= ItemsInList(sFunc, "|")
	if((strlen(sFunc) > 0) && (n >= 2))
		Make/O/N=(n-1) wFuncParams
		for(j=1; j<n; j+=1)
			wFuncParams[j-1]				= str2num(StringFromList(j, sFunc, "|"))
		endfor	
		FUNCREF ScM_ScanPathProtoFunc f	= $(StringFromList(0, sFunc, "|"))
		f(wFuncParams)
	endif	
end	

function	ScM_ScanPathProtoFunc (w)
	wave		w
end
	
// ==================================================================================
// Spiral scan path, version 1
//
// Number of points = Npoints, excluding the flyback
// Totalsize = Numerical diameter of the spiral (50 gives  +25 to -25)
// Separation = Scale factor to change the speed of the spiral - Higher number gives 
// ...lower speed. This is used to alter the separation between spiral lines
// Flyback = Number of points used in flyback
// ----------------------------------------------------------------------------------
function 	SpiralScan1 (wFuncParams)
wave		wFuncParams

Variable 	NumberofPoints, Totalsize, separation, flyback
Variable 	jj ,tt, zz, cc, ttt, ff
Variable 	Xmax, Ymax, angle

NumberofPoints	= wFuncParams[0]
Totalsize		= wFuncParams[1]
separation		= wFuncParams[2]
flyback			= wFuncParams[3]

NumberofPoints	+= Flyback

//make /o /n=60000 			Lookuptable = 0
make /o /n=600000 				Lookuptable = 0
make /o /n=(NumberofPoints) 	Lookuptable2 = 0
make /o /n=(NumberofPoints) 	StimX = 0
make /o /n=(NumberofPoints) 	StimY = 0

LookupTable[]=p/1000*(1+(p/1000)^2)^0.5 + ln((p/1000)+(1+(p/1000)^2)^0.5)
	
cc = 1	
	
for (zz=0;zz< (NumberofPoints);zz+=1)
	do
		cc+=1
	while (Lookuptable[cc]<zz)

	LookupTable2[zz]	= cc/separation
	
	StimX[zz+1]		= Lookuptable2[zz]*cos(Lookuptable2[zz])
	StimY[zz+1]		= Lookuptable2[zz]*sin(Lookuptable2[zz])
endfor  

Xmax	= wavemax(StimX)
Ymax	= wavemax(StimY)

StimX	/=Xmax
StimX	*=Totalsize/2

StimY	/=Ymax
StimY	*=Totalsize/2

for (ff=0;ff< (flyback);ff+=1)

	angle 						= ff/flyback * pi / 2
	StimX[Numberofpoints-ff]	*=sin(angle)
	StimY[Numberofpoints-ff]	*=sin(angle)
	
	//SpiralX[Numberofpoints-ff]*=(ff)^0.5/(flyback)^0.5
	//SpiralY[Numberofpoints-ff]*=(ff)^0.5/(flyback)^0.5
endfor

KillWaves/Z LookupTable2, Lookuptable
end
 
// ---------------------------------------------------------------------------------- 
// X-Y image scans
// ---------------------------------------------------------------------------------- 
function 	XYScan1 (wFuncParams)
	wave		wFuncParams

	variable	dx, dy, j, nPntsTotal
	
	nPntsTotal		= wFuncParams[0]	
	dx				= wFuncParams[1]
	dy				= wFuncParams[2]	
	Make/O/N=(nPntsTotal) StimX, StimY
	
	for(j=0; j<nPntsTotal; j+=1)					
		StimX[j]	= mod(j, dx)/dx -0.5	
		StimY[j] 	= (j /dx)/dy -0.5		
	endfor	
end	

// ---------------------------------------------------------------------------------- 
function 	XYScan2 (wFuncParams)
	wave		wFuncParams

	variable	dx, dxScan, dy, nPntsTotal, nPntsRetrace, iX, iY
	variable	yInc1, xInc1, yInc2, xInc2, yVLastLine, nPntsLineOffs
	variable	xVMax, yVMax, noYScan
	
	nPntsTotal		= wFuncParams[0]	// = dx*dy
	dx				= wFuncParams[1]	// including nPntsRetrace
	dy				= wFuncParams[2]	
	nPntsRetrace	= wFuncParams[3]	// # of points per line used for retrace	
	nPntsLineOffs	= wFuncParams[4]	// # of points per line before pixels are aquired
										// (for allowing the scanner to "settle")
	noYScan        = wFuncParams[5]										
	dxScan			= dx -nPntsRetrace
	if(dx > dy)
		xVMax		= 0.5
		yVMax		= dy/dxScan /2
	else	 
		xVMax		= dxScan/dy /2
		yVMax		= 0.5
	endif	
	xInc1			= 2*xVMax /(nPntsRetrace +1)
	yInc1			= 2*yVMax /(dy-1) /(nPntsRetrace +1)
	
	yInc2			= 2*yVMax /((nPntsRetrace +1) *2)
	xInc2			= xInc1 /2
//	xInc2			= 2*xVMax /((nPntsRetrace -1)	*2)
	
	Make/O/N=(nPntsTotal) StimX, StimY, StimPC
	StimPC			= ScM_TTLlow	
	
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
	variable	xVMax, yVMax, nStimPerFr
	
	nPntsTotal		= wFuncParams[0]	// = dx*dy *nStimPerFr
	dx				= wFuncParams[1]	// including nPntsRetrace
	dy				= wFuncParams[2]	
	nPntsRetrace	= wFuncParams[3]	// # of points per line used for retrace	
	nPntsLineOffs	= wFuncParams[4]	// # of points per line before pixels are aquired
										// (for allowing the scanner to "settle")
	nStimPerFr		= wFuncParams[5]	// # of stimulus buffers per frame
										
	dxScan			= dx -nPntsRetrace
	if(dx > dy)
		xVMax		= 0.5
		yVMax		= dy/dxScan /2
	else	 
		xVMax		= dxScan/dy /2
		yVMax		= 0.5
	endif	
	xInc1			= 2*xVMax /(nPntsRetrace +1)
	yInc1			= 2*yVMax /(dy-1) /(nPntsRetrace +1)
	
	yInc2			= 2*yVMax /((nPntsRetrace +1) *2)
	xInc2			= xInc1 /2
	
	Make/O/N=(nPntsTotal) StimX, StimY, StimPC
	StimPC			= ScM_TTLlow	
	
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
end	

// ---------------------------------------------------------------------------------- 
//function 	XYScan4 (wFuncParams)
//	wave		wFuncParams
//
//	variable	dx, dxScan, dy, nPntsTotal, nPntsRetrace, iX, iY, iB, iP, nB
//	variable	yInc1, xInc1, yInc2, xInc2, yVLastLine, nPntsLineOffs
//	variable	xVMax, yVMax, nStimPerFr
//	variable	nPixPerGenLockPulse
//	
//	nPntsTotal		= wFuncParams[0]	// = dx*dy *nStimPerFr
//	dx				= wFuncParams[1]	// including nPntsRetrace
//	dy				= wFuncParams[2]	
//	nPntsRetrace	= wFuncParams[3]	// # of points per line used for retrace	
//	nPntsLineOffs	= wFuncParams[4]	// # of points per line before pixels are aquired
//										// (for allowing the scanner to "settle")
//	nStimPerFr		= wFuncParams[5]	// # of stimulus buffers per frame
//										
//	dxScan			= dx -nPntsRetrace
//	if(dx > dy)
//		xVMax		= 0.5
//		yVMax		= dy/dxScan /2
//	else	 
//		xVMax		= dxScan/dy /2
//		yVMax		= 0.5
//	endif	
//	xInc1			= 2*xVMax /(nPntsRetrace +1)
//	yInc1			= 2*yVMax /(dy-1) /(nPntsRetrace +1)
//	
//	yInc2			= 2*yVMax /((nPntsRetrace +1) *2)
//	xInc2			= xInc1 /2
//	
//	Make/O/N=(nPntsTotal) StimX, StimY, StimPC, StimGenLock
//	StimPC			= ScM_TTLlow	
//	StimGenLock		= ScM_TTLlow
//	
//	for(iY=0; iY<dy; iY+=1)
//		// Define scan points
//		//
//		for(iX=0; iX<dxScan; iX+=1)
//			StimX[iY*dx +iX]		= 2*xVMax *iX/(dxScan -1) -xVMax
//			StimY[iY*dx +iX]		= 2*yVMax *(iY/(dy -1)) -yVMax				
//			if(iX >= nPntsLineOffs)
//				StimPC[iY*dx +iX]	= ScM_TTLhigh
//			endif	
//		endfor
//		if(nPntsRetrace <= 0)		
//			continue
//		endif	
//		yVLastLine					= StimY[iY*dx +dxScan -1] 	
//		
//		// Define retrace points, if there is a retrace section
//		// 
//		if(iY < (dy-1))
//			// Is not yet last line, thus line retrace
//			//
//			for(iX=dxScan; iX<dx; iX+=1)
//				StimX[iY*dx +iX]	= xVMax -xInc1 *(ix -dxScan +1)
//				StimY[iY*dx +iX]	= yVLastLine +yInc1 *(ix -dxScan +1)
//			endfor
//		else
//			// Last line, thus retrace needs to go back to starting position
//			//
//			for(iX=dxScan; iX<dx; iX+=1)
//				StimX[iY*dx +iX]	= xVMax -xInc2 *(ix -dxScan +1)
//				StimY[iY*dx +iX]	= yVLastLine -yInc2 *(ix-dxScan +1)
//			endfor
//		endif	
//		
//		// Define genlock-sync pulse every 8 lines
//		//
//		if(nPixPerGenLockPulse > 0)
//			nPixPerGenLockPulse -= 1
//			if(nPixPerGenLockPulse == 0)
//				StimGenLock[iY*dx +iX]	= ScM_TTLlow
//			endif
//		endif	
//		if(mod(iY, 8) == 0)
//			StimGenLock[iY*dx +iX]	= ScM_TTLhigh
//			nPixPerGenLockPulse  = 5
//		endif	
//	endfor	
//	
//	nB		= nPntsTotal/nStimPerFr
//	for(iB=1; iB<nStimPerFr; iB+=1)
//		iP	= nB*iB
//		StimX[iP, iP+nB-1]  		= StimX[p-iP]	
//		StimY[iP, iP+nB-1]  		= StimY[p-iP]
//		StimPC[iP, iP+nB-1] 		= StimPC[p-iP]
//		StimGenLock[iP, iP+nB-1] 	= StimGenLock[p-iP]
//	endfor
//end	

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
					//	if(iZ == (nZPntsLineOffs +dzScan +1))
					//		lastVZ	   		= StimZ[iY*dz +iZ -1]
					//	endif	
						iZFract				= (iZ -nZPntsLineOffs -dzScan) /nZPntsRetrace
						StimY[iY*dz +iZ]	= yVMax *(1 -iZFract) 
					//	StimZ[iY*dz +iZ]	= lastVZ *(1 -iZFract)
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
// ##########################		
// 2016-02-11 ADDED, TE ==>
//
function	XYZScan1_scaleZ(val, scaler)
	variable	val, scaler
	
	// ...
	return val *scaler
end
// <==
// ##########################		

// ---------------------------------------------------------------------------------- 
// X line scans
// ---------------------------------------------------------------------------------- 
function 	XScan2 (wFuncParams)
	wave		wFuncParams

	XYScan2(wFuncParams)
	wave		pwStimY		=$("StimY")
	pwStimY					= 0
end

// ---------------------------------------------------------------------------------- 	
// "Despiral"
// ---------------------------------------------------------------------------------- 	
function 	despiral (iAICh, dxRast, dyRast, isDebug, doSmartfillAvg)
	variable	iAICh, dxRast, dyRast
	variable	isDebug, doSmartfillAvg

	wave 		pwParNum	= $("wParamsNum")
	wave/T 		pwParStr	= $("wParamsStr")	
	wave		pwData		= $("wDataCh" +Num2Str(iAICh))
	string		sTemp
	variable	nFr, dx, dy, ix, iy, nPixB, v
	variable	minAO, maxAO, vx, vy, dAO, minStim, maxStim, dStim
	
	if(pwParNum[%User_ScanMode] != ScM_scanMode_Traject)
		printf "### Error: Is not trajectory scan\r"
		return -1
	endif	
	
	// Calculate some parameters
	//
	dx			= pwParNum[%User_dxPix]
	dy			= pwParNum[%User_dyPix]
	nPixB		= pwParNum[%NumberOfPixBufsSet] -pwParNum[%PixBufCounter]
	nFr			= nPixB *dy
	minAO		= pwParNum[%MinVolts_AO]
	maxAO		= pwParNum[%MaxVolts_AO]
	dAO			= maxAO -minAO
	// ...
	
	// Generate spirals AO
	//			
	ScM_callScanPathFunc(pwParStr[%User_ScanPathFunc])
	wave		pwStimX		= $("StimX")
	wave		pwStimY		= $("StimY")	
	WaveStats/Q pwStimX
	minStim		= round(V_min*10)/10	
	maxStim		= round(V_max*10)/10
	dStim		= maxStim -minStim
	
	// Make 2D waves for despiraled data
	//
	sprintf sTemp, "wDataCh%d_coverage", iAICh
	Make/O/N=(dxRast, dyRast)	$(sTemp)
	wave 		pwImg_os 	=$(sTemp)
	sprintf sTemp, "wDataCh%d_avg", iAICh
	Make/O/N=(dxRast, dyRast)	$(sTemp)
	wave 		pwImg_avg 	=$(sTemp)	
	sprintf sTemp, "wDataCh%d_reconst", iAICh
	Make/O/N=(dxRast, dyRast, nFr) $(sTemp)
	wave 		pwImg		=$(sTemp)	
	pwImg_os	= 0	
	pwImg_avg	= 0
	pwImg		= 0		

	// Despiral
	//
	for(iy=0; iy<nFr; iy+=1)		// for each trajectory
		for(ix=0; ix<dx; ix+=1)	// along each trajectory

			v						= pwData[ix][iy]
			vx						= trunc((pwStimX[ix] -minStim)/dStim *dxRast)
			vy						= trunc((pwStimY[ix] -minStim)/dStim *dyRast)
			pwImg_avg[vx][vy]		+= v			
			pwImg[vx][vy][iy]		+= v 					
			if(iy == 0)
				pwImg_os[vx][vy]	+= 1	
			endif	
		endfor
		pwImg[][][iy]				/= pwImg_os[p][q]			
	endfor
	
	pwImg[][][]		= (pwImg[p][q][r] > 0)?(pwImg[p][q][r]):(NaN)		
	
	pwImg_avg		/= pwImg_os			
	pwImg_avg		/= nFr
	wave w			= pwImg_avg
	if(doSmartfillAvg)
		// Replace zeros by the average of the neighboring pixels
		//
		w	= (NumType(w[p][q]) == 2)?(0):(w[p][q])		
		w	= (w[p][q] == 0)?((w[p-1][q]+w[p+1][q]+w[p][q-1]+w[p][q+1])/4):(w[p][q])
	else
		// Replace zeros by NaNs
		//
		w	= (w[p][q] > 0)?(w[p][q]):(NaN)
	endif	
	
//	pwParNum[%MinVolts_AO]
//	pwParNum[%MaxVolts_AO]
//	pwParNum[%MaxStimBufMapLen]
//	pwParNum[%NumberOfInputChans]
//	pwParNum[%PixSizeInBytes]
//	pwParNum[%PixelOffs]
//	pwParNum[%User_nXPixLineOffs]
//	pwParNum[%User_divFrameBufReq]
	
	// Clean up
	//
	if(!isDebug)
		KillWaves/Z	 pwImg_os, pwImg_avg
	endif
	KillWaves/Z pwStimX, pwStimY
end

// ---------------------------------------------------------------------------------- 	