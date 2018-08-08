#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// ----------------------------------------------------------------------------------
function usr_AutoScale (wFrame, scaler, newMin, newMax)
	// If exists, is called when "auto" button is pressed.
	// wFrame			:= IN,  current image frame of the channel selected in the GUI
	// scaler	  		:= IN,  scaling factor
	// newMin, newMax	:= OUT, new limits for scaling of colour map
	//
	WAVE		wFrame	
	variable	scaler			
	variable	&newMin, &newMax

	ImageStats wFrame
	newMin	= V_min
	newMax	= V_avg +V_sdev *scaler
	print newMin, newMax, scaler
end

// ----------------------------------------------------------------------------------
function shiftZ(U_V)
	variable	U_V
	WAVE pw		= $("wStimBufData")
	variable n = DimSize(pw, 1)
	pw[3][n/2, n-1] += U_V
end		

// ----------------------------------------------------------------------------------
//function setFocus()
//	string 	sPath	= "root:" +SCM_GlobalVarFolderName +":"
//	WAVE pwSCA		= $(sPath +SCM_SetScanAreaStr +SCM_ParamWavePostStr)
////	print pwSCA
//	ScMSetScanArea(pwSCA, 1000)
//end	

// ----------------------------------------------------------------------------------
function usr_FrameDiff(pw1, pw2)
	// If exists, is called when difference between two frames is estimated
	// pw1				:= IN,  first frame
	// pw2		  		:= IN,  second frame
	//
	WAVE 		pw1, pw2
	
	// Very simple implementation of MSE (mean squared error) as difference between
	// pixels
	//
	Make/FREE/O/N=(DimSize(pw1, 0), DimSize(pw1, 1)) wMSE
	wMSE		= NaN
	wMSE[][]	= sqrt((pw1[p][q] -pw2[p][q])^2)
	WaveStats/Q/M=1  wMSE
	return V_sum/V_npnts
end
	
// ----------------------------------------------------------------------------------
		


