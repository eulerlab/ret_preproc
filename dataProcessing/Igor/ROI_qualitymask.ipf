#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function ROI_qualitymask(threshold)

variable threshold
wave ROIs, QualityValues, Averages0
variable roinum, xx, yy
variable nX = DimSize(ROIs,0)
variable nY = DimSize(ROIs,1)
make/o/n=(nX,nY) ROI_qualityvals = 0
make/o/n=(nX,nY) ROI_threshmask = 0


for (yy=0;yy<nY;yy+=1)
	for (xx=0;xx<nX;xx+=1)
		if (ROIs[xx][yy]<1)
			roinum=(-1)*ROIs[xx][yy]
			ROI_qualityvals[xx][yy]=QualityValues[roinum-1]
			if (QualityValues[roinum-1]>threshold)
				ROI_threshmask[xx][yy]=1
			endif
		endif
	endfor
endfor

ROIs = ROIs * ROI_threshmask //overwrite, then re-run Traces and Triggers and Averages

variable countdown = -1
for (yy=0; yy<nY; yy+=1)
	for (xx=0; xx<nX;xx+=1)
		if (ROIs[xx][yy]<0)
			ROIs[xx][yy]=countdown
			countdown-=1
		endif
	endfor
endfor



end