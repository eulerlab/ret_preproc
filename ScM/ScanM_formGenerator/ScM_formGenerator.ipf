// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_formGenerator.ipf
//	Author		: Thomas Euler
//	Copyright	: (C) CIN/Uni Tübingen 2009-2015
//	History		: 2015-10-22 	Creation
//
//	Purpose		: Stand-alone editor for experimental header files 
//
// ----------------------------------------------------------------------------------
//
//	FG_createForm(sWinName)
//		Generates a new form using "experimentHeaderFile_template.txt" in the present 
//		directory
//
//	function FG_updateKeyValueLists (sFPath, sFName)
//		Update key-value lists from .ini file
//		Parameters:
//		sFPath		:= full or partial path to folder for the header file, w/o final "\\"
//		sFName		:= name of header file w/o file extension
//		
//	function FG_updateForm ()
//		Update form from key-value lists
//
//	function FG_saveToINIFile (sFPath, sFName, doOverwrite)
// 		Saves key-value list to a experimental header file. The file must not yet exist.
//		Parameters:
//		sFPath		:= full or partial path to folder for the header file, w/o final "\\"
//		sFName		:= name of header file w/o file extension
//		doOverwrite	:= 0=abort if file exists; 1=overwrite file after making a backup copy
//					   (note that backup copies are overwritten) 	
//
// ----------------------------------------------------------------------------------
//
// 	Example template file:
//	---------------------
//	675,186,1166,661
//	title=General information|key=|type=subheader.
//	title=Experimenter name|key=ExperimenterName|type=string.
//	title=Mouse|key=|type=subheader.
//	title=Mouse ID|key=MouseID|type=string.
//	title=Mouse line|key=MouseLine|type=popup|options=other;Bl6;Pcp2:Cre;PV:Cre;HR1_2:TN-XL.
//	title=Mouse line, details|key=MouseLineDetails|type=string.
//	title=Mouse line, reporter line|key=MouseLineReporter|type=popup|options=none;other;Ai9;Ai95.
//	title=Mouse line, reporter line, details|key=MouseLineReporterDetails|type=string.
//	title=Eye|key=MouseEye|type=popup|options=left;right.
//	title=Other stuff|key=|type=subheader.
//	title=Dark-adapted|key=IsDarkAdapted|type=checkbox.
//	title=Preparation type|key=Preparation|type=popup|options=whole-mount;slice.
//
// -------------------------------------------------------------------------------------
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// -------------------------------------------------------------------------------------
strconstant		sNameTemplateFile	= "experimentHeaderFile_template.txt"
strconstant		sFExt_HeaderFile	= ".ini" 
strconstant		sFPre_HeaderFile	= ""	
strconstant		sFileFilter_Ini	= "Experiment Header File (*.ini):.ini;"
strconstant 	sFileIniOpenDialog	= "Select an Experiment Header File ..."
strconstant 	sRelPathToTemplate	= "User Procedures:ScanM:"
strconstant 	sWinName_Default	= "ExperimentalHeaderEditor"

constant		FG_isDebug			= 1

strconstant		sValType_uint8		= "uint8"
strconstant		sValType_int32   	= "int32"
strconstant		sValType_uint32   	= "uint32"
strconstant		sValType_float   	= "float"
strconstant		sValType_string	= "string"
strconstant		sValType_bool		= "bool"

constant		GUIEntry_string	= 0
constant		GUIEntry_float		= 1
constant		GUIEntry_uint8		= 2
constant		GUIEntry_int32		= 3
constant		GUIEntry_uint32	= 4
constant		GUIEntry_checkbox	= 5
constant		GUIEntry_popup		= 6
constant		GUIEntry_list		= 7
constant		GUIEntry_rule		= 97
constant		GUIEntry_comment	= 98
constant		GUIEntry_subheader	= 99

