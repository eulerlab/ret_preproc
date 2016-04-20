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

Additional dependencies of recording on stimulus table
[Stimulus   <- Recording                        ] 

Inclusion of stacks and images for a given field
[...        <- Field    <- Zstack               ]
[                       <- Image                ]

~ Notes 

Currently put Geneline as the highest point in the heirarchy. Though I think a case can be 
made for putting it lower than this, it seems like a reasonable first category for pooling
experiments.

Not sure whether to separate Indicator table into Electroporation, Retinal Injection and 
Brain Injection subtables. If so, what would be the natural primary keys for each of these 
tables? Does it make sense to separate them when each retina in an experiment would only 
have one entry for each of these tables?

Have removed enum() in favour of varchars. In general, have set all varchar to be 255, though
these could be limited in some cases as an error check. Where varchar(5) is present, the cell
in the table is intended for booleans. If it is more intuitive to use a tinyint, these can be
updated. There is no option to input boolean directly.

There seem to be a few things in the experiment details which are potentially superfluous (e.g.
bath temperature) or otherwise clutter the information. Should these be migrated to their own
experiment info table?

"""
import datajoint as dj

@schema
class Geneline(dj.Manual):
    definition = """
    # Information about the genetic background name
    
    bkg_line                  :varchar(255)                     # Genetic background line
    ---    
    genbkglinerem             :varchar(255)                     # Comments about background line
    genline_reporter          :varchar(255)                     # Genetic reporter line 
    genline_reporterrem       :varchar(255)                     # Comments about reporter line 
    """
    
@schema
class Animal(dj.Manual):
    definition = """
    # Basic animal info
    
    -> Geneline
    
    animal_id                 :varchar(255)                     # unique ID given to the animal
    ---
    species="mouse"           :enum("mouse","rat","zebrafish")  # animal species
    gender                    :enum("M","F")                    # gender.
    date_of_birth             :date                             # date of birth
    age                       :varchar(255)                     # Whether to have this or DOB?
    anim_rem                  :varchar(255)                     # Comments about animal
    """

@schema
class Experiment(dj.Manual):
    definition = """
    # Basic experiment info

    -> Animal

    exp_date                    :date                           # date of recording
    eye                         :enum("L","R","U")              # left or right eye of the animal
    ---
    path                        :varchar(255)                   # relative path of the experimental data folder
    experimenter                :varchar(255)                   # first letter of first name plus last name
    proj_name                   :varchar(255)                   # name of experimental project
    setup                       :tinyint                        # setup 1-3
    preparation="wholemount"    :enum("wholemount","slice")     # preparation type of the retina
    dark_adaptation             :float                          # time spent dark adapting animal before disection
    slice_thickness             :tinyint                        # thickness of each slice in slice preparation
    bath_temp                   :tinyint                        # temperature of bath chamber
    prep_rem                    :varchar(255)                   # comments on the preparation
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
    is_injected                 :varchar(5)                     # whether the retina was injected
    virus_vector                :varchar(255)                   # what vector was used in the injection
    virus_serotype              :varchar(255)                   # what serotype was used in the injection 
    virus_trans_protein         :varchar(255)                   # the viral transprotein
    virus_inject_rem            :varchar(255)                   # comments about the injection 
    virus_inject_q              :varchar(255)                   # numerical rating of the injection quality
    is_brain_inject             :varchar(5)                     # whether the brain has been injected
    tracer                      :varchar(255)                   # what tracer has been used in the brain injection
    brain_inject_q              :varchar(255)                   # numerical rating of the brain injection quality
    brain_inject_rem            :varchar(255)                   # comments on the brain injection
    """
    
@schema
class Pharmacology(dj.Manual): 
    definition = """
    # Information about pharmacology used in experiment

    -> Experiment
    
    pharm_drug                  :varchar(255)                   # name of drug which was applied
    --- 
    pharm_drug_conc             :varchar(255)                   # concentration of drug
    pharm_rem                   :varchar(255)                   # comments on the drug application
    """

@schema
class Field(dj.Manual):
    definition="""
    # Info about a single field of cells, for which there are one or more recordings
    
    -> Experiment
    
    field_id                    :tinyint                        # integer id of field
    ---
    roi_mask                    :longblob                       # roi mask for the recording field  
    """
        
@schema
class Recording(dj.Manual): 
    definition="""
    # Info about a recording for a particular field. Typically corresponding to one stimuli.
    
    -> Field
    
    recording_id                :tinyint                        # integer id of recording
    ---
    stim_type                   :varchar(255)                   # type of stimulus played during the recording
    trigger_times               :longblob                       # numerical array of stimulus triggers 
    """
    
@schema
class Roi(dj.Manual): 
    definition="""
    # Roi extracted from recording according to roi mask
    
    -> Recording
    
    roi_num                     :tinyint                        # integer id of roi
    ---
    trace_times                 :longblob                       # numerical array of trace times
    traces_raw                  :longblob                       # raw trace from recording
    """
   