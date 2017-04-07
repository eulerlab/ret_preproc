# -*- coding: utf-8 -*-
"""
Created on Tue May 10 11:03:55 2016

@author: andre
"""

#script to assign data collected to a previously existing cluster
#use the next two lines to add reload to ipython. 
#%% 
%load_ext autoreload
##
%autoreload 2  
#%% 
#import copy
import pandas as pd
import os
import numpy as np
#import h5py
#import re
import matplotlib.pyplot as plt
import pycircstat as circ
#import scipy.signal as signal
#from configparser import ConfigParser
import scipy.io.matlab as matlab

os.chdir("E:\\github\\ret_preproc\\dataProcessing\\Python\\load_after_igor_processing")
import ImportPreprocessedData as ipd

os.chdir("E:\\github\\ret_preproc\\dataProcessing\\Python\\postProcessing")
import classFuncs as cfs
#%% 
#os.chdir("E:\\github\\ret_preproc\\dataProcessing\\Python\\read_scanm_python")
#import readScanM as rsm

#load data from nature paper
natureFile = "Z:\\User\\Chagas\\nature2016_RGCs\\2016_clusters.mat"
#natureFile = "E:\\2016_nature_paper\\2016_clusters.mat"
natureData = matlab.loadmat(natureFile)

dbPath = "Z:\\Data\\Chagas\\"

#          

experimentList=[#"20161102\\1\\","20170119\\1\\",
                #"20160607\\1\\","20160914\\1\\",
                #"20160919\\1\\","20160921\\1\\",
                #"20160927\\1\\","20161005\\2\\",
                #"20161017\\1\\","20161011\\1\\",
                #"20170217\\1\\","20170221\\1\\",
                "20170223\\2\\","20170223\\1\\",                
                #"20161026\\1\\","20161102\\1\\",
                #"20170119\\1\\", 
                 ]
                #
#folderName = "20170223\\"
#subFolder = "1\\"
#"20161026\\2\\",



#headerPath = dbPath+folderName+subFolder+"Raw\\"

#not to comprimise the folder/file structure of the DB,
#use another location on the server to save the data
storePath = "Z:\\User\\Chagas\\analysisResults\\"


 

#turn analysis of responses to certain stimulus on/off.
noiseFlag=False
cnoiseFlag=False
bgFlag=True
chirpFlag=True
dsFlag=True
darkdsFlag=False
spotFlag=False
flickerFlag=False

allCells = 0
#%% 
for folder in experimentList:
    folderName=folder.split("\\")[0]+"\\"
    subFolder = folder.split("\\")[1]+"\\"
    filePath = dbPath+folder+"Pre\\"
    tree = cfs.get_folder_tree(filePath)
    fileList= [s for s in tree if "Pre" in s]
    fileList.sort()
    
    for filePrefix in fileList:
        if "loc" not in filePrefix: 
            fileFolder=filePrefix[0:filePrefix.index("\\SMP")]
            print(filePrefix)
            splitFile = filePrefix.split("\\")
            
            fileName = splitFile[-1]
    
            sufix = fileName.split("_")
            sufix = sufix[-1]
            sufix = sufix.split(".")
            sufix = sufix[0]

            #get ini file, in order to get which eye was used
            experimentIni = filePrefix[0:filePrefix.index("\\Pre")+1]
            experimentIni = cfs.get_folder_tree(experimentIni)
            experimentIni = experimentIni[".ini" in experimentIni]

            #grab only the ones related to coordinate recording (edges + optic disk)
            coorList = [s for s in fileList if "loc" in s]
    
            if len(coorList) > 0:
                fieldOut,fieldOutAbs = cfs.process_field_location(iniFile = experimentIni,
                                          edgesFolder = fileFolder,
                                          fieldPath = filePrefix ,pattern=None,
                                          fileList = coorList[:]) 
        
                fieldx = fieldOut["x"].dropna().values[0]
                fieldy = fieldOut["y"].dropna().values[0]
                fieldxabs = fieldOutAbs["x"].dropna().values[0]
                fieldyabs = fieldOutAbs["y"].dropna().values[0]
            else:
                print("no coordinate recordings")
                fieldx=np.nan
                fieldy=np.nan
                fieldOut = pd.DataFrame([[np.nan,np.nan]],index=["no_loc","no_loc"])
                
            if np.any(fieldOut.index == "ventral"):
                fieldOut["x"] = fieldOut["x"]*-1
            
            if np.any(fieldOut.index == "nasal"):
                fieldOut["y"] = fieldOut["y"]*-1

            fieldx=pd.Series(fieldx,index=[int(0)],name="relative_x")
            fieldy=pd.Series(fieldy,index=[int(0)],name="relative_y")
            
            fieldxabs=pd.Series(fieldxabs,index=[int(0)],name="abs_x")

            quadrant = pd.DataFrame([fieldOut.values[0][0],fieldOut.values[1][1],
                                 fieldOutAbs.values[0][0],fieldOutAbs.values[1][1]],
                                columns=[0],
                                index=[fieldOut.index[0],fieldOut.index[1],
                                       fieldOutAbs.index[0]+"_abs",fieldOutAbs.index[1]+"_abs"])