// -------------------------------------------------------------------------------------
function FG_createForm(sWinName)
	string		sWinName
	
	string 		sEntries, sFullFName, sIgorUserPath 
	string 		sTitle, sType, sTemp, sEntry, sKey, sOpts, sFirst 
	string		sRange, sDefault, sDigits, sFormat
	variable	xPos, yPos, dxVal, dxTitle, dy, iEntry, nEntr
	variable   wPosx1, wPosx2, wPosy1, wPosy2
	variable	isDummyEntry
	variable	refNum, errCode, len, nLine, vMin, vMax, yPosCurr
	string 		sRule, sCondition, sKeys
	 
	sEntries	= ""
	refNum		= 0
	nLine		= 0
	if(strlen(sWinName) == 0)
		sWinName	= sWinName_Default
	endif	
	
	if(FG_isDebug)
		printf "FG|Creating form from template ...\r"
	endif	
	
	try
		// Open the template file
		//	
		sIgorUserPath	= SpecialDirPath("Igor Pro User Files", 0,0,0)
		sFullFName		= sIgorUserPath +sRelPathToTemplate +sNameTemplateFile
		print sFullFName
		Open/R/Z=2 refNum as sFullFName
		errCode		= V_flag	
		AbortOnValue (errCode != 0), -1
		do
			FReadLine refNum, sTemp
			len 	= strlen(sTemp)
			if(len == 0)
				break
			endif
			if(StringMatch(sTemp[len-1], "\r"))
				sTemp	= sTemp[0,len-2]
			endif	
			
			if(nLine == 0)
				// Window coordinates
				//
				wPosx1	= Str2Num(StringFromList(0, sTemp, ","))
				wPosy1	= Str2Num(StringFromList(1, sTemp, ","))
				wPosx2	= Str2Num(StringFromList(2, sTemp, ","))
				wPosy2	= Str2Num(StringFromList(3, sTemp, ","))
			else
				// Field/key-value pair entries
				//
				sEntries	+= sTemp
			endif	
			nLine	+= 1
		while(1)
		Close refNum
		
	catch 
		if(refNum > 0)
			Close refNum
		endif	
		switch (V_AbortCode)
			case -1:
				printf "ERROR opening template file (code=%d)\r", errCode
				break
		endswitch	
		return V_AbortCode
	endtry	
	
	// Generate form from the template
	//
	xPos		= 14
	yPos		= 10
	dxTitle		= 200
	dxVal		= 250
	dy			= 20
	yPosCurr	= yPos
	
	nEntr	= ItemsInList(sEntries, ".")
	Make/O/T/N=(nEntr) wValStr, wKeyStr, wOptStr
	Make/O/N=(nEntr) wVal, wGUIType

	sTemp	= GetDataFolder(1)
	SetDataFolder root:
	String/G formGenTables			= "wValStr;wKeyStr;wVal;wOptStr;wGUIType" 
	String/G formGenFolder			= sTemp
	String/G formGenWinName		= sWinName
	Variable/G formGenWinHeight	= wPosy2 -wPosy1
	Variable/G formGenWinIsScroll	= 0
	SetDataFolder $(sTemp)
	
	DoWindow/F $sWinName
	if(V_flag)
		DoWindow/K $sWinName
	endif	
	NewPanel/K=2/N=$sWinName /W=(wPosx1, wPosy1, wPosx2, wPosy2)
	
	for(iEntry=0; iEntry<nEntr; iEntry+=1)
		sEntry		= StringFromList(iEntry, sEntries, ".")
		sTitle		= StringByKey("title", sEntry, "=", "|")
		sType		= StringByKey("type", sEntry, "=", "|")
		sKey		= StringByKey("key", sEntry, "=", "|")
		sDefault	= StringByKey("default", sEntry, "=", "|")
		sRange		= StringByKey("range", sEntry, "=", "|")
		sDigits		= StringByKey("digits", sEntry, "=", "|")	
		sRule		= StringByKey("rule", sEntry, "=", "|")		
		sCondition	= StringByKey("condition", sEntry, "=", "|")		
		sKeys		= StringByKey("keys", sEntry, "=", "|")		

		isDummyEntry	= 0 
	
		if(strlen(sTitle) > 0)
			sTemp  	= "title" +Num2Str(iEntry)
			TitleBox $(sTemp), pos={xPos, yPosCurr}, size={dxTitle, dy} 
			TitleBox $(sTemp), title=sTitle, frame=0, font="Arial", fsize=11
	
			strswitch(sType)
				case "string":
					sTemp  	= "setVar_" +sKey
					SetVariable $(sTemp), pos={xPos +dxTitle, yPosCurr -2}, size={dxVal, 20}
					SetVariable $(sTemp), value=wValStr[iEntry],  title=" ", font="Arial", fsize=11
					sKey	= sValType_string +"_" +sKey
					wVal[iEntry]	= -1
					wGUIType[iEntry]	= GUIEntry_string
					if(StringMatch(sKey, "*_date"))
						wValStr	[iEntry]	= Secs2Date(datetime,-2) +"_" +Secs2Time(datetime, 3) 
						SetVariable $(sTemp), value=wValStr[iEntry], disable=2
					endif
					break
				
				case "float":
					sTemp  	= "setVar_" +sKey
					SetVariable $(sTemp), pos={xPos +dxTitle, yPosCurr -2}, size={dxVal/4, 22}
					SetVariable $(sTemp), format="%.3f", title=" ", font="Arial", fsize=11
					if(strlen(sRange) > 0)
						vMin	= Str2Num(StringFromList(0, sRange, ";"))
						vMax	= Str2Num(StringFromList(1, sRange, ";"))
						SetVariable $(sTemp), limits={vMin, vMax, 1}
					endif	
					sKey	= sValType_float +"_" +sKey
					if(strlen(sDefault) > 0)
						wVal[iEntry]	= Str2Num(sDefault)
						SetVariable $(sTemp), value=wVal[iEntry] 
					endif	
					if(strlen(sDigits) > 0)	
						sprintf sFormat, ".%df", Str2Num(sDigits)			
						SetVariable $(sTemp), format=("%" +sFormat)
					endif						
					wGUIType[iEntry]	= GUIEntry_float
					break					

				case "uint8":
					sTemp  	= "setVar_" +sKey
					SetVariable $(sTemp), pos={xPos +dxTitle, yPosCurr -2}, size={dxVal/4, 20}
					SetVariable $(sTemp), format="%d", title=" ", font="Arial", fsize=11
					if(strlen(sRange) > 0)
						vMin	= Str2Num(StringFromList(0, sRange, ";"))
						vMax	= Str2Num(StringFromList(1, sRange, ";"))
						SetVariable $(sTemp), limits={vMin, vMax, 1}
					endif	
					sKey	= sValType_uint8 +"_" +sKey
					if(strlen(sDefault) > 0)
						wVal[iEntry]	= Str2Num(sDefault)
						SetVariable $(sTemp), value=wVal[iEntry] 
					endif	
					wGUIType[iEntry]	= GUIEntry_uint8
					break					
	
				case "int32":
					sTemp  	= "setVar_" +sKey
					SetVariable $(sTemp), pos={xPos +dxTitle, yPosCurr -2}, size={dxVal/4, 20}
					SetVariable $(sTemp), format="%d", title=" ", font="Arial", fsize=11
					if(strlen(sRange) > 0)
						vMin	= Str2Num(StringFromList(0, sRange, ";"))
						vMax	= Str2Num(StringFromList(1, sRange, ";"))
						SetVariable $(sTemp), limits={vMin, vMax, 1}
					endif	
					sKey	= sValType_int32 +"_" +sKey
					if(strlen(sDefault) > 0)
						wVal[iEntry]	= Str2Num(sDefault)
						SetVariable $(sTemp), value=wVal[iEntry] 
					endif	
					wGUIType[iEntry]	= GUIEntry_int32
					break					
	
				case "uint32":
					sTemp  	= "setVar_" +sKey
					SetVariable $(sTemp), pos={xPos +dxTitle, yPosCurr -2}, size={dxVal/4, 20}
					SetVariable $(sTemp), format="%d", title=" ", font="Arial", fsize=11
					if(strlen(sRange) > 0)
						vMin	= Str2Num(StringFromList(0, sRange, ";"))
						vMax	= Str2Num(StringFromList(1, sRange, ";"))
						SetVariable $(sTemp), limits={vMin, vMax, 1}
					endif	
					sKey	= sValType_uint32 +"_" +sKey
					if(strlen(sDefault) > 0)
						wVal[iEntry]	= Str2Num(sDefault)
						SetVariable $(sTemp), value=wVal[iEntry] 
					endif	
					wGUIType[iEntry]	= GUIEntry_uint32
					break					
	
				case "checkbox":
					sTemp  	= "check_" +sKey //Num2Str(iEntry)		
					CheckBox $(sTemp), pos={xPos +dxTitle-1, yPosCurr}
					CheckBox $(sTemp), proc=FG_onFormCheckProc,  title=" "
					sKey	= sValType_bool +"_" +sKey
					wGUIType[iEntry]	= GUIEntry_checkbox
					break
	
				case "popup":
					sOpts	= StringByKey("options", sEntry, "=", "|")
					sFirst	= StringFromList(0, sOpts)	
					wOptStr[iEntry]	= sOpts				
					sOpts	= "\"" +sOpts +"\""
					sTemp  	= "popup_" +sKey //Num2Str(iEntry)		
					PopupMenu $(sTemp), pos={xPos +dxTitle-6, yPosCurr -4}
					PopupMenu $(sTemp), title=" ", proc=FG_onFormPopMenuProc
					PopupMenu $(sTemp), mode=1, popvalue=sFirst, value= #sOpts, font="Arial", fsize=11
					sKey	= sValType_string +"_" +sKey
					wGUIType[iEntry]	= GUIEntry_popup
					break
					
				case "list":
					sOpts	= StringByKey("options", sEntry, "=", "|")
					sFirst	= StringFromList(0, sOpts)	
					wOptStr[iEntry]	= sOpts				
					sOpts	= "\"" +sOpts +"\""
					sTemp  	= "popup_" +sKey
					PopupMenu $(sTemp), pos={xPos +dxTitle +dxVal, yPosCurr -4}
					PopupMenu $(sTemp), title=" ", proc=FG_onFormPopMenuProc, font="Arial", fsize=11
					PopupMenu $(sTemp), mode=0, popvalue=sFirst, value= #sOpts
	
					sTemp  	= "button_" +sKey
					Button $(sTemp), pos={xPos +dxTitle-6 +dxVal +38, yPosCurr -4},size={45,20},title="Clear"
					Button $(sTemp), proc=FG_onFormButtonProc, font="Arial", fsize=11
	
					sTemp  	= "setVar_" +sKey
					SetVariable $(sTemp), pos={xPos +dxTitle, yPosCurr -2}, size={dxVal, 20}
					SetVariable $(sTemp), value=wValStr[iEntry],  title=" ", noedit=1, font="Arial", fsize=11
					sKey	= sValType_string +"_" +sKey
					wVal[iEntry]	= -1
					wGUIType[iEntry]	= GUIEntry_list
					break
	
				case "subheader":
					sTemp  	= "title" +Num2Str(iEntry)
					TitleBox $(sTemp), fstyle=1, font="Arial", fsize=12, pos={xPos -6, yPosCurr}
					sKey	= "[" +sTitle +"]"
					wGUIType[iEntry]	= GUIEntry_subheader
					break
	
				case "comment":
					sTemp  	= "title" +Num2Str(iEntry)
					TitleBox $(sTemp), fstyle=2, font="Arial", fsize=11, pos={xPos, yPosCurr -2}
					sKey	= ""
					wGUIType[iEntry]	= GUIEntry_comment
					break
	
			endswitch		
			if(!isDummyEntry)
				wKeyStr[iEntry]	= sKey
			endif	
			yPosCurr	+= dy

		elseif(strlen(sRule) > 0)
			wKeyStr[iEntry]	= sKeys
			wValStr[iEntry]	= sCondition
			wOptStr[iEntry]	= sRule
			wGUIType[iEntry]	= GUIEntry_rule
		endif	
	endfor	
	
	Button buttonSave,pos={xPos +dxTitle, yPosCurr -2},size={100,20},proc=FG_onFormButtonProc,title="Save"
	Button buttonSaveExit,pos={xPos +dxTitle +108, yPosCurr -2},size={100,20},proc=FG_onFormButtonProc,title="Save & Exit"

	SetWindow $(sWinName) hook(scroll)=FG_panelScrollHook
	
	if(FG_isDebug)
		printf "... done.\r"
	endif	
