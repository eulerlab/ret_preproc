// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_FileIO.ipf
//	Author		: Thomas Euler
//	Copyright	: (C) MPImF/Heidelberg, CIN/Uni Tübingen 2009-2013
//	History		: 2010-10-22 	Creation
//				  2011-02-13	Modification for "real" SMP files started
//				  2012-12-18	and before: added new header parameters, 
//								adapted for multiple frames per z-step (z-stacks)
//				  2013-03-27	Small changes to improve access by external .ipfs
//
//	Purpose		: Stand-Alone reader/writer for ScanM's SMP files
//
//	function	ScMIO_LoadSMP (sFPath, sFName, doLog)
// 		Load SMP file named 'sFName' from disk path 'sFPath' (w/o trailing '\')
//
//	function	ScMIO_SaveSMP (sDFSMP, sFPath, sFName, doLog)
//		Save data in data folder 'sDFSMP' onto disk
//
//	function	ScMIO_NewSMPDataFolder (sDFSMP)
// 		Create new SMP data folder named 'sDFSMP' and the standard waves. Assumes
//		that folder does not yet exist
//
//	function	ScMIO_KillSMPFolder (sDFSMP, doLog)	
//		Kill data folder 'sDFSMP'
//
// ----------------------------------------------------------------------------------
//	Pre-header	: 8 x uint64
//	#0		File type ID
//	#1,2	GUID
//	#3		headerlength in Bytes
//	#4		headerlength in key-value-pairs
//	#5		headerstart in bytes (from start of file) 
//	#6		length of pixel data in bytes
//	#7		length of analog data in byte
//
//	Header		: UNICODE text, organized as: type,variable_name=value;
//
// ----------------------------------------------------------------------------------
#pragma tGlobals=1		// Use modern global access method.

// ----------------------------------------------------------------------------------
// Constants that define the import behavior of this module
// -->
constant		SCMIO_addCFDNote			= 0
constant		SCMIO_integrStim_StimCh	= 2
constant		SCMIO_integrStim_TargetCh	= 0
constant		SCMIO_Stim_toFractOfMax	= 1
constant		SCMIO_to8Bits				= 0
constant		SCMIO_to8Bits_min			= 10500
constant		SCMIO_to8Bits_max			= 13200
constant		SCMIO_cropToPixelArea		= 1
constant		SCMIO_despiralTraject		= 1
strconstant		SCMIO_ChsToDespiral_List	= "0;1"	
constant		SCMIO_doShowOpenedData		= 0
constant		SCMIO_doSmartfillTrajAvg	= 1
// <--

// ----------------------------------------------------------------------------------
#include	"ScM_ScanPathFuncs"
#define 	ScM_FileIO_isDebug

// ----------------------------------------------------------------------------------
// Global definitions
//
strconstant		SCMIO_DataWavePreStr		= "DATA_"
strconstant		SCMIO_wPixDataWaveName		= "pixelData"

strconstant		SCMIO_pixelDataFileExtStr	= "smp"		
strconstant		SCMIO_headerFileExtStr		= "smh"		
strconstant 	SCMIO_configSetFileExtStr	= "scmcfs"

strconstant		SCMIO_IgorProUserFilesStr	= "Igor Pro User Files"

strconstant		SCMIO_typeKeySep			= ","
strconstant		SCMIO_keyValueSep			= "="
strconstant		SCMIO_entrySep				= ";"
strconstant		SCMIO_entryFormatStr		= "%s,%s=%s;"
strconstant		SCMIO_uint32Str			= "UINT32"
strconstant		SCMIO_uint64Str			= "UINT64"
strconstant		SCMIO_stringStr			= "String"
strconstant		SCMIO_real32Str			= "REAL32"

strconstant		SCMIO_INFStr				= "INF"
strconstant		SCMIO_NaNStr				= "NaN"

strconstant		SCMIO_StrParamWave			= "wParamsStr"
strconstant		SCMIO_NumParamWave			= "wParamsNum"
strconstant		SCMIO_StimBufMapEntrWave	= "wStimBufMapEntries"	
strconstant		SCMIO_pixDataWaveFormat	= "wDataCh%d"	

constant		SCMIO_maxStimBufMapEntries= 128
constant		SCMIO_maxStimChans			= 32
constant		SCMIO_maxInputChans		= 4		// 1024, current ScM limited

#ifndef ScM_ipf_present
constant		ScM_scanMode_XYImage		= 0
constant		ScM_scanMode_Line			= 1
constant		ScM_scanMode_Traject		= 2
// ...
constant		ScM_scanType_timelapsed	= 10
constant		ScM_scanType_zStack		= 11
// ...
#endif

strconstant 	ScM_CFDNoteStart       	= "CFD_START"	
strconstant 	ScM_CFDNoteEnd         	= "CFD_END"

#ifdef ScM_FileIO_isDebug
constant		SCMIO_doDebug				= 1
#else
constant		SCMIO_doDebug				= 0
#endif

// ----------------------------------------------------------------------------------
constant		SCMIO_preHeaderSize_bytes	= 64

Structure 		SMP_preHeaderStruct		// "uint64"
	char		fileTypeID[8]				// #0
	uint32		GUID[4]						// #1,2
	uint32		headerSize_bytes[2]		// #3	
	uint32		headerLen_pairs[2]			// #4
	uint32		headerStart_bytes[2]		// #5
	uint32		pixelDataLen_bytes[2]		// #6
	uint32		analogDataLen_bytes[2]		// #7
EndStructure

// ----------------------------------------------------------------------------------
// 	Variable type abbreviations:
//		s=string, u=uint32, f=float(real32), ...
//
strconstant		SCMIO_key_ComputerName					= "sComputerName"
strconstant		SCMIO_key_UserName						= "sUserName"
strconstant		SCMIO_key_OrigPixDataFName			= "sOriginalPixelDataFileName"
strconstant		SCMIO_key_DateStamp_d_m_y				= "sDateStamp"
strconstant		SCMIO_key_TimeStamp_h_m_s_ms			= "sTimeStamp"
strconstant		SCMIO_key_ScM_ProdVer_TargetOS		= "sScanMproductVersionAndTargetOS"
strconstant		SCMIO_key_CallingProcessPath			= "sCallingProcessPath"
strconstant		SCMIO_key_CallingProcessVer			= "sCallingProcessVersion"
strconstant		SCMIO_key_PixelSizeInBytes			= "uPixelSizeInBytes"
strconstant		SCMIO_key_StimulusChannelMask			= "uStimulusChannelMask"
strconstant		SCMIO_key_MinVolts_AO					= "fMinVoltsAO"
strconstant		SCMIO_key_MaxVolts_AO					= "fMaxVoltsAO"	
strconstant		SCMIO_key_MaxStimBufMapLen			= "uMaxStimulusBufferMapLength"
strconstant		SCMIO_key_NumberOfStimBufs			= "uNumberOfStimulusBuffers"
strconstant		SCMIO_key_InputChannelMask			= "uInputChannelMask"
strconstant		SCMIO_key_TargetedPixDur				= "fTargetedPixelDuration_µs"
strconstant		SCMIO_key_MinVolts_AI					= "fMinVoltsAI"
strconstant		SCMIO_key_MaxVolts_AI					= "fMaxVoltsAI"	
strconstant		SCMIO_key_NumberOfFrames				= "uNumberOfFrames"
strconstant		SCMIO_key_PixelOffset					= "uPixelOffset"
strconstant		SCMIO_key_HdrLenInValuePairs			= "uHeaderLengthInValuePairs"
strconstant		SCMIO_key_HdrLenInBytes				= "uHeader_length_in_bytes"
strconstant		SCMIO_key_FrameCounter					= "uFrameCounter"
strconstant		SCMIO_key_Unused0						= "uUnusedValue"

strconstant		SCMIO_key_RealPixDur					= "fRealPixelDuration_µs"
strconstant		SCMIO_key_OversampFactor				= "uOversampling_Factor"
//strconstant	SCMIO_key_XCoord_um					= "fXCoord_um"
//strconstant	SCMIO_key_YCoord_um					= "fYCoord_um"
//strconstant	SCMIO_key_ZCoord_um					= "fZCoord_um"
//strconstant	SCMIO_key_ZStep_um						= "fZStep_um"

