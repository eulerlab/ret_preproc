#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function OS_hdf5Import(filePath)
//function to open hdf5 files in igor. It is more flexible than hdf5import.ipf,
//since this function opens all items inside the hdf5 file automatically.
//created by amchagas April 2016.
string filePath

if (strlen(filePath)==0)
	filePath=""
endif


//create necessary variables, strings and what not
variable fid;
string groups;
variable ii=0;
string temp
string  dataFolder
variable dataIndx
string attrib

//create a data folder with the file name where all data from file
//will be stored
if (!stringmatch(filePath,""))
	dataIndx = strsearch(filePath,"\\",inf,1)
	dataFolder = "root:"+filePath[dataIndx+1,inf]
	print (dataFolder)
else
	dataFolder = "root:hdf5data"
	//print (dataFolder)
	
endif
NewDataFolder /O/S $dataFolder

make /O /T  attributes //create text wave
InsertPoints /M=1 0,1, attributes //make the wave 2 dimensions

HDF5OpenFile /R fid as filePath //open hdf5 file
HDF5ListGroup fid, "/" //get all groups that are inside root ("/")
groups = S_HDF5ListGroup  //make previous function output explicit

ii=0; //index for the while loop
do 
	temp = stringfromlist(ii,groups,";") //get the next group name
	if (!stringmatch(temp,"")) //if temp is not empty
		HDF5ListAttributes /TYPE = 2, fid, temp //get attributes from that group
		attrib = S_HDF5ListAttributes //store the attributes in an explicit variable
		//print "attribute"
		//print attrib
		HDF5LoadData /O /A="" /Q /IGOR=-1 /VAR=1 fid, temp //load data from group
		attributes [ii][0] = temp //store the attribute name in the first column
		attributes [ii][1] = attrib //store the attribute type in the second column

	endif
	ii= ii+1 //increase group name index
while( strlen(temp) >= 1 ) //while the temp string has something in it (aka is not 0)

end //do - while

HDF5CloseFile fid //close the hdf5 file

end