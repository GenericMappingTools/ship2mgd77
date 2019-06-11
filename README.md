# ship2mgd77

Tool for producing NCEI-compliant MGD77T files from shipboard data.
Michael T. Hamilton

To build and install, cd into src and type "make all".
All scripts and executables will be placed in the directory bin
at the same level as src.

The latest magnetic indices files can be found in the share
directory.  You should either replace the ones in the GMT
share/mgd77 directory with these or edit ship2mgd77.so to
pass the full paths to the new ones via mgd77magref options

	**-D**\ *path-to-Dst_all.wdc* **-E**\ *path-to-F107_mon.plt*
	
For information about usage and test data, please visit
http://www.soest.hawaii.edu/mgd77 and select Documentation.