constant		SCMIO_UserParameterCount				= 19
strconstant		SCMIO_key_USER_ScanMode				= "uScanMode"
strconstant		SCMIO_key_USER_ScanType				= "uScanType"
strconstant		SCMIO_key_USER_dxPix					= "uFrameWidth"
strconstant		SCMIO_key_USER_dyPix					= "uFrameHeight"
strconstant		SCMIO_key_USER_scanPathFunc			= "sScanPathFunc"
strconstant		SCMIO_key_USER_nPixRetrace			= "uPixRetraceLen"
strconstant		SCMIO_key_USER_nXPixLineOffs			= "uXPixLineOffs"
strconstant		SCMIO_key_USER_divFrameBufReq			= "uChunksPerFrame"
strconstant		SCMIO_key_USER_nSubPixOversamp		= "uNSubPixOversamp"
strconstant		SCMIO_key_USER_coordX					= "fXCoord_um"
strconstant		SCMIO_key_USER_coordY					= "fYCoord_um"
strconstant		SCMIO_key_USER_coordZ					= "fZCoord_um"
strconstant		SCMIO_key_USER_dZStep_um				= "fZStep_um"
strconstant		SCMIO_key_USER_zoom   					= "fZoom"
strconstant		SCMIO_key_USER_angle_deg				= "fAngle_deg"
strconstant		SCMIO_key_USER_IgorGUIVer				= "sIgorGUIVer"
strconstant		SCMIO_key_USER_NFrPerStep				= "uNFrPerStep"
strconstant		SCMIO_key_USER_offsetX_V				= "fXOffset_V"
strconstant		SCMIO_key_USER_offsetY_V				= "fYOffset_V"

strconstant		SCMIO_key_Ch_x_StimBufMapEntr_y		= "uChannel_%d_StimulusBufferMapEntry_#%d"
strconstant		SCMIO_key_StimBufLen_x					= "uStimulusBufferLength_#%d"
strconstant		SCMIO_key_Ch_x_TargetedStimDur		= "fChannel_%d_TargetedStimulusDuration_µs"
strconstant		SCMIO_key_InputCh_x_PixBufLen			= "uPixelBuffer_#%d_Length"

strconstant		SCMIO_key_AO_x_Ch_x_RealStimDur		= "fAO_%s_Channel_%d_RealStimulusDuration_µs"
// e.g.  REAL32,AO_A_Channel_0_RealStimulusDuration_µs=786432.000000

// ----------------------------------------------------------------------------------
constant		SCMIO_Param_addCFDNote					= 0
constant		SCMIO_Param_integrStim					= 1
constant		SCMIO_Param_integrStim_StimCh			= 2
constant		SCMIO_Param_integrStim_TargetCh		= 3
constant		SCMIO_Param_Stim_toFractOfMax			= 4
constant		SCMIO_Param_to8Bits					= 5
constant		SCMIO_Param_cropToPixelArea			= 6
constant		SCMIO_Param_despiralTraject			= 7
constant		SCMIO_Param_lastEntry					= 7

strconstant		SCMIO_mne_ToggleIntegrStim			= " Integrate stimulus in AI3 into AI0"

// ----------------------------------------------------------------------------------
Menu "ScanM", dynamic
	"-"
	" Load ScanM data file ...",	/Q, 	LoadSMPFileWithDialog()
	mneMacrosToggleIntegrStim(), 	/Q, 	ToggleMne_IntegrStim()
	"-"	
End

// ----------------------------------------------------------------------------------
function/WAVE CreateSCIOParamsWave ()

	variable 	doIntegrStim 	= NumVarOrDefault("root:ScMIO_doIntegrStim", 1)
	
	Make/O/N=(SCMIO_Param_lastEntry +1) wSCIOParams
	wSCIOParams		= 0
	wSCIOParams	[SCMIO_Param_addCFDNote]			= SCMIO_addCFDNote
	wSCIOParams	[SCMIO_Param_integrStim]			= doIntegrStim
	wSCIOParams	[SCMIO_Param_integrStim_StimCh]	= SCMIO_integrStim_StimCh
	wSCIOParams	[SCMIO_Param_integrStim_TargetCh]	= SCMIO_integrStim_TargetCh
	wSCIOParams	[SCMIO_Param_Stim_toFractOfMax]	= SCMIO_Stim_toFractOfMax
	wSCIOParams	[SCMIO_Param_to8Bits]				= SCMIO_to8Bits		
	wSCIOParams	[SCMIO_Param_cropToPixelArea]		= SCMIO_cropToPixelArea		
	wSCIOParams	[SCMIO_Param_despiralTraject]		= SCMIO_despiralTraject		
	return wSCIOParams
end	

// ----------------------------------------------------------------------------------
function LoadSMPFileWithDialog ()

	variable	j
	string		sDF, sSavDF
	variable	doLog
//	variable 	doIntegrStim 	= NumVarOrDefault("root:ScMIO_doIntegrStim", 1)

	sSavDF				= GetDataFolder(1)	
	WAVE wSCIOParams	= createSCIOParamsWave()
//	Make/O/N=(SCMIO_Param_lastEntry +1) wSCIOParams
//	wSCIOParams		= 0
//	wSCIOParams	[SCMIO_Param_addCFDNote]			= SCMIO_addCFDNote
//	wSCIOParams	[SCMIO_Param_integrStim]			= doIntegrStim
//	wSCIOParams	[SCMIO_Param_integrStim_StimCh]	= SCMIO_integrStim_StimCh
//	wSCIOParams	[SCMIO_Param_integrStim_TargetCh]	= SCMIO_integrStim_TargetCh
//	wSCIOParams	[SCMIO_Param_Stim_toFractOfMax]	= SCMIO_Stim_toFractOfMax
//	wSCIOParams	[SCMIO_Param_to8Bits]				= SCMIO_to8Bits		
//	wSCIOParams	[SCMIO_Param_cropToPixelArea]		= SCMIO_cropToPixelArea		
//	wSCIOParams	[SCMIO_Param_despiralTraject]		= SCMIO_despiralTraject		
	
	doLog			= 1
	sDF				= ScMIO_LoadSMP ("", "", doLog, wSCIOParams)

	if((strlen(sDF) > 0) && SCMIO_doShowOpenedData)
		SetDataFolder "root:" +sDF
		for(j=0; j<4; j+=1)
			wave pw	= $("wDataCh" +Num2Str(j))
			if(WaveExists(pw))
				NewImage/F/K=1 pw
				if(DimSize(pw, 2) > 0)
				//	WMAppend3DImageSlider();
				else
					ModifyGraph swapXY=1, height=100
					DoUpdate
					ModifyGraph tkLblRot=0 //, width={Plan,0.2,bottom,left}
				endif	
			endif	
		endfor
	endif
	KillWaves/Z wSCIOParams
	SetDataFolder $(sSavDF)
end

// ----------------------------------------------------------------------------------
function	ToggleMne_IntegrStim ()
	Variable prevMode 						= NumVarOrDefault("root:ScMIO_doIntegrStim", 1)
	Variable/G root:ScMIO_doIntegrStim	= !prevMode
end


function/S	mneMacrosToggleIntegrStim ()

	variable doIntegrStim 	= NumVarOrDefault("root:ScMIO_doIntegrStim", 1)
	if(doIntegrStim)
		return "!"+num2char(18)+SCMIO_mne_ToggleIntegrStim
	else
		return SCMIO_mne_ToggleIntegrStim
	endif
End

