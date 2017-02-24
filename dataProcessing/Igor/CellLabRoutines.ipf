//  File: CellLabRoutines.ipf
//  Routines for cells segmentation
//
//  Main functions:
//    function RecognizeCells(wImage, wLabels)
//      Makes a map of segments - wLabels
//      Returns number of segments
//  
//  History:
//    DV-120320 - Created. Dmytro Velychko, 20.03.2012. dmytro.velychko@uni-tuebingen.de
//    DV-120415 - Added radius hint to ELWatershed
//


#pragma rtGlobals=1		// Use modern global access method.

// Watershed clustering
function/Wave ELWatershed(scan, neighbors, approxRadiusHint)
	Wave scan
	Variable neighbors // 4 or 8
	Variable approxRadiusHint
	
	Variable he = DimSize(scan, 0)
	Variable wi = DimSize(scan, 1)
	Make /O/FREE/N=(he, wi) clusterID = 0
	
	Duplicate /O/FREE scan imgVect	
	Make /O/FREE/N=(he,wi) orderX, orderY
	Make /O/FREE/N=(he*wi) clusterCenterX, clusterCenterY
	
	orderX[][] = p;
	orderY[][] = q;
	Redimension /N=(he*wi) imgVect, orderX, orderY
	Sort /R imgVect, orderX, orderY
	Variable nClusters = 0;
	Variable k1, k2, x, y
	for (k1 = 0; k1<he*wi; k1+=1)
		x = orderX[k1];
    	y = orderY[k1];
    	Make /O/FREE /N=(8) CID
    	if (scan[x][y] > 0)
			CID[] = 0; // cluster IDs of neighbors
            if (x>0)    
            	CID[0] = clusterID[x-1][y]; 
            endif
            if (x<he-1) 
            	CID[1] = clusterID[x+1][y]; 
            endif
            if (y>0)    
            	CID[2] = clusterID[x][y-1]; 
            endif
            if (y<wi-1) 
            	CID[3] = clusterID[x][y+1]; 
            endif
            if (neighbors == 8)
                if ((x>0) && (y>0))   
                	CID[4] = clusterID[x-1][y-1]; 
                endif
                if ((x<he-1) && (y>0))  
                	CID[5] = clusterID[x+1][y-1]; 
                endif
                if ((x>0) && (y<wi-1))
                	CID[6] = clusterID[x-1][y+1]; 
                endif
                if ((x<he-1) && (y<wi-1))
                	CID[7] = clusterID[x+1][y+1]; 
                endif
            endif
            Variable nCID = 0;
            for (k2=0; k2<8; k2+=1)
            	if (CID[k2] > 0)
            		nCID += 1
            	endif
            endfor
            if (nCID == 0)
                // New cluster center suspect            
                // Search for the closest existing cluster center
                Variable closestDist = Inf;
                Variable closestX, closestY
                for (k2=0; k2<nClusters; k2+=1)
                    Variable distToCluster = ELPointPointDist(x, y, clusterCenterX[k2], clusterCenterY[k2]);
                    if (distToCluster < closestDist)
                        closestX = clusterCenterX[k2];
                        closestY = clusterCenterY[k2];
                        closestDist = distToCluster;
                    endif
                endfor
                if (closestDist <= 0.9*approxRadiusHint) // < sqrt(8)
                    clusterID[x][y] = clusterID[closestX][closestY];
                else            
                    nClusters = nClusters + 1;
                    clusterID[x][y] = nClusters;
                    clusterCenterX[nClusters] = x;
                    clusterCenterY[nClusters] = y;
                endif
            else
				Sort /R CID, CID
            	Variable ID = CID[0]
            	CID[] = CID[p] - ID 
            	Variable bSameCID = 1
            	for (k2=0; k2<nCID; k2+=1)
            		bSameCID = bSameCID && (CID[k2] == 0)
            	endfor
                if (bSameCID)
                    // Attach the point to the existing cluster            
                    clusterID[x][y] = ID
                endif
            endif
        
    	endif
	endfor
	
	return clusterID
end
  
function ELPointPointDist(pt1X, pt1Y, pt2X, pt2Y)
	variable pt1X, pt1Y, pt2X, pt2Y
	variable dist = sqrt((pt1X-pt2X)*(pt1X-pt2X) + (pt1Y-pt2Y)*(pt1Y-pt2Y))
	return dist
end
  