end
	
// -------------------------------------------------------------------------------------	
function FG_onFormCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	
	switch(cba.eventCode)
		case 2: // mouse up
			iEntr			= FG_getIndex(sValType_bool +"_" +StringByKey("check", cba.ctrlName, "_"))
			pwVal[iEntr]	= cba.checked
			FG_updateRules()
			break
		case -1: // control being killed
			break
	endswitch
	return 0
end


function FG_onFormPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	NVAR		isScroll	= $("root:formGenWinIsScroll")

	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	WAVE		wGUIType	= $(sPath +StringFromList(4, sTables))	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwOptStr	= $(sPath +StringFromList(3, sTables))

	if(isScroll)
		return 0
	endif
	switch( pa.eventCode )
		case 2: // mouse up
			iEntr			= FG_getIndex(sValType_string +"_" +StringByKey("popup", pa.ctrlName, "_"))
			if(wGUIType[iEntr] == GUIEntry_popup)
				pwVal[iEntr]	= pa.popNum
			elseif(wGUIType[iEntr] == GUIEntry_list)	
			//	if(!StringMatch(pwValStr[iEntr], "*" +pa.popStr +"*"))
					if(strlen(pwValStr[iEntr]) > 0)
						pwValStr[iEntr] 	+= ";"
					endif
					pwValStr[iEntr] 	+= pa.popStr
			//	endif	
			endif
			FG_updateRules()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


