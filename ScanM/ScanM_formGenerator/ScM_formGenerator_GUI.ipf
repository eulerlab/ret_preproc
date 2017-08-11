// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_formGenerator_GUI.ipf
//	Author		: Thomas Euler
//	Copyright	: (C) CIN/Uni Tübingen 2009-2015
//	History		: 2015-10-22 	Creation
//
//	Purpose		: Stand-alone editor for experimental header files 
//				  (see ScM_formGenerator.ipf for details)
//
// -------------------------------------------------------------------------------------
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// -------------------------------------------------------------------------------------
#include "ScM_formGenerator"

// ----------------------------------------------------------------------------------
Menu "ScanM", dynamic
	"-"
	" Load experiment header file or template", 	/Q, 	FG_Menue_loadExpHeaderFile()
	"-"	
End

// -------------------------------------------------------------------------------------
//function FG_Menue_createExpHeaderFile()
//
//	FG_createForm("")
//	FG_updateForm()
//end

// -------------------------------------------------------------------------------------
function FG_Menue_loadExpHeaderFile()

	string	sWinName	= StrVarOrDefault("root:formGenWinName", "")
	if(strlen(sWinName) == 0)
		FG_createForm("")
	else
		DoWindow/F 	$(sWinName)
		if(V_flag == 0)
			FG_createForm("")
		endif	
	endif	
	FG_updateKeyValueLists("", "")
end

// -------------------------------------------------------------------------------------	