function/WAVE ELConvergence(fx, fy, kernel)
	Wave fx, fy, kernel
	
	Variable sx = DimSize(fx, 0)
	Variable sy = DimSize(fx, 1)
	Variable kx = DimSize(kernel, 0)
	Variable ky = DimSize(kernel, 1)
	Variable halfX = (kx-1)/2;
    Variable halfY = (ky-1)/2;
    
	Make /O/FREE/N=(sx,sy) res = 0
	Make /O/FREE/N=(kx,ky) pieceX, pieceY
	
	Variable k1, k2, k3, k4
	for (k1 = 0; k1<sx; k1+=1)
    	for (k2 = 0; k2<sy; k2+=1)
    		pieceX[][] = kernel[p][q]*((k1-halfX+p>=0) && (k1-halfX+p<sx)? ((k2-halfY+q>=0) && (k2-halfY+q<sy) ? fx[k1-halfX+p][k2-halfY+q]: 0): 0)
    		pieceY[][] = kernel[p][q]*((k1-halfX+p>=0) && (k1-halfX+p<sx)? ((k2-halfY+q>=0) && (k2-halfY+q<sy) ? fy[k1-halfX+p][k2-halfY+q]: 0): 0)
    		Variable conv = 0
    		for (k3 = 0; k3<kx; k3+=1)
    			for (k4 = 0; k4<ky; k4+=1)
    				Variable vCenterX = halfX - k3
    				Variable vCenterY = halfY - k4
    				Variable n = ELPointPointDist(0,0,vCenterX,vCenterY)
    				if (n != 0)
    					vCenterX = vCenterX / n
    					vCenterY = vCenterY / n
    					conv = conv + (vCenterX*pieceX[k3][k4] + vCenterY*pieceY[k3][k4])
    				endif
    			endfor
    		endfor
    		res[k1][k2] = conv	 
    	endfor
    endfor
	return res 	
end  

function ELGradients(scan, fx, fy)
	Wave scan, fx, fy
	Variable sx = DimSize(scan, 0)
	Variable sy = DimSize(scan, 1)
	
	// Calculate gradient as Matlab does it
	fx[][]   = ((p>0) && (p<sx-1) ? (scan[p+1][q] - scan[p-1][q])/2 : 0)
	fx[0][]  = scan[1][q] - scan[0][q]
	fx[sx-1][] = scan[sx-1][q] - scan[sx-2][q]
	
	fy[][]   = ((p>0) && (p<sx-1) ? (scan[p][q+1] - scan[p][q-1])/2 : 0)
	fy[][0]  = scan[p][1] - scan[p][0]
	fy[][sy-1] = scan[p][sy-1] - scan[p][sy-2]
end

// Clamps 2D wave x with limits v1 and v2. v1<v2
function ELClamp(x, v1, v2)
	Wave x
	Variable v1, v2
	x[][] = min(max(x[p][q], v1), v2) 
end

// Limits dynamic range with given threshold
function/Wave ELLimitClustersRange(scan, clusterID, thresh)
	Wave scan, clusterID
	Variable thresh
	Variable sx = DimSize(scan, 0)
	Variable sy = DimSize(scan, 1)
	
	Make/O/FREE/N=(sx,sy) res
	
	res[][] = clusterID[p][q]
    Variable nClusters = WaveMax(clusterID);
    Make/O/FREE/N=(nClusters+1) maxMap = -Inf;
    Variable k1, k2
    for (k1 = 0; k1<sx; k1+=1)
        for (k2 = 0; k2<sy; k2+=1)
            maxMap[clusterID[k1][k2]] = max(maxMap[clusterID[k1][k2]], scan[k1][k2]);
        endfor
    endfor
    
    for (k1 = 0; k1<sx; k1+=1)
        for (k2 = 0; k2<sy; k2+=1)
            if (scan[k1][k2] < thresh*maxMap[clusterID[k1][k2]])
                res[k1][k2] = 0;
            endif
        endfor
    endfor
    return res
end

function/Wave ELFindCells(scan, neighbors, approxRadiusHint)
	Wave scan
	Variable neighbors
	Variable approxRadiusHint
	Variable sx = DimSize(scan, 0)
	Variable sy = DimSize(scan, 1)
	
	Make/O/FREE/N=(sx,sy) fx, fy

	ELGradients(scan, fx, fy)
	ELClamp(fx, -1, 1)
	ELClamp(fy, -1, 1)
	Variable sigma = 1.1/3 * approxRadiusHint
	Variable sKernel = 2*(approxRadiusHint-1) + 1
	Make/O/FREE/n=(sKernel,sKernel) kernel=gauss(x,(sKernel-1)/2,sigma,y,(sKernel-1)/2,sigma)
	Wave conv = ELConvergence(fx, fy, kernel)
	conv = conv + 1 
	Make/O/FREE/n=(sx,sy) gConv = conv
	
	Wave cID = ELWatershed(conv, neighbors, approxRadiusHint)
	Wave cIDLimited = ELLimitClustersRange(scan, cID, 0.2)
	
	return cIDLimited
end


///////////////////////////////////////////////////

// Main function, called from UI
function RecognizeCells(wImage, wLabels, approxRadiusHint)
	wave wImage, wLabels
	Variable approxRadiusHint
	wave wLabelsRes = ELFindCells(wImage, 4, approxRadiusHint)
	Duplicate/O wLabelsRes wLabels
	return WaveMax(wLabels)
end

	