function FG_onFormButtonProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	string		sFileName, sFilePath, sTemp
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))

	switch( ba.eventCode )
		case 2: // mouse up
			strswitch(ba.ctrlName)
				case "buttonSave":
				case "buttonSaveExit":				
					sTemp	= ReplaceString("-", Secs2Date(datetime,-2), "")
					sprintf sFileName, "%s%s", sFPre_HeaderFile, sTemp
					GetFileFolderInfo/Q/D/Z=2
					if(V_flag == 0)
						sFilePath	= RemoveEnding(S_path, ":")
						FG_saveToINIFile(sFilePath, sFileName, 1)
						if(stringmatch(ba.ctrlName, "buttonSaveExit"))
							DoWindow/K $(ba.win)
						endif	
					endif	
					break
					
				default:	
					iEntr	= FG_getIndex(sValType_string +"_" +StringByKey("button", ba.ctrlName, "_"))
					pwValStr[iEntr]	= ""
					break
			endswitch
			break
		case -1: // control being killed
			break
	endswitch

	return 0
end

// -------------------------------------------------------------------------------------	
//	Update form from key-value lists
//
function FG_updateForm ()

	string 		sTemp, sRule, sCondition, sKeys, sKey, sCtrlList
	variable	iEntr, jEntr, disableVal, k
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	SVAR		sWinName	= $("root:formGenWinName")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	WAVE		pwGUIType	= $(sPath +StringFromList(4, sTables))	
	WAVE/T		pwOptStr	= $(sPath +StringFromList(3, sTables))
	
	if(FG_isDebug)
		printf "FG|Updating GUI from waves ...\r"
	endif	
	
	DoWindow/F $(sWinName)
	
	for(iEntr=0; iEntr<DimSize(pwValStr, 0); iEntr+=1)
		// Update all entries
		//			
		if(StringMatch(pwKeyStr[iEntr], sValType_string +"*"))
			if((pwGUIType[iEntr] == GUIEntry_string) || (pwGUIType[iEntr] == GUIEntry_list))
				sTemp  	= "setVar_" +StringByKey(sValType_string, pwKeyStr[iEntr], "_")
				SetVariable $(sTemp), value=pwValStr[iEntr] 

			elseif(pwGUIType[iEntr] == GUIEntry_popup)
				sTemp  	= "popup_" +StringByKey(sValType_string, pwKeyStr[iEntr], "_")
				PopupMenu $(sTemp),mode=pwVal[iEntr]
			endif
				
		elseif(StringMatch(pwKeyStr[iEntr], sValType_bool +"*"))
			sTemp  	= "check_" +StringByKey(sValType_bool, pwKeyStr[iEntr], "_")
			CheckBox $(sTemp), value=pwVal[iEntr]
				
		elseif(StringMatch(pwKeyStr[iEntr], sValType_uint8 +"*"))		   	       
			sTemp  	= "setVar_" +StringByKey(sValType_uint8, pwKeyStr[iEntr], "_")
			SetVariable $(sTemp), value=pwVal[iEntr] 

		elseif(StringMatch(pwKeyStr[iEntr], sValType_uint32 +"*"))		   	       
			sTemp  	= "setVar_" +StringByKey(sValType_uint32, pwKeyStr[iEntr], "_")
			SetVariable $(sTemp), value=pwVal[iEntr] 

		elseif(StringMatch(pwKeyStr[iEntr], sValType_int32 +"*"))
			sTemp  	= "setVar_" +StringByKey(sValType_int32, pwKeyStr[iEntr], "_")
			SetVariable $(sTemp), value=pwVal[iEntr] 
				
		elseif(StringMatch(pwKeyStr[iEntr], sValType_float +"*"))
			sTemp  	= "setVar_" +StringByKey(sValType_float, pwKeyStr[iEntr], "_")
			SetVariable $(sTemp), value=pwVal[iEntr] 
		
		endif
	endfor
	FG_updateRules()
	
	if(FG_isDebug)
		printf "... done.\r"
	endif	