// ----------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------
// Create new SMP data folder named 'sDFSMP' and the standard waves 
// (Assumes that folder does not yet exist)
//
// ----------------------------------------------------------------------------------
function	ScMIO_NewSMPDataFolder (sDFSMP)
	string		sDFSMP
	
	string		sSavDF	= GetDataFolder(1)
	SetDataFolder root:
	NewDataFolder/S/O $(sDFSMP)

	Make/T/O/N=14 $(SCMIO_StrParamWave)
	wave/T wStrParams	= $(SCMIO_StrParamWave)
	SetDimLabel 0, 0, GUID,					wStrParams
	SetDimLabel 0, 1, ComputerName,			wStrParams
	SetDimLabel 0, 2, UserName,				wStrParams
	SetDimLabel 0, 3, OrigPixDataFileName,	wStrParams
	SetDimLabel 0, 4, DateStamp_d_m_y,		wStrParams
	SetDimLabel 0, 5, TimeStamp_h_m_s_ms,		wStrParams
	SetDimLabel 0, 6, ScanM_PVer_TargetOS,	wStrParams
	SetDimLabel 0, 7, CallingProcessPath,		wStrParams		
	SetDimLabel 0, 8, CallingProcessVer,		wStrParams			
	SetDimLabel 0, 9, StimBufLenList,			wStrParams				
	SetDimLabel 0,10, TargetedStimDurList,	wStrParams					
	SetDimLabel 0,11, InChan_PixBufLenList,	wStrParams		
	
	SetDimLabel 0,12, User_ScanPathFunc,		wStrParams		
	SetDimLabel 0,13, IgorGUIVer,				wStrParams	
	wStrParams			= ""				

	Make/O/N=35 $(SCMIO_NumParamWave)	
	wave wNumParams	= $(SCMIO_NumParamWave)	
	SetDimLabel 0, 0, HdrLenInValuePairs,		wNumParams				
	SetDimLabel 0, 1, HdrLenInBytes,			wNumParams		
	SetDimLabel 0, 2, MinVolts_AO,			wNumParams				
	SetDimLabel 0, 3, MaxVolts_AO,			wNumParams				
	SetDimLabel 0, 4, StimChanMask,			wNumParams					
	SetDimLabel 0, 5, MaxStimBufMapLen,		wNumParams				
	SetDimLabel 0, 6, NumberOfStimBufs,		wNumParams				
	SetDimLabel 0, 7, TargetedPixDur_us,		wNumParams				
	SetDimLabel 0, 8, MinVolts_AI,			wNumParams				
	SetDimLabel 0, 9, MaxVolts_AI,			wNumParams				
	SetDimLabel 0,10, InputChanMask,			wNumParams				
	SetDimLabel 0,11, NumberOfInputChans,		wNumParams
	SetDimLabel 0,12, PixSizeInBytes,			wNumParams				
	SetDimLabel 0,13, NumberOfPixBufsSet,		wNumParams				
	SetDimLabel 0,14, PixelOffs,				wNumParams		
	SetDimLabel 0,15, PixBufCounter,			wNumParams		
	
	SetDimLabel 0,16, User_ScanMode,			wNumParams				
	SetDimLabel 0,22, User_ScanType,			wNumParams					
	SetDimLabel 0,17, User_dxPix,				wNumParams					
	SetDimLabel 0,18, User_dyPix,				wNumParams				
	SetDimLabel 0,19, User_nPixRetrace,		wNumParams				
	SetDimLabel 0,20, User_nXPixLineOffs,		wNumParams				
	SetDimLabel 0,21, User_divFrameBufReq,	wNumParams		
	SetDimLabel 0,23, User_nSubPixOversamp,	wNumParams			
	
	SetDimLabel 0,24, RealPixDur,				wNumParams				
	SetDimLabel 0,25, OversampFactor,			wNumParams				
	SetDimLabel 0,26, XCoord_um,				wNumParams				
	SetDimLabel 0,27, YCoord_um,				wNumParams				
	SetDimLabel 0,28, ZCoord_um,				wNumParams				
	SetDimLabel 0,29, ZStep_um,				wNumParams	
	SetDimLabel 0,30, Zoom,					wNumParams	
	SetDimLabel 0,31, Angle_deg,				wNumParams	
	SetDimLabel 0,32, User_NFrPerStep,		wNumParams	
	SetDimLabel 0,33, User_XOffset_V,			wNumParams	
	SetDimLabel 0,34, User_YOffset_V,			wNumParams	
	wNumParams			= NaN		
	
	Make/O/N=(SCMIO_maxStimChans, SCMIO_maxStimBufMapEntries), $(SCMIO_StimBufMapEntrWave)		
	
	SetDataFolder $(sSavDF)
end	

