%% This script converts OG anc files to mot in OpenSim Land 
clear ; close all ; format compact ; clc

repoDir = [pwd,''];
addpath([repoDir, '']);

% User inputs if you'd like
dataDir = [repoDir '/anc_files'] ;
cd(dataDir)

%freq_filtering = 15 ; % lpCutoffFreq for generic force data usually 999 for no filter
freq_filtering = 999;
zero_threshold = 20 ; % forces below this go to 0

plateNamesOG = {'1','2'} ; % Reset this to 1,2,3 for generality if desired
plateNamesWalking = {'','1'} ; % Reset this to '','1_' for old style

rotateOG_xForward = true ;

% % % End user inputs

display('Select *.anc files to convert into motion files.');
[files,inpath]=uigetfile('*.anc','Select overground analog files with forces (in Edited folder)','multiselect','on');
files=cellstr(files);
cd(inpath)

[a b] = size(files);
for i=1:b;
    clear FPData
    infile=char(files(:,i));
    [samp_rate, channel_names, range, time, data, inpath, fileroot]=open_anc(inpath,infile);
    time_forces = time ;
    
    % 16-bit system 2^16 = 65536
    % range is given in milivolts, so multiply by 0.001 to make volts
    data=(ones(size(data,1),1)*range*2).*(data/65536)*0.001; % Convert all data into volts
    
    columnsToDrop = [13,14,15,16,17,18,19,20,21,22,23,24,25,26];
    data(:, columnsToDrop) = []; % Drop the specified columns


    forcenames = ['F1X';'F1Y';'F1Z';'M1X';'M1Y';'M1Z';'F2X';'F2Y';'F2Z';'M2X';'M2Y';'M2Z'] ;
    
    % Create raw matrix of forces
    forceraw = zeros(size(data,1),length(forcenames)) ;
    for p = 1:size(forcenames,1) ;
        forceindicies(p) = find(strcmp(channel_names,forcenames(p,:))) ;
        forceraw(:,p) = data(:,forceindicies(p)) ;
    end
    
    filt_freq = freq_filtering ; % lpCutoffFreq for force and marker data
    threshold = zero_threshold ; % Fz threshold in Newtons - this is how we define steps
    threshold_high = 200;
    threshold_low = 40;
    % indicies are [start_right end_right fz_right; start_left end_left fz_left]
    indices = [1 7 3;8 12 10];


    % Turning Forces from V to Newtons, Filtering, and Zeroing during swing
    % This structure includes forces and COP for FP1 (right foot) and FP2 (left foot) in the
    % following order: Fx Fy Fz COPx COPy COPz Tz
    [forces_proc_meters] = FiltBertecForces(forceraw,indices,samp_rate(1),filt_freq,threshold_high, threshold_low) ;
    
    
    % for general OG trials - output by forceplate number
    % Transform forces and COP into x-forward, y-up, and z-right for
    % OpenSim
    R=[1  0  0;
        0  0 -1;
        0  1  0];
    
    if rotateOG_xForward
        R = R* [0 0 -1;
            0 1 0;
            1 0 0] ;
    end
    
    R9 = zeros(9,9) ; R9(1:3,1:3) = R ; R9(4:6,4:6) = R ; R9(7:9,7:9) = R ;
    R27 = blkdiag(R9,R9,R9) ;
    
    % Get into F,COP,M order (add zeros for the Mx and My entries)
    zeroCols = zeros(size(forces_proc_meters,1),2) ;
    forces_proc_meters = horzcat(forces_proc_meters(:,1:6),zeroCols,...
        forces_proc_meters(:,7:12),zeroCols) ;
    
    % Rotate into Opensim frame
    GRF_write = forces_proc_meters * R27 ;
    k=strfind(infile,'static');
    if k>0
        forceplate_2_massForce = mean(GRF_write(:,11));
        Forceplate_totalmass_force = forceplate_2_massForce;
        subj_mass_kg = Forceplate_totalmass_force/9.8;
    end


%% Write forces files
% write out a per-plate Grf file
% Write Forces File
npts = size(GRF_write,1);

input_file = strrep(infile, '.anc', ['_forces_filt' num2str(freq_filtering) 'Hz.mot']);

fid = fopen([tempdir,input_file],'w');

colNames = {'time'} ;
nPlates = 2 ;
dTypes = {'ground_force_v','ground_force_p','ground_torque_'} ;
dims = {'x','y','z'} ;
for iPlate = 1:nPlates
    for j = 1:length(dTypes)
        for k = 1:length(dims) ;
            colNames{end+1} = [plateNamesOG{iPlate} '_' dTypes{j} dims{k}] ;
        end
    end
end

% Write the header
fprintf(fid,'%s\n',input_file);
fprintf(fid,'%s\n','version=1');
fprintf(fid,'%s\n',['nRows=' num2str(length(GRF_write))]);
fprintf(fid,'%s\n',['nColumns=',num2str(9*nPlates+1)]);
fprintf(fid,'%s\n','inDegrees=yes');
fprintf(fid,'%s\n','endheader');
fprintf(fid,repmat('%s\t',1,9*nPlates+1),colNames{:});
fprintf(fid,'\n') ;

% Write the data
for j=1:npts
    % Data order is 1Fxyz,1COPxyz,1Mxyz,2Fxyz...
    fprintf(fid,'%f',time_forces(j));
    fprintf(fid,'\t%10.6f',GRF_write(j,:));
    fprintf(fid,'\n');
end

disp(['Wrote ',num2str(npts),' frames of force data to ',input_file]);
fclose(fid);
copyfile([tempdir,input_file],[inpath,input_file])
delete([tempdir,input_file])

end