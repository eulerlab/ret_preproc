//  File: CellLabUI.ipf
//  User interface for cells segmentation
//
//  Keyboard shortcuts:
//    A - add cell
//    S - Show all / Show selected cell
//    D - Delete selected cell
//    R - Recognize cells
//    C - Clean small cells
//
//  Mouse:
//    LButton - Paint
//    Ctrl+LButton - Erase
//
//  Main functions:
//    function RecognizeCellsUI(wCellImage, sTargetROIName, sTargetReportName)
//      Creates UI with wCellImage wave and sTargetROIName as a result and sTargetReportName report
//     
//  
//  History:
//    DV-120320 - Created. Dmytro Velychko, 20.03.2012. dmytro.velychko@student.uni-tuebingen.de
//    DV-120415 - Moved data to separate wave-specific folder; bugfixes in Clean; lots of refactoring
//    DV-120612 - Added cells sorting for the report wave according to scanline order
//    DV-120617 - Added cells regions clean-up if 4-connected region is less then provided, SARFIA 
//				mask is sorted in scanline order

#pragma rtGlobals=1		// Use modern global access method.
#include <Resize Controls>
#include <SaveGraph>
#include <All IP Procedures>

#include "CellLabRoutines"

////////////////////////////////////////////////////////////////////////////////////////////
// User-adjustable constants
Constant SHOW_ALL_ALPHA 		= 100
Constant MARGIN_ALPHA 			= 200
Constant SINGLE_CELL_ALPHA 	= 50
Constant PAINT_CELL_ALPHA 	= 100

////////////////////////////////////////////////////////////////////////////////////////////
// Internal constants
Constant MODE_PAINT 			= 0
Constant MODE_SELECT 			= 1
StrConstant CELL_LAB_ROOT_2D 	= "root:CellLab2D"
StrConstant WAVES_FOLDER		= "Waves"

// Prefixes
StrConstant SARFIA_ROI_SUFFIX = "_SARFIA_ROI"
StrConstant REPORT_SUFFIX 	= "_report"

// Variables names
StrConstant G_TARGET_ROI_NAME		= ":gTargetROIName"
StrConstant G_TARGET_REPORT_NAME	= ":gTargetReportName"
StrConstant G_BRUSH_RADIUS 		= ":gBrushRadius"
StrConstant G_PAINT_MODE 			= ":gPaintMode"
StrConstant G_CELL_TOTAL_NUMBER 	= ":gCellsTotalNumber"
StrConstant G_CURRENT_CELL_ID 	= ":gCurrentCellID"
StrConstant G_CURRENT_CELL 		= ":gCurrentCell"
StrConstant G_RESCALE_TO 			= ":gRescaleTo"
StrConstant W_LABELING 			= ":wLabeling"
StrConstant W_DISPLAY 				= ":wDisplay"
StrConstant W_ROI 					= ":wROI"
StrConstant G_EXPERIMENT_NUMBER 	= ":gExperimentNumber"
StrConstant G_APPROX_CELL_RADIUS 	= ":gApproxCellRadius"
StrConstant G_MARGIN_TOP 			= ":gMarginTop"
StrConstant G_MARGIN_BOTTOM 		= ":gMarginBottom"
StrConstant G_MARGIN_LEFT 		= ":gMarginLeft"
StrConstant G_MARGIN_RIGHT 		= ":gMarginRight"
StrConstant G_MIN_CELL_SIZE 		= ":gMinCellSize"
StrConstant G_LAST_EDITED_CELL 	= ":gLastEditedCell"
StrConstant G_CELL_IMAGE_NAME 	= ":gCellImageName"
StrConstant G_CELL_IMAGE_FOLDER = ":gCellImageFolder"

////////////////////////////////////////////////////////////////////////////////////////////

function/s ELFolderFromWave(sWaveName)
	String sWaveName
	return CELL_LAB_ROOT_2D + ":" + sWaveName
end

function/s ELWavesFolderFromWave(sWaveName)
	String sWaveName
	return ELFolderFromWave(sWaveName) + ":" + WAVES_FOLDER
end

function ELGetBrushRadius(sWaveName)
	String sWaveName
	NVAR gBrushRadius = $(ELFolderFromWave(sWaveName) + G_BRUSH_RADIUS)
	return gBrushRadius
end

function ELGetPaintMode(sWaveName)
	String sWaveName
	NVAR gPaintMode = $(ELFolderFromWave(sWaveName) + G_PAINT_MODE)
	return gPaintMode
end		

function ELSetPaintMode(sWaveName, value)
	String sWaveName
	Variable value
	NVAR gPaintMode = $(ELFolderFromWave(sWaveName) + G_PAINT_MODE)
	gPaintMode = value
end		
		
function ELSetNumberCells(sWaveName, value)	
	String sWaveName
	Variable value
	NVAR nCells = $(ELFolderFromWave(sWaveName) + G_CELL_TOTAL_NUMBER)
	nCells = value
	
	ValDisplay valdispNumberCells win=CellLab,value=_NUM:nCells
	SetVariable edtCurrentCell win=CellLab,limits={0,nCells,1}
