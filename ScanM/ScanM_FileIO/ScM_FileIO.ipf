// ----------------------------------------------------------------------------------
//	Project		: ScanMachine (ScanM)
//	Module		: ScM_FileIO.ipf
//	Author		: Thomas Euler
//	Copyright	: (C) MPImF/Heidelberg, CIN/Uni Tübingen 2009-2016
//	History		: 2010-10-22 	Creation
//				  2011-02-13	Modification for "real" SMP files started
//				  2012-12-18	and before: added new header parameters, 
//								adapted for multiple frames per z-step (z-stacks)
//				  2013-03-27	Small changes to improve access by external .ipfs
//				  2016-01-28	Experimental YZ-scans (w/electrical lens) started
//				  2016-08-23	Cleaned up a bit, fixed the problem of multiple output
//								buffers per frame and added frame aspect ratio	  		
//				  2016-08-26	Fixed stupid bug		
//				  2017-01-30	Added the possibility to define external scan path
//								functions that are loaded from files
//				  2017-02-27	Supplemented the header with z scan and arbitrary
//								scan parameters	
//				  2017-05-29	Added ability to includeexternal user functions
//								(in "User Procedures\ScanM" matching "usr_*.ipf") 
//       		  2017-07-07	Bug fix	 	 
//				  2017-08-10	Bug fix and checked for compatibitity to Igor7 32bit 
//				  2017-08-19	Added the ability to recreate stimBufData for
//				  				reconstructing/decoding the scans	
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
constant		SCMIO_addCFDNote				= 0
constant		SCMIO_integrStim_StimCh		= 2
constant		SCMIO_integrStim_TargetCh		= 0
constant		SCMIO_doIntegrStim_default	= 0
constant		SCMIO_Stim_toFractOfMax		= 0
constant		SCMIO_to8Bits					= 0
constant		SCMIO_to8Bits_min				= 10500
constant		SCMIO_to8Bits_max				= 13200
constant		SCMIO_cropToPixelArea			= 1
constant		SCMIO_despiralTraject			= 1
strconstant		SCMIO_ChsToDespiral_List		= "0;1"	
constant		SCMIO_doShowOpenedData			= 0
constant		SCMIO_doSmartfillTrajAvg		= 1
// <--

// ----------------------------------------------------------------------------------
#include	"ScM_ScanPathFuncs"
//#define 	ScM_FileIO_isDebug

// ----------------------------------------------------------------------------------
// Global definitions
//
strconstant		SCMIO_DataWavePreStr			= "DATA_"
strconstant		SCMIO_wPixDataWaveName			= "pixelData"

strconstant		SCMIO_pixelDataFileExtStr		= "smp"		
strconstant		SCMIO_headerFileExtStr			= "smh"		
strconstant 	SCMIO_configSetFileExtStr		= "scmcfs"

strconstant		SCMIO_IgorProUserFilesStr		= "Igor Pro User Files"
strconstant		SCMIO_ScanPathFuncFilesStr	= "User Procedures\\ScanM\\"
strconstant		SCMIO_ScanPathFuncFileMask	= "spf_*.ipf"

strconstant		SCMIO_UserFuncFilesStr			= "User Procedures\\ScanM\\"
strconstant		SCMIO_UserFuncFileMask			= "usr_*.ipf"

strconstant		SCMIO_stimBufFolder			= "ScM_stimBufs"
strconstant		SCMIO_stimBufListName			= "wStimBufList"
strconstant		SCMIO_stimBufInfoWaveName		= "wStimBufInfo"
strconstant		SCMIO_scanDecCountMatrixName	= "countMatrix"

strconstant		SCMIO_typeKeySep				= ","
strconstant		SCMIO_keyValueSep				= "="
strconstant		SCMIO_entrySep					= ";"
strconstant		SCMIO_entryFormatStr			= "%s,%s=%s;"
strconstant		SCMIO_uint32Str				= "UINT32"
strconstant		SCMIO_uint64Str				= "UINT64"
strconstant		SCMIO_stringStr				= "String"
strconstant		SCMIO_real32Str				= "REAL32"

strconstant		SCMIO_INFStr					= "INF"
strconstant		SCMIO_NaNStr					= "NaN"

strconstant		SCMIO_StrParamWave				= "wParamsStr"
strconstant		SCMIO_NumParamWave				= "wParamsNum"
strconstant		SCMIO_StimBufMapEntrWave		= "wStimBufMapEntries"	
strconstant		SCMIO_pixDataWaveRawFormat	= "wDataCh%d_raw"	
strconstant		SCMIO_pixDataWaveDecodeFormat	= "wDataCh%d"	

strconstant		SCMIO_TrajParamWave			= "wTrajParams"	

constant		SCMIO_maxStimBufMapEntries	= 128
constant		SCMIO_maxStimChans				= 32
constant		SCMIO_maxInputChans			= 4		// 1024, current ScM limited
constant		SCMIO_maxTrajParams			= 100

#ifndef ScM_ipf_present
constant		ScM_scanMode_XYImage			= 0
//constant		ScM_scanMode_Line				= 1
//constant		ScM_scanMode_Traject			= 2
constant 		ScM_scanMode_XYZImage			= 3		// xy planes stacked along z
constant 		ScM_scanMode_XZYImage			= 4		// xz sections stacked along y (x is fastest scanner)
constant 		ScM_scanMode_ZXYImage			= 5		// zx sections stacked along y (z is fastest scanner)
constant		ScM_scanMode_TrajectArb		= 6
//constant		ScM_scanMode_XZImage			= 7		// ??

// ...
constant		ScM_scanType_timelapsed		= 10
constant		ScM_scanType_zStack			= 11
// ...
#endif

strconstant 	ScM_CFDNoteStart       		= "CFD_START"	
strconstant 	ScM_CFDNoteEnd         		= "CFD_END"

#ifdef ScM_FileIO_isDebug
constant		SCMIO_doDebug					= 1
#else
constant		SCMIO_doDebug					= 0
#endif

// ----------------------------------------------------------------------------------
constant		SCMIO_preHeaderSize_bytes		= 64

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
strconstant		SCM_usr_AutoScale				= "usr_AutoScale"

function	ScM_UserAutoScaleFunc (wFrame, scaler, newMin, newMax)
	WAVE		wFrame
	variable	scaler
	variable	&newMin, &newMax
end

