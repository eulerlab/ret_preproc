import datajoint as dj
import h5py
import datetime
import numpy as np

schema = dj.schema('imaging_v1',locals())	# decorator for all classes that represent tables from the database 'rgcEphys'

@schema
class Animal(dj.Manual):
	definition = """
	# Basic animal info
	
	animal_id			:varchar(255)						# unique ID given to the animal
	---
	species="mouse"		:enum("mouse","rat","zebrafish")								# animal species
	animal_line			:enum("PvCreAi9","B1/6","ChATCre","PvCreTdT","PCP2TdT","ChATCreTdT","WT")	# transgnenetic animal line, here listed: mouse lines
	gender="unknown"	:enum("M","F","unknown")										# gender
	age		            :varchar(255) # Changed from date_of_birth to age															# date of birth
	animRem             :varchar(255)
	"""

@schema
class Experiment(dj.Manual):
	definition = """
	# Basic experiment info. Also includes genetic information.
	
	-> Animal
	
	exp_date	:varchar(255)			# date of recording
	eye			:enum("R","L")	# left or right eye of the animal
	---
	experimenter				:varchar(255)				# first letter of first name + last name = lrogerson/tstadler
	setup="1"					:tinyint unsigned			# setup 1-3
	darkAdapt                   :float
	isInjected="False"          :boolean
	tracer                      :enum("")
	brainInjectQ                :enum("")
	brainInjectRem              :varchar(255)
	virusVector                 :enum("")
	virusSerotype               :enum("")
	virusTransProtein           :enum("")
	preparation="wholemount"	:enum("wholemount","slice")	# preparation type of the retina
	sliceThickness              :tinyint
	prepRem                     :enum("")
	isEpore                     :boolean
	eporDye                     :enum("")
	bathTemp                    :tinyint
	dye         				:enum("sulfrho")			# dye used for pipette solution to image morphology of the cell
	path						:varchar(255)				# relative path of the experimental data folder
	pharmDrug                   :enum("")
	pharmDrugConc               :enum("")
	pharmRem                    :varchar(255)
	"""

@schema
class Cell(dj.Manual): # <- Field?
	definition="""
	# Single cell info
	
	-> Experiment
	
	cell_id	:tinyint unsigned	# unique ID given to each cell patched
	---
	abs_x=0		:smallint			#absolute x coordinate from the sutter in integer precision
	abs_y=0		:smallint			#absolute y coordinate from the sutter in integer precision
	abs_z=0		:smallint			#absolute z coordinate from the sutter in integer precision
	rel_x=0		:smallint			#relative x coordinate from the sutter in integer precision
	rel_y=0		:smallint			#relative y coordinate from the sutter in integer precision
	rel_z=0		:smallint			#relative z coordinate from the sutter in integer precision
	folder		:varchar(50)		#relative folder path for the subexperiment
	morphology	:boolean			#whether morphology of this cell was recorded or not
	"""
	
@schema
class Recording(dj.Manual): # <- Stimulus
	definition="""
	# Stimulus information for a particular recording
	
	->Cell
	
    filename		:varchar(50) 							# name of the converted recording file
    ---
    stim_type		:enum("bw_noise","chirp","ds","on_off","water")	# type of stimulus played during the recording
	"""

@schema
class Rawdata(dj.Computed):
	definition="""
	# Rawdata extracted from h5 file
	
	->Recording
	---
	rawtrace		:longblob	# array containing the raw voltage trace
	tracetimes      :longblob	# array containing the light trigger trace
	triggertimes	:longblob	# array containing the light trigger trace
	"""
	
