#pragma rtGlobals=3		// Use modern global access method and strict wave access.

#include "OS_ParameterTable"
#include "OS_DetrendStack"
#include "OS_ManualROI"
#include "OS_AutoRoiByCorr"
#include "OS_TracesAndTriggers"
#include "OS_BasicAveraging"
#include "OS_hdf5Export"
#include "OS_LaunchCellLab"
#include "OS_STRFs"
#include "OS_EventFinder"
#include "OS_MakeCutouts"

//----------------------------------------------------------------------------------------------------------------------
Menu "ScanM", dynamic
	"-"
	" Open OS GUI",	/Q, 	OS_GUI()
	"-"	
End
//----------------------------------------------------------------------------------------------------------------------


function OS_GUI()
	variable check
	NewPanel /N=OfficialScripts /k=1 /W=(200,100,450,600)
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
	DrawText 24,364,"Step 5: Averaging (just for display) "
	SetDrawEnv fstyle= 1
	DrawText 24,424,"Step 6: Generate Database files"
	Button step1,pos={48,39},size={147,26},proc=OS_GUI_Buttonpress,title="Make New Parameter Table"
	Button step2a,pos={48,94},size={71,26},proc=OS_GUI_Buttonpress,title="One Channel"
	Button step2b,pos={124,94},size={71,26},proc=OS_GUI_Buttonpress,title="Ratiometric"
	Button step3a1,pos={48,155},size={71,20},proc=OS_GUI_Buttonpress,title="Manually"
	Button step3a2,pos={124,155},size={71,20},proc=OS_GUI_Buttonpress,title="Apply"
	Button step3a3,pos={48,179},size={147,20},proc=OS_GUI_Buttonpress,title="Use existing SARFIA Mask"	
	Button step3b,pos={48,203},size={147,20},proc=OS_GUI_Buttonpress,title="Autom. by Correlation"
	Button step3c,pos={48,228},size={147,20},proc=OS_GUI_Buttonpress,title="Autom. CellLab"
	Button step4,pos={48,278},size={147,26},proc=OS_GUI_Buttonpress,title="Traces and Triggers"

	Button step4a pos={48,308},size={147,26},proc = OS_GUI_Buttonpress,title = "Cutouts" 
	//CheckBox step4a pos={78,328}, value=1,variable=check, proc = OS_GUI_check,title = "make cutouts" 
	
	Button step5a,pos={48,371},size={43,26},proc=OS_GUI_Buttonpress,title="Ave"
	Button step5b,pos={100,371},size={43,26},proc=OS_GUI_Buttonpress,title="Events"			
	Button step5c,pos={151,371},size={43,26},proc=OS_GUI_Buttonpress,title="RFs"
	Button step6,pos={48,432},size={147,26},proc=OS_GUI_Buttonpress,title="Export for database"
	
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
				case "step4a":
					OS_MakeCutouts()
					break				
				case "step5a":
					OS_BasicAveraging()
					break
				case "step5b":
					OS_EventFinder()
					break					
				case "step5c":
					OS_STRFs()
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

Function OS_GUI_check(CB) : CheckBoxControl
	STRUCT WMCheckboxAction &CB
	variable check = 0
	check = CB.checked
	return check
//	if (CB.eventCode==2)
		//print CB.checked
		
		
end