// ----------------------------------------------------------------------------------
// 	Variable type abbreviations:
//		s=string, u=uint32, f=float(real32), ...
//
strconstant	SCMIO_key_ComputerName					= "sComputerName"
strconstant	SCMIO_key_UserName						= "sUserName"
strconstant	SCMIO_key_OrigPixDataFName			= "sOriginalPixelDataFileName"
strconstant	SCMIO_key_DateStamp_d_m_y				= "sDateStamp"
strconstant	SCMIO_key_TimeStamp_h_m_s_ms			= "sTimeStamp"
strconstant	SCMIO_key_ScM_ProdVer_TargetOS		= "sScanMproductVersionAndTargetOS"
strconstant	SCMIO_key_CallingProcessPath			= "sCallingProcessPath"
strconstant	SCMIO_key_CallingProcessVer			= "sCallingProcessVersion"
strconstant	SCMIO_key_PixelSizeInBytes			= "uPixelSizeInBytes"
strconstant	SCMIO_key_StimulusChannelMask			= "uStimulusChannelMask"
strconstant	SCMIO_key_MinVolts_AO					= "fMinVoltsAO"
strconstant	SCMIO_key_MaxVolts_AO					= "fMaxVoltsAO"	
strconstant	SCMIO_key_MaxStimBufMapLen			= "uMaxStimulusBufferMapLength"
strconstant	SCMIO_key_NumberOfStimBufs			= "uNumberOfStimulusBuffers"
strconstant	SCMIO_key_InputChannelMask			= "uInputChannelMask"
strconstant	SCMIO_key_TargetedPixDur				= "fTargetedPixelDuration_µs"
strconstant	SCMIO_key_MinVolts_AI					= "fMinVoltsAI"
strconstant	SCMIO_key_MaxVolts_AI					= "fMaxVoltsAI"	
strconstant	SCMIO_key_NumberOfFrames				= "uNumberOfFrames"
strconstant	SCMIO_key_PixelOffset					= "uPixelOffset"
strconstant	SCMIO_key_HdrLenInValuePairs			= "uHeaderLengthInValuePairs"
strconstant	SCMIO_key_HdrLenInBytes				= "uHeader_length_in_bytes"
strconstant	SCMIO_key_FrameCounter					= "uFrameCounter"
strconstant	SCMIO_key_Unused0						= "uUnusedValue"

strconstant	SCMIO_key_RealPixDur					= "fRealPixelDuration_µs"
strconstant	SCMIO_key_OversampFactor				= "uOversampling_Factor"
//strconstant	SCMIO_key_XCoord_um				= "fXCoord_um"
//strconstant	SCMIO_key_YCoord_um				= "fYCoord_um"
//strconstant	SCMIO_key_ZCoord_um				= "fZCoord_um"
//strconstant	SCMIO_key_ZStep_um					= "fZStep_um"

constant		SCMIO_UserParameterCount			= 41
strconstant		SCMIO_key_USER_ScanMode			= "uScanMode"
strconstant		SCMIO_key_USER_ScanType			= "uScanType"
strconstant		SCMIO_key_USER_dxPix				= "uFrameWidth"
strconstant		SCMIO_key_USER_dyPix				= "uFrameHeight"
strconstant		SCMIO_key_USER_dzPix				= "udZPixels"
strconstant		SCMIO_key_USER_scanPathFunc		= "sScanPathFunc"
strconstant		SCMIO_key_USER_nPixRetrace		= "uPixRetraceLen"
strconstant		SCMIO_key_USER_nXPixLineOffs		= "uXPixLineOffs"
strconstant		SCMIO_key_USER_nYPixLineOffs		= "uYPixLineOffs"
strconstant		SCMIO_key_USER_nZPixLineOffs		= "uZPixLineOffs"
strconstant		SCMIO_key_USER_divFrameBufReq		= "uChunksPerFrame"
strconstant		SCMIO_key_USER_nSubPixOversamp	= "uNSubPixOversamp"
strconstant		SCMIO_key_USER_coordX				= "fXCoord_um"
strconstant		SCMIO_key_USER_coordY				= "fYCoord_um"
strconstant		SCMIO_key_USER_coordZ				= "fZCoord_um"
strconstant		SCMIO_key_USER_dZStep_um			= "fZStep_um"
strconstant		SCMIO_key_USER_zoom   				= "fZoom"
strconstant		SCMIO_key_USER_angle_deg			= "fAngle_deg"
strconstant		SCMIO_key_USER_IgorGUIVer			= "sIgorGUIVer"
strconstant		SCMIO_key_USER_NFrPerStep			= "uNFrPerStep"
strconstant		SCMIO_key_USER_offsetX_V			= "fXOffset_V"
strconstant		SCMIO_key_USER_offsetY_V			= "fYOffset_V"
//strconstant	SCMIO_key_USER_nZPixRetrace		= "uZPixRetraceLen"
//strconstant	SCMIO_key_USER_usesZForFastScan	= "uUsesZForFastScan"
strconstant		SCMIO_key_USER_Comment				= "sComment"
strconstant		SCMIO_key_USER_SetupID				= "uSetupID"
strconstant		SCMIO_key_USER_LaserWavelen_nm	= "uLaserWavelength_nm"
strconstant		SCMIO_key_USER_Objective			= "sObjective"
//strconstant	SCMIO_key_USER_ZLensScaler		= "uZLensScaler"
//strconstant	SCMIO_key_USER_ZLensShifty		= "uZLensShifty"
strconstant		SCMIO_key_USER_aspectRatioFrame	= "fAspectRatioFrame"
strconstant		SCMIO_key_USER_stimBufPerFr		= "uStimBufPerFr"
strconstant		SCMIO_key_USER_iChFastScan		= "uiChFastScan"
//strconstant		SCMIO_key_USER_noYScan				= "unoYScan"
strconstant		SCMIO_key_USER_dxFrDecoded		= "udxFrDecoded"
strconstant		SCMIO_key_USER_dyFrDecoded		= "udyFrDecoded"
strconstant		SCMIO_key_USER_dzFrDecoded		= "udzFrDecoded"
strconstant		SCMIO_key_USER_trajDefVRange_V	= "ftrajDefVRange_V"
strconstant		SCMIO_key_USER_nTrajParams		= "unTrajParams"
//strconstant	SCMIO_key_USER_trajParams_mask	= "fTrajParams_*"
strconstant		SCMIO_key_USER_zoomZ  				= "fzoomFactorZ"
strconstant		SCMIO_key_USER_offsetZ_V  		= "foffsetZ_V"
strconstant		SCMIO_key_USER_zeroZ_V				= "fzeroZ_V"
strconstant		SCMIO_key_USER_ETL_polarity		= "fETL_polarity_V"
strconstant		SCMIO_key_USER_ETL_minV			= "fETL_min_V"
strconstant		SCMIO_key_USER_ETL_maxV			= "fETL_max_V"
strconstant		SCMIO_key_USER_ETL_neutralV		= "fETL_neutral_V"
// ...

