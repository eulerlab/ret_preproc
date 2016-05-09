# -*- coding: utf-8 -*-
"""
Created on April 19th 2016 @author: Luke Edward Rogerson, AG Euler

~ Heirarchy (Arrow indicates membership to)

Geneline    <- Animal   <- Experiment   <- Field        <- Recording    <- Roi
                                        <- Indicator
                                        <- Pharmacology

~ Potential Expansions

Computed traces and receptive fields                                       
[...        <- Roi      <- Trace        <- RF   ]

Inclusion of stacks and images for a given field
[...        <- Field    <- Zstack               ]
[                       <- Image                ]

"""
import datajoint as dj

schema = dj.schema(p['database'],locals())

@schema
class Animal(dj.Manual):
    definition = """
    # Basic animal info
    
    animid                    :varchar(255)                     # unique ID given to the animal
    ---
    genbkgline                :varchar(255)                     # Genetic background line
    genbkglinerem             :varchar(255)                     # Comments about background line
    genline_reporter          :varchar(255)                     # Genetic reporter line 
    genline_reporterrem       :varchar(255)                     # Comments about reporter line 
    animspecies="mouse"       :enum("mouse","rat","zebrafish")  # animal species
    animgender                :enum("M","F")                    # gender.
    animage                   :varchar(255)                     # Whether to have this or DOB?
    animrem                   :varchar(255)                     # Comments about animal
    """

@schema
class Experiment(dj.Manual):
    definition = """
    # Basic experiment info

    -> Animal

    date                        :date                           # date of recording
    eye                         :enum("left","right","unknown") # left or right eye of the animal
    ---
    path                        :varchar(255)                   # relative path of the experimental data folder
    username                    :varchar(255)                   # first letter of first name plus last name
    projname                    :varchar(255)                   # name of experimental project
    setupid                     :varchar(255)                   # setup 1-3
    prep="wholemount"           :enum("wholemount","slice")     # preparation type of the retina
    darkadapt_hrs               :float                          # time spent dark adapting animal before disection
    slicethickness              :tinyint                        # thickness of each slice in slice preparation
    preprem                     :varchar(255)                   # comments on the preparation
    bathtemp_degc               :tinyint                        # temperature of bath chamber
    """

@schema
class Indicator(dj.Manual):
    definition = """
    # Basic indicator info

    -> Experiment
    
    indicator_id                :tinyint                        # id associated with indicator
    ---
    is_epore                    :varchar(5)                     # whether the retina was electroporated
    epor_rem                    :varchar(255)                   # comments about the electroporation
    epor_dye                    :varchar(255)                   # which dye was used for the electroporation
    isvirusinject               :varchar(5)                     # whether the retina was injected
    virusvect                   :varchar(255)                   # what vector was used in the injection
    virusserotype               :varchar(255)                   # what serotype was used in the injection 
    virustransprotein           :varchar(255)                   # the viral transprotein
    virusinjectrem              :varchar(255)                   # comments about the injection 
    virusinjectq                :varchar(255)                   # numerical rating of the injection quality
    isbraininject               :varchar(5)                     # whether the retina was injected
    tracer                      :varchar(255)                   # what tracer has been used in the brain injection
    braininjectq                :varchar(255)                   # numerical rating of the brain injection quality
    braininjectrem              :varchar(255)                   # comments on the brain injection
    """


@schema
class Field(dj.Manual):
    definition="""
    # Info about a single field of cells, for which there are one or more recordings
    
    -> Experiment
    
    field_id                    :tinyint                        # integer id of field
    ---
    field_str                   :varchar(255)                   # string identifying files corresponding to field
    """

@schema
class Pharmacology(dj.Manual): 
    definition = """
    # Information about pharmacology used in experiment

    -> Field
    
    pharmdrug                  :varchar(255)                   # name of drug which was applied
    --- 
    pharmdrugconc_um           :varchar(255)                   # concentration of drug
    pharmrem                   :varchar(255)                   # comments on the drug application
    """
           
@schema
class Recording(dj.Manual): 
    definition="""
    # Info about a recording for a particular field. Typically corresponding to one stimuli.
    
    -> Field
    # -> StimulusSpec
    
    recording_id                :tinyint                        # integer id of recording
    ---
    os_parameters               :longblob                       # parameters used in preprocessing script
    triggertimes                :longblob                       # numerical array of stimulus triggers 
    wdatach0                    :longblob                       # Raw data from first channel
    wdatach1                    :longblob                       # Raw data from second channel
    """
    
@schema
class Roi(dj.Manual): 
    definition="""
    # Roi extracted from recording according to roi mask
    
    -> Recording
    
    roi_num                     :tinyint                        # integer id of roi
    ---
    roi_mask                    :longblob                       # roi mask for the recording field
    trace_times                 :longblob                       # numerical array of trace times
    trace_raw                  :longblob                       # raw trace from recording
    """