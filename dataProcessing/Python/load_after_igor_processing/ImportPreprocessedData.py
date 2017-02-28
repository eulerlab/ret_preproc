
#get_ipython().magic(u'matplotlib inline')
import h5py
import numpy as np
import os
import pandas as pd
import seaborn as sns

# Import differences between remote iPython scripts and local desktop scripts. Marked with ##REMOTE tags

def importPreprocessedData(filePath,fileName):
    # Import preprocessedData.h5 from specified directory, store in dictionary
#    os.chdir('/notebooks/Data/Rogerson/20151027/3/Imaging') ##REMOTE - will differ for local and remote execution
    importedData = h5py.File(filePath+"//"+fileName, "r")
    preprocessedData = {wave:np.asarray(np.transpose(importedData[wave])) for wave in list(importedData.keys())}
    
    # Set minimimum ROI index to zero
    preprocessedData['ROIs'] = preprocessedData['ROIs'] - preprocessedData['ROIs'].min()

    # Convert waves to pandas dataframe
    preprocessedData = removeNanValues(preprocessedData,['OS_Parameters','Triggertimes','Triggervalues'])
    
    # Convert OS_Parameters to dataframe with parameter labels

    parameterLabels = [str(attribute[0]).replace('b','') for attribute in importedData['OS_Parameters'].attrs['IGORWaveDimensionLabels'][1:]]    
    preprocessedData['OS_Parameters'] = pd.DataFrame([value for value in importedData['OS_Parameters']], index=parameterLabels,columns=['Value'])

    
    #Convert Traces0_raw and Traces0_znorm to pandas dataframe with numbered ROIs
#    preprocessedData = labelledDataframe(preprocessedData,['Traces0_znorm','Traces0_raw'])
    #seems znorm are not exported anymore
    preprocessedData = labelledDataframe(preprocessedData,['Traces0_raw'])
    
    # Combine triggerTimes and triggerValues in single pandas dataframe
    preprocessedData['Triggers'] = pd.DataFrame(np.transpose([preprocessedData.pop('Triggertimes', None),preprocessedData.pop('Triggervalues', None)]),columns=['Trigger Time','Trigger Value'])
    
    # Plot ROIs as heatmap
    # plotROIs(preprocessedData['ROIs'])
    
    return importedData, preprocessedData

def removeNanValues(preprocessedData,entries):
    for entry in entries:
        preprocessedData[entry] = (preprocessedData[entry][~np.isnan(preprocessedData[entry])])
    return preprocessedData

def labelledDataframe(preprocessedData,entries):
    for entry in entries:
        ROIindex = {"ROI" + str(num+1).zfill(3) for num in range(preprocessedData[entry].shape[0])}
        preprocessedData[entry] = pd.DataFrame(preprocessedData[entry],index=ROIindex)
    return preprocessedData

def plotROIs(ROIs):
    from pylab import rcParams
    rcParams['figure.figsize'] = 5,5
    sns.heatmap(preprocessedData['ROIs'],cmap="Dark2",cbar=False, yticklabels=False, xticklabels=False)