//strconstant	SCMIO_key_USER_trajParams_x		= "fTrajParams_%d"
strconstant		SCMIO_key_Ch_x_StimBufMapEntr_y	= "uChannel_%d_StimulusBufferMapEntry_#%d"
strconstant		SCMIO_key_StimBufLen_x				= "uStimulusBufferLength_#%d"
strconstant		SCMIO_key_Ch_x_TargetedStimDur	= "fChannel_%d_TargetedStimulusDuration_µs"
strconstant		SCMIO_key_InputCh_x_PixBufLen		= "uPixelBuffer_#%d_Length"

strconstant		SCMIO_key_AO_x_Ch_x_RealStimDur	= "fAO_%s_Channel_%d_RealStimulusDuration_µs"
// e.g.  REAL32,AO_A_Channel_0_RealStimulusDuration_µs=786432.000000

// ----------------------------------------------------------------------------------
constant		SCMIO_Param_addCFDNote				= 0
constant		SCMIO_Param_integrStim				= 1
constant		SCMIO_Param_integrStim_StimCh		= 2
constant		SCMIO_Param_integrStim_TargetCh	= 3
constant		SCMIO_Param_Stim_toFractOfMax		= 4
constant		SCMIO_Param_to8Bits				= 5
constant		SCMIO_Param_cropToPixelArea		= 6
constant		SCMIO_Param_despiralTraject		= 7
constant		SCMIO_Param_lastEntry				= 7

strconstant		SCMIO_mne_ToggleIntegrStim		= " Integrate stimulus in AI3 into AI0"

// ----------------------------------------------------------------------------------
Menu "ScanM", dynamic
	"-"
	" Load ScanM data file ...",	/Q, 	LoadSMPFileWithDialog()
	mneMacrosToggleIntegrStim(),	/Q, 	ToggleMne_IntegrStim()
	"-"	
End

// ----------------------------------------------------------------------------------
function/WAVE CreateSCIOParamsWave ()

	variable 	doIntegrStim 	= NumVarOrDefault("root:ScMIO_doIntegrStim", SCMIO_doIntegrStim_default)
	
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
	
#ifndef ScM_ipf_present
 	// ##########################
	// 2017-01-30, -05-29 CHANGED TE ==>
	ScM_LoadExternalScanPathFuncs()
	ScM_LoadExternalIPFs()
	// <==	
#endif	

	doLog	= 1
	sDF		= ScMIO_LoadSMP ("", "", doLog, wSCIOParams)

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
	Variable prevMode 						= NumVarOrDefault("root:ScMIO_doIntegrStim", SCMIO_doIntegrStim_default)
	Variable/G root:ScMIO_doIntegrStim	= !prevMode
end