end

// -------------------------------------------------------------------------------------	
//	Update form from key-value lists
//
function FG_updateRules ()

	string 		sTemp, sRule, sCondition, sKeys, sKey, sCtrlList
	variable	iEntr, jEntr, isTrue, k, j
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	SVAR		sWinName	= $("root:formGenWinName")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	WAVE		pwGUIType	= $(sPath +StringFromList(4, sTables))	
	WAVE/T		pwOptStr	= $(sPath +StringFromList(3, sTables))
	
	if(FG_isDebug)
		printf "FG|Updating GUI from rules ...\r"
	endif	
	
	DoWindow/F $(sWinName)
	ModifyControlList/Z ControlNameList("", ";", "*") disable=0
	ModifyControlList/Z ControlNameList("", ";", "*_date") disable=2
	
	for(iEntr=0; iEntr<DimSize(pwValStr, 0); iEntr+=1)
		if(pwGUIType[iEntr] == GUIEntry_rule)
			sRule		= pwOptStr[iEntr]
			sCondition	= pwValStr[iEntr]
			sKeys		= pwKeyStr[iEntr]
			isTrue		= 0
			
			strswitch(sRule)
				case "enable":
				case "disable":
					sKey	= StringFromList(0, sCondition)
					jEntr	= FG_getIndex(sKey)
					switch(pwGUIType[jEntr])
						case GUIEntry_popup:
							sTemp	= StringFromList(pwVal[jEntr]-1, pwOptStr[jEntr])
							isTrue	= StringMatch(StringFromList(1, sCondition), sTemp)
							break
							
						case GUIEntry_checkbox:
							isTrue	= (pwVal[jEntr] == Str2Num(StringFromList(1, sCondition)))
							break

					endswitch	
					sCtrlList	= ""
					for(k=0; k<ItemsInList(sKeys); k+=1)
						sTemp	= StringFromList(k, sKeys)
						sCtrlList += FG_getControlType(sTemp) +sTemp +";"
						if(pwGUIType[FG_getIndex(sTemp)] == GUIEntry_list)
							sCtrlList += "setVar_" +sTemp +";"
						endif
					endfor
					if(stringmatch(sRule, "enable"))
						if(isTrue)
						 	ModifyControlList/Z sCtrlList, disable=0
						else	
							ModifyControlList/Z sCtrlList, disable=2
						endif	
					endif	
					if(stringmatch(sRule, "disable") && isTrue)
					 	ModifyControlList/Z sCtrlList, disable=2
					endif												 	
					break
			endswitch
		endif
	endfor	
	
	if(FG_isDebug)
		printf "... done\r"
	endif	