end
		
function SetCurrentCell(sWaveName, value)		
	String sWaveName
	Variable value
	NVAR iCell = $(ELFolderFromWave(sWaveName) + G_CURRENT_CELL_ID)
	iCell = value
	
	NVAR gCurrentCell = $(ELFolderFromWave(sWaveName) + G_CURRENT_CELL)
	gCurrentCell = value
end

//////////////////////////////////////////////////////////////////////////////////////////////////////

function/s GetRescaleImageName(sWaveName)
	String sWaveName
	SVAR gRescaleTo = $(ELFolderFromWave(sWaveName) + G_RESCALE_TO)
	return gRescaleTo
end

function SetRescaleImageName(sWaveName, sName)
	String sWaveName
	string sName
	SVAR gRescaleTo = $(ELFolderFromWave(sWaveName) + G_RESCALE_TO)
	gRescaleTo = sName
end

function/s CellLabelingMaskName(sWaveName)
	string sWaveName
	return ELWavesFolderFromWave(sWaveName) + W_LABELING
end

function/s CellDisplayMaskName(sWaveName)
	string sWaveName
	return ELWavesFolderFromWave(sWaveName) + W_DISPLAY
end

function/s CellROIMaskName(sWaveName)
	string sWaveName
	return ELWavesFolderFromWave(sWaveName) + W_ROI
end

function/s SARFIAMaskName(sWaveName)
	string sWaveName
	
	SVAR   sName1 =  $(ELFolderFromWave(sWaveName) + G_CELL_IMAGE_FOLDER) 
	SVAR   sName2 =  $(ELFolderFromWave(sWaveName) + G_TARGET_ROI_NAME)
	return sName1 + sName2
end

function/s CellReportName(sWaveName)
	string sWaveName
	SVAR   sName1 = $(ELFolderFromWave(sWaveName) + G_CELL_IMAGE_FOLDER)
	SVAR   sName2 = $(ELFolderFromWave(sWaveName) + G_TARGET_REPORT_NAME)
	return sName1 + sName2
end

function/s CellsTotalNumberName(sWaveName)
	string sWaveName
	return ELFolderFromWave(sWaveName) + G_CELL_TOTAL_NUMBER
end

function/s CurrentCellIDName(sWaveName)
	string sWaveName
	return ELFolderFromWave(sWaveName) + G_CURRENT_CELL_ID
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////

function/s ELActiveImageNameByWindow(sWinName)
	String sWinName
	string sImages = ImageNameList(sWinName, ";")
	string sName = StringFromList(0, sImages, ";")
	if (cmpstr(sName[0], "'") == 0)
		sName = sName[1, strlen(sName)-2]
	endif
	return sName
end

function/Wave ELActiveImageWaveByWindow(sWinName)
	String sWinName
	string sImages = ImageNameList(sWinName, ";")
	string sName = StringFromList(0, sImages, ";")
	if (cmpstr(sName[0], "'") == 0)
		sName = sName[1, strlen(sName)-2]
	endif
	return ImageNameToWaveRef(sWinName, sName)
end

function SliceSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
	string sImage = sa.UserData
	if (strlen(sImage) > 0)
		ModifyImage $(sImage) plane=sa.curval
	endif
end

function PrepadeDataFolders(sWaveName)
	String sWaveName
	String savedDataFolder = GetDataFolder(1)
	SetDataFolder("root:")
	NewDataFolder/O $(CELL_LAB_ROOT_2D)
	KillDataFolder/Z $(ELFolderFromWave(sWaveName))
	NewDataFolder/O $(ELFolderFromWave(sWaveName))
	NewDataFolder/O $(ELWavesFolderFromWave(sWaveName))
	SetDataFolder(savedDataFolder)
end

function UpdateControlsToRecognizedCells(sWaveNameFull)
	String sWaveNameFull
	if (strlen(sWaveNameFull) == 0)
		return 0
	endif
	String sWaveName = NameOfWave($(sWaveNameFull))
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	Wave wCellMaskDisplay = $(CellDisplayMaskName(sWaveName))
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	
	if (iCell > 0)
		// delete the old cell mask
		wCellMask[][] = ((wCellMask[p][q] == iCell)? 0 : wCellMask[p][q])
		// make a border around selection
		wCellMask[][] = ((wCellMaskDisplay[p][q][3] > 0) || (wCellMaskDisplay[p+1][q][3] > 0) || (wCellMaskDisplay[p-1][q][3] > 0) || (wCellMaskDisplay[p][q+1][3] > 0) || (wCellMaskDisplay[p][q-1][3] > 0)? 0 : wCellMask[p][q])
		// transfer the cell mask
		wCellMask[][] = ((wCellMaskDisplay[p][q][3] > 0)? iCell : wCellMask[p][q])
	endif	
end