function/S	mneMacrosToggleIntegrStim ()

	variable doIntegrStim 	= NumVarOrDefault("root:ScMIO_doIntegrStim", SCMIO_doIntegrStim_default)
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

	Make/T/O/N=17 $(SCMIO_StrParamWave)
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
	SetDimLabel 0,14, User_Comment,			wStrParams		
	SetDimLabel 0,15, User_Objective,			wStrParams		
	SetDimLabel 0,16, RealStimDurList,		wStrParams					
	wStrParams			= ""				

	Make/O/N=60 $(SCMIO_NumParamWave)	
	wave wNumParams	= $(SCMIO_NumParamWave)	
	SetDimLabel 0, 0, HdrLenInValuePairs,	wNumParams				
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
	
	SetDimLabel 0,35, User_dzPix,				wNumParams		
	SetDimLabel 0,37, User_nZPixLineOff,		wNumParams		

	SetDimLabel 0,39, User_SetupID,			wNumParams		
	SetDimLabel 0,40, User_LaserWaveLen_nm,	wNumParams		
	
	SetDimLabel 0,43, User_aspectRatioFr,		wNumParams
	SetDimLabel 0,44, User_stimBufPerFr,		wNumParams
	
	SetDimLabel 0,45, User_nYPixLineOffs,		wNumParams		
	SetDimLabel 0,45, User_nYPixLineOffs,		wNumParams		
	SetDimLabel 0,46, User_iChFastScan,		wNumParams		
	SetDimLabel 0,47, User_noYScan,			wNumParams		
	SetDimLabel 0,48, User_dxFrDecoded,		wNumParams		
	SetDimLabel 0,49, User_dyFrDecoded,		wNumParams		
	SetDimLabel 0,50, User_dzFrDecoded,		wNumParams		

	SetDimLabel 0,51, User_trajDefVRange_V,	wNumParams		
	SetDimLabel 0,52, User_nTrajParams,		wNumParams		
	SetDimLabel 0,53, User_zoomZ,				wNumParams		
	SetDimLabel 0,54, User_offsetZ_V,			wNumParams		
	SetDimLabel 0,55, User_zeroZ_V,			wNumParams
	
	SetDimLabel 0,56, User_ETL_polarity_V,	wNumParams
	SetDimLabel 0,57, User_ETL_min_V,			wNumParams
	SetDimLabel 0,58, User_ETL_max_V,			wNumParams
	SetDimLabel 0,59, User_ETL_neutral_V,		wNumParams
		
	Make/O/N=(SCMIO_maxStimChans, SCMIO_maxStimBufMapEntries), $(SCMIO_StimBufMapEntrWave)		
	Make/O/N=(SCMIO_maxTrajParams), $(SCMIO_TrajParamWave)		
	
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
	variable	fileHnd, j, iInCh, m, n, o, nAICh, iPixBPerCh
	variable	nHdr_bytes, nHdr_pairs, iPixB, nPixB, PixBLen, nFr
	string		sTemp, sSavDF, sDFName, sHeader, sWave, sTemp2, sUserScanFName
	string		sWaveRaw, sWaveDecode, sWaveDecodeAv 
	struct		SMP_preHeaderStruct	preHdr
	variable	iAvFr
	variable	isFirst, dxRecon, dyRecon, isAvZStack, nFrPerStep
	variable   dxNew, dyNew, nFrNew
	variable	dFast, nFastPixRetr, nFastPixOff
	variable	dSlow1, dSlow2, nPixPerFr
	variable	iStimBuf
	variable	dxFrDecode, dyFrDecode, dzFrDecode, nPixDecodeFr
	string 		sPixDataRawFormat, sPixDataDecodeFormat
	variable	isExtSPF, isDecoded, iCh, iPixBAllCh, nBufPerFr
	
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
		// ---------------------------------------------------------------------------
		// Open SMH file
		//
		if((strlen(sFPath) == 0) || strlen(sFName) == 0)
			sprintf sTemp, "ScanM Pixel Header File (*.%s):.%s;", SCMIO_headerFileExtStr, SCMIO_headerFileExtStr
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
		sDFName						= "SMP_" +sFName	
		sDFName						= ReplaceString("-", sDFName, "")
		sDFName						= ReplaceString(" ", sDFName, "_")		
		ScMIO_NewSMPDataFolder(sDFName)
		DoUpdate
		SetDataFolder $(sDFName)
		wave/T pwSP					= $(SCMIO_StrParamWave)
		wave pwNP					= $(SCMIO_NumParamWave)
		wave pwStimBufMapEntries	= $(SCMIO_StimBufMapEntrWave)	

		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		// Read binary pre-header and check if beginning of file
		// indicates correct type of file
		//
		FBinRead/B=0 fileHnd, preHdr
		sTemp		= ""		
		for(j=0; j<8; j+=2)
			sTemp 	+= num2char(preHdr.fileTypeID[j])
		endfor
		AbortOnValue (stringmatch(SCMIO_headerFileExtStr, sTemp) == 0), 3
		
		// Skip to text header
		//
		if(preHdr.headerStart_bytes[0] > SCMIO_preHeaderSize_bytes)
			// ...
			AbortOnValue 1, 4
		endif 		

		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		// Read in header
		//
		nHdr_bytes	= preHdr.headerSize_bytes[0] -SCMIO_preHeaderSize_bytes
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
		
		// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		// Extract header parameters
		//
		ScMIO_HdrStr2Params(sHeader)
		
		// Handle GUID ...
		//
		pwSP[%GUID]			= ""		
		for(j=0; j<4; j+=1)
			sprintf sTemp, "%.8X", preHdr.GUID[j]
			pwSP[%GUID]		+= sTemp
		endfor

		// Close header file
		//
		Close fileHnd
		
		
		// ---------------------------------------------------------------------------
		// Recreate stimulus buffer, if required
		//
		WAVE	pwInfo	= ScM_getStimBufInfo(sDFName)
		iStimBuf		=  pwInfo[%stimBufIndex] 
		sprintf sTemp, "root:%s:%s", SCMIO_stimBufFolder, SCMIO_stimBufListName
		WAVE/T	pwStimBufList	= $(sTemp)
		sUserScanFName	= stringfromlist(0, pwStimBufList[iStimBuf], "|")
		
		// Copy stimulus buffer and related waves temporarily to the data folder
		//
		sTemp2			= "wScanPathFuncParams"
		sprintf sTemp, "root:%s:%s_%d", SCMIO_stimBufFolder, sTemp2, iStimBuf
		Duplicate/O $(sTemp), $(sTemp2)
		WAVE pwScanPathFuncParams	= $(sTemp2)
		sTemp2			= "wStimBufData"		
		sprintf sTemp, "root:%s:%s_%d", SCMIO_stimBufFolder, sTemp2, iStimBuf
		Duplicate/O $(sTemp), $(sTemp2)
		WAVE pwStimBufData			= $(sTemp2)
		if(pwInfo[%hasCountMatrix])
			sTemp2		= SCMIO_scanDecCountMatrixName		
			sprintf sTemp, "root:%s:%s_%d", SCMIO_stimBufFolder, sTemp2, iStimBuf
			Duplicate/O $(sTemp), $(sTemp2)
			WAVE pwCountMatrix		= $(sTemp2)
		endif	
		
		// If external scan path function, create scan decoder function
		//
		if(pwInfo[%isExtScanFunction]) 
			FUNCREF ScM_ScanPathDecodeProtoFunc fDecode	= $(sUserScanFName + "_decode")
		endif

		
		// ---------------------------------------------------------------------------
		// Open SMP file and read in pixel data
		//	
		Open/Z/R fileHnd as (sFPath +sFName +"." +SCMIO_pixelDataFileExtStr)
		AbortOnValue (V_flag != 0), 6
		
		isAvZStack	= (pwNP[%User_ScanType] == ScM_scanType_zStack)	&& (pwNP[%User_NFrPerStep] > 1)	
		nFrPerStep	= (isAvZStack)?(pwNP[%User_NFrPerStep]):(1)
		switch(pwNP[%User_ScanMode])
			case ScM_scanMode_XYImage		:
			case ScM_scanMode_TrajectArb	:
				dFast			= pwNP[%User_dxPix]	
				nFastPixRetr	= pwNP[%User_nPixRetrace]		
				nFastPixOff		= pwNP[%User_nXPixLineOffs]		
				dSlow1			= pwNP[%User_dyPix]	
				dSlow2			= pwNP[%User_dzPix]	
				// ##########################
				// 2017-07-07 CHANGED TE ==>						
				if(dSlow1 == 0)
					dSlow1		= 1
				endif	
				if(dSlow2 == 0)
					dSlow2		= 1
				endif	
				// <==
				
				if(pwNP[%User_ScanMode] == ScM_scanMode_TrajectArb)
					// ##########################				
					// TODO LR ==>
					// <==
				endif
				break

			case ScM_scanMode_XZYImage	:
				dFast			= pwNP[%User_dxPix]				
				nFastPixRetr	= pwNP[%User_nPixRetrace]		
				nFastPixOff		= pwNP[%User_nXPixLineOffs]		
				dSlow1			= pwNP[%User_dzPix]	
				dSlow2			= pwNP[%User_dyPix]			
				break

			case ScM_scanMode_ZXYImage	:
				dFast			= pwNP[%User_dzPix]				
				nFastPixRetr	= pwNP[%User_nPixRetrace]		
				nFastPixOff		= pwNP[%User_nZPixLineOffs]		
				dSlow1			= pwNP[%User_dxPix]	
				dSlow2			= pwNP[%User_dyPix]			
				break
				
		//	case ScM_scanMode_XYZImage	:
			default							:
				AbortOnValue 1, 9
				break
		endswitch		
		
	 	// ##########################
		// 2016-08-24 CHANGED TE ==>
		// Correct number of pixel buffers, because it is not correctly reported 
		// by the ScanM.dll if one stimulus buffer contained the data for multiple
		// frames (i.e. cp.stimBufPerFr != 1)
		//
		if(pwNP[%User_stimBufPerFr] > 0)
			pwNP[%NumberOfPixBufsSet]	*= pwNP[%User_stimBufPerFr]
			pwNP[%PixBufCounter]		*= pwNP[%User_stimBufPerFr]
		endif	
		// <==

		PixBLen			= Str2Num(StringFromList(0, pwSP[%InChan_PixBufLenList]))		
		nPixPerFr		= dFast *dSlow1 *dSlow2
		if(pwNP[%NumberOfPixBufsSet] == pwNP[%PixBufCounter])
			nPixB		= pwNP[%NumberOfPixBufsSet] *(nPixPerFr /PixBLen)
		else	
			nPixB		= (pwNP[%NumberOfPixBufsSet] -pwNP[%PixBufCounter])*(nPixPerFr /PixBLen)	
		endif	
		nPixB			= nPixB *nFrPerStep
		nBufPerFr		= nPixPerFr /PixBLen
		nFr				= (nPixB/nFrPerStep*PixBLen) /(nPixPerFr) 
		nAICh			= pwNP[%NumberOfInputChans]
		dxFrDecode		= pwNP[%User_dxFrDecoded]
		dyFrDecode		= pwNP[%User_dyFrDecoded]
		dzFrDecode		= pwNP[%User_dzFrDecoded]
		nPixDecodeFr	= dxFrDecode *dyFrDecode //*dzFrDecode
		
		sprintf sTemp, "%d AI channels (0x%.4b)\r", nAICh, pwNP[%InputChanMask]
		writeToLog(sTemp, "", doLog, 0)
		sprintf sTemp, "%d of %d buffers (each %d pixels) per channel\r", nPixB, pwNP[%NumberOfPixBufsSet], PixBLen
		writeToLog(sTemp, "", doLog, 0)		

		// Make waves for pixel data, one per AI channel
		//
		for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
			if(pwNP[%InputChanMask] & (2^iInCh))
				AbortOnValue ((pwNP[%PixSizeInBytes] != 2) && (pwNP[%PixSizeInBytes] != 8)), 7

				// "wDataChx_raw" contains the raw pixel data, "wDataChx" the decoded pixel
				// data that can be directly used for traditional preprocessing. With standard
				// xy scans, raw and decoded are the same (or for scan path functions that
				// just resort the pixel data), therefore no "wDataChx_raw" wave
				// are created
				//
				if(pwInfo[%isExtScanFunction] && (pwInfo[%pixDecodeMode] == SCM_PixDataDecoded)) 
					sPixDataRawFormat		= SCMIO_pixDataWaveRawFormat
					sPixDataDecodeFormat	= SCMIO_pixDataWaveDecodeFormat
					sprintf sWaveRaw, sPixDataRawFormat, iInCh
					sprintf sWave, sPixDataDecodeFormat, iInCh		
				else
					sPixDataRawFormat		= SCMIO_pixDataWaveDecodeFormat
					sPixDataDecodeFormat	= sPixDataRawFormat
					sprintf sWaveRaw, sPixDataDecodeFormat, iInCh		
					sWave	= ""							
				endif	

				switch (pwNP[%PixSizeInBytes])
					case 8:
						Make/D/O/N=(nPixB/nFrPerStep *PixBLen) $(sWaveRaw)	
						break
					case 2:
						Make/U/W/O/N=(nPixB/nFrPerStep *PixBLen) $(sWaveRaw)	
						break
				endswitch		
				wave pwPixData	= $(sWaveRaw) 
				pwPixData		= 0			
				
				if(strlen(sWave) > 0)
					Make/O/N=(dxFrDecode, dyFrDecode, nFr) $(sWave)						
				endif
				Make/O/N=(nPixDecodeFr) wDecode, wDecodeAv
			endif	
		endfor
		
		// Make wave for pixel buffers to read data from file
		//
		switch (pwNP[%PixSizeInBytes])
			case 8:
				Make/D/O/N=(dFast, PixBLen/dFast) $("wPixB")	
				Make/D/O/N=(dFast, PixBLen/dFast, nAICh) $("wPixBAllCh") 
				break
			case 2:
				Make/U/W/O/N=(dFast, PixBLen/dFast) $("wPixB") 
				Make/U/W/O/N=(dFast, PixBLen/dFast, nAICh) $("wPixBAllCh") 
				break
		endswitch
		wave pwPixB			= $("wPixB") 
		wave pwPixBAllCh	= $("wPixBAllCh") 		
		pwPixB				= 0				
		pwPixBAllCh			= 0				
		
		// Load pixel data buffer by buffer in the AI channel waves			
		//
		iPixB		= 0
		iPixBAllCh	= 0
		iAvFr		= 0
		isExtSPF	= pwInfo[%isExtScanFunction]
		isDecoded	= (pwInfo[%pixDecodeMode] == SCM_PixDataDecoded)
		Make/O/N=7 wTempMoreParam

		if(isAvZStack)
			// is z-stack with more than one frame per step, requires
			// averaging ...
			//
			for(iPixBPerCh=0; iPixBPerCh<nPixB; iPixBPerCh+=1)
				for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
					if(pwNP[%InputChanMask] & (2^iInCh))
						sprintf sWaveRaw, sPixDataRawFormat, iInCh
						wave pwPixData	= $(sWaveRaw)
						Redimension/E=1/N=(PixBLen) pwPixB
						FBinRead/B=0 fileHnd, pwPixB
						Redimension/E=1/N=(dFast, PixBLen/dFast) pwPixB
						m 	= trunc(iPixBPerCh/nFrPerStep)*PixBLen
						n	= (trunc(iPixBPerCh/nFrPerStep)+1)*PixBLen -1
						if(iAvFr == 0)							
							pwPixData[m,n]	= pwPixB[p-m]								
						elseif(iAvFr < (nFrPerStep-1))
							pwPixData[m,n]	+= pwPixB[p-m]	
						else	
							pwPixData[m,n]	+= pwPixB[p-m]								
							pwPixData[m,n] /= nFrPerStep
						endif	
						iPixB	+= 1
					endif
				endfor
			 	// ##########################
				// TODO: TE, Account for several buffers per frame?!?
				// <==
				iAvFr		+= 1
				if(iAvFr >= nFrPerStep)
					iAvFr	= 0
				endif	
			endfor		
		else
			// w/o frame averaging (as usual)
			//
			for(iPixBPerCh=0; iPixBPerCh<nPixB; iPixBPerCh+=1)
				// Read next pixel buffer (containing all AI channels)
				//
				Redimension/E=1/N=(PixBLen *nAICh) pwPixBAllCh
				FBinRead/B=0 fileHnd, pwPixBAllCh
			//	Redimension/E=1/N=(dFast, PixBLen/dFast, nAICh) pwPixBAllCh
			
				iCh	= 0
				for(iInCh=0; iInCh<SCMIO_maxInputChans; iInCh+=1)
					if(pwNP[%InputChanMask] & (2^iInCh))
						Redimension/E=1/N=(PixBLen) pwPixB
						pwPixB[]	= pwPixBAllCh[p +iCh*PixBLen]
						
						if((isExtSPF && isDecoded) || !isExtSPF)
							// Standard scan path function was used or external scan
							// path function with pixel decoding
							//
							sprintf sWaveRaw, sPixDataRawFormat, iInCh
							wave pwPixData	= $(sWaveRaw)
							m 				= iPixBPerCh *PixBLen
							n				= (iPixBPerCh+1) *PixBLen -1
							pwPixData[m,n]	= pwPixB[p-m]
						endif
						if(isExtSPF)
							// External scan path function, therefore call the 
							// decoder to fill the second set of pixel data waves
							//
							wTempMoreParam[0]	= nAICh 
							wTempMoreParam[1]	= iInCh		
							wTempMoreParam[2]	= iPixBAllCh *PixBLen // *nAICh				
							wTempMoreParam[3]	= nPixPerFr	 				
							wTempMoreParam[4]	= PixBLen
							wTempMoreParam[5]	= 1				
							wTempMoreParam[6]	= 0		
							fDecode(wDecode, wDecodeAv, pwPixBAllCh, "root:" +sDFName +":", wTempMoreParam)
								
								
							// Copy pixel data from temporary frame into pixel data wave
							// 	
							sprintf sWave, sPixDataDecodeFormat, iInCh
							wave pwPixData	= $(sWave)
							Redimension/E=1/N=(dxFrDecode *dyFrDecode *nFr) pwPixData
							m				= iPixBPerCh *PixBLen			
							n				= m +PixBLen -1 
							o				= mod(iPixBPerCh, nBufPerFr)*PixBLen
						//	print m, n, o, iPixBPerCh, nBufPerFr
							pwPixData[m,n]	= wDecode[p-m+o]
							Redimension/E=1/N=(dxFrDecode, dyFrDecode, nFr) pwPixData
						endif
						iPixB	+= 1
						iCh		+= 1
					endif
				endfor
				iPixBAllCh	+= 1
			endfor		
		endif	
		KillWaves/Z wDecode, wDecodeAv, wTempMoreParam

		// ##########################
		// TODO: Read "post header" from pixel data file
		//
		// Note that there is the same 64 byte structure as at the beginning of the 
		// header file (pre-header, see above) pasted to the end of the pixel data
		// file. It can be used for verification of SMH/SMP file pairs. 
		// <==
		
		// Close pixel data file
		//
		if(fileHnd != 0)
			Close fileHnd
		endif	


		// ---------------------------------------------------------------------------
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
				sprintf sWaveRaw, sPixDataRawFormat, iInCh
				wave pwPixData	= $(sWaveRaw)
				
				// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
				// Add wave note in CFD style, if requested
				//
				if((iInCh == 0) && doAddCFDNote)
					ScMIO_writeParamsToNotes(pwPixData, 0)
				endif	
				
				// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
				// Reshape AI channel pixel waves
				//
				switch(	pwNP[%User_ScanMode])
					case ScM_scanMode_XYImage		:
					case ScM_scanMode_XZYImage	:
					case ScM_scanMode_ZXYImage	:
						nFr	= (nPixB/nFrPerStep*PixBLen) /(nPixPerFr) 
						Redimension/E=1/N=(dFast, dSlow1, nFr) pwPixData									
						break			

					case ScM_scanMode_TrajectArb	:
						// ##########################				
						// Just a quick fix; TODO ==>
						nFr	= (nPixB/nFrPerStep*PixBLen) /(nPixPerFr) 
						Redimension/E=1/N=(dFast, dSlow1, nFr) pwPixData									
						// <==
						break
						
				//	case ScM_scanMode_XYZImage 	:
				//		break
				endswitch		
				
				// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
				// Remove offset and retrace regions of frames, if requested
				//
				if(pwSCIOParams[SCMIO_Param_cropToPixelArea])
					switch(pwNP[%User_ScanMode])
						case ScM_scanMode_XYImage		:
						case ScM_scanMode_XZYImage	:	
						case ScM_scanMode_ZXYImage	:					
							// e.g. String,ScanPathFunc=XYScan2|5120|80|64|10|6;
						 	// ##########################
							// 2017-02-28 CHANGED TE ==>
							// These parameters should have already been extracted
						//	nFastPixRetr	= Str2Num(StringFromList(4, pwSP[%User_ScanPathFunc], "|"))
						//	nFastPixOff		= Str2Num(StringFromList(5, pwSP[%User_ScanPathFunc], "|"))		
							DeletePoints 0, nFastPixOff, pwPixData
							DeletePoints dFast-nFastPixOff-nFastPixRetr, nFastPixRetr, pwPixData
							break
							
						case ScM_scanMode_TrajectArb	:
							// ##########################				
							// TODO ==>
							// <==
							break
							
					//	case ScM_scanMode_XYZImage	:	
					//		break
					endswitch		
				endif	

				// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
				// Convert data to unsigned 8 bit, if requested
				//
				if(pwSCIOParams[SCMIO_Param_to8Bits])
					Redimension/S pwPixData
					if((iInCh == 0) || (iInCh == 1))
						Wavestats/Q pwPixData
						printf "#%d:\tmin/max\t%.0f ... %.0f (mean=%.0f +/- %.0f)\r", iInCh, V_min, V_max, V_avg, V_sdev
					
						switch (iInCh)
						 	case 0:
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

				// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
				// Decode pixel data, if external scan path function was used
				//
				if(pwInfo[%isExtScanFunction]) 


				//	pwInfo	= ScM_getStimBufInfo(sDFName)
				//	iStimBuf		=  pwInfo[%stimBufIndex] 
				//	sUserScanFName	= stringfromlist(0, pwStimBufList[iStimBuf], "|")
				//	WAVE pwScanPathFuncParams	= $(sTemp2)
				//	WAVE pwStimBufData			= $(sTemp2)
				//	WAVE pwCountMatrix		= $(sTemp2)
				//
				//	FUNCREF ScM_ScanPathDecodeProtoFunc fDecode	= $(sUserScanFName + "_decode")
				endif
			endif
		endfor		
		
		// Integrate stimulus channel into first (leftmost) column of a data channel
		//
		if(doIntStim)
			sprintf sWaveRaw, sPixDataRawFormat, StimCh
			wave pwStim		= $(sWaveRaw)
			sprintf sWaveRaw, sPixDataRawFormat, TargetCh
			wave pwTarg		= $(sWaveRaw)
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
			case 9:
 				writeToLog("", "Scan mode not yet implemented", doLog, -1)
 				break
			case 10:
 				writeToLog("", "Aborted by user", doLog, -1)
 				break
 				
		endswitch	
		KillWaves/Z pwSP, pwNP, pwStimBufMapEntries
		sDFName	= ""
	endtry	
	
	// Clean up
	//
	KillWaves/Z wHdr, wPixB, pwStimBufMapEntries, pwPixBAllCh
	KillWaves/Z pwScanPathFuncParams, pwCountMatrix, pwStimBufData, wStimBufData_temp
	KillWaves/Z wTempDecodeAv, wPixelDataBlockForCh
