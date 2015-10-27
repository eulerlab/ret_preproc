#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "OS_ParameterTable"
#include "OS_DetrendStack"
#include "OS_ManualROI"
#include "OS_AutoRoiByCorr"
#include "OS_TracesAndTriggers"
#include "OS_BasicAveraging"
#include "OS_hdf5Export"

function OS_GUI()
	NewPanel /k=1 /W=(1557,74,1817,516)
	SetDrawLayer UserBack
	SetDrawEnv fstyle= 1
	DrawText 24,149,"Step 3: ROI placement"
	SetDrawEnv fstyle= 1
	DrawText 24,90,"Step 2: Detrending"
	SetDrawEnv fstyle= 1
	DrawText 24,36,"Step 1: Generate Parameter Table"
	SetDrawEnv fstyle= 1
	DrawText 24,252,"Step 4: Extract Traces and Triggers"
	SetDrawEnv fstyle= 1
	DrawText 24,314,"Step 5: Averaging (just for display) "
	SetDrawEnv fstyle= 1
	DrawText 24,374,"Step 6: Generate Database files"
	Button step1,pos={78,39},size={147,27},proc=OS_GUI_Buttonpress,title="Load Parameter Table"
	Button step2,pos={78,93},size={147,27},proc=OS_GUI_Buttonpress,title="Detrend Stack"
	Button step3a1,pos={78,153},size={71,18},proc=OS_GUI_Buttonpress,title="Manually"
	Button step3a2,pos={154,153},size={71,18},proc=OS_GUI_Buttonpress,title="Apply"	
	Button step3b,pos={78,178},size={147,19},proc=OS_GUI_Buttonpress,title="Autom. by Correlation"
	Button step3c,pos={78,203},size={147,19},proc=OS_GUI_Buttonpress,title="Autom. CellLab (not impl.)"
	Button step4,pos={78,258},size={147,27},proc=OS_GUI_Buttonpress,title="Traces and Triggers"
	Button step5,pos={78,321},size={147,27},proc=OS_GUI_Buttonpress,title="Basic Averaging"
	Button step6,pos={78,382},size={147,27},proc=OS_GUI_Buttonpress,title="Export for database"
	

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
				case "step2":
					OS_DetrendStack()
					break
				case "step3a1":
					OS_CallManualROI()
					break
				case "step3a2":
					OS_ApplyManualRoi()
					break										
				case "step3b":
					OS_AutoRoiByCorr()
					break
				case "step3c":
					print "NOT IMPLEMENTED YET - DID NOTHING"
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
