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
//	FG_createForm()
//		Generates a new form using "template.txt" in the present directory
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
strconstant		sNameTemplateFile	= "template.txt"
strconstant		sFExt_HeaderFile	= ".ini" 

strconstant		sValType_uint8		= "uint8"
strconstant		sValType_int32   	= "int32"
strconstant		sValType_uint32   	= "uint32"
strconstant		sValType_float   	= "float"
strconstant		sValType_string	= "string"
strconstant		sValType_bool		= "bool"

// -------------------------------------------------------------------------------------
function FG_createForm()

	string 		sEntries 
	string 		sTitle, sType, sTemp, sEntry, sKey, sOpts, sFirst, sWinName
	variable	xPos, yPos, dxVal, dxTitle, dy, iEntry, nEntr
	variable   wPosx1, wPosx2, wPosy1, wPosy2
	variable	isDummyEntry
	variable	refNum, errCode, len, nLine
	 
	sEntries	= ""
	refNum		= 0
	sWinName	= "ExperimentalHeader"
	nLine		= 0
	
	try
		// Open the template file
		//	
		Open/R/Z=2/P=home refNum as sNameTemplateFile
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
	xPos	= 10
	yPos	= 10
	dxTitle	= 200
	dxVal	= 250
	dy		= 22
	
	nEntr	= ItemsInList(sEntries, ".")
	Make/O/T/N=(nEntr)	wValStr, wKeyStr
	Make/O/N=(nEntr)	wVal

	sTemp	= GetDataFolder(1)
	SetDataFolder root:
	String/G formGenTables			= "wValStr;wKeyStr;wVal;" 
	String/G formGenFolder			= sTemp
	String/G formGenWinName		= sWinName
	Variable/G formGenWinHeight	= wPosy2 -wPosy1
	SetDataFolder $(sTemp)
	
	DoWindow/F $sWinName
	if(V_flag)
		DoWindow/K $sWinName
	endif	
	NewPanel/N=$sWinName /W=(wPosx1, wPosy1, wPosx2, wPosy2)
	
	for(iEntry=0; iEntry<nEntr; iEntry+=1)
		sEntry	= StringFromList(iEntry, sEntries, ".")
		sTitle	= StringByKey("title", sEntry, "=", "|")
		sType	= StringByKey("type", sEntry, "=", "|")
		sKey	= StringByKey("key", sEntry, "=", "|")
		isDummyEntry	= 0 
	
		sTemp  	= "title" +Num2Str(iEntry)
		TitleBox $(sTemp), pos={xPos, yPos +dy*iEntry}, size={dxTitle, dy} 
		TitleBox $(sTemp), title=sTitle, frame=0
	
		//s=string, u=uint32, f=float(real32), ...
		strswitch(sType)
			case "string":
				sTemp  	= "setVar_" +sKey //Num2Str(iEntry)		
				SetVariable $(sTemp), pos={xPos +dxTitle, yPos +dy*iEntry-2}, size={dxVal, 20}
				SetVariable $(sTemp), value=wValStr[iEntry],  title=" "
				sKey	= sValType_string +"_" +sKey
				wVal[iEntry]	= -1
				break
				
			case "float":
				// ...
				sKey	= sValType_float +"_" +sKey
				break					

			case "uint8":
				// ...
				sKey	= sValType_uint8 +"_" +sKey
				break					

			case "int32":
				// ...
				sKey	= sValType_int32 +"_" +sKey
				break					

			case "uint32":
				// ...
				sKey	= sValType_uint32 +"_" +sKey
				break					

			case "checkbox":
				sTemp  	= "check_" +sKey //Num2Str(iEntry)		
				CheckBox $(sTemp), pos={xPos +dxTitle-1, yPos +dy*iEntry}
				CheckBox $(sTemp), proc=FG_onFormCheckProc,  title=" "
				sKey	= sValType_bool +"_" +sKey
				break

			case "popup":
				sOpts	= StringByKey("options", sEntry, "=", "|")
				sFirst	= StringFromList(0, sOpts)	
				wValStr[iEntry]	= sOpts				
				sOpts	= "\"" +sOpts +"\""
				sTemp  	= "popup_" +sKey //Num2Str(iEntry)		
				PopupMenu $(sTemp), pos={xPos +dxTitle-6, yPos +dy*iEntry-4}
				PopupMenu $(sTemp), title=" ", proc=FG_onFormPopMenuProc
				PopupMenu $(sTemp), mode=1, popvalue=sFirst, value= #sOpts
				sKey	= sValType_string +"_" +sKey
				break

			case "subheader":
				sTemp  	= "title" +Num2Str(iEntry)
				TitleBox $(sTemp), fstyle=1
				//isDummyEntry	= 1
				sKey	= "[" +sTitle +"]"
				break

		endswitch		
		if(!isDummyEntry)
			wKeyStr[iEntry]	= sKey
		endif	
	endfor	
	
	SetWindow $(sWinName) hook(scroll)=FG_panelScrollHook
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
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			iEntr			= FG_getIndex(sValType_string +"_" +StringByKey("popup", pa.ctrlName, "_"))
			pwVal[iEntr]	= pa.popNum
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

// -------------------------------------------------------------------------------------	
//	Update form from key-value lists
//
function FG_updateForm ()

	string 		sTemp
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	SVAR		sWinName	= $("root:formGenWinName")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))

	DoWindow/F $(sWinName)
	
	for(iEntr=0; iEntr<DimSize(pwValStr, 0); iEntr+=1)
		// Update all entries
		//			
		if(StringMatch(pwKeyStr[iEntr], sValType_string +"*"))
			if(pwVal[iEntr] < 0)
				sTemp  	= "setVar_" +StringByKey(sValType_string, pwKeyStr[iEntr], "_")
				SetVariable $(sTemp), value=pwValStr[iEntr] 
			else
				sTemp  	= "popup_" +StringByKey(sValType_string, pwKeyStr[iEntr], "_")
				PopupMenu $(sTemp),mode=pwVal[iEntr]
			endif	
				
		elseif(StringMatch(pwKeyStr[iEntr], sValType_bool +"*"))
			sTemp  	= "check_" +StringByKey(sValType_bool, pwKeyStr[iEntr], "_")
			CheckBox $(sTemp), value=pwVal[iEntr]
				
		elseif(StringMatch(pwKeyStr[iEntr], sValType_uint8 +"*"))		   	       

		elseif(StringMatch(pwKeyStr[iEntr], sValType_uint32 +"*"))		   	       

		elseif(StringMatch(pwKeyStr[iEntr], sValType_int32 +"*"))
				
		elseif(StringMatch(pwKeyStr[iEntr], sValType_float +"*"))
		
		endif
	endfor
end

// -------------------------------------------------------------------------------------	
//	Update key-value lists from .ini file
//
function FG_updateKeyValueLists (sFPath, sFName)
	string		sFPath, sFName

	string 		sTemp, sFullFName, sKey, sVal
	variable	refNum, errCode, j
	variable	iEntr, len
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))

	refNum		= 0
	
	try
		// Try reading the .ini file
		//	
		sFullFName	= sFPath + "\\" +sFName +sFExt_HeaderFile
		Open/R/Z refNum as sFullFName
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
					if(pwVal[iEntr] < 0)
						pwValStr[iEntr]	= sVal
					else
						j = WhichListItem(sVal, pwValStr[iEntr])
						if(j < 0)
							printf "ERROR: Option '%s' does not exist for key '%s'\r", sVal, sKey
						else
							pwVal[iEntr]	= j+1
						endif		 
					endif		
					
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
	
	FG_updateForm()
end


function FG_getIndex (sKey)
	string 		sKey
	
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))

	for(iEntr=0; iEntr<DimSize(pwKeyStr, 0); iEntr+=1)
		if(StringMatch(pwKeyStr[iEntr], sKey))
			return iEntr
		endif			
	endfor
	return -1
end


// -------------------------------------------------------------------------------------	
// 	Saves key-value list to a experimental header file. The file must not yet exist.
//
//	sFPath		:= full or partial path to folder for the header file, w/o final "\\"
//	sFName		:= name of header file w/o file extension
//	doOverwrite	:= 0=abort if file exists; 1=overwrite file after making a backup copy
//				   (note that backup copies are overwritten) 	
//
function FG_saveToINIFile (sFPath, sFName, doOverwrite)
	string		sFPath, sFName
	variable	doOverwrite
	
	variable	refNum, errCode
	string		sFullFName, sTemp
	variable	iEntr
	SVAR		sPath		= $("root:formGenFolder")
	SVAR		sTables		= $("root:formGenTables")	
	WAVE/T		pwValStr	= $(sPath +StringFromList(0, sTables))
	WAVE/T		pwKeyStr	= $(sPath +StringFromList(1, sTables))
	WAVE		pwVal		= $(sPath +StringFromList(2, sTables))

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
				CopyFile/O sFullFName as (sFullFName +".old")
			endif	
		else
			AbortOnValue (errCode == 0), -1 // File already exists
		endif	
		
		// Now open the experiment header file for writing
		//
		Open/Z=2 refNum as sFullFName
		for(iEntr=0; iEntr<DimSize(pwValStr, 0); iEntr+=1)
			// Add all entries
			//			
			if(StringMatch(pwKeyStr[iEntr][0], "[*"))
				if(iEntr > 0)
					fprintf refNum, "\r\n"
				endif	
				fprintf refNum, "%s\r\n", pwKeyStr[iEntr]
				
			elseif(StringMatch(pwKeyStr[iEntr], sValType_string +"*"))
				if(pwVal[iEntr] < 0)
					fprintf refNum, "%s=%s\r\n", pwKeyStr[iEntr], pwValStr[iEntr]
				else	
					print pwVal[iEntr], pwKeyStr[iEntr], pwValStr[iEntr]
					fprintf refNum, "%s=%s\r\n", pwKeyStr[iEntr], StringFromList(pwVal[iEntr]-1, pwValStr[iEntr])
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
				printf "ERROR: Unknown key type (%s); ignored\r", pwKeyStr[iEntr]

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
end

// -------------------------------------------------------------------------------------	
Function FG_panelScrollHook(info)
	Struct WMWinHookStruct &info

	SVAR		sWinName	= $("root:formGenWinName")	
	NVAR		winHeight	= $("root:formGenWinHeight")
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
			if( !mouseIsOverSubWindow )
				String controls = ControlNameList(info.winName)
				ControlInfo/W=$sWinName $(StringFromList(0, controls))
				y1 	= V_top
				ControlInfo/W=$sWinName $(StringFromList(ItemsInList(controls)-1, controls))
				y2 	= V_top
				if(((info.wheelDy > 0) && (y1 <= 6)) || ((info.wheelDy < 0) && (y2 >= winHeight-24)))
					ModifyControlList controls, win=$info.winName, pos+={0,info.wheelDy*8}	// up/down
				endif	
			endif
			break
	endswitch
	return 0	// process all events normally
End

// -------------------------------------------------------------------------------------	
