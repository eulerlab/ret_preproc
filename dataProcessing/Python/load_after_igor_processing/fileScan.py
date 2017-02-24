
# coding: utf-8

# In[294]:

get_ipython().magic(u'matplotlib inline')
from configparser import SafeConfigParser
import fnmatch
import h5py
import hashlib
from itertools import chain
import numpy as np
import os
import pandas as pd
import re
import seaborn as sns

def fileScan(dataDirectory = '/notebooks/Data',fileTypes = ['abf','ini','h5','smh','smp']):
    fileLocation_pathlist = list(chain(*[findFileType('*.' + suffix, dataDirectory) for suffix in fileTypes]))
    fileLocation_table = locationToTable(fileLocation_pathlist)
    
    return fileLocation_table

def findFileType(fileType,directory): # Type: '*.ini'
    # Find .ini files in all folders and subfolders of a specified directory
    fileLocation = [os.path.join(dirpath, f)
    for dirpath, dirnames, files in os.walk(directory)
    for f in fnmatch.filter(files,fileType)]
    return fileLocation

def parseFileLocation(fileLocation,targetString='/'):
    # Extract useful information from directory path
    for fileType in list(fileLocation.keys()):
        backslash = [m.start() for m in re.finditer(targetString, entry)]
        headerFiles[entry].loc['surname'] = ['string',entry[backslash[-4]+1:backslash[-3]]]
        headerFiles[entry].loc['date'] = ['string',entry[backslash[-3]+1:backslash[-2]]]
        headerFiles[entry].loc['nExperiment'] = ['string',entry[backslash[-2]+1:backslash[-1]]]
    return headerFiles

def readSHA1(fileLocation):
    # Find SHA-1 for file at file location
    BLOCKSIZE = 65536
    hasher = hashlib.sha1()
    with open(fileLocation, 'rb') as afile:
        buf = afile.read(BLOCKSIZE)
        while len(buf) > 0:
            hasher.update(buf)
            buf = afile.read(BLOCKSIZE)
    return hasher.hexdigest() 

def locationToTable(fileLocation_pathlist,targetString='/',topDirectory='Data/'):
    # Specification of dataframe in which to store information about files
    tableColumns = ['Surname', 'Date', 'Experiment', 'Subexpr', 'Filename', 'Filetype', 'Path', 'SHA1']
    fileLocation_table = pd.DataFrame(columns=tableColumns)

    for itx in range(len(fileLocation_pathlist)):
        path = fileLocation_pathlist[itx]
        # Find filepath within top directory, typically the 'Data/' folder
        subDirectory = path[path.find(topDirectory)+len(topDirectory):]

        # Find location of backslashes, which demarcate folders
        backslash = [m.start() for m in re.finditer(targetString, subDirectory)]

        # Extract folder and file names
        file = subDirectory[backslash[-1]+1:]
        fileName = file[:file.find('.')]
        fileType = file[file.find('.'):]
        Surname = subDirectory[:backslash[0]]
        Date = subDirectory[backslash[0]+1:backslash[1]]

        Experiment = np.nan
        Subexpr = np.nan
        if len(backslash) > 2:
            Experiment = subDirectory[backslash[1]+1:backslash[2]]
        if len(backslash) > 3:
            Subexpr = subDirectory[backslash[2]+1:backslash[3]]
        
        SHA1 = readSHA1(path)
        
        fileEntry = [Surname,Date,Experiment,Subexpr,fileName,fileType,path,SHA1]
        fileLocation_table.loc[itx] = fileEntry
        
    return fileLocation_table