//	KillWaves/Z wTempDecode
	
	SetDataFolder $(sSavDF)
	
	if(strlen(sDFName) > 0)
		writeToLog(" done.\r", "", doLog, 0)	
	endif	
	return sDFName
end

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
	
	variable	nE, iE, nEDone, nEDonePrev, iBuf, iInCh, n, iStCh, j
	string		sTemp, sKey, sType, sVal, sTypeCh			

	// Get wave references and clear waves
	//	
	wave/T pwSP					= $(SCMIO_StrParamWave)
	wave pwNP					= $(SCMIO_NumParamWave)
	wave pwStimBufMapEntries	= $(SCMIO_StimBufMapEntrWave)	
	wave pwTrajParams			= $(SCMIO_TrajParamWave)	
	pwSP						= ""
	pwNP						= 0
	pwStimBufMapEntries		= 0	
	pwTrajParams				= 0
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
					pwSP[%DateStamp_d_m_y]		= sVal				
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
				elseif(stringmatch(sTemp,	SCMIO_key_USER_Comment))
					pwSP[%User_Comment]			= sVal				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_Objective))
					pwSP[%User_Objective]			= sVal				
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
					pwNP[%User_NFrPerStep]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dzPix))
					pwNP[%User_dzPix]				= str2num(sVal)				
					nEDone	+= 1
