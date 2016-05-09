# -*- coding: utf-8 -*-
"""
Created on May 6th 2016 @author: Luke Edward Rogerson, AG Euler

"""
import datajoint as dj

@schema
class StimulusFile(dj.Manual):
    definition = """
    # General stimulus attributes

    -> Experiment
    
    commit_id               :varchar(255) # commit id on github
    --- 
    linked_file_id          :varchar(255) # commit id of file dependency on github
    name                    :varchar(255)
    description             :varchar(255)
    platform                :varchar(255) # eg. QDStim, QDSpy, Arduino
    language                :varchar(255) # eg. Python 2, Python 3, Arduino
    is_noise                :varchar(5)   # Whether the stimulus is suitable for STA
    """
    
class StimulusSpec(dj.Manual):
    definition = """
    # Basic experiment info

    -> StimulusFile
    
    spec_id                 :tinyint 
    ---
    frame_duration          :float
    marker_duration         :float
    trials                  :tinyint
    random_seed             :tinyint
    parameters              :longblob
    """    

        