# mocap-processing
 Process mocap data from the Stanford HPL

Steps from Cortex to simulation:

CORTEX
1) Label and fill gaps for ALL marker data in Cortex. 
2) Trim capture to only the portion of the trial you are analyzing with options, save as a "Trimmed_myTrial.cap". Appending a number at the end of a new trial name is important to keep your data organized!
3) After editing all marker data for a collection, run "GenerateANC_TRC.sky" in Cortex on one of the HPL computers. (Note: Exporting GRFs is currently not functional on the MoCap Workstation). In Cortex, navigate to Tools->SkyFiles->Batch. This writes out:
    - a .trc file: marker positions
    - a .anc file: analog data in bits. Need to turn this into volts before EMG or force processing.
	
MATLAB
4) Write GRFs + COP to a .mot file: In MATLAB, run write_GRF_MotFile.m. Change flags depending on treadmill or overground, and how you want to name the forces being applied to both feet. This script takes a .trc and a .anc. It uses .trc to determine what foot to apply forces to and to make sure the COP stays within the foot when vertical forces are low.
5) If you have dynamic hip joint center trials, skip this step and go to step 6. Otherwise, in MATLAB, run RotateTRC.m to rotate the marker data from the force place reference frame to the OpenSim frame. 

OPTIONAL
6) If you have dynamic hip joint center trials, run ?????.m to add virtual markers, hip centers to marker data, and rotate to OpenSim frame (x forward, y up, z right) from lab frame (x forward, y left, z up when facing cupboards for overground and walking forward on treadmill).
7) Process EMG data and write to a .sto file. This takes in a .anc file, an opensim model, and it looks for normalization .anc files (maxAct_<something>.anc). You define a mapping between your analog muscle names and the muscle names in the opensim model. It then processes the EMG data (bandpass filter, rectify, lowpass filter), normalizes by the largest value it got in any of the maxAct trials, then writes it to a .sto file.
