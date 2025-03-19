function [samp_rate, channel_names, range, time, data, inpath, fileroot]= ...
    open_anc(inpath, infile)
% open_anc is used to open analog data files from Motion Analysis Cortex
%   (*.anc).  The number of channels, samp rate and range are determined
%   from the file header.
%
% Re-written by Sam Hamner, March 17, 2025

    % Construct the full file path
    filename = fullfile(inpath, infile);
    fileroot = extractBefore(infile,'.');

    % Open the file
    fid = fopen(filename);

    % Initialize variables
    samp_rate = [];
    channel_names = [];
    range = [];
    time = [];
    data = [];
    num_blank_rows = 3; % Specific to *.anc file type from Cortex

    % Read and process headers until end of file
    while (~feof(fid))
        line = fgetl(fid);

        % Exit if blank line after headers
        if isempty(line)
            break;
        end
        
        % Process relevant headers
        line_split = strsplit(line, '\t');
        line_split = strtrim(line_split); % remove extra spaces
        
        for i = 1:length(line_split)
            if contains(line_split{i}, 'Trial_Name:')
                if i < length(line_split)
                    Trial_Name = line_split{i+1};
                end
            elseif contains(line_split{i}, 'Duration(Sec.):')
                if i < length(line_split)
                    Duration = str2double(line_split{i+1});
                end
            elseif contains(line_split{i}, '#Channels:')
                if i < length(line_split)
                    Num_Channels = str2double(line_split{i+1});
                end
            elseif contains(line_split{i}, 'PreciseRate:')
                if i < length(line_split)
                    samp_rate = str2double(line_split{i+1});
                end
            end
        end
    end
    
    % Read and ignore 3 blank rows
    for ii = 1:num_blank_rows
        fgetl(fid);
    end
        
    % Read Channel Names
    channel_names_line = fgetl(fid);
    channel_names_split = strsplit(channel_names_line, '\t');
    channel_names_split = strtrim(channel_names_split); % trim each element
    channel_names = channel_names_split(2:end); % skip the first element
    
    % Remove any empty cells at the end
    channel_names = channel_names(~cellfun('isempty', channel_names));
    
    % Read and ignore the "Rate" line
    fgetl(fid);

    % Read Range
    range_line = fgetl(fid);
    range_split = strsplit(range_line, '\t');
    range_split = strtrim(range_split); % trim each element
    range = str2double(range_split(2:end)); % skip the first element

    % Remove any NaN at the end
    range = range(~isnan(range));

    % Read Data
    data_cell = textscan(fid, repmat('%f', 1, Num_Channels + 1),...
        'Delimiter', '\t');
    
    % Close the file
    fclose(fid);
    
    % Separate time and data
    data_matrix = cell2mat(data_cell);
    time = data_matrix(:, 1);
    data = data_matrix(:, 2:end);
end