function UpdateRecognizedCellsToControls(sWaveNameFull)
	String sWaveNameFull
	if (strlen(sWaveNameFull) == 0)
		return 0
	endif
	String sWaveName = NameOfWave($(sWaveNameFull))
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	Wave wCellMaskDisplay = $(CellDisplayMaskName(sWaveName))
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	
	wCellMaskDisplay = 0
	wCellMaskDisplay[][][0] = 255 //red	
	if (iCell > 0)
		// displaying single cell
		wCellMaskDisplay[][][3] = ((wCellMask[p][q] == iCell)? SINGLE_CELL_ALPHA : 0) //alpha
		ELSetPaintMode(sWaveName, MODE_PAINT)
	else
		// displaying all cells 
		//wCellMaskDisplay[][][0] = wCellMask[p][q]
		//wCellMaskDisplay[][][1] = mod(wCellMask[p][q] * 5, 255)
		//wCellMaskDisplay[][][2] = mod(wCellMask[p][q] * 10, 255)
		wCellMaskDisplay[][][3] = ((wCellMask[p][q] > 0)? 0 : SHOW_ALL_ALPHA) //alpha
		ELSetPaintMode(sWaveName, MODE_SELECT)
	endif	
	
	ELSetNumberCells(sWaveName, nCells)
	SetCurrentCell(sWaveName, iCell)
end


function ShowAllCells(sWaveNameFull)
	String sWaveNameFull
	if (strlen(sWaveNameFull) == 0)
		return 0
	endif
	String sWaveName = NameOfWave($(sWaveNameFull))
	UpdateControlsToRecognizedCells(sWaveNameFull)	
	
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	iCell = 0
	UpdateRecognizedCellsToControls(sWaveNameFull)
end

function PickCellSelection(sWaveNameFull, x, y)
	String sWaveNameFull
	Variable x
	Variable y
	if (strlen(sWaveNameFull) == 0)
		return 0
	endif
	String sWaveName = NameOfWave($(sWaveNameFull))
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	Variable iPickedCell = wCellMask[x][y]		
	if (iPickedCell > 0)
		NVAR iCell  = $(CurrentCellIDName(sWaveName))
		iCell = iPickedCell
		UpdateRecognizedCellsToControls(sWaveNameFull)
	endif
end

function AddCells(sWaveNameFull)
	String sWaveNameFull
	String sWaveName = NameOfWave($(sWaveNameFull))
	UpdateControlsToRecognizedCells(sWaveNameFull)	
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	nCells +=1;
	iCell = nCells	
	UpdateRecognizedCellsToControls(sWaveNameFull)
end

function RemoveCells(sWaveNameFull)	
	String sWaveNameFull
	String sWaveName = NameOfWave($(sWaveNameFull))
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	if (iCell > 0)
		wCellMask[][] = ((wCellMask[p][q] == iCell)? 0 : wCellMask[p][q]) // erase current cell marking
		wCellMask[][] = ((wCellMask[p][q] > iCell)? wCellMask[p][q] - 1 : wCellMask[p][q]) // decrement other cells markings
		nCells -=1;
		iCell = nCells
		UpdateRecognizedCellsToControls(sWaveNameFull)
	endif	
end

function EditCurrentCellsProc(s) : SetVariableControl
	STRUCT WMSetVariableAction &s
	
	String sWaveName = s.userData
	
	if (strlen(sWaveName) == 0)
		return 0
	endif
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	if (s.dval <= nCells)
		UpdateControlsToRecognizedCells(sWaveName)	
		iCell = s.dval
		UpdateRecognizedCellsToControls(sWaveName)
	endif
end

function/Wave MakeCellOrderMap(wCellMask)
	Wave wCellMask
	
	Variable nCells = WaveMax(wCellMask)
	Variable dimX = DimSize(wCellMask, 0)
	Variable dimY = DimSize(wCellMask, 1)
	Make /O/Free /N=(nCells+1) wCellXMin, wCellXMax, wCellYMin, wCellYMax, wCellX, wCellY, wCellOrder, wNonCellPreSort
	wCellXMin = Inf
	wCellYMin = Inf
	Variable k, k1, k2
	for (k1 = 0; k1<dimX; k1+=1)
		for (k2 = 0; k2<dimY; k2+=1)
			k = wCellMask[k1][k2]
			wCellXMin[k] = min(k1, wCellXMin[k])
			wCellYMin[k] = min(k2, wCellYMin[k])
			wCellXMax[k] = max(k1, wCellXMax[k])
			wCellYMax[k] = max(k2, wCellYMax[k])
		endfor
	endfor
	
	// Sort the cells in the scanline order
	wCellX[] = (wCellXMax[p] + wCellXMin[p])/2
	wCellY[] = (wCellYMax[p] + wCellYMin[p])/2
	wCellOrder[] = p
	wNonCellPreSort[] = 1
	wNonCellPreSort[0] = 0 
	Sort {wNonCellPreSort, wCellY, wCellX}, wCellOrder
	return wCellOrder
