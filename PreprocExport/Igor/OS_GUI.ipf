#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "OS_ParameterTable"
#include "OS_DetrendStack"
#include "OS_ManualROI"
#include "OS_AutoRoiByCorr"
#include "OS_TracesAndTriggers"
#include "OS_BasicAveraging"
#include "OS_hdf5Export"
#include "OS_LaunchCellLab"

//----------------------------------------------------------------------------------------------------------------------
Menu "ScanM", dynamic
	"-"
	" Open OS GUI",	/Q, 	OS_GUI()
	"-"	
End
//----------------------------------------------------------------------------------------------------------------------


function OS_GUI()
	NewPanel /N=OfficialScripts /k=1 /W=(200,100,450,550)
	ShowTools/A
	SetDrawLayer UserBack
	SetDrawEnv fstyle= 1
	DrawText 24,149,"Step 3: ROI placement"
	SetDrawEnv fstyle= 1
	DrawText 24,90,"Step 2: Detrending"
	SetDrawEnv fstyle= 1
	DrawText 24,36,"Step 1: Generate Parameter Table"
	SetDrawEnv fstyle= 1
	DrawText 24,272,"Step 4: Extract Traces and Triggers"
	SetDrawEnv fstyle= 1
	DrawText 24,334,"Step 5: Averaging (just for display) "
	SetDrawEnv fstyle= 1
	DrawText 24,394,"Step 6: Generate Database files"
	Button step1,pos={78,39},size={147,26},proc=OS_GUI_Buttonpress,title="Load Parameter Table"
	Button step2a,pos={78,94},size={71,26},proc=OS_GUI_Buttonpress,title="One Channel"
	Button step2b,pos={154,94},size={71,26},proc=OS_GUI_Buttonpress,title="Ratiometric"
	Button step3a1,pos={78,155},size={71,20},proc=OS_GUI_Buttonpress,title="Manually"
	Button step3a2,pos={154,155},size={71,20},proc=OS_GUI_Buttonpress,title="Apply"
	Button step3a3,pos={78,179},size={147,20},proc=OS_GUI_Buttonpress,title="Use existing SARFIA Mask"	
	Button step3b,pos={78,203},size={147,20},proc=OS_GUI_Buttonpress,title="Autom. by Correlation"
	Button step3c,pos={78,228},size={147,20},proc=OS_GUI_Buttonpress,title="Autom. CellLab (not impl.)"
	Button step4,pos={78,278},size={147,26},proc=OS_GUI_Buttonpress,title="Traces and Triggers"
	Button step5,pos={78,341},size={147,26},proc=OS_GUI_Buttonpress,title="Basic Averaging"
	Button step6,pos={78,402},size={147,26},proc=OS_GUI_Buttonpress,title="Export for database"
	
	HideTools/A
end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Function OS_GUI_Buttonpress(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			strswitch (ba.ctrlName)
				case "step1":
					OS_ParameterTable()
					break
				case "step2a":
					OS_DetrendStack()
					break
				case "step2b":
					OS_DetrendRatiometric()
					break					
				case "step3a1":
					OS_CallManualROI()
					break
				case "step3a2":
					OS_ApplyManualRoi()
					break	
				case "step3a3":
					OS_CloneSarfiaRoi()
					break																		
				case "step3b":
					OS_AutoRoiByCorr()
					break
				case "step3c":
					OS_LaunchCellLab()
					break
				case "step4":
					OS_TracesAndTriggers()
					break					
				case "step5":
					OS_BasicAveraging()
					break
				case "step6":
					OS_hdf5Export()
					break										
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