// ----------------------------------------------------------------------------------
// 	Load SMP file from disk ...
//
// ----------------------------------------------------------------------------------
function/T	ScMIO_LoadSMP (sFPath, sFName, doLog, pwSCIOParams)
	string		sFPath, sFName
	variable	doLog
	wave		pwSCIOParams 
	
	variable	doAddCFDNote, doIntStim, StimCh, TargetCh
	variable	fileHnd, j, iInCh, dx, dy, m, n, nAICh, iPixBPerCh
	variable	nHdr_bytes, nHdr_pairs, iPixB, nPixB, PixBLen, nFr
	string		sTemp, sSavDF, sDFName, sHeader, sWave
	struct		SMP_preHeaderStruct	preHdr
	variable	pixRetrace, pixOffs, iAvFr
	variable	isFirst, dxRecon, dyRecon, isAvZStack, nFrPerStep
	variable   dxNew, dyNew, nFrNew
	
	// Initialize
	//
	fileHnd			= 0
	sSavDF			= GetDataFolder(1)	
	sDFName			= ""
	doAddCFDNote	= pwSCIOParams[SCMIO_Param_addCFDNote]			
	doIntStim		= pwSCIOParams[SCMIO_Param_integrStim]			
	StimCh			= pwSCIOParams[SCMIO_Param_integrStim_StimCh]			
	TargetCh		= pwSCIOParams[SCMIO_Param_integrStim_TargetCh]			
	// ...	
	
	try
		// Open data file
		//
		if((strlen(sFPath) == 0) || strlen(sFName) == 0)
			sprintf sTemp, "ScanM Pixel Heaser File (*.%s):.%s;", SCMIO_headerFileExtStr, SCMIO_headerFileExtStr
			Open/R/D=1/F=(sTemp) fileHnd as (sFPath +"\\" +sFName)
			AbortOnValue (strlen(S_fileName) == 0), 10
			fileHnd	= 0			
			Open/Z/R fileHnd as (S_fileName)
			sFName	= ParseFilePath(3, S_fileName, ":", 0, 0)
			sFPath	= ParseFilePath(1, S_fileName, ":", 1, 0)
			sFPath	= ParseFilePath(5, sFPath, "*", 0, 0)			
		else	
			sFPath += "\\"
			Open/Z/R fileHnd as (sFPath +sFName +"." +SCMIO_headerFileExtStr)
		endif	
		AbortOnValue (V_flag != 0), 2
		writeToLog("Load .SMH file '%s' ...\r", sFName, doLog, 0)		

		// Make a folder for data and waves
		//
		SetDataFolder root:
	//	AbortOnValue (DataFolderExists(sDFName)), 5
		sDFName						= "SMP_" +sFName	
		sDFName						= ReplaceString("-", sDFName, "")
		sDFName						= ReplaceString(" ", sDFName, "_")		
		ScMIO_NewSMPDataFolder(sDFName)
		DoUpdate
		SetDataFolder $(sDFName)
		wave/T pwSP					= $(SCMIO_StrParamWave)
		wave pwNP					= $(SCMIO_NumParamWave)
		wave pwStimBufMapEntries	= $(SCMIO_StimBufMapEntrWave)	

		// ---------------------------------------------------------------------------
		// Read binary pre-header and check if beginning of file
		// indicates correct type
		//
		FBinRead/B=0 fileHnd, preHdr
		sTemp		= ""		
		for(j=0; j<8; j+=2)
			sTemp 	+= num2char(preHdr.fileTypeID[j])
		endfor
		AbortOnValue (stringmatch(SCMIO_headerFileExtStr, sTemp) == 0), 3
		
		// Handle GUID ...
		//
	//	pwSP[%pwSP]		= 
		// ...
	
		// Skip to text header
		//
		if(preHdr.headerStart_bytes[0] > SCMIO_preHeaderSize_bytes)
			// ...
			AbortOnValue 1, 4
		endif 		

		// ---------------------------------------------------------------------------
		// Read in header
		//
		nHdr_bytes	= preHdr.headerSize_bytes[0]
		nHdr_pairs	= preHdr.headerLen_pairs[0]			
		Make/O/B/U/N=(nHdr_bytes) wHdr
		FBinRead/B=0 fileHnd, wHdr
		sHeader		= ""
		for(j=0; j<nHdr_bytes; j+=2)
			if((wHdr[j] == 13) && (wHdr[j+2] == 10))
				j			+= 2
			elseif(wHdr[j] > 32)
				sHeader		+= num2char(wHdr[j])
			endif
		endfor	
		
		// Extract header parameters
		//
		ScMIO_HdrStr2Params(sHeader)
		
		// Close header file and open pixel data file
		//
		Close fileHnd
		Open/Z/R fileHnd as (sFPath +sFName +"." +SCMIO_pixelDataFileExtStr)
		AbortOnValue (V_flag != 0), 6
		
		// ---------------------------------------------------------------------------
		// Read in pixel data
		//	
		isAvZStack	= (pwNP[%User_ScanType] == ScM_scanType_zStack)	&& (pwNP[%User_NFrPerStep] > 1)	
		nFrPerStep	= (isAvZStack)?(pwNP[%User_NFrPerStep]):(1)
		dx			= pwNP[%User_dxPix]
		dy			= pwNP[%User_dyPix]
		PixBLen		= Str2Num(StringFromList(0, pwSP[%InChan_PixBufLenList]))		
		if(pwNP[%NumberOfPixBufsSet] == pwNP[%PixBufCounter])
			nPixB	= pwNP[%NumberOfPixBufsSet] *(dx*dy /PixBLen)
		else	
			nPixB	= (pwNP[%NumberOfPixBufsSet] -pwNP[%PixBufCounter])*(dx*dy /PixBLen)	
		endif	
		nPixB		= nPixB *nFrPerStep
		
		nAICh		= pwNP[%NumberOfInputChans]
		sprintf sTemp, "%d AI channels (0x%.4b)\r", nAICh, pwNP[%InputChanMask]
		writeToLog(sTemp, "", doLog, 0)
		sprintf sTemp, "%d of %d buffers (each %d pixels) per channel\r", nPixB, pwNP[%NumberOfPixBufsSet], PixBLen
		writeToLog(sTemp, "", doLog, 0)		
		
		// Make waves for pixel data, one per AI channel
		//
		for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
			if(pwNP[%InputChanMask] & (2^iInCh))
				sprintf sWave, SCMIO_pixDataWaveFormat, iInCh
				AbortOnValue ((pwNP[%PixSizeInBytes] != 2) && (pwNP[%PixSizeInBytes] != 8)), 7
				switch (pwNP[%PixSizeInBytes])
					case 8:
						Make/D/O/N=(nPixB/nFrPerStep *PixBLen) $(sWave)	
					//	Make/D/O/N=(nPixB *PixBLen) $(sWave)	
						break
					case 2:
						Make/U/W/O/N=(nPixB/nFrPerStep *PixBLen) $(sWave)	
					//	Make/U/W/O/N=(nPixB *PixBLen) $(sWave)							
						break
				endswitch			
				wave pwPixData	= $(sWave) 
				pwPixData		= 0				
			endif	
		endfor
		switch (pwNP[%PixSizeInBytes])
			case 8:
				Make/D/O/N=(dx, PixBLen/dx) $("wPixB")
				break
			case 2:
				Make/U/W/O/N=(dx, PixBLen/dx) $("wPixB")
				break
		endswitch
		wave pwPixB		= $("wPixB") 
		pwPixB			= 0				
		
		
		// Load pixel data buffer by buffer in the AI channel waves			
		//
		iPixB	= 0
		iAvFr	= 0
		if(isAvZStack)
			// is z-stack with more than one frame per step, requires
			// averaging ...
			//
			for(iPixBPerCh=0; iPixBPerCh<nPixB; iPixBPerCh+=1)
				for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
					if(pwNP[%InputChanMask] & (2^iInCh))
						sprintf sWave, SCMIO_pixDataWaveFormat, iInCh
						wave pwPixData	= $(sWave)
						Redimension/E=1/N=(PixBLen) wPixB
						FBinRead/B=0 fileHnd, wPixB
						Redimension/E=1/N=(dx, PixBLen/dx) wPixB
						m 					= trunc(iPixBPerCh/nFrPerStep)*PixBLen
						n					= (trunc(iPixBPerCh/nFrPerStep)+1)*PixBLen -1
						if(iAvFr == 0)							
							pwPixData[m,n]	= pwPixB[p-m]								
						elseif(iAvFr < (nFrPerStep-1))
							pwPixData[m,n]	+= pwPixB[p-m]	
						else	
							pwPixData[m,n]	+= pwPixB[p-m]								
							pwPixData[m,n] /= nFrPerStep
						endif	
						iPixB			+= 1
					//	DoUpdate
					endif
				endfor
				// ***ACCOUNT FOR SEVERAL BUFFERS PER FRAME***
				iAvFr		+= 1
				if(iAvFr >= nFrPerStep)
					iAvFr	= 0
				endif	
			endfor		
		else
			// w/o frame averaging (as usual)
			//
			for(iPixBPerCh=0; iPixBPerCh<nPixB; iPixBPerCh+=1)
				for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
					if(pwNP[%InputChanMask] & (2^iInCh))
						sprintf sWave, SCMIO_pixDataWaveFormat, iInCh
						wave pwPixData	= $(sWave)
						Redimension/E=1/N=(PixBLen) wPixB
						FBinRead/B=0 fileHnd, wPixB
						Redimension/E=1/N=(dx, PixBLen/dx) wPixB
						m 				= iPixBPerCh*PixBLen
						n				= (iPixBPerCh+1)*PixBLen -1
						pwPixData[m,n]	= pwPixB[p-m]	
						iPixB			+= 1
					//	DoUpdate
					endif
				endfor
			endfor		
		endif	

		// Post-process data waves according to user settings
		//
		variable tmpCh0_min, tmpCh0_max, tmpCh1_min, tmpCh1_max
		variable used_min, used_max
		variable nSorted
		tmpCh0_min = 0
		tmpCh0_max = 0
		tmpCh1_min = 0
		tmpCh1_max = 0
		isFirst		= 1
		
		for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
			if(pwNP[%InputChanMask] & (2^iInCh))
				sprintf sWave, SCMIO_pixDataWaveFormat, iInCh
				wave pwPixData	= $(sWave)
				
				// Add wave note in CFD style, if requested
				//
				if((iInCh == 0) && doAddCFDNote)
					ScMIO_writeParamsToNotes(pwPixData, 0)
				endif	
				
				// Reshape AI channel pixel waves
				//
				switch(	pwNP[%User_ScanMode])
					case 10:
					case ScM_scanMode_XYImage :
						nFr	= (nPixB/nFrPerStep*PixBLen) /(dx*dy) 
						Redimension/E=1/N=(dx, dy, nFr) pwPixData									
						break					
					case ScM_scanMode_Line		:
					case ScM_scanMode_Traject :
						Redimension/E=1/N=(dx, nPixB *PixBLen /dx) pwPixData									
						break
				endswitch		

				// Remove offset and retrace regions of frames, if requested
				// (ScM_scanMode_XYImage only)
				//
				if(pwSCIOParams[SCMIO_Param_cropToPixelArea])
					if(pwNP[%User_ScanMode] == ScM_scanMode_XYImage)
						// e.g. String,ScanPathFunc=XYScan2|5120|80|64|10|6;
						//
						pixRetrace		= Str2Num(StringFromList(4, pwSP[%User_ScanPathFunc], "|"))
						pixOffs			= Str2Num(StringFromList(5, pwSP[%User_ScanPathFunc], "|"))				
						DeletePoints 0, pixOffs, pwPixData
						DeletePoints dx-pixOffs-pixRetrace, pixRetrace, pwPixData
					endif	
				endif	

				// Convert data to unsigned 8 bit, if requested
				//
				if(pwSCIOParams[SCMIO_Param_to8Bits])
					Redimension/S pwPixData
					if((iInCh == 0) || (iInCh == 1))
						Wavestats/Q pwPixData
						printf "#%d:\tmin/max\t%.0f ... %.0f (mean=%.0f +/- %.0f)\r", iInCh, V_min, V_max, V_avg, V_sdev
					