end

function MakeSARFIAMask(sWaveNameFull)
	String sWaveNameFull
	String sWaveName = NameOfWave($(sWaveNameFull))
	UpdateControlsToRecognizedCells(sWaveNameFull)	
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	Wave wRescaleImage = $(GetRescaleImageName(sWaveName))
	string sSARFIAMaskName = SARFIAMaskName(sWaveName)
	
	Variable dimX = DimSize(wCellMask, 0)
	Variable dimY = DimSize(wCellMask, 1)
	if (WaveExists(wRescaleImage))
		Variable dimToX = DimSize(wRescaleImage, 0)
		Variable dimToY = DimSize(wRescaleImage, 1)
		Make /O /N=(dimToX, dimToY) $(sSARFIAMaskName)
		Wave wSARFIAMask = $(sSARFIAMaskName)
		wSARFIAMask = 0
		wSARFIAMask[][] = ((wCellMask[p/dimToX*dimX][q/dimToY*dimY] > 0)? -wCellMask[p/dimToX*dimX][q/dimToY*dimY]: 1) 
	else
		Make /O /N=(dimX, dimY) $(sSARFIAMaskName)
		Wave wSARFIAMask = $(sSARFIAMaskName)
		wSARFIAMask = 0
		wSARFIAMask[][] = ((wCellMask[p][q] > 0)? -wCellMask[p][q]: 1) 
	endif
	
	// Generate report wave
	Variable nCells
	nCells = WaveMax(wCellMask)
	string sReportName = CellReportName(sWaveName)
	Make /O /N=(nCells+1, 5) $(sReportName)
	Wave wReport = $(sReportName)
	Make /Free /N=(nCells+1) wCellXMin, wCellXMax, wCellYMin, wCellYMax, wCellSize
	wCellXMin = Inf
	wCellYMin = Inf
	Variable k, k1, k2
	for (k1 = 0; k1<dimX; k1+=1)
		for (k2 = 0; k2<dimY; k2+=1)
			k = wCellMask[k1][k2]
			wCellSize[k] += 1
			wCellXMin[k] = min(k1, wCellXMin[k])
			wCellYMin[k] = min(k2, wCellYMin[k])
			wCellXMax[k] = max(k1, wCellXMax[k])
			wCellYMax[k] = max(k2, wCellYMax[k])
		endfor
	endfor
	
	// Sort the cells in the scanline order
	Wave wCellOrder = MakeCellOrderMap(wCellMask)
	Duplicate /Free wCellOrder wCellOrderInverse
	for (k1 = 0; k1<=nCells; k1+=1)
		wCellOrderInverse[wCellOrder[k1]] = k1
	endfor
	wSARFIAMask[][] = ((wSARFIAMask[p][q] < 0)? -wCellOrderInverse[-wSARFIAMask[p][q]]: 1) 
	
	NVAR experimentNumber = $(ELFolderFromWave(sWaveName) + G_EXPERIMENT_NUMBER)
	
	wReport[][0] = experimentNumber
	wReport[][1] = wCellOrder[p]
	wReport[][2] = wCellSize[wCellOrder[p]]
	wReport[][3] = (wCellXMax[wCellOrder[p]] + wCellXMin[wCellOrder[p]])/2
	wReport[][4] = (wCellYMax[wCellOrder[p]] + wCellYMin[wCellOrder[p]])/2
	// calculate Pixel size in microns to scale ROIs
	wave wParamsNum // Reads data-header
	variable zoom = wParamsNum(30) // extract zoom
	variable nX = Dimsize(wSARFIAMask,0)
	variable nY = Dimsize(wSARFIAMask,1)	
	variable px_Size = (0.65/zoom * 110)/nX // microns
	setscale /p x,-nX/2*px_Size,px_Size,"µm" wSARFIAMask
	setscale /p y,-nY/2*px_Size,px_Size,"µm"  wSARFIAMask
	
end

function OnRecognizeCells(sWaveNameFull)
	String sWaveNameFull
	Wave wImage = $(sWaveNameFull)
	if (!WaveExists(wImage))
		return 0
	endif
	String sWaveName = NameOfWave($(sWaveNameFull))
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR approxRadiusHint = $(ELFolderFromWave(sWaveName) + G_APPROX_CELL_RADIUS)
	// Use borders
	NVAR marginTop = $(ELFolderFromWave(sWaveName) + G_MARGIN_TOP)
	NVAR marginBottom = $(ELFolderFromWave(sWaveName) + G_MARGIN_BOTTOM) 
	NVAR marginLeft = $(ELFolderFromWave(sWaveName) + G_MARGIN_LEFT)
	NVAR marginRight = $(ELFolderFromWave(sWaveName) + G_MARGIN_RIGHT)
	Wave wROIMask = $(CellROIMaskName(sWaveName))
	Variable dimX = DimSize(wROIMask, 0)
	Variable dimY = DimSize(wROIMask, 1)
	Make /Free /N = (dimX-marginLeft-marginRight, dimY-marginTop-marginBottom) wImageCropped
	Make /Free /N = (dimX-marginLeft-marginRight, dimY-marginTop-marginBottom) wCellMaskCropped
	wImageCropped[][] = wImage[p+marginLeft][q+marginBottom]
	
	nCells = RecognizeCells(wImageCropped, wCellMaskCropped, approxRadiusHint)
	
	wCellMask = 0; 
	wCellMask[][] = ((p>=marginLeft) && (p<dimX-marginRight) && (q>=marginBottom) && (p<dimY-marginTop) ? wCellMaskCropped[p-marginLeft][q-marginBottom] : 0)
	
	UpdateRecognizedCellsToControls(sWaveNameFull)
	ShowAllCells(sWaveNameFull)