end

// -------------------------------------------------------------------------------------	
//	Update key-value lists from .ini file
//
function FG_updateKeyValueLists (sFPath, sFName)
	string		sFPath, sFName

	string 		sTemp, sFullFName, sKey, sVal, sIgorUserPath
	variable	refNum, errCode, j
	variable	iEntr, len
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	WAVE		pwGUIType	= $(sPath +StringFromList(4, sTables))	
	WAVE/T		pwOptStr	= $(sPath +StringFromList(3, sTables))

	refNum		= 0

	if(FG_isDebug)
		printf "FG|Updating form waves from .ini file ...\r"
	endif	
	
	try
		// Try reading the .ini file
		//	
		sIgorUserPath	= SpecialDirPath("Igor Pro User Files", 0,0,0)
		if(strlen(sFName) == 0)
			sFullFName	= sIgorUserPath +sRelPathToTemplate
		else	
			sFullFName	= sIgorUserPath +sRelPathToTemplate +sFName +sFExt_HeaderFile
		endif	
		Open/Z=2/R/F=sFileFilter_Ini refNum as sFullFName
		errCode		= V_flag	
		AbortOnValue (errCode != 0), -1 // File does not exist
		do
			FReadLine refNum, sTemp
			len 	= strlen(sTemp)
			if(len == 0)
				break
			endif
			if(StringMatch(sTemp[len-1], "\r"))
				sTemp	= sTemp[0,len-2]
			endif	
			sKey		= StringFromList(0, sTemp, "=")
			sVal		= StringFromList(1, sTemp, "=")
			iEntr		= FG_getIndex(sKey)

			if(!StringMatch(sKey, "[*") && (iEntr >= 0))
				if(StringMatch(sKey, sValType_string +"*"))
					switch(pwGUIType[iEntr])
						case GUIEntry_string:
						case GUIEntry_list:
							pwValStr[iEntr]	= sVal
							if(StringMatch(sKey, "*_date") && (strlen(sVal) == 0))
								pwValStr[iEntr]	= Secs2Date(datetime,-2) +"_" +Secs2Time(datetime, 3) 
							endif
							break
							
						case GUIEntry_popup:	
							j = WhichListItem(sVal, pwOptStr[iEntr])
							if(j < 0)
								printf "ERROR: Option '%s' does not exist for key '%s'\r", sVal, sKey
								pwVal[iEntr]	= 0
							else
								pwVal[iEntr]	= j+1
							endif		 
							break
					endswitch
					
				elseif(StringMatch(sKey, sValType_bool +"*"))
					if(StringMatch(sVal, "True"))
						pwVal[iEntr]	= 1
					else	
						pwVal[iEntr]	= 0
					endif	
				
				elseif(StringMatch(sKey, sValType_uint8 +"*"))		   	       
					pwVal[iEntr]	= Str2Num(sVal)
	
				elseif(StringMatch(sKey, sValType_uint32 +"*"))		   	       
					pwVal[iEntr]	= Str2Num(sVal)
					
				elseif(StringMatch(sKey, sValType_int32 +"*"))
					pwVal[iEntr]	= Str2Num(sVal)
									
				elseif(StringMatch(sKey, sValType_float +"*"))
					pwVal[iEntr]	= Str2Num(sVal)		
				endif
			endif	
		while(1)

		// Close file
		//
		Close refNum

	catch 
		if(refNum > 0)
			Close refNum
		endif	
		switch (V_AbortCode)
			case -1:
				printf "ERROR: File does not exist (code=%d)\r", errCode
				break
		endswitch	
		return V_AbortCode
	endtry	
	
	if(FG_isDebug)
		printf "... done\r"
	endif
	FG_updateForm()