#    if "loc" not in filePrefix:  
            _,data = ipd.importPreprocessedData(filePath+"//"+fileName)
                             
        #get all traces
            allTraces = data["Traces0_raw"]
            allTraces = allTraces.transpose()
            dim=1
        
        #get OS_parameter dict
#        osPar = 
        #get sampling frequency
            sampRate = data["OS_Parameters"]["samp_rate_hz"]
            
        #get stimulator delay
            stimDel = data["OS_Parameters"]["stimulatordelay"]
        #get all rois
            rois = data["ROIs"]

            xcoor = pd.Series(data['wParamsNum']['xcoord_um'],name='xcoord_um')
            ycoor = pd.Series(data['wParamsNum']['ycoord_um'],name='ycoord_um')
            zcoor = pd.Series(data['wParamsNum']['zcoord_um'],name='zcoord_um')
    
            storeName = filePrefix[:]
            storeName = storeName.replace("Data","user")
            storeName = storeName.replace(folderName,"analysisResults\\"+folderName)        
        
            if not os.path.exists(storeName[0:storeName.index("\\Pre")]):
                os.makedirs(storeName[0:storeName.index("\\Pre")])
        
            storeName = storeName.replace("\\Pre","")
            storeName = storeName.replace(".h5","_panda.h5")
           
            hdStore = pd.HDFStore(storeName,"w") 
#%%   
            for i in range(0,np.size(allTraces,dim)):
#        for i in [33,40,55,57,30,65,25,46,62,31,52,2,27,9,24,60,59,22,64,14,44,20,17,43,53,19,21]:
                temp = "cell"+str(i+1)
                print(temp) 
                pixels,roix,roiy = cfs.calc_area(rois,i)
                pixels=pixels*((110/64)*(110/64)) 
                pixels = pd.Series(pixels,name="area_um")
                samp = pd.Series(sampRate,name="sampRate")
                stimDel = pd.Series(stimDel,name="stimulator_delay")      
                
            #set the index to call from the roi dictionary
                if i+1 < 10:
                    indx="00"+str(i+1)
                elif i+1 < 100:
                    indx="0"+str(i+1)
                else:
                    indx=str(i+1) 


                if "noise" not in  filePrefix and "cnoise" not in filePrefix:
                    if "chirp" in filePrefix or "bg" in filePrefix or "spot" in filePrefix:
                        trig = 2
                        flag = 1
                    else:
                        trig = 1
                        flag = 1
                else:  
                    trig = 1
                    flag = 0

                rawTrace = allTraces["ROI"+indx]
        
                traceTime = data["Tracetimes0"][i,:]
                triggerTime = data["Triggertimes"]

                allData = cfs.raw2panda(rawTrace=rawTrace,traceTime=traceTime, 
                                    triggerTime=triggerTime,
                                    trigMode=trig,sampRate=sampRate,
                                    stimName=sufix,trialFlag=flag)                                 
                
                
                allData = allData.append(pixels)
                allData = allData.append(samp)
                allData = allData.append(stimDel)
                allData = allData.append(xcoor)
                allData = allData.append(ycoor)
                allData = allData.append(zcoor)
                allData = allData.append(fieldx)
                allData = allData.append(fieldy)
                allData = allData.append(quadrant)