//				elseif(stringmatch(sTemp,	SCMIO_key_USER_nZPixRetrace))
//					pwNP[%User_nZPixRetrace]			= str2num(sVal)				
//					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_nZPixLineOffs))
					pwNP[%User_nZPixLineOff]			= str2num(sVal)				
					nEDone	+= 1
//				elseif(stringmatch(sTemp,	SCMIO_key_USER_usesZForFastScan))
//					pwNP[%User_ZForFastScan]			= str2num(sVal)				
//					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_SetupID))
					pwNP[%User_SetupID]				= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_LaserWavelen_nm))
					pwNP[%User_LaserWaveLen_nm]		= str2num(sVal)				
					nEDone	+= 1
//				elseif(stringmatch(sTemp,	SCMIO_key_USER_ZLensScaler))
//					pwNP[%User_ZLensScaler]			= str2num(sVal)				
//					nEDone	+= 1
//				elseif(stringmatch(sTemp,	SCMIO_key_USER_ZLensShifty))
//					pwNP[%User_ZLensShifty]			= str2num(sVal)				
//					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_stimBufPerFr))
					pwNP[%User_stimBufPerFr]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_nYPixLineOffs))
					pwNP[%User_nYPixLineOffsr]		= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_iChFastScan))
					pwNP[%User_iChFastScan]			= str2num(sVal)				
					nEDone	+= 1