end


function FG_getIndex (sKey)
	string 		sKey
	
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))

	for(iEntr=0; iEntr<DimSize(pwKeyStr, 0); iEntr+=1)
		if(StringMatch(pwKeyStr[iEntr], "*" +sKey))
			return iEntr
		endif			
	endfor
	return -1
end


function/T FG_getControlType (sKey)
	string 		sKey
	
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwGUIType	= $(sPath +StringFromList(4, sTables))	

	for(iEntr=0; iEntr<DimSize(pwKeyStr, 0); iEntr+=1)
		if(StringMatch(pwKeyStr[iEntr], "*" +sKey))
			switch(pwGUIType[iEntr])
				case GUIEntry_string:
				case GUIEntry_float:
				case GUIEntry_uint8:
				case GUIEntry_int32:
				case GUIEntry_uint32:
					return "setVar_"

				case GUIEntry_checkbox:
					return "check_"
					
				case GUIEntry_popup:
				case GUIEntry_list:
					return "popup_"
			endswitch	
		endif			
	endfor
	return ""
end

// -------------------------------------------------------------------------------------	
// 	Saves key-value list to a experimental header file. The file must not yet exist.
//
//	sFPath		:= full or partial path to folder for the header file, w/o final "\\"
//	sFName		:= name of header file w/o file extension
//	doOverwrite	:= 0=abort if file exists; 1=overwrite file after making a backup copy
//
function FG_saveToINIFile (sFPath, sFName, doOverwrite)
	string		sFPath, sFName
	variable	doOverwrite
	
	variable	refNum, errCode, j, isOK
	string		sFullFName, sTemp
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	WAVE		wGUIType	= $(sPath +StringFromList(4, sTables))	
	WAVE/T		pwOptStr	= $(sPath +StringFromList(3, sTables))

	if(FG_isDebug)
		printf "FG|Save waves to .ini file ...\r"
	endif	

	try
		// Check the experiment header file; if it exists, respond as the user
		// requests
		//	
		sFullFName	= sFPath + "\\" +sFName +sFExt_HeaderFile
		Open/R/Z refNum as sFullFName
		errCode		= V_flag	
		if(doOverwrite)		
			if(errCode == 0)
				// File already exists; make a backup
				//
				j		= 0	
				isOk	= 0
				do
					sprintf sTemp, "%s.%.3d", sFullFName, j
					GetFileFolderInfo/Z/Q sTemp
					if(V_Flag < 0)
						CopyFile/I=0 sFullFName as sTemp
						SetFileFolderInfo/RO sTemp
						isOK	= 1
					else
						j	+= 1
					endif		
				while(!isOK)
			endif	
		else
			AbortOnValue (errCode == 0), -1 // File already exists
		endif	
		
		// Now open the experiment header file for writing
		//
		Open/Z=2/F=sFileFilter_Ini refNum as sFullFName
		AbortOnValue (strlen(S_fileName) == 0), 0
		sFullFName	= S_fileName
		
		for(iEntr=0; iEntr<DimSize(pwValStr, 0); iEntr+=1)
			// Add all entries
			//			
			if(StringMatch(pwKeyStr[iEntr][0], "[*"))
				if(iEntr > 0)
					fprintf refNum, "\r\n"
				endif	
				fprintf refNum, "%s\r\n", pwKeyStr[iEntr]
				
			elseif(StringMatch(pwKeyStr[iEntr], sValType_string +"*"))
				if((wGUIType[iEntr] == GUIEntry_string) || (wGUIType[iEntr] == GUIEntry_list))
					fprintf refNum, "%s=%s\r\n", pwKeyStr[iEntr], pwValStr[iEntr]
				elseif(wGUIType[iEntr] == GUIEntry_popup)
					fprintf refNum, "%s=%s\r\n", pwKeyStr[iEntr], StringFromList(pwVal[iEntr]-1, pwOptStr[iEntr])
				endif
				
			elseif(StringMatch(pwKeyStr[iEntr], sValType_bool +"*"))
				if(pwVal[iEntr] > 0)
					sTemp	= "True"
				else	
					sTemp	= "False"
				endif	
				fprintf refNum, "%s=%s\r\n", pwKeyStr[iEntr], sTemp
				
			elseif(StringMatch(pwKeyStr[iEntr], sValType_uint8 +"*"))		   	       
				fprintf refNum, "%s=%d\r\n", pwKeyStr[iEntr], pwVal[iEntr]

			elseif(StringMatch(pwKeyStr[iEntr], sValType_uint32 +"*"))		   	       
				fprintf refNum, "%s=%d\r\n", pwKeyStr[iEntr], pwVal[iEntr]

			elseif(StringMatch(pwKeyStr[iEntr], sValType_int32 +"*"))
				fprintf refNum, "%s=%d\r\n", pwKeyStr[iEntr], pwVal[iEntr]
				
			elseif(StringMatch(pwKeyStr[iEntr], sValType_float +"*"))
				fprintf refNum, "%s=%f\r\n", pwKeyStr[iEntr], pwVal[iEntr]

			else	
				switch(wGUIType[iEntr])
					case GUIEntry_rule:
					case GUIEntry_comment:
						break
					default:
						printf "ERROR: Unknown key type (%s); ignored\r", pwKeyStr[iEntr]
				endswitch
			endif	
		endfor

		// Close file
		//
		Close refNum

	catch 
		if(refNum > 0)
			Close refNum
		endif	
		switch (V_AbortCode)
			case -1:
				printf "ERROR: File already exists (code=%d)\r", errCode
				break
		endswitch	
		return V_AbortCode
	endtry	
	if(FG_isDebug)
		printf "-> %s\r", sFullFName
		printf "... done.\r"	
	endif	