#%%         
                if "bg" in filePrefix and bgFlag is True:
                    allData = cfs.process_bg(allData)
             
#%%            
                if "ds" in filePrefix and dsFlag is True and "dark" not in filePrefix:
                    allData = cfs.process_ds(allData,sufix)
#%%                     
                if "darkds" in filePrefix and darkdsFlag is True:
                    allData = cfs.process_ds(allData,sufix)
#%%             
                if "chirp" in filePrefix and chirpFlag is True:
                    allData = cfs.process_chirp(allData,natureData)
                    allCells = allCells + 1
#                    clusterName="31"
#                    plt.plot(natureData["c"+clusterName]["chirpMean"][0][0][0])
#                    plt.plot(allData.loc["medianTrace"][0:249])
#%% 
                if "flicker" in filePrefix and flickerFlag is True:

                    stim,tStim = cfs.create_step(sampFreq=sampRate,sizes=1,onTime=2.0,offTime=2.0)
                    stim = pd.Series(stim.flatten(),name="stimTrace")
                    tStim = pd.Series(tStim.flatten(),name = "stimVector")
                    allData = allData.append(stim)
                    allData = allData.append(tStim)      
#%%                     
                if "spot" in filePrefix and spotFlag is True:
                    
                    stim,tStim = cfs.create_step(sampFreq=sampRate,sizes=2,onTime=2.0,offTime=2.0)
                    stim = pd.Series(stim.flatten(),name="stimTrace")
                    tStim = pd.Series(tStim.flatten(),name = "stimVector")
                
                    allData = allData.append(stim)
                    allData = allData.append(tStim)               
#%%                 
                if ("noise" in filePrefix and noiseFlag is True and "cnoise" not in filePrefix) or \
                            ("cnoise" in filePrefix and cnoiseFlag is True):
            
                    stimuliPath="Z:\\User\\Chagas\\RGCs_stimuli\\"
                    storeName2 = filePrefix[:]
                    storeName2 = storeName2.replace("Data","user")
                    storeName2 = storeName2.replace(folderName,"analysisResults\\"+folderName)
                    storeName2 = storeName2.replace("\\Pre","")
                    storeName2 = storeName2.replace(".h5","_resp.h5")
                    hdStore2 = pd.HDFStore(storeName2,"w") 
        
                    if "noise" in filePrefix and "cnoise" not in filePrefix:
                        noiseFile = "BWNoise_official.txt"
                    
                    #cNoise=False
                    else:
                        noiseFile = "colorNoise.txt"
#                        cNoise=True
#                        hdStore1 = pd.HDFStore(storePath+folderName+subFolder+filePrefix+sufix+"_cnoise.h5","w")
                
                    noiseList = cfs.read_stimulus(stimuliPath+noiseFile)
                
                    noise = cfs.reconstruct_noise(noiseList)
                
            

                #if noiseF==1 and noiseCount<2:
                    if ~os.path.isfile(storePath+folderName+subFolder+filePrefix+sufix+"_stim.h5"):
                        noiseStimPath = storeName[0:storeName.index(".")-6]
                        hdStore1 = pd.HDFStore(noiseStimPath+"_stim.h5","w")
                        for j in range(len(noise)):
                            rFrame = pd.DataFrame(noise[j,:,:,0]) 
                            gFrame = pd.DataFrame(noise[j,:,:,1]) 
                            bFrame = pd.DataFrame(noise[j,:,:,2]) 
                            exec("hdStore1['red_frame_"+str(j)+"'] = rFrame")
                            exec("hdStore1['green_frame_"+str(j)+"'] = gFrame")
                            exec("hdStore1['red_frame_"+str(j)+"'] = bFrame")
                        
#                        noiseCount=noiseCount+1
                        hdStore1.close()