end

function/Wave GetFloodRegion(wImg, xStart, yStart)
	Wave wImg
	Variable xStart, yStart
	
	Variable dimX = DimSize(wImg, 0)
	Variable dimY = DimSize(wImg, 1)
	Make /Free /N = (dimX * dimY, 2) wPoints
	Duplicate /Free wImg, wImgVisited
	Variable val = wImg[xStart][yStart]
	wPoints[0][0] = xStart
	wPoints[0][1] = yStart
	Variable nPoints = 1
	Variable kIter = 0
	do
		Variable x = wPoints[kIter][0] 
		Variable y = wPoints[kIter][1] 
		if ((x > 0) && (wImgVisited[x-1][y] == val))
			wImgVisited[x-1][y] = val-1
			wPoints[nPoints][0] = x-1
			wPoints[nPoints][1] = y
			nPoints = nPoints + 1
		endif
		if ((x < dimX-1) && (wImgVisited[x+1][y] == val))
			wImgVisited[x+1][y] = val-1
			wPoints[nPoints][0] = x+1
			wPoints[nPoints][1] = y
			nPoints = nPoints + 1
		endif
		if ((y > 0) && (wImgVisited[x][y-1] == val))
			wImgVisited[x][y-1] = val-1
			wPoints[nPoints][0] = x
			wPoints[nPoints][1] = y-1
			nPoints = nPoints + 1
		endif
		if ((y < dimY-1) && (wImgVisited[x][y+1] == val))
			wImgVisited[x][y+1] = val-1
			wPoints[nPoints][0] = x
			wPoints[nPoints][1] = y+1
			nPoints = nPoints + 1
		endif
		kIter = kIter + 1
	while (kIter < nPoints)
	
	Duplicate /FREE /R=(0, nPoints-1)(0, 1) wPoints, wPointsRes
	return wPointsRes
end 

function CleanSmallCells(sWaveNameFull)
	String sWaveNameFull
	
	String sWaveName = NameOfWave($(sWaveNameFull))
	NVAR nCells = $(CellsTotalNumberName(sWaveName))
	NVAR iCell  = $(CurrentCellIDName(sWaveName))
	Wave wCellMask = $(CellLabelingMaskName(sWaveName))
	NVAR minCellSize = $(ELFolderFromWave(sWaveName) + G_MIN_CELL_SIZE)
	
	Variable dimX = DimSize(wCellMask, 0)
	Variable dimY = DimSize(wCellMask, 1)
	
	Duplicate /FREE wCellMask, wVisited
	Variable k, k1, k2, k3
	for (k1 = 0; k1<dimX; k1+=1)
		for (k2 = 0; k2<dimY; k2+=1)
			if (wVisited[k1][k2] > 0)
				Wave wRegion = GetFloodRegion(wCellMask, k1, k2)
				Variable dimRegion = DimSize(wRegion, 0)
				if (dimRegion < minCellSize)
					for (k3 = 0; k3<dimRegion; k3+=1)
						wCellMask[wRegion[k3][0]][wRegion[k3][1]] = 0
					endfor
				endif
				for (k3 = 0; k3<dimRegion; k3+=1)
					wVisited[wRegion[k3][0]][wRegion[k3][1]] = 0
				endfor
			endif
		endfor
	endfor
	
	nCells = WaveMax(wCellMask)
	Make /Free /N=(nCells+1) wCellSize= 0
	Make /Free /N=(nCells+1) wDecrementFactor= 0
	for (k1 = 0; k1<dimX; k1+=1)
		for (k2 = 0; k2<dimY; k2+=1)
			wCellSize[wCellMask[k1][k2]] += 1
		endfor
	endfor
	
	for (k = 1; k<=nCells; k+=1)
		if (wCellSize[k] < minCellSize)
			wDecrementFactor[k] = k
			for (k1 = k+1; k1<=nCells; k1+=1)
				wDecrementFactor[k1] += 1
			endfor
		endif
	endfor
	
	wCellMask[][] = (wCellMask[p][q] - wDecrementFactor[wCellMask[p][q]])
	nCells = WaveMax(wCellMask)
	iCell = nCells
	UpdateRecognizedCellsToControls(sWaveNameFull)
	ShowAllCells(sWaveNameFull)
