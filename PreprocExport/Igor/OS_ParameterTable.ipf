#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function OS_ParameterTable()

// make a new table
make /o/n=(100) OS_Parameters = NaN

// reads data-header
wave wParamsNum

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
OS_Parameters[%LineDuration] = wParamsNum(7) * wParamsNum(17) * 10^-6  // == 0.002, usually; number of seconds per scan line
// Note - initially had this manual entry = 0.002, but some scan protocols have this time not equal to 2 ms, so instead now I calculate it from effective pixel duration (header position 7) multiplied by
// actual frame width (i.-e. beyond the cropped x-scale shown during the scan, header position 17. the unit in "7" is microseconds, so to scale to seconds is * 10^-6 
entry_position+=1

/// DETREND ////////////////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Detrend_smooth_window,OS_Parameters
OS_Parameters[%Detrend_smooth_window] = 1000 // smoothing window in seconds - default 1000
entry_position+=1

SetDimLabel 0,entry_position,Detrend_RatiometricData,OS_Parameters
OS_Parameters[%Detrend_RatiometricData] = 0 // Does Ratiometric data get detrended (1) or just combined (0)? - default 0
entry_position+=1

/// ROI PLACEMENT /////////////////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,ROI_corr_min,OS_Parameters
OS_Parameters[%ROI_corr_min] = 0.1 // Activity correlation minimum to allow a seeded ROI to grow - default 0.1
entry_position+=1

SetDimLabel 0,entry_position,ROI_mindiameter,OS_Parameters
OS_Parameters[%ROI_mindiameter] = 1 // min circle equivalent diameter in micron - default 1
entry_position+=1

SetDimLabel 0,entry_position,ROI_maxdiameter,OS_Parameters
OS_Parameters[%ROI_maxdiameter] = 3 // max circle equivalent diameter in micron - default 3
entry_position+=1

SetDimLabel 0,entry_position,ROI_minpix,OS_Parameters
OS_Parameters[%ROI_minpix] = 2 // minimum number of pixels per ROI, overrides ROI_mindiameter - default 2
entry_position+=1

SetDimLabel 0,entry_position,nRoiKillsAllowed,OS_Parameters
OS_Parameters[%nRoiKillsAllowed] = 10 // nRois that get killed due to size minimum before the routine aborts trying to place more  - default 10
entry_position+=1

SetDimLabel 0,entry_position,ROI_PxBinning,OS_Parameters
OS_Parameters[%ROI_PxBinning] = 1 // Bin pixels to autoplace ROIs (speedup = 2^Bin)  - default 1
entry_position+=1

/// TRACE AND TRIGGER EXTRACTION  ///////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Trigger_Threshold,OS_Parameters
OS_Parameters[%Trigger_Threshold] = 20000 // Threshold to Trigger in Triggerchannel - default 20000
entry_position+=1

SetDimLabel 0,entry_position,Trigger_after_skip_s,OS_Parameters
OS_Parameters[%Trigger_after_skip_s] = 0.1 // if triggers in triggerchannel, it skips X seconds - default 0.1
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

SetDimLabel 0,entry_position,IgnoreLastXseconds,OS_Parameters
OS_Parameters[%IgnoreLastXseconds] = 0 // if weird stuff happens at end of trace can cut away
entry_position+=1

/// BASIC AVERAGING  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Use_Znorm,OS_Parameters
OS_Parameters[%Use_Znorm] = 1 // use znormalised or raw traces (0/1) - default 1
entry_position+=1

SetDimLabel 0,entry_position,Trigger_Mode,OS_Parameters
OS_Parameters[%Trigger_Mode] = 1 // Use every nth trigger - default 1
entry_position+=1

SetDimLabel 0,entry_position,AverageStack_make,OS_Parameters
OS_Parameters[%AverageStack_make] = 0 // yes or no /0/1 - default 0
entry_position+=1

SetDimLabel 0,entry_position,AverageStack_rate,OS_Parameters
OS_Parameters[%AverageStack_rate] = 50 // Time resolution of the Average stack, in Hz - the faster the longer it calculates
entry_position+=1

SetDimLabel 0,entry_position,AverageStack_dF,OS_Parameters
OS_Parameters[%AverageStack_dF] = 1 // Subtract Average
entry_position+=1
/// EVENT TRIGGERING  ////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Events_nMax,OS_Parameters
OS_Parameters[%Events_nMax] = 1000 // maximal number of events identified in single full trace - default 1000
entry_position+=1

SetDimLabel 0,entry_position,Events_Threshold,OS_Parameters
OS_Parameters[%Events_Threshold] = 1 // Threshold for Peak detection (log scale), default = 1
entry_position+=1

SetDimLabel 0,entry_position,Events_RateBins_s,OS_Parameters
OS_Parameters[%Events_RateBins_s] = 0.05 // "Smooth_size" for Event rate plots (s) - default 0.05
entry_position+=1


/// RF Calculations  /////////////////////////////////////////////////////////////////////////

SetDimLabel 0,entry_position,Noise_PxSize_microns,OS_Parameters
OS_Parameters[%Noise_PxSize_microns] = 20 // pixel size of 3D noise - default 20 microns
entry_position+=1

SetDimLabel 0,entry_position,Noise_EventSD,OS_Parameters
OS_Parameters[%Noise_EventSD] = 0.7 // Sensitivity of Event triggering
entry_position+=1

SetDimLabel 0,entry_position,Noise_FilterLength_s,OS_Parameters
OS_Parameters[%Noise_FilterLength_s] = 1 // Length extracted in seconds
entry_position+=1

SetDimLabel 0,entry_position,Noise_Compression,OS_Parameters
OS_Parameters[%Noise_Compression] = 10 // Noise RF calculation speed up
entry_position+=1


// Display the Table
edit /k=1 /W=(50,50,300,500)OS_Parameters.l, OS_Parameters

end