//						dxNew		= Dimsize(pwPixData, 0)
//						dyNew		= Dimsize(pwPixData, 1)
//						nFrNew		= Dimsize(pwPixData, 2)
//						Duplicate/O pwPixData, pwPixDataSorted 
//						Redimension/E=0/N=(dxNew*dyNew*nFrNew) pwPixDataSorted 	
//						Resample/DOWN=2 pwPixDataSorted				
//						Sort pwPixDataSorted, pwPixDataSorted
//						nSorted		= DimSize(pwPixDataSorted, 0)
						switch (iInCh)
						 	case 0:
								//tmpCh0_min	= mean(pwPixDataSorted, 0, nSorted*0.005) 
								//tmpCh0_max	= mean(pwPixDataSorted, nSorted*0.995, nSorted)	
								//printf "\t\t1percent\t%.0f ... %.0f\r", tmpCh0_min, tmpCh0_max
								tmpCh0_min	= V_avg -V_sdev*25 
								tmpCh0_max	= V_avg +V_sdev*25 
								printf "\t\t+/-25 DS\t%.0f ... %.0f\r", tmpCh0_min, tmpCh0_max
							    break
							case 1:     	
								tmpCh1_min	= V_avg -V_sdev*25
								tmpCh1_max	= V_avg +V_sdev*25
								printf "\t\t+/-25 DS\t%.0f ... %.0f\r", tmpCh1_min, tmpCh1_max
							    break
						endswitch	    
						//KillWaves/Z pwPixDataSorted
						if(iInCh == 0)
							wave pwPixDataCh0	= pwPixData
						endif	
						if(iInCh == 1)
							if(tmpCh0_min < tmpCh1_min)
								used_min 	= tmpCh0_min
							else
								used_min 	= tmpCh1_min
							endif	
							if(tmpCh0_max > tmpCh1_max)
								used_max 	= tmpCh0_max
							else
								used_max 	= tmpCh1_max
							endif	
							//pwPixData	-= SCMIO_to8Bits_min 
							//pwPixData	/= SCMIO_to8Bits_max -SCMIO_to8Bits_min 
							//printf "\t\tused\t%.0f ... %.0f)\r",  SCMIO_to8Bits_min, SCMIO_to8Bits_max 
							pwPixData		-= used_min 
							pwPixData		/= used_max -used_min 
							pwPixData		*= 255
							pwPixDataCh0	-= used_min 
							pwPixDataCh0	/= used_max -used_min 
							pwPixDataCh0	*= 255
							printf "\t\t#0+#1\t%.0f ... %.0f)\r",  used_min, used_max 
							
						endif	
					endif	
					
					if(iInCh == StimCh) 
						pwPixData	-= V_Min 
						pwPixData	/= V_Max -V_Min 
						pwPixData	*= 255
						printf "\t\tused\t%.0f ... %.0f)\r",  V_Min, V_Max 
					endif
					Redimension/B/U pwPixData					
				endif	
		
				// "Despiral" trajectories
				// (ScM_scanMode_Traject only)
				//
				if(pwSCIOParams[SCMIO_Param_despiralTraject])
					if(pwNP[%User_ScanMode] == ScM_scanMode_Traject)
						// e.g. SpiralScan1|4032|1|317|64
						//	
						if(WhichListItem(Num2Str(iInCh), SCMIO_ChsToDespiral_List) >= 0)
							if(isFirst)
								dxRecon	= 75
								dyRecon	= 75
								Prompt dxRecon, 	"# x pixels"
								Prompt dyRecon, 	"# y pixels"								
								DoPrompt "Reconstructed frame size:", dxRecon, dyRecon		
								isFirst	= 0														
							endif	
							despiral(iInCh, dxRecon, dyRecon, SCMIO_doDebug, SCMIO_doSmartfillTrajAvg)
						endif
					endif
				endif
			endif
		endfor		
		
		// Integrate stimulus channel into first (leftmost) column of a data channel
		//
		if(doIntStim)
			sprintf sWave, SCMIO_pixDataWaveFormat, StimCh
			wave pwStim			= $(sWave)
			sprintf sWave, SCMIO_pixDataWaveFormat, TargetCh
			wave pwTarg			= $(sWave)
			if(WaveExists(pwStim) && WaveExists(pwTarg))
				pwStim			*= pwSCIOParams[SCMIO_Param_Stim_toFractOfMax]			
				pwTarg[0][][]	= pwStim[0][q][r]	
				KillWaves/Z pwStim
			endif
		endif	

	catch 
		switch (V_AbortCode)
			case 2:
				writeToLog("", "Header (smh) file not found", doLog, -1)
				break
			case 3:
				writeToLog("", "Wrong file type", doLog, -1)
				break
			case 4:
 				writeToLog("", "INTERNAL, longer pre-header not implemented", doLog, -1)
 				break
			case 5:
 				writeToLog("", "Data folder already exists", doLog, -1)
 				break
			case 6:
 				writeToLog("", "Pixel data (smp) file not found", doLog, -1)
 				break
			case 7:
 				writeToLog("", "Pixel size not yet implemented", doLog, -1)
 				break
//			case 8:
// 				writeToLog("", "Incomplete pixel buffers in file?!", doLog, -1)
// 				break
			case 10:
 				writeToLog("", "Aborted by user", doLog, -1)
 				break
 				
		endswitch	
		KillWaves/Z pwSP, pwNP, pwStimBufMapEntries
		sDFName	= ""
	endtry	
	
	// Close file and clean up
	//
	if(fileHnd != 0)
		Close fileHnd
	endif	
	KillWaves/Z wHdr
	SetDataFolder $(sSavDF)
	
	if(strlen(sDFName) > 0)
		writeToLog(" done.\r", "", doLog, 0)	
	endif	
	return sDFName
end