end

function ButtonHandlerProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	String sWaveName
	sWaveName = ba.userData
	
	switch( ba.eventCode )
		case 2: // mouse up
			strswitch(ba.ctrlName)	
				case "btnRecognizeCells":
					OnRecognizeCells(sWaveName)
					break
				case "btnAddCells":
					AddCells(sWaveName)
					break
				case "btnRemoveCells":
					RemoveCells(sWaveName)
					break
				case "btnShowAllCells"	:
					ShowAllCells(sWaveName)
					break
				case "btnMakeSARFIAMask":
					MakeSARFIAMask(sWaveName)
					break
				case "btnCleanSmallCells":
					CleanSmallCells(sWaveName)
					break	
			endswitch
		case -1: // control being killed
			break
	endswitch
	return 0
end


function CreateMaskWaves(wCellImage)
	wave wCellImage
	
	// Create cell mask labeling wave
	string sCellImageName = NameOfWave(wCellImage)
	string sLabelingMaskName = CellLabelingMaskName(sCellImageName)
	Make /O /N=(DimSize(wCellImage, 0), DimSize(wCellImage, 1))/U $(sLabelingMaskName)
	Wave wCellLabelingMask = $(sLabelingMaskName)				
	wCellLabelingMask[][] = 0
				
	// Create ROI mask wave (for edges, etc.)
	string sROIMaskName = CellROIMaskName(sCellImageName)
	Make /O /N=(DimSize(wCellImage, 0), DimSize(wCellImage, 1), 4)/B/U $(sROIMaskName)
	Wave wROIMask = $(sROIMaskName)				
	wROIMask[][][1] = 255 // green
	wROIMask[][][3] = 0 // alpha
				
	// Create cell maks display wave
	string sDisplayMaskName = CellDisplayMaskName(sCellImageName)
	Make /O /N=(DimSize(wCellImage, 0), DimSize(wCellImage, 1), 4)/B/U $(sDisplayMaskName)
	Wave wDisplayMask = $(sDisplayMaskName)				
	wDisplayMask[][][0] = 255 // red
	wDisplayMask[][][3] = 0 // alpha
		
	// Create a variable for number of recognized cells
	Variable/G/U $(CellsTotalNumberName(sCellImageName))
	Variable/G/U $(CurrentCellIDName(sCellImageName))
end

function PointDist(pt1X, pt1Y, pt2X, pt2Y)
	variable pt1X, pt1Y, pt2X, pt2Y
	return sqrt((pt1X-pt2X)*(pt1X-pt2X) + (pt1Y-pt2Y)*(pt1Y-pt2Y))
end

function PaintWithBrush(wCanvas, nX, nY, nRadius, nColor)
	Wave wCanvas
	Variable nX, nY, nRadius, nColor
	
	Variable k1, k2
	for (k1 = nX-nRadius+1; k1<nX+nRadius; k1 += 1)
		for (k2 = nY-nRadius+1; k2<nY+nRadius; k2 += 1)
			if (PointDist(nX, nY, k1, k2) < nRadius-0.5)
				wCanvas[k1][k2][3] = nColor // red
			endif
		endfor
	endfor
end

function CellImageWindowHook(s)
	STRUCT WMWinHookStruct &s
	Variable rval = 0
	//print s
	
	//String sWaveName
	Wave wWave = ELActiveImageWaveByWindow(s.winName)
	
	if (WaveExists(wWave))
		String sWaveName = NameOfWave(wWave)
		string sWaveNameFull = GetWavesDataFolder(wWave, 2)
		if (cmpstr(s.eventName, "keyboard") == 0)
			if (s.keycode == char2num("s"))
				NVAR iCell  = $(CurrentCellIDName(sWaveName))
				NVAR iLastEditedCell = $(ELFolderFromWave(sWaveName) + G_LAST_EDITED_CELL)
				if ((iCell == 0) && (iLastEditedCell != 0))
					SetCurrentCell(sWaveNameFull, iLastEditedCell);
					UpdateRecognizedCellsToControls(sWaveNameFull)
				else
					
					iLastEditedCell = iCell
					ShowAllCells(sWaveNameFull)
				endif
			elseif (s.keycode == char2num("d"))
				UpdateControlsToRecognizedCells(sWaveNameFull)
				RemoveCells(sWaveNameFull)
				ShowAllCells(sWaveNameFull)
			elseif (s.keycode == char2num("a"))
				AddCells(sWaveNameFull)
			elseif (s.keycode == char2num("r"))
				OnRecognizeCells(sWaveNameFull)
			elseif (s.keycode == char2num("c"))	
				CleanSmallCells(sWaveNameFull)
			endif
			
		endif
		
		string sDisplayMaskName = CellDisplayMaskName(sWaveName)
		Wave wDisplayMask = $(sDisplayMaskName)
	
		Variable xx,yy
		xx=trunc(AxisValFromPixel(s.winName, "bottom", s.mouseLoc.h )+0.5)
		yy=trunc(AxisValFromPixel(s.winName, "left", s.mouseLoc.v )+0.5)
		if (((s.eventMod & 1) == 1) && (XX >= 0) && (yy >= 0) && (xx <= DimSize(wDisplayMask,0)) && (yy <= DimSize(wDisplayMask,1)))
			switch(ELGetPaintMode(sWaveName))	
				case MODE_PAINT:
					if (s.eventMod == 1)
						PaintWithBrush(wDisplayMask, xx, yy, ELGetBrushRadius(sWaveName), PAINT_CELL_ALPHA)
					elseif (s.eventMod == 9)
						PaintWithBrush(wDisplayMask, xx, yy, ELGetBrushRadius(sWaveName), 0)
					endif
					break						
				case MODE_SELECT:
					PickCellSelection(sWaveNameFull, xx,yy)
					break						
			endswitch
			rval = 1					
		endif	
	endif
	
	return rval
