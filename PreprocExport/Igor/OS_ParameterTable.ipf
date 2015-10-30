#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_ParameterTable()

// make a new table
make /o/n=(100) OS_Parameters = NaN

// Define Entries
variable entry_position = 0
/// GENERAL ////////////////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Data_Channel,OS_Parameters
OS_Parameters[%Data_Channel] = 0 // Fluorescence Data in wDataChX - default 0
entry_position+=1

SetDimLabel 0,entry_position,Data_Channel2,OS_Parameters
OS_Parameters[%Data_Channel2] = 1 // Fluorescence Data in wDataChX - default 1 (for Ratiometric)
entry_position+=1

SetDimLabel 0,entry_position,Trigger_Channel,OS_Parameters
OS_Parameters[%Trigger_Channel] = 2 // Trigger Data in wDataChX - default 2 
entry_position+=1

SetDimLabel 0,entry_position,Display_Stuff,OS_Parameters
OS_Parameters[%Display_Stuff] = 1 // generate graphs? - 0/1 - default 1
entry_position+=1

SetDimLabel 0,entry_position,LightArtifact_cut,OS_Parameters
OS_Parameters[%LightArtifact_cut] = 3 // nPixels cut in X to remove LightArtifact - default 3
entry_position+=1

SetDimLabel 0,entry_position,LineDuration,OS_Parameters
OS_Parameters[%LineDuration] = 0.002 // number of seconds per scan line - default 0.002
entry_position+=1

/// DETREND ////////////////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Detrend_smooth_window,OS_Parameters
OS_Parameters[%Detrend_smooth_window] = 1000 // smoothing window in seconds - default 1000
entry_position+=1

SetDimLabel 0,entry_position,Detrend_RatiometricData,OS_Parameters
OS_Parameters[%Detrend_RatiometricData] = 0 // Does Ratiometric data get detrended (1) or just combined (0)? - default 0
entry_position+=1

/// ROI PLACEMENT /////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,ROI_SD_min,OS_Parameters
OS_Parameters[%ROI_SD_min] = 10 // Response minimum of a pixel to be used to seed a ROI - default 10
entry_position+=1

SetDimLabel 0,entry_position,ROI_corr_min,OS_Parameters
OS_Parameters[%ROI_corr_min] = 0.3 // Activity correlation minimum to allow a seeded ROI to grow - default 0.3
entry_position+=1

SetDimLabel 0,entry_position,ROI_mindiameter,OS_Parameters
OS_Parameters[%ROI_mindiameter] = 1 // min circle equivalent diameter in micron - default 1
entry_position+=1

SetDimLabel 0,entry_position,ROI_maxdiameter,OS_Parameters
OS_Parameters[%ROI_maxdiameter] = 6 // max circle equivalent diameter in micron - default 6
entry_position+=1

SetDimLabel 0,entry_position,ROI_minpix,OS_Parameters
OS_Parameters[%ROI_minpix] = 3 // minimum number of pixels per ROI, overrides ROI_mindiameter - default 3
entry_position+=1

SetDimLabel 0,entry_position,nRoiKillsAllowed,OS_Parameters
OS_Parameters[%nRoiKillsAllowed] = 10 // nRois that get killed due to size minimum before the routine aborts trying to place more  - default 10
entry_position+=1

/// TRACE AND TRIGGER EXTRACTION  ///////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Trigger_Threshold,OS_Parameters
OS_Parameters[%Trigger_Threshold] = 20000 // Threshold to Trigger in Triggerchannel - default 20000
entry_position+=1

SetDimLabel 0,entry_position,Trigger_after_skip_s,OS_Parameters
OS_Parameters[%Trigger_after_skip_s] = 0.2 // if triggers in triggerchannel, it skips X seconds - default 0.2
entry_position+=1

SetDimLabel 0,entry_position,Trigger_LevelRead_after_lines,OS_Parameters
OS_Parameters[%Trigger_levelread_after_lines] = 2  // to read "Triggervalue" - want to avoid landing on the slope of the trigger - default 2
entry_position+=1

SetDimLabel 0,entry_position,Trigger_DisplayHeight,OS_Parameters
OS_Parameters[%Trigger_DisplayHeight] = 6  // How long are the trigger lines in the display (in SD) - default 6
entry_position+=1

SetDimLabel 0,entry_position,Baseline_nSeconds,OS_Parameters
OS_Parameters[%Baseline_nSeconds] = 5  // takes the 1st n seconds to calculate the baseline noise (for z-normalisation) - default 5
entry_position+=1

SetDimLabel 0,entry_position,Ignore1stXseconds,OS_Parameters
OS_Parameters[%Ignore1stXseconds] = 1 // for baseline extraction & for averaging across triggers (below): ignores X 1st seconds of triggers
entry_position+=1

/// BASIC AVERAGING  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Use_Znorm,OS_Parameters
OS_Parameters[%Use_Znorm] = 1 // use znormalised or raw traces (0/1) - default 1
entry_position+=1

SetDimLabel 0,entry_position,Trigger_Mode,OS_Parameters
OS_Parameters[%Trigger_Mode] = 1 // Use every nth trigger - default 1
entry_position+=1





// Display the Table
edit /k=1 OS_Parameters.l, OS_Parameters

end