//				elseif(stringmatch(sTemp,	SCMIO_key_USER_noYScan))
//					pwNP[%User_noYScan]				= str2num(sVal)				
//					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dxFrDecoded))
					pwNP[%User_dxFrDecoded]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dyFrDecoded))
					pwNP[%User_dyFrDecoded]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_dzFrDecoded))
					pwNP[%User_dzFrDecoded]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_nTrajParams))
					pwNP[%User_nTrajParams]			= str2num(sVal)				
					nEDone	+= 1
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
					
				// --> USER	
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
					pwNP[%User_XOffset_V]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_offsetY_V))
					pwNP[%User_YOffset_V]			= str2num(sVal)				
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_aspectRatioFrame))
					pwNP[%User_aspectRatioFr]		= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_trajDefVRange_V))
					pwNP[%User_trajDefVRange_V]	= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_zoomZ))
					pwNP[%User_zoomZ]				= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_offsetZ_V))
					pwNP[%User_offsetZ_V]			= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_zeroZ_V))
					pwNP[%User_zeroZ_V]			= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_ETL_polarity))
					pwNP[%User_ETL_polarity_V]	= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_ETL_minV))
					pwNP[%User_ETL_min_V]			= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_ETL_maxV))
					pwNP[%User_ETL_max_V]			= str2num(sVal)		
					nEDone	+= 1
				elseif(stringmatch(sTemp,	SCMIO_key_USER_ETL_neutralV))
					pwNP[%User_ETL_neutral_V]		= str2num(sVal)		
					nEDone	+= 1
//				elseif(stringmatch(sTemp,	SCMIO_key_USER_trajParams_mask))
//					j		= str2num(StringByKey(sVal[0,10], sVal, "_"))
//					if(j < SCMIO_maxTrajParams)
//						pwTrajParams[j]			= str2num(sVal)		
//					endif
//					nEDone	+= 1
				endif					
				// <--	
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
		
		n		= strlen(SCMIO_key_AO_x_Ch_x_RealStimDur)
		sTemp	= SCMIO_real32Str +"," +SCMIO_key_AO_x_Ch_x_RealStimDur[1,n]
		sprintf sKey, sTemp, "A", iBuf
		sVal	= StringByKey(sKey, s, SCMIO_keyValueSep, SCMIO_entrySep, 0) 
		if(strlen(sVal) > 0)
			pwSP[%RealStimDurList		]	+= sVal +SCMIO_entrySep
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
//	constant   CFDIsLineScan  = 1
//	constant   CFDIsXYSeries 	= 2
//	constant   CFDIsZStack   	= 3
	switch(pwNP[%User_ScanMode])
		case ScM_scanMode_XYImage	:
			sTemp2	= "2"
			break
//		case ScM_scanMode_Line		:	
//		case ScM_scanMode_Traject	:	
//			sTemp2	= "1"		
//			break
		case ScM_scanMode_XYZImage	:
			sTemp2	= "3"
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
// ##########################
// 2017-05-29 ADDED TE ==>
//
function	ScM_LoadExternalIPFs ()

	string		sFName, sFList, sDF
	variable	nFiles, jF

	// Create path to folder that .ipfs with user functions
	// (in \UserProcedures\ScanM)
	//
	string		sPath	= SpecialDirPath(SCMIO_IgorProUserFilesStr, 0, 0, 0)
	NewPath/Q/O scmUserFuncs, (sPath +SCMIO_UserFuncFilesStr)
	
	// Get a list of all .ipf files in that directory
	//
	sFList		= IndexedFile(scmUserFuncs, -1,".ipf")	
	nFiles		= 0
	for(jF=0; jF<ItemsInList(sFList); jF+=1)
		sFName	= StringFromList(jF, sFList)
		if(StringMatch(sFName, SCMIO_UserFuncFileMask))
			// Add file as an #include and recompile
			//
			sFName	= sFName[0,strlen(sFName) -5]
			sDF		= sFName[5,INF]
			Execute/P/Q/Z "INSERTINCLUDE \"" +sFName +"\""		
			nFiles	+= 1
		endif	
	endfor	
	if(nFiles > 0)
		Execute/P/Q/Z "COMPILEPROCEDURES "	
		printf "### %d external user function files found and loaded\r", nFiles
	endif
