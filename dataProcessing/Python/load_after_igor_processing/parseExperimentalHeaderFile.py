
# coding: utf-8

# In[43]:

from configparser import SafeConfigParser
import fnmatch
import os
import pandas as pd
import re

def importAllHeaders():
    docker = True
    # Import all header files in directory as DataFrames; store each DataFrame in dictionary
    headerFiles = {fileLocation:readExperimentalHeader(fileLocation) for fileLocation in findExperimentalHeader(docker)}
    headerFiles = parseFileLocation(headerFiles,docker)
    return headerFiles

def findExperimentalHeader(docker):
    if docker: directory='/notebooks/Data'
    else: directory = r'\\172.25.250.112\euler_data\Data' 
    # Find .ini files in all folders and subfolders of a specified directory
    headerFileLocation = [os.path.join(dirpath, f)
    for dirpath, dirnames, files in os.walk(directory)
    for f in fnmatch.filter(files, '*.ini')]
    return headerFileLocation

def parseFileLocation(headerFiles,docker):
    # Extract useful information from directory path
    for entry in list(headerFiles.keys()):
        if docker: targetString = '/'
        else: targetString = r'\\'
        backslash = [m.start() for m in re.finditer(targetString, entry)]
        headerFiles[entry].loc['surname'] = ['string',entry[backslash[-4]+1:backslash[-3]]]
        headerFiles[entry].loc['date'] = ['string',entry[backslash[-3]+1:backslash[-2]]]
        headerFiles[entry].loc['nExperiment'] = ['string',entry[backslash[-2]+1:backslash[-1]]]
        print('Found: ' + entry[backslash[-1]+1:] + ' at ' + entry[:backslash[-1]+1])
        ## Check surname in filepath matches entry in experiment header
        # if headerFiles[entry].loc['surname'] is not headerFiles[entry].loc['experimenter']: 
        #    print('Error: surname in directory and experimenter surname do not match')
    return headerFiles

def readExperimentalHeader(fileLocation):
    # Read .ini file cf: https://wiki.python.org/moin/ConfigParserExamples
    parser = SafeConfigParser()
    parser.read(fileLocation)

    # Store entries from .ini file in pandas dataframe
    experimentalHeader = pd.DataFrame(columns=['valueType','valueEntry'])
    for section in parser.sections():
        for option in parser.options(section):
            underScoreLocation = option.find("_")
            headerKey = option[underScoreLocation+1:]
            experimentalHeader.loc[headerKey] = [option[0:underScoreLocation],parser.get(section,option)]
    return experimentalHeader

