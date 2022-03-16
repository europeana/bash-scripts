# bash-scripts
Scripts in this repository are reusable scripts that are run by jenkins jobs or other scripts.
Be very vigilant when changing something here, because it can affect a lot of scripts.  
The utilities directory contains bash script files that contain re-usable functions.  
The files can be sourced in other scripts 
e.g. `source utilities/common_utils.sh`