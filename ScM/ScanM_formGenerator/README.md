### ScanM formGenerator - formGenerator for IgorPRO

e.g. for experimental header files (beta)

####Functions

``function FG_createForm()``

Generates a new form using ``template.txt`` in the present directory.

``function FG_updateKeyValueLists (sFPath, sFName)``

Update key-value lists from .ini file, with ``sFPath``, a full or partial path to folder for the header file, w/o final "\\", and ``sFName``, the name of header file (``.ini`` file) w/o file extension.

``function FG_updateForm ()``

Update form from key-value lists.

``function FG_saveToINIFile (sFPath, sFName, doOverwrite)``

Saves key-value list to a experimental header file. The file must not yet exist. With ``sFPath``, a full or partial path to folder for the header file, w/o final "\\", ``sFName`` the name of header file (``.ini`` file) w/o file extension, and ``doOverwrite`` (0=abort if file exists; 1=overwrite file after making a backup copy).  Note that only one backup copy is kept.	

####TODO

- Add sanity check for entries, e.g. if a checkbox is checked, there might be more field which then need to be filled out. Could also disable/enable other fields.

- Save button; save on close ...