end

function CreateCellImageWindow(wCellImage, wDisplayImage, wROIImage)
	Wave wCellImage
	Wave wDisplayImage
	Wave wROIImage
	Display /K=1 as "Cell ROI Selection"
	Appendimage wCellImage
	ModifyGraph width={Aspect,1},height={Aspect,1}
	DoUpdate
	if (WaveDims(wCellImage) == 3)
		WMAppend3DImageSlider();
	endif
	AppendImage wDisplayImage
	AppendImage wROIImage
	SetWindow #, hook(MyHook)=CellImageWindowHook
end

function PopupMeunProc(s) : PopupMenuControl
	STRUCT WMPopupAction &s
	String ctrlName
	
	String sWaveName = s.userData
	
	strswitch(s.ctrlname)
		case "menuRescaleTo":
			SetRescaleImageName(sWaveName, s.popStr)
		break
	endswitch
end

function BrushRadiusSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
end

function EditMarginsProc(s) : SetVariableControl
	STRUCT WMSetVariableAction &s
	
	String sWaveName = NameOfWave($(s.userData))
	String sFolder = ELFolderFromWave(sWaveName)
	
	NVAR marginTop = $(sFolder + G_MARGIN_TOP)
	NVAR marginBottom = $(sFolder + G_MARGIN_BOTTOM)
	NVAR marginLeft = $(sFolder + G_MARGIN_LEFT)
	NVAR marginRight = $(sFolder + G_MARGIN_RIGHT)
	
	// Replace the ROI image
	SVAR gCellImageName = $(sFolder + G_CELL_IMAGE_NAME)
	Wave wROIMask = $(CellROIMaskName(gCellImageName))
	Variable dimX = DimSize(wROIMask, 0)
	Variable dimY = DimSize(wROIMask, 1)
	wROIMask[][][1] = 255 // green
	wROIMask[][][3] = ((p>=marginLeft) && (p<dimX-marginRight) && (q>=marginBottom) && (q<dimY-marginTop)? 0 : MARGIN_ALPHA) // alpha 
end
	
