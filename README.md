# PwshIFMResXTools
PowerShell tools (scripts) for manipulating RESX files from IFM's Maintenance tool for IFM's PLC and HMI modules.

## IFM MPC RESX Reducer.ps1
Reduce the size of a RESX file for the IFM BasicLine series of modules, by removing unnecessary memory records.
- The script accepts two parameters.
  - SearchPath - Accepts a list of wildcard paths to search for RESX files to reduce.  The pipeline may also be used to supply this parameter with file path arguments.
  - Recurse - A switch to recurse the specified paths.
- Reduced files (or files attempted to be reduced) will have appended to their name ' Reduced' in the same location.

## IFM RESX Classic H86 Extraction.ps1
Sample scripts to extract H86 files from the RESX file of Classic line of modules.
- This script file is not yet ready to be ran as a script, instead use excerpts of the file individually.  Scripting knowledge required.
- H86 files are compatible with other tools, namely IFM's Download tool.

## Futher Notes
These tools are still a work in progress.  It is expected that in the near future, they will be revised to be modules that could be imported in to a PowerShell session, accepting arguments or pipeline input

For more info on IFM, see http://www.ifm.com/