// ----------------------------------------------------------------------------------
//	Save data in data folder 'sDFSMP' onto disk
//
// ----------------------------------------------------------------------------------
//function	ScMIO_SaveSMP (sDFSMP, sFPath, sFName, doLog)
//	string		sDFSMP, sFPath, sFName
//	variable	doLog
//	
//	variable	fileHnd, Result, iInCh, j
//	string		sSavDF, sTemp, sDFPath, swDataChList, sWave, sHdr, sVal
//	struct		SMP_preHeaderStruct preHdr
//	
//	// Initialize
//	//
//	fileHnd		= 0
//	Result		= 0
//	sSavDF		= GetDataFolder(1)	
//	sDFPath		= "root:" +sDFSMP
//	// ...
//	writeToLog("Save data in '%s' to .SMP file ...", sDFSMP, doLog, 0)
//	
//	try	
//		// Check if data folder exists ...
//		SetDataFolder root:
//		AbortOnValue (!DataFolderExists(sDFPath)), 2
//		
//		// ... and if it contains the required data
//		//
//		sWave					= sDFPath +":" +SCMIO_StrParamWave
//		AbortOnValue (!WaveExists($(sWave))), 3
//		wave/T pwSP				= $(sWave)
//		sWave					= sDFPath +":" +SCMIO_NumParamWave		
//		AbortOnValue (!WaveExists($(sWave))), 3
//		wave pwNP				= $(sWave)
//		sWave					= sDFPath +":" +SCMIO_StimBufMapEntrWave				
//		AbortOnValue (!WaveExists($(sWave))), 3
//		wave pwStimBufMapEntrs	= $(sWave)
//		
//		sWave					= sDFPath +":" +SCMIO_DataWavePreStr +SCMIO_wPixDataWaveName
//		AbortOnValue (!WaveExists($(sWave))), 3
//		wave pwPixelData		= $(sWave)
//		
//		// Check if file already exists, open dialog to allow user to change the name
//		//
//		Open/R/Z fileHnd as (sFPath +"\\" +sFName +"." +SCMIO_pixelDataFileExtStr)
//		if(strlen(S_fileName) > 0)
//			// File already exists, open dialog ...
//			//
//			Close fileHnd
//			
//			fileHnd		= 0
//			sprintf sTemp, "ScanM Pixel Data File (*.%s):.%s;", SCMIO_pixelDataFileExtStr, SCMIO_pixelDataFileExtStr
//			Open/D=1/F=(sTemp) fileHnd as (sFPath +"\\" +sFName)
//			AbortOnValue (strlen(S_fileName) == 0), 4
//			Open fileHnd as (S_fileName)			
//		else
//			Open fileHnd as (sFPath +"\\" +sFName +"." +SCMIO_pixelDataFileExtStr)
//		endif
//		
//		// ---------------------------------------------------------------------------
//		// Compile header
//		//
//		switch (WaveType(pwPixelData, 0))
//			case 0x04:	// 64-bit float
//				pwNP[%PixSizeInBytes]	= 8
//				break
//			// ...	
//		endswitch	
//		
//		sHdr	= ""
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_ComputerName, 			pwSP[%ComputerName])
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_UserName, 				pwSP[%UserName])
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_OrigPixDataFName,		pwSP[%OrigPixDataFileName])
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_DateStamp_d_m_y, 		pwSP[%DateStamp_d_m_y])
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_TimeStamp_h_m_s_ms,	pwSP[%TimeStamp_h_m_s_ms])
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_ScM_ProdVer_TargetOS,	pwSP[%ScanM_PVer_TargetOS])										
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_CallingProcessPath, 	pwSP[%CallingProcessPath])		
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_CallingProcessVer, 	pwSP[%CallingProcessVer])				
//		
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_PixelSizeInBytes, 	pwNP[%PixSizeInBytes])				
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_StimulusChannelMask, 	pwNP[%StimChanMask])				
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_MinVolts_AO, 			pwNP[%MinVolts_AO])				
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_MaxVolts_AO, 			pwNP[%MaxVolts_AO])				
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_MaxStimBufMapLen, 	pwNP[%MaxStimBufMapLen])				
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_NumberOfStimBufs, 	pwNP[%NumberOfStimBufs])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_InputChannelMask, 	pwNP[%InputChanMask])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_TargetedPixDur, 		pwNP[%TargetedPixDur_us])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_MinVolts_AI, 			pwNP[%MinVolts_AI])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_MaxVolts_AI, 			pwNP[%MaxVolts_AI])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_NumberOfFrames, 		pwNP[%NumberOfFrames])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_PixelOffset, 			pwNP[%PixelOffs])	
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_FrameCounter, 			pwNP[%FrameCounter])			
//
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_USER_ScanMode, 		pwNP[%User_ScanMode])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_USER_dxPix, 			pwNP[%User_dxPix])																
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_USER_dyPix, 			pwNP[%User_dyPix])																				
//		sHdr	+= ScMIO_getHrdStrEntry(SCMIO_key_USER_scanPathFunc, 	pwSP[%User_ScanPathFunc])																				
//		// ...
//
//		//	pwSP[%StimBufLenList]	=
//		//strconstant		SCMIO_key_StimBufLen_x					= "uStimulusBufferLength_#_%d"
//
//		//	pwStimBufMapEntrs
//		//strconstant		SCMIO_key_Ch_x_StimBufMapEntr_y		= "uChannel_%d_StimulusBufferMapEntry_#_%d"	
//
//		//	pwSP[%TargetedStimDurList]	=
//		//strconstant		SCMIO_key_Ch_x_TargetedStimDur		= "uChannel_%d_TargetedStimulusDuration"
//
//		//	pwSP[%InChan_PixBufLenList]	=
//		//strconstant		SCMIO_key_InputCh_x_PixBufLen			= "uInputChannel_%d_PixelBufferLength"
//
//		pwNP[%HdrLenInValuePairs]	= ItemsInList(sHdr, SCMIO_entrySep) +2
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_HdrLenInValuePairs, 	pwNP[%HdrLenInValuePairs])																
//		sTemp	= ScMIO_getHrdNumEntry(SCMIO_key_HdrLenInBytes, 	1)	
//		pwNP[%HdrLenInBytes]		= strlen(sHdr) +strlen(sTemp) +15
//		sHdr	+= ScMIO_getHrdNumEntry(SCMIO_key_HdrLenInBytes, 		pwNP[%HdrLenInBytes]*2)
//		sHdr						= padstring(sHdr, pwNP[%HdrLenInBytes], 0x20)		
//	//	print ">>" +sHdr[650,strlen(sHdr)] +"<<", pwNP[%HdrLenInBytes], strlen(sHdr)		
//
//		// ---------------------------------------------------------------------------
//		// Compile and write pre-header
//		// (Header size in byte x2 because of Unicode ...)
//		//
//		preHdr.fileTypeID				= "S" +num2char(0) +"M" +num2char(0) +"P" +num2char(0)
//		preHdr.GUID	[0]					= 0					// *** TODO [4]
//		preHdr.GUID	[1]					= 0					// *** TODO [4]
//		preHdr.GUID	[2]					= 0					// *** TODO [4]
//		preHdr.GUID	[3]					= 0					// *** TODO [4]						
//		preHdr.headerSize_bytes[0]	= pwNP[%HdrLenInBytes]*2
//		preHdr.headerSize_bytes[1]	= 0
//		preHdr.	headerLen_pairs[0]		= pwNP[%HdrLenInValuePairs]
//		preHdr.	headerLen_pairs[1]		= 0	
//		preHdr.headerStart_bytes[0]	= SCMIO_preHeaderSize_bytes
//		preHdr.headerStart_bytes[1]	= 0
//	//	preHdr.notUsed[]				= 0					// *** TODO [4]
//		FBinWrite/B=3/F=0 fileHnd, preHdr	
//
//		// ---------------------------------------------------------------------------
//		// Write header
//		//
//		Make/O/B/U/N=(pwNP[%HdrLenInBytes]*2) wHdr		
//		wHdr			= 0
//		for(j=0; j<pwNP[%HdrLenInBytes]; j+=1)
//			wHdr[j*2]	= char2num(sHdr[j])
//		endfor	
//		FBinWrite/B=3/F=0 fileHnd, wHdr			
//				
//		// ---------------------------------------------------------------------------
//		// Write data ...
//		// (Multiplexed, as it comes from the recording)
//		//
//		FBinWrite/B=3/F=0 fileHnd, pwPixelData
//			
//	catch 
//		switch (V_AbortCode)
//			case 2:
//				writeToLog("", "Data folder not found", doLog, -1)
//				break
//			case 3:
//				writeToLog("", "Data wave(s) '"+ sWave +"' are missing", doLog, -1)
//				break
//			case 4:
// 				writeToLog("", "Aborted by used", doLog, -1)
// 				break
//		endswitch	
//		Result	= -1
//	endtry	
//	
//	// Close file and clean up
//	//
//	if(fileHnd != 0)
//		Close fileHnd
//	endif	
//	SetDataFolder $(sSavDF)
//	
//	if(Result == 0)
//		writeToLog(" done.\r", "", doLog, 0)	
//	endif	
//	return Result
//end

// ----------------------------------------------------------------------------------
// Kill data folder 'sDFSMP'
//
// ----------------------------------------------------------------------------------
function	ScMIO_KillSMPFolder (sDFSMP, doLog)	
	string		sDFSMP
	variable	doLog	

	variable	iInCh, Result
	string		sSavDF, sDFPath, sWave

	sSavDF		= GetDataFolder(1)	
	sDFPath		= "root:" +sDFSMP
	Result		= 0	
	// ...
	writeToLog("Kill data folder '%s' ...", sDFSMP, doLog, 0)
	
	try	
		// Check if data folder exists ...
		SetDataFolder root:
		AbortOnValue (!DataFolderExists(sDFPath)), 2
		SetDataFolder $(sDFPath)
				
		// Kill waves ...
		//
		KillWaves/Z/A

		// Find where waves are used and remove them there??
		//
		// ...		
//		wave pwSP	= $(sDFPath +":" +SCMIO_StrParamWave)
//		wave pwNP	= $(sDFPath +":" +SCMIO_NumParamWave)
//		wave pw3	= $(sDFPath +":" +SCMIO_StimBufMapEntrWave)
//		
//		for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
//			if((pwNP[%InputChanMask] & (2^iInCh)) > 0)
//				sprintf sWave, SCMIO_pixDataWaveFormat, iInCh
//				wave pw		= $(sDFPath +":" +sWave)
//				KillWaves/Z pw
//			endif	
//		endfor	
//		KillWaves/Z pwSP, pwNP, pw3

	catch 
		switch (V_AbortCode)
			case 2:
				writeToLog("", "Data folder not found", doLog, -1)
				break
		endswitch	
		Result	= -1
	endtry	
	
	// Clean up
	//
	SetDataFolder $(sSavDF)
	
	if(Result == 0)
		writeToLog(" done.\r", "", doLog, 0)	
	endif	
	return Result
end

// ==================================================================================
// ----------------------------------------------------------------------------------
static function	writeToLog (sMsg, sInfo, doLog, isError)
	string		sMsg, sInfo
	variable	doLog, isError
	
	if(doLog)
		if(isError)
			printf "### ERROR:\t%s\r", sInfo
		else	
			if(strlen(sInfo) == 0)
				printf sMsg
			else	
			    printf sMsg, sInfo
			endif		    
		endif    
	endif  
end