end
// <==	

// ----------------------------------------------------------------------------------
// ##########################
// 2017-08-19 ADDED TE ==>
//
function/WAVE 	ScM_getStimBufInfo (sDF)
	string		sDF

	variable	nStimBuf, lenStimBuf, nSBList, isEmpty, isSBFound, isExtScanF
	string		sUserScanFFull, sUserScanFName, sTemp
	variable	AOCh3Scale, j, result
		
	// Initialize 
	//
	DFREF	saveDFR 	= GetDataFolderDFR()	
	SetDataFolder $("root:" +sDF)
	
	WAVE  	pwPNum		= $("wParamsNum")
	WAVE/T 	pwPStr		= $("wParamsStr")	
	nStimBuf			= pwPNum[%numberOfStimBufs]
	lenStimBuf			= str2num(stringfromlist(0, pwPStr[%StimBufLenList]))
	sUserScanFFull		= pwPStr[%User_ScanPathFunc]
	sUserScanFName		= stringfromlist(0, sUserScanFFull, "|")
	isExtScanF			= (FindListItem(sUserScanFName, "XYScan2;XYScan3;XYZScan1") < 0) 	
	
	// Create stim buffer info wave in data folder
	//
	Make/O/N=(4) $(SCMIO_stimBufInfoWaveName)
	WAVE 	pwInfo		= $(SCMIO_stimBufInfoWaveName)
	SetDimLabel 0, 0, 	stimBufIndex,		pwInfo
	SetDimLabel 0, 1, 	isExtScanFunction,	pwInfo
	SetDimLabel 0, 2, 	hasCountMatrix,	pwInfo
	SetDimLabel 0, 3, 	pixDecodeMode,		pwInfo
	// ...
	pwInfo[%isExtScanFunction]	= isExtScanF	
	
	printf "### Looking for stimulus buffer for `%s` ...\r", sUserScanFFull	
	
	// Check for stimulus buffer data folder under root, if not there, create
	// folder and inventory list
	//
	NewDataFolder/O/S $("root:" +SCMIO_stimBufFolder)
	if(!WaveExists($(SCMIO_stimBufListName)))
		Make/T/N=100  $(SCMIO_stimBufListName) = ""
	endif		
	WAVE/T	pwSBList	= $(SCMIO_stimBufListName)
	
	// Check if fitting stimulus buffer is already in list
	nSBList				= 0
	isSBFound			= 0
	do
		isEmpty			= strlen(pwSBList[nSBList]) == 0
		if(!isEmpty)	
			isSBFound	= StringMatch(pwSBList[nSBList], sUserScanFFull)
			if(isSBFound)	
				// Matching stimulus buffer entry found, return reference
				// to stimulus buffer wave
				//	
				printf "### Matching stimulus buffer already exists\r"
				
				pwInfo[%stimBufIndex]		= nSBList
				pwInfo[%hasCountMatrix]	= WaveExists($(SCMIO_scanDecCountMatrixName +"_" +Num2Str(nSBList)))

				SetDataFolder saveDFR		
				return pwInfo
			else
				nSBList		+= 1
			endif	
		endif	
	while(!isEmpty)
	printf "### No matching stimulus buffer found, recreating ...\r"
	
	// Create stimulus buffer wave ...
	//
	sTemp	= "wStimBufData_" +Num2Str(nSBList)
	Make/O/S/N=(nStimBuf, lenStimBuf) $(sTemp)
	WAVE	pwStimBufData	= $(sTemp)
	
	// Fill stimulus buffer with scan path data
	//
	switch(pwPNum[%User_ScanMode])
		case ScM_scanMode_XYImage		:
		case ScM_scanMode_XZYImage	:	
		case ScM_scanMode_ZXYImage	:				
			AOCh3Scale	= pwPNum[%MaxVolts_AO]
			break
			
		case ScM_scanMode_TrajectArb	:	
			// Other than for "standard" scans, here no scaling (i.e. for the blanking
			// signal) happens; it is expected that the stimuli contain final voltages
			//
			AOCh3Scale	= 1.0
			break
	endswitch		

	// Call scan path function and receive four buffers (see below) with the scan path
	// data for one frame
	//
	ScM_callScanPathFunc(sUserScanFFull)
	wave pwTempX				= $("StimX")	
	wave pwTempY				= $("StimY")		
	wave pwTempPC				= $("StimPC")	
	wave pwTempZ				= $("StimZ")
	wave pwScanPathFuncParams	= $("wScanPathFuncParams")	
	sTemp						= "wScanPathFuncParams_" +Num2Str(nSBList)
	Duplicate/O pwScanPathFuncParams, $(sTemp)
	KillWaves/Z pwScanPathFuncParams
	wave pwScanPathFuncParams	= $(sTemp)
	
	// Copy scan path data into the stimulus buffer
	//
	for(j=0; j<lenStimBuf; j+=1)
		pwStimBufData[SCM_indexScannerX][j]	= pwTempX[q]
		pwStimBufData[SCM_indexScannerY][j]	= pwTempY[q]
		pwStimBufData[SCM_indexLaserBlk][j]	= pwTempPC[q] *AOCh3Scale
		pwStimBufData[SCM_indexLensZ][j]		= pwTempZ[q] *pwPNum[%User_ETL_polarity_V]
	endfor
	
	if(isExtScanF)
		// If an external scan path function is defined, prepare its decoder
		//
		FUNCREF ScM_ScanPathPrepDecodeProtoFunc fPrepDecode	= $(sUserScanFName + "_prepareDecode")
		result 	= fPrepDecode(pwStimBufData, pwScanPathFuncParams)
		pwInfo[%pixDecodeMode]		= result
		
		if(WaveExists(countMatrix))
			sTemp	= SCMIO_scanDecCountMatrixName +"_" +Num2Str(nSBList)
			Duplicate/O $(SCMIO_scanDecCountMatrixName), $(sTemp)
			KillWaves/Z $(SCMIO_scanDecCountMatrixName)
		endif	
	endif

	// Save entry in stimulus buffer list and fill out info wave
	//
	pwSBList[nSBList]			= sUserScanFFull
	pwInfo[%stimBufIndex]		= nSBList
	pwInfo[%hasCountMatrix]	= WaveExists($(SCMIO_scanDecCountMatrixName +"_" +Num2Str(nSBList)))

	// Clean up
	//
	KillWaves/Z pwTempX, pwTempY, pwTempPC, pwTempZ, wStimBufData_temp
	SetDataFolder saveDFR		
	
	return pwInfo
end
	
// <==	

// ----------------------------------------------------------------------------------
	