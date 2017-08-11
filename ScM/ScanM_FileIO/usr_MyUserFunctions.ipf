#pragma rtGlobals=3		// Use modern global access method and strict wave access.

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