// ----------------------------------------------------------------------------------
// Converts extracts parameter from header string and writes them into the standard
// waves in the current folder (waves must already been created and labeled)
//   s 			:= the header in string format
//
static function	ScMIO_HdrStr2Params (s)
	string		s
	
	variable	nE, iE, nEDone, nEDonePrev, iBuf, iInCh, n, iStCh
	string		sTemp, sKey, sType, sVal, sTypeCh			

	// Get wave references and clear waves
	//	
	wave/T pwSP					= $(SCMIO_StrParamWave)
	wave pwNP					= $(SCMIO_NumParamWave)
	wave pwStimBufMapEntries	= $(SCMIO_StimBufMapEntrWave)	
	pwSP						= ""
	pwNP						= 0
	pwStimBufMapEntries		= 0	
	// ...							
	
	// Parse string
	//	
	nE			= ItemsInList(s, SCMIO_entrySep)
	nEDone		= 0
	nEDonePrev	= 0
	
	for(iE=0; iE<nE; iE+=1)
		sTemp	= StringFromList(iE, s, SCMIO_entrySep)	
		if(strlen(sTemp) == 0)
			continue
		endif	
	//	printf "%.2d %s\r", iE, sTemp
		
		sType	= LowerStr(StringFromList(0, sTemp, SCMIO_typeKeySep))
		sTemp	= StringFromList(1, sTemp, SCMIO_typeKeySep)
		sKey	= StringFromList(0, sTemp, SCMIO_keyValueSep)		
		sVal	= StringFromList(1, sTemp, SCMIO_keyValueSep)			

		strswitch (sType)
			case "string"	:
				sTemp		= "s" +sKey
				if(stringmatch(sTemp,		SCMIO_key_ComputerName))
					pwSP[%ComputerName]			= sVal
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_UserName))
					pwSP[%UserName]				= sVal
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_OrigPixDataFName))
					pwSP[%OrigPixDataFileName]	= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_DateStamp_d_m_y))
					pwSP[%DateStamp_d_m_y]			= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_TimeStamp_h_m_s_ms))
					pwSP[%TimeStamp_h_m_s_ms]		= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_ScM_ProdVer_TargetOS))
					pwSP[%ScanM_PVer_TargetOS]	= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_CallingProcessPath))
					pwSP[%CallingProcessPath]		= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_CallingProcessVer))
					pwSP[%CallingProcessVer]		= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_IgorGUIVer))
					pwSP[%IgorGUIVer]				= sVal				
					nEDone	+= 1
					
				// --> USER	
				elseif(stringmatch(sTemp,	SCMIO_key_USER_scanPathFunc))
					pwSP[%User_ScanPathFunc]		= sVal				
					nEDone	+= 1
				// <--					
				endif	
				break
					
			case "uint32"	:
			case "uint64"	:			
				sTemp		= "u" +sKey
				if(stringmatch(sTemp,		SCMIO_key_PixelSizeInBytes))
					pwNP[%PixSizeInBytes]			= str2num(sVal)
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_StimulusChannelMask))
					pwNP[%StimChanMask]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_MaxStimBufMapLen))
					pwNP[%MaxStimBufMapLen]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_NumberOfStimBufs))
					pwNP[%NumberOfStimBufs]		= str2num(sVal)				
					nEDone	+= 1
					
				elseif(stringmatch(sTemp,	SCMIO_key_InputChannelMask))
					pwNP[%InputChanMask]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_NumberOfFrames))
					pwNP[%NumberOfPixBufsSet]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_PixelOffset))
					pwNP[%PixelOffs]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_HdrLenInValuePairs))
					pwNP[%HdrLenInValuePairs]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_HdrLenInBytes))
					pwNP[%HdrLenInBytes]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_FrameCounter))
					pwNP[%PixBufCounter]			= str2num(sVal)				
					nEDone	+= 1
					
				elseif(stringmatch(sTemp,	SCMIO_key_OversampFactor))
					pwNP[%OversampFactor]			= str2num(sVal)				
					nEDone	+= 1
					
				// --> USER	
				elseif(stringmatch(sTemp,	SCMIO_key_USER_ScanMode))
					pwNP[%User_ScanMode]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_ScanType))
					pwNP[%User_ScanType]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dxPix))
					pwNP[%User_dxPix]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dyPix))
					pwNP[%User_dyPix]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_nPixRetrace))
					pwNP[%User_nPixRetrace]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_nXPixLineOffs))
					pwNP[%User_nXPixLineOffs]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_divFrameBufReq))
					pwNP[%User_divFrameBufReq]	= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_nSubPixOversamp))
					pwNP[%User_nSubPixOversamp]	= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_NFrPerStep))
					pwNP[%User_NFrPerStep]			= str2num(sVal)				
					nEDone	+= 1
				// ...	
				// <-- 
				elseif(stringmatch(sTemp,	SCMIO_key_Unused0))
					nEDone	+= 1
				endif			
				break

			case "real32"	:
				sTemp		= "f" +sKey			
				if(stringmatch(sTemp,	SCMIO_key_MinVolts_AO))
					pwNP[%MinVolts_AO]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_MaxVolts_AO))
					pwNP[%MaxVolts_AO]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_MinVolts_AI))
					pwNP[%MinVolts_AI]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_MaxVolts_AI))
					pwNP[%MaxVolts_AI]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_TargetedPixDur))
					pwNP[%TargetedPixDur_us]		= str2num(sVal)				
					nEDone	+= 1
					
				elseif(stringmatch(sTemp,	SCMIO_key_RealPixDur))
					pwNP[%RealPixDur]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_OversampFactor))
					pwNP[%OversampFactor]			= str2num(sVal)				
					nEDone	+= 1
					
				elseif(stringmatch(sTemp,	SCMIO_key_USER_coordX))
					pwNP[%XCoord_um]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_coordY))
					pwNP[%YCoord_um]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_coordZ))
					pwNP[%ZCoord_um]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dZStep_um))
					pwNP[%ZStep_um]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_zoom))
					pwNP[%Zoom]						= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_angle_deg))
					pwNP[%Angle_deg]				= str2num(sVal)				
					nEDone	+= 1

				elseif(stringmatch(sTemp,	SCMIO_key_USER_offsetX_V))
					pwNP[%ser_XOffset_V]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_offsetY_V))
					pwNP[%ser_YOffset_V]			= str2num(sVal)				
					nEDone	+= 1
					
				endif					
				break
				
			default			:
				sprintf sTemp, "Type (%s) in entry #%d not recognized", sType, iE
				writeToLog("", sTemp, 1, -1)
		endswitch		
		if(nEDone > nEDonePrev)
			RemoveRecogEntry(s, sType + SCMIO_typeKeySep +sKey)
			iE 		-= 1
		endif
		nEDonePrev	= nEDone	
	endfor

	// Retrieve list of stim buffer lengths and targeted durations	
	//
	for(iBuf=0; iBuf<pwNP[%NumberOfStimBufs]; iBuf+=1)
		n		= strlen(SCMIO_key_StimBufLen_x)
		sTemp	= SCMIO_uint32Str +SCMIO_typeKeySep +SCMIO_key_StimBufLen_x[1,n]
		sprintf sKey, sTemp, iBuf
		sVal	= StringByKey(sKey, s, SCMIO_keyValueSep, SCMIO_entrySep, 0) 
		if(strlen(sVal) > 0)
			pwSP[%StimBufLenList]			+= sVal +SCMIO_entrySep
			RemoveRecogEntry(s, sKey)
			nEDone	+= 1			
		endif
		
		n		= strlen(SCMIO_key_Ch_x_TargetedStimDur)		
		sTemp	= SCMIO_real32Str +SCMIO_typeKeySep +SCMIO_key_Ch_x_TargetedStimDur[1,n]
		sprintf sKey, sTemp, iBuf
		sVal	= StringByKey(sKey, s, SCMIO_keyValueSep, SCMIO_entrySep, 0) 
		if(strlen(sVal) > 0)
			pwSP[%TargetedStimDurList]	+= sVal +SCMIO_entrySep
			RemoveRecogEntry(s, sKey)			
			nEDone	+= 1			
		endif
	endfor

	// Retrieve stimulus buffer map
	//	
	for(iStCh=0; iStCh<SCMIO_maxStimChans; iStCh+=1)	
		if((pwNP[%StimChanMask] & (2^iStCh)) > 0)
			for(iE=0; iE<pwNP[%MaxStimBufMapLen]; iE+=1)
				n		= strlen(SCMIO_key_Ch_x_StimBufMapEntr_y)
				sTemp	= SCMIO_uint32Str +"," +SCMIO_key_Ch_x_StimBufMapEntr_y[1,n]
				sprintf sKey, sTemp, iStCh, iE
				sVal	= StringByKey(sKey, s, SCMIO_keyValueSep, SCMIO_entrySep, 0) 
				if(strlen(sVal) > 0)
					pwStimBufMapEntries[iStCh][iE]	= str2num(sVal)
					RemoveRecogEntry(s, sKey)					
					nEDone	+= 1			
				endif
			endfor
		endif	
	endfor
	
	// Retrieve list of input channel pixel buffer lengths
	// (number of pixel puffer is continous, NOT equal to the AI channel index!)
	//
	pwNP[%NumberOfInputChans]	= 0
	for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
		if((pwNP[%InputChanMask] & (2^iInCh)) > 0)
			n			= strlen(SCMIO_key_InputCh_x_PixBufLen)
			sTemp		= SCMIO_uint32Str +"," +SCMIO_key_InputCh_x_PixBufLen[1,n]
			sprintf sKey, sTemp, pwNP[%NumberOfInputChans]
			sVal		= StringByKey(sKey, s, SCMIO_keyValueSep, SCMIO_entrySep, 0) 
			if(strlen(sVal) > 0)
				pwSP[%InChan_PixBufLenList]	+= sVal +SCMIO_entrySep
				pwNP[%NumberOfInputChans]		+= 1
				RemoveRecogEntry(s, sKey)				
				nEDone	+= 1			
			endif	
		endif
	endfor		
	
	if(nEDone < nE)
		sprintf sTemp, "Only %d of %d key-value pairs recognized, remaining:", nEDone, nE
		writeToLog("", sTemp, 1, -1)	
		
		for(iE=0; iE<ItemsInList(s); iE+=1)
			sTemp	= StringFromList(iE, s, SCMIO_entrySep) +"\r"	
			writeToLog(sTemp, "", 1, 0)	
		endfor
	endif	