#                  noiseF=0
                    
                
                #pyplot.plot(trace)
                    if len(triggerTime)>=1000:
                    
                        trace,triggerInd,trigger = cfs.get_traces_n_triggers(allData)
                        trace = trace[~np.isnan(trace)]
                              
                        velTrace,normTrace,sd = cfs.get_vel_trace(trace)
                    
                        indexes = cfs.get_peaks_above_sd(trace = velTrace,sd = sd,onlypos=1)
                        
                    #create 5x5 gaussian window with 1 as standard deviation
                        gauss = cfs.create_2d_gaussian_window(5,5,1)
                



                                
                        allTimesG = list()
                        allTimesB = list()                                     
                        for j in range(0,-10,-1):
                            if j<0:
                                sign="neg"
                            else:
                                sign="pos"
                        
                            rawG=cfs.STA(spkInd=indexes,triggerInd=triggerInd.dropna(),
                                       stimMatrix=noise[:,:,:,1],responseTrace=trace,
                                       timeDelay=j,gaussianFilter=gauss)
                        
#                    rawG = rawG/np.std(rawG)
                        
                            rawB=cfs.STA(spkInd=indexes,triggerInd=triggerInd.dropna(),
                                       stimMatrix=noise[:,:,:,2],responseTrace=trace,
                                       timeDelay=j,gaussianFilter=gauss)
                        
                            avgG = np.mean(rawG,axis=0)                  
                            avgB = np.mean(rawB,axis=0)

#                    avgB = signal.convolve2d(in1=np.mean(rawB,axis=0),in2=gauss,
#                                         mode="same",boundary='symm')
#                    avgG = signal.convolve2d(in1=np.mean(rawG,axis=0),in2=gauss,
#                                         mode="same",boundary='symm')
                    
                    
                            tempG ="avg_green_RF_"+sign+str(abs(j))
                            tempB ="avg_blue_RF_"+sign+str(abs(j))

                        
                            allTimesG.append(avgG)#/np.std(avgG))
#                    allAvgG.append(avgG)
                            allTimesB.append(avgB)#/np.std(avgB))
#                    avgG=pd.DataFrame(avgG)
#                    avgB=pd.DataFrame(avgB)

                            
                            exec("hdStore2['"+temp+"_"+tempG+"'] = pd.DataFrame(avgG)")
                            exec("hdStore2['"+temp+"_"+tempB+"'] = pd.DataFrame(avgB)")

                        
                        
                        maxFrameG,maxRowG,maxColG = np.where(allTimesG==np.amax(allTimesG))
                
                        idxMaxG = pd.DataFrame([maxFrameG,maxRowG,maxColG],
                                       index=["frame","row","column"],
                                        columns=["max_green"])    
                
                        minFrameG,minRowG,minColG = np.where(allTimesG==np.amin(allTimesG))
                
                        idxMinG = pd.DataFrame([minFrameG,minRowG,minColG],
                                       index=["frame","row","column"],
                                        columns=["min_green"])
                
                        maxFrameB,maxRowB,maxColB = np.where(allTimesB==np.amax(allTimesB))
#                
                        idxMaxB = pd.DataFrame([maxFrameB,maxRowB,maxColB],
                                       index=["frame","row","column"],
                                       columns=["max_blue"])
#                
                        minFrameB,minRowB,minColB = np.where(allTimesB==np.amin(allTimesB))
#                   
                        idxMinB = pd.DataFrame([minFrameB,minRowB,minColB],
                                       index=["frame","row","column"],
                                        columns=["min_blue"])
                
#                for k in range(0,5):#len(allTimesG)):
#                    plt.matshow(test[k],
#                                vmax=np.max(test),
#                                vmin=np.min(test),cmap="gray_r")
#                    plt.matshow(testA[k],
#                                vmax=np.max(testA),
#                                vmin=np.min(testA),cmap="gray_r")
#                    if k==7:
#                        
#                        plt.colorbar()
                        
                        allData = allData.append(idxMaxG)
                        allData = allData.append(idxMaxB)
                        allData = allData.append(idxMinG)
                        allData = allData.append(idxMinB)
                
            #end if suifx is noise
                    hdStore2.close() 
            
                hdStore[temp] = allData
#            del allData
#                allData.to_hdf(storePath+folderName+subFolder+filePrefix+sufix+"_panda.h5",
#                           "/"+temp+"/",append=True)
            
            hdStore.close()
            #del hdStore
#    if "hdStore2" in locals():
#        hdStore2.close()
##            del allData


#k=1
#plt.matshow(allTimesG[k],vmin =np.amin(allTimesG), vmax=np.amax(allTimesG))
#plt.colorbar()