end

// -------------------------------------------------------------------------------------	
Function FG_panelScrollHook(info)
	Struct WMWinHookStruct &info

	SVAR		sWinName	= $("root:formGenWinName")	
	NVAR		winHeight	= $("root:formGenWinHeight")
	NVAR		isScroll	= $("root:formGenWinIsScroll")
	variable	y1, y2

	if(!StringMatch(info.WinName, sWinName))
		return 0
	endif	

	strswitch( info.eventName )
		case "mouseWheel":
			// If the mouse wheel is above a subwindow, info.name won't be the top level
			// window. This test allows the scroll wheel to work normally when over a 
			// table subwindow.
			//
			Variable mouseIsOverSubWindow= ItemsInList(info.WinName,"#") > 1
			if(!mouseIsOverSubWindow)
				String controls = ControlNameList(info.winName)
				ControlInfo/W=$sWinName $(StringFromList(0, controls))
				y1 	= V_top
				ControlInfo/W=$sWinName $(StringFromList(ItemsInList(controls)-1, controls))
				y2 	= V_top
				if(((info.wheelDy > 0) && (y1 <= 6)) || ((info.wheelDy < 0) && (y2 >= winHeight-24)))
					isScroll = 1
					ModifyControlList controls, win=$info.winName, pos+={0,info.wheelDy*56}
					DoUpdate
					isScroll = 0
				endif	
				return 1
			endif
			break
	endswitch
	return 0	// process all events normally
End

// -------------------------------------------------------------------------------------	