function RecognizeCellsUI(wCellImage, sTargetROIName, sTargetReportName)
	wave wCellImage
	string sTargetROIName
	string sTargetReportName
	string sWaveName = NameOfWave(wCellImage)
	string sWaveFolder = GetWavesDataFolder(wCellImage, 1)
	string sWaveFullName = GetWavesDataFolder(wCellImage, 2)
	
	if (cmpstr(sTargetROIName, "") == 0)
		sTargetROIName = sWaveName + SARFIA_ROI_SUFFIX
	endif
	if (cmpstr(sTargetReportName, "") == 0)
		sTargetReportName = sWaveName + REPORT_SUFFIX
	endif
	
	
	PrepadeDataFolders(sWaveName)
	String sFolder = ELFolderFromWave(sWaveName)
	
	String/G   $(sFolder + G_CELL_IMAGE_NAME) = sWaveName
	String/G   $(sFolder + G_CELL_IMAGE_FOLDER) = sWaveFolder
	Variable/G $(sFolder + G_CELL_TOTAL_NUMBER) = 0
	Variable/G $(sFolder + G_CURRENT_CELL_ID) = 0
	Variable/G $(sFolder + G_CURRENT_CELL) = 0
	Variable/G $(sFolder + G_PAINT_MODE) = MODE_PAINT
	Variable/G $(sFolder + G_BRUSH_RADIUS) = 1
	Variable/G $(sFolder + G_LAST_EDITED_CELL) = 0
	Variable/G $(sFolder + G_MARGIN_TOP) = 0
	Variable/G $(sFolder + G_MARGIN_BOTTOM) = 0
	Variable/G $(sFolder + G_MARGIN_LEFT) = 0
	Variable/G $(sFolder + G_MARGIN_RIGHT) = 0
	Variable/G $(sFolder + G_APPROX_CELL_RADIUS) = 3
	Variable/G $(sFolder + G_MIN_CELL_SIZE) = 3
	Variable/G $(sFolder + G_EXPERIMENT_NUMBER) = 1
	String/G   $(sFolder + G_RESCALE_TO) = "none"
	String/G   $(sFolder + G_TARGET_ROI_NAME) = sTargetROIName
	String/G   $(sFolder + G_TARGET_REPORT_NAME) = sTargetReportName
	

	NewPanel /W=(600,200,940,570) /N=CellLab /K=1
	SetDrawLayer UserBack

	GroupBox groupMargin pos={20,10},size={300,60}
	DrawText 30,30,"Margins"
	SetVariable edtMarginTop pos={115,20},size={80,20}; DelayUpdate
	SetVariable edtMarginTop limits={0,100,1}, value=$(sFolder + G_MARGIN_TOP)
	SetVariable edtMarginTop title="Top", proc=EditMarginsProc, userData = sWaveFullName
	
	SetVariable edtMarginBottom pos={115,45},size={80,20}; DelayUpdate
	SetVariable edtMarginBottom limits={0,100,1}, value=$(sFolder + G_MARGIN_BOTTOM)
	SetVariable edtMarginBottom title="Bot.", proc=EditMarginsProc, userData = sWaveFullName
	
	SetVariable edtMarginLeft pos={30,33},size={80,20}; DelayUpdate
	SetVariable edtMarginLeft limits={0,100,1}, value=$(sFolder + G_MARGIN_LEFT)
	SetVariable edtMarginLeft title="Left", proc=EditMarginsProc, userData = sWaveFullName
	
	SetVariable edtMarginRight pos={205,33},size={80,20}; DelayUpdate
	SetVariable edtMarginRight limits={0,100,1}, value=$(sFolder + G_MARGIN_RIGHT)
	SetVariable edtMarginRight title="Right", proc=EditMarginsProc, userData = sWaveFullName
	
	DrawText 20,100,"Brush"
	Slider sliderBrushRadius,pos={70,80},size={230,70}, userData = sWaveFullName
	Slider sliderBrushRadius,limits={1,25,1},variable=$(sFolder + G_BRUSH_RADIUS),vert=0,proc=BrushRadiusSliderProc 
	
	Button btnAddCells title="Add cell",pos={20,130},size={180,20},proc=ButtonHandlerProc, userData = sWaveFullName
	Button btnRemoveCells title="Remove",pos={220,130},size={80,20},proc=ButtonHandlerProc, userData = sWaveFullName
	
	SetVariable edtCurrentCell pos={20,170},size={140,20}; DelayUpdate
	SetVariable edtCurrentCell limits={0,1000,1}, value=$(sFolder + G_CURRENT_CELL)
	SetVariable edtCurrentCell title="Current cell", proc=EditCurrentCellsProc, userData = sWaveFullName
	
	ValDisplay valdispNumberCells pos={170,170},size={35,20},value=_NUM:0, userData = sWaveFullName
	
	Button btnShowAllCells title="Show all", pos={220,170}, size={80,20}, proc=ButtonHandlerProc, userData = sWaveFullName
	
	SetVariable edtApproxCellRadius pos={20,200},size={190,20}; DelayUpdate
	SetVariable edtApproxCellRadius limits={2,100,1}, value=$(sFolder + G_APPROX_CELL_RADIUS)
	SetVariable edtApproxCellRadius title="Radius hint for auto, pix", userData = sWaveFullName
	
	Button btnRecognizeCells title="Recognize",pos={220,200},size={80,20},proc=ButtonHandlerProc, userData = sWaveFullName
	
	SetVariable edtMinCellSize pos={20,230},size={190,20}; DelayUpdate
	SetVariable edtMinCellSize limits={0,100,1}, value=$(sFolder + G_MIN_CELL_SIZE)
	SetVariable edtMinCellSize title="Cell min pixels count", userData = sWaveFullName
	
	Button btnCleanSmallCells title="Clean",pos={220,230},size={80,20}, proc=ButtonHandlerProc, userData = sWaveFullName
	
	GroupBox groupFinal pos={20,260},size={300,100}
	
	SetVariable edtExperiment pos={30,270},size={180,20}; DelayUpdate
	SetVariable edtExperiment limits={0,10000,1}, value=$(sFolder + G_EXPERIMENT_NUMBER)
	SetVariable edtExperiment title="Experiment number", userData = sWaveFullName

	Popupmenu menuRescaleTo pos={220, 300},bodywidth=180,mode=1,proc = PopupMeunProc, title="Rescale to", popvalue="none", value=WaveList("*",";","TEXT:0,DIMS:3"), userData = sWaveFullName
	
	Button btnMakeSARFIAMask title="Make SARFIA Mask",pos={30,330},size={270,20},proc=ButtonHandlerProc, userData = sWaveFullName
	
	
	CreateMaskWaves(wCellImage)
	CreateCellImageWindow(wCellImage, $(CellDisplayMaskName(sWaveName)), $(CellROIMaskName(sWaveName)))
end 