#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function QualityOfData(threshold)
variable Threshold 

if (Threshold == 0)
	Threshold= 0.6
endif	

/////

wave Snippets0, Averages0 // defines input waves
variable nFrames = DimSize(Snippets0,0) // returns number of rows of Snippets0
variable nLoops = DimSize(Snippets0,1) // returns number of loops
variable nROIs = DimSize(Snippets0,2) // returns number of ROIs
variable rr, ll

//

make/o/n=(nROIs) QualityValues = 0

for (rr=0; rr<nRois;rr+=1)
	variable VarianceOfMean = 0
	variable MeanOfVariance = 0
	for (ll=0; ll<nLoops;ll+=1)
		make/o/n=(nFrames) CurrentTrace = Snippets0[p][ll][rr] // extract single loop trace of ROI rr and Loop ll
		WaveStats/Q CurrentTrace // calculate SD for trace
		MeanOfVariance+=(V_sdev^2)/nLoops // save SD value
	endfor
	make/o/n=(nFrames) CurrentTrace = Averages0[p][rr] // extract average trace of ROI rr and Loop ll
	WaveStats/Q CurrentTrace // calculate SD for average trace
	VarianceOfMean = V_sdev^2
	QualityValues[rr] = VarianceOfMean/MeanOfVariance
endfor

//

variable nROIs_Higher = 0

for (rr=0; rr<nRois;rr+=1)
	if (QualityValues[rr] > Threshold)
		nROIs_Higher+=1
	endif
endfor

variable Percentage = (nROIs_Higher/nROIs)*100

print "'Percentage of cells responding to the moving bars: ", Percentage, "%"

return Percentage
end