end

// ----------------------------------------------------------------------------------
static function	RemoveRecogEntry(sList, sKey)
	string		&sList, sKey
	
	string		sTemp
	variable	sListLen	= strlen(sList)
	sList		= RemoveByKey(sKey, sList, SCMIO_keyValueSep, SCMIO_entrySep, 0)
	if(strlen(sList) == sListLen)
		sprintf sTemp, "INTERNAL: Entry '%s' could not be removed from list", sKey
		writeToLog("", sTemp, 1, -1)	
	else	
#ifdef ScM_FileIO_isDebug
		sprintf sTemp, "ok: key=%s\r", sKey
		writeToLog(sTemp, "", 1, 0)	
#endif	
	endif
end	

// ----------------------------------------------------------------------------------
static function/T	ScMIO_getHrdStrEntry (sKey, sVal)
	string 		sKey, sVal		

	string		sType, sRes
	string		sKey1	= sKey[1,strlen(sKey)-1]
	
	strswitch (sKey[0])
		case "s":
			sType	= SCMIO_stringStr
			break
		case "u":
			sType	= SCMIO_uint32Str
			break
		case "l":	
			sType	= SCMIO_uint64Str
			break
		case "f":
			sType	= SCMIO_real32Str
			break
	endswitch
	sRes	= sType +SCMIO_typeKeySep +sKey1 +SCMIO_keyValueSep +sVal +SCMIO_entrySep 
	return sRes +"\r\n"
end


static function/T	ScMIO_getHrdNumEntry (sKey, nVal)
	string 		sKey
	variable	nVal

	string		sType, sVal, sRes
	string		sKey1	= sKey[1,strlen(sKey)-1]

	switch (numtype(nVal))
		case 0:
			sVal	= num2str(nVal)		
			break			
		case 1:
			sVal	= SCMIO_INFStr
			break
		case 2:
			sVal	= SCMIO_NaNStr
			break
	endswitch		
	strswitch (sKey[0])
		case "u":
			sType	= SCMIO_uint32Str
			break
		case "l":	
			sType	= SCMIO_uint64Str
			break
		case "f":
			sType	= SCMIO_real32Str
			sprintf sVal, "%.10f", nVal			
			break
	endswitch
	sRes	= sType +SCMIO_typeKeySep +sKey1 +SCMIO_keyValueSep +sVal +SCMIO_entrySep 	
	return sRes +"\r\n"
end

// ----------------------------------------------------------------------------------
// To mimic the internal CFD format of the xCDFReader write important parameters to 
// wave note
//  
static function	ScMIO_writeParamsToNotes (pwPixData, iAICh)
	wave 		pwPixData	
	variable	iAICh

	string		sTemp, sTemp2, sNA
	variable	nPixB, PixBLen, nPixPFr, nFr
	
	wave/T pwSP					= $(SCMIO_StrParamWave)
	wave pwNP					= $(SCMIO_NumParamWave)
	wave pwStimBufMapEntries	= $(SCMIO_StimBufMapEntrWave)	
	sNA							= "n/a"
	
	Note/K pwPixData
	sTemp  = "CFD_Version="  +Num2Str(999) +";"
	sTemp += "CFD_FName="    +pwSP[%OrigPixDataFileName] +";"
 	sTemp += "CFD_User="     +pwSP[%UserName] +";"  
    
  	sTemp += "CFD_RecTime="  +sNA +";"  
  	sTemp += "CFD_RecDate="  +sNA +";"  
  	sTemp += "CFD_GrbStart=" +sNA +";"  
  	sTemp += "CFD_GrbStop="  +sNA +";"  
  
//  constant	CFDIsUndefined	= 0
//	constant   	CFDIsLineScan  = 1
//	constant   	CFDIsXYSeries 	= 2
//	constant   	CFDIsZStack   	= 3
	switch(pwNP[%User_ScanMode])
		case ScM_scanMode_XYImage	:
			sTemp2	= "2"
			break
		case ScM_scanMode_Line		:	
		case ScM_scanMode_Traject	:	
			sTemp2	= "1"		
			break
	endswitch		
  	sTemp += "CFD_ImgType="  +sTemp2 +";"  
  	sTemp += "CFD_nChan="    +Num2Str(pwNP[%NumberOfInputChans]) +";"    
  	sTemp += "CFD_dx="       +Num2Str(pwNP[%User_dxPix]) +";"        
  	sTemp += "CFD_dy="       +Num2Str(pwNP[%User_dyPix]) +";"        
  	
	nPixB	= pwNP[%NumberOfPixBufsSet] -pwNP[%PixBufCounter]	
	PixBLen	= Str2Num(StringFromList(0, pwSP[%InChan_PixBufLenList]))
	nPixPFr	= PixBLen*nPixB
	nFr		= nPixPFr /(pwNP[%User_dxPix] *pwNP[%User_dyPix])
  	sTemp += "CFD_nFr="      +Num2Str(nFr) +";"  
  	sTemp += "CFD_nFrAvg="   +Num2Str(1) +";" 
  	sTemp += "CFD_SplitFr="  +Num2Str(1) +";"            
  
	sTemp += "CFD_msPerLn="  +Num2Str(pwNP[%TargetedPixDur_us]*pwNP[%User_dxPix] *1000) +";"  
  	sTemp += "CFD_msPerRt="  +Num2Str(0) +";"    

  	sTemp += "CFD_ScnOffX="  +Num2Str(0) +";"          
  	sTemp += "CFD_ScnOffY="  +Num2Str(0) +";"          
  	sTemp += "CFD_ScnRgeX="  +Num2Str(5) +";"          
  	sTemp += "CFD_ScnRgeY="  +Num2Str(5) +";"       
  
//  sTemp2 = Num2Str(Str2Num(pwInfo[10][1])/1000)
//  sTemp += "CFD_SutX0_um=" +sTemp2 +";"  
//  sTemp2 = Num2Str(Str2Num(pwInfo[11][1])/1000)
//  sTemp += "CFD_SutY0_um=" +sTemp2 +";"  
//  sTemp2 = Num2Str(Str2Num(pwInfo[ 9][1])/1000)
//  sTemp += "CFD_SutZ0_um=" +sTemp2 +";"  
//  sTemp2 = Num2Str(Str2Num(pwInfo[25][1])/1000)
//  sTemp += "CFD_SutX1_um=" +sTemp2 +";"  
//  sTemp2 = Num2Str(Str2Num(pwInfo[26][1])/1000)
//  sTemp += "CFD_SutY1_um=" +sTemp2 +";"  
//  sTemp2 = Num2Str(Str2Num(pwInfo[27][1])/1000)
//  sTemp += "CFD_SutZ1_um=" +sTemp2 +";"     
  
//  	sTemp2 = StrRemoveTrailingChars(pwInfo[23][1], "\00")        
//  	sTemp += "CFD_Orient="   +sTemp2 +";"  
//  	sTemp2 = StrRemoveTrailingChars(pwInfo[24][1], "\00")          
//  	sTemp += "CFD_ZoomFac="  +sTemp2 +";"  
//  
//  	sTemp += "CFD_zIncr_nm="  +Num2Str(ACVzInc)  

//	if((pwACVFlagSet & 0x0001) >0)
//  	sTemp += "CFD_F_Pol=1;"
//	else
// 		sTemp += "CFD_F_Pol=0;"    
//	endif  
//	if((pwACVFlagSet & 0x0100) >0)
//  	sTemp += "CFD_F_LnScn=1;"
//	else
//  	sTemp += "CFD_F_LnScn=0;"    
//	endif  
//	if((pwACVCFlags & 0x0100) >0)
//  	sTemp += "CFD_F_ZStack=1;"
//	else
//  	sTemp += "CFD_F_ZStack=0;"    
//	endif  

  	Note pwPixData, ScM_CFDNoteStart +";CFD_Chn=" +Num2Str(iAICh) +";" +sTemp +";" +ScM_CFDNoteEnd
end	

// ----------------------------------------------------------------------------------
