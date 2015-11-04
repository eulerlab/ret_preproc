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
	" New experiment header file",	/Q, 	FG_Menue_createExpHeaderFile()
	" Load experiment header file", 	/Q, 	FG_Menue_loadExpHeaderFile()
	"-"	
End

// -------------------------------------------------------------------------------------
function FG_Menue_createExpHeaderFile()

	FG_createForm()
end


// -------------------------------------------------------------------------------------
function FG_Menue_loadExpHeaderFile()

	FG_createForm()
	FG_updateKeyValueLists("", "")
end

// -------------------------------------------------------------------------------------	
