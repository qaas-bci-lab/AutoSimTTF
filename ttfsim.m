function ttfsim(subj,recipe,varargin)


addpath(genpath([fileparts(which(mfilename)) filesep 'lib/']));
addpath(genpath([fileparts(which(mfilename)) filesep 'src/']));
%% check inputs
fprintf('\n\n');
disp('======================================================')
disp('CHECKING INPUTS...')
disp('======================================================')
fprintf('\n');


% check subject name
if nargin<1 || isempty(subj)
    subj = 'example/MNI152_T1_1mm.nii';
end

% The bundled NIfTI reader works with uncompressed .nii files. Accept
% compressed .nii.gz inputs by preparing an adjacent .nii working copy.
subj = normalizeNiftiInput(subj);

if  ~exist(subj,'file')
    error(['The subject MRI you provided ' subj ' does not exist.']);
end

% take in user-specified recipe and electrodes
if nargin<2 || isempty(recipe)
    recipe = {'Fp1',100,'P4',0};
end

% take in user-specified options
if mod(length(varargin),2)~=0
    error('Unrecognized format of options. Please enter as property-value pair.');
end

indArg = 1;
while indArg <= length(varargin)
    switch lower(varargin{indArg})
        case 'captype'
            capType = varargin{indArg+1};
            indArg = indArg+2;
        case 'electype'
            elecType = varargin{indArg+1};
            indArg = indArg+2;
        case 'elecsize'
            elecSize = varargin{indArg+1};
            indArg = indArg+2;
        case 'elecori'
            elecOri = varargin{indArg+1};
            indArg = indArg+2;
        case 't2'
            T2 = varargin{indArg+1};
            indArg = indArg+2;
        case 'meshoptions'
            meshOpt = varargin{indArg+1};
            indArg = indArg+2;
        case 'simulationtag'
            simTag = varargin{indArg+1};
            indArg = indArg+2;
        case 'resampling'
            doResamp = varargin{indArg+1};
            indArg = indArg+2;
        case 'zeropadding'
            paddingAmt = varargin{indArg+1};
            indArg = indArg+2;
        case 'conductivities'
            conductivities = varargin{indArg+1};
            indArg = indArg+2;
        case 'dielectrics'
            dielectrics = varargin{indArg+1};
            indArg = indArg+2;
        case 'frequency'
            frequency = varargin{indArg+1};
            indArg = indArg+2;
        otherwise
            error('Supported options are: ''capType'', ''elecType'', ''elecSize'', ''elecOri'', ''T2'', ''meshOptions'', ''conductivities'', ''dielectrics'', ''frequency'', ''simulationTag'', ''resampling'', and ''zeroPadding''.');
    end
end

% Predefined montages selected by simulationTag. These tags intentionally
% override the recipe supplied by the caller.
if exist('simTag','var') && (ischar(simTag) || isstring(simTag))
    if strcmpi(char(simTag),'AP')
        recipe = {'AF3', 100, 'AFz', 100, 'AF4', 100, ...
            'F1', 100, 'Fz', 100, 'F2', 100, ...
            'FC1', 100, 'FCz', 100, 'FC2', 100, ...
            'P1', -100, 'Pz', -100, 'P2', -100, ...
            'PO3', -100, 'POz', -100, 'PO4', -100, ...
            'O1', -100, 'Oz', -100, 'O2', -100};
    elseif strcmpi(char(simTag),'LR')
        recipe = {'FC3', 100, 'C3', 100, 'CP3', 100, ...
            'FC5', 100, 'C5', 100, 'CP5', 100, ...
            'FT7', 100, 'T7', 100, 'TP7', 100, ...
            'FC4', -100, 'C4', -100, 'CP4', -100, ...
            'FC6', -100, 'C6', -100, 'CP6', -100, ...
            'FT8', -100, 'T8', -100, 'TP8', -100};
    end
end
    
if any(~strcmpi(recipe,'leadfield'))

    % check recipe syntax
    if mod(length(recipe),2)~=0
        error('Unrecognized format of your recipe. Please enter as electrodeName-injectedCurrent pair.');
    end
    elecName = (recipe(1:2:end-1))';
    injectCurrent = (cell2mat(recipe(2:2:end)))';
    % if abs(sum(injectCurrent))>eps % eps is floating-point relative accuracy, a very small value
    %     error('Electric currents going in and out of the head not balanced. Please make sure they sum to 0.');
    % end

    % set up defaults and check on option conflicts
    if ~exist('capType','var')
        capType = '1010';
    else
        if ~any(strcmpi(capType,{'1020','1010','1005','biosemi','egi'}))
            error('Supported cap types are: ''1020'', ''1010'', ''1005'', ''BioSemi'' and ''EGI''.');
        end
    end
    
    if ~exist('elecType','var')
        elecType = 'disc';
    else
        if ~iscellstr(elecType)
            if ~any(strcmpi(elecType,{'disc','pad','ring'}))
                error('Supported electrodes are: ''disc'', ''pad'' and ''ring''.');
            end
        else
            if length(elecType)~=length(elecName)
                error('You want to place more than 1 type of electrodes, but did not tell AutoSimTTF which type for each electrode. Please provide the type for each electrode respectively, as the value for option ''elecType'', in a cell array of length equals to the number of electrodes to be placed.');
            end
            for i=1:length(elecType)
                if ~any(strcmpi(elecType{i},{'disc','pad','ring'}))
                    error('Supported electrodes are: ''disc'', ''pad'' and ''ring''.');
                end
            end
        end
    end
    
    if ~exist('elecSize','var')
        if ~iscellstr(elecType)
            switch lower(elecType)
                case {'disc'}
                    elecSize = [8 1];
                case {'pad'}
                    elecSize = [50 30 3];
                case {'ring'}
                    elecSize = [4 6 2];
            end
        else
            elecSize = cell(1,length(elecType));
            for i=1:length(elecSize)
                switch lower(elecType{i})
                    case {'disc'}
                        elecSize{i} = [8 1];
                    case {'pad'}
                        elecSize{i} = [50 30 3];
                    case {'ring'}
                        elecSize{i} = [4 6 2];
                end
            end
        end
    else
        if ~iscellstr(elecType)
            if iscell(elecSize)
                warning('Looks like you''re placing only 1 type of electrodes. AutoSimTTF will only use the 1st entry of the cell array of ''elecSize''. If this is not what you want and you meant differect sizes for different electrodes of the same type, just enter ''elecSize'' option as an N-by-2 or N-by-3 matrix, where N is number of electrodes to be placed.');
                elecSize = elecSize{1};
            end
            if any(elecSize(:)<=0)
                error('Please enter non-negative values for electrode size.');
            end
            if size(elecSize,2)~=2 && size(elecSize,2)~=3
                error('Unrecognized electrode sizes. Please specify as [radius height] for disc, [length width height] for pad, and [innerRadius outterRadius height] for ring electrode.');
            end
            if size(elecSize,1)>1 && size(elecSize,1)~=length(elecName)
                error('You want different sizes for each electrode. Please tell AutoSimTTF the size for each electrode respectively, in a N-row matrix, where N is the number of electrodes to be placed.');
            end
            if strcmpi(elecType,'disc') && size(elecSize,2)==3
                error('Redundant size info for Disc electrodes. Please enter as [radius height]');
            end
            if any(strcmpi(elecType,{'pad','ring'})) && size(elecSize,2)==2
                error('Insufficient size info for Pad or Ring electrodes. Please specify as [length width height] for pad, and [innerRadius outterRadius height] for ring electrode.');
            end
            if strcmpi(elecType,'pad') && any(elecSize(:,1) < elecSize(:,2))
                error('For Pad electrodes, the width of the pad should not be bigger than its length. Please enter as [length width height]');
            end
            if strcmpi(elecType,'pad') && any(elecSize(:,3) < 3)
                error('For Pad electrodes, the thickness should at least be 3 mm.');
            end
            if strcmpi(elecType,'pad') && any(elecSize(:) > 80)
                warning('You''re placing large pad electrodes (one of its dimensions is bigger than 8 cm). For large pads, the size will not be exact in the model because they will be bent to fit the scalp surface.');
            end
            if strcmpi(elecType,'ring') && any(elecSize(:,1) >= elecSize(:,2))
                error('For Ring electrodes, the inner radius should be smaller than outter radius. Please enter as [innerRadius outterRadius height]');
            end
        else
            if ~iscell(elecSize)
                error('You want to place at least 2 types of electrodes, but only provided size info for 1 type. Please provide complete size info for all types of electrodes in a cell array as the value for option ''elecSize'', or just use defaults by not specifying ''elecSize'' option.');
            end
            if length(elecSize)~=length(elecType)
                error('You want to place more than 1 type of electrodes. Please tell AutoSimTTF the size for each electrode respectively, as the value for option ''elecSize'', in a cell array of length equals to the number of electrodes to be placed.');
            end
            for i=1:length(elecSize)
                if isempty(elecSize{i})
                    switch lower(elecType{i})
                        case {'disc'}
                            elecSize{i} = [8 1];
                        case {'pad'}
                            elecSize{i} = [50 30 3];
                        case {'ring'}
                            elecSize{i} = [4 6 2];
                    end
                else
                    if any(elecSize{i}(:)<=0)
                        error('Please enter non-negative values for electrode size.');
                    end
                    if size(elecSize{i},2)~=2 && size(elecSize{i},2)~=3
                        error('Unrecognized electrode sizes. Please specify as [radius height] for disc, [length width height] for pad, and [innerRadius outterRadius height] for ring electrode.');
                    end
                    if size(elecSize{i},1)>1
                        error('You''re placing more than 1 type of electrodes. Please put size info for each electrode as a 1-row vector in a cell array for option ''elecSize''.');
                    end
                    if strcmpi(elecType{i},'disc') && size(elecSize{i},2)==3
                        error('Redundant size info for Disc electrodes. Please enter as [radius height]');
                    end
                    if any(strcmpi(elecType{i},{'pad','ring'})) && size(elecSize{i},2)==2
                        error('Insufficient size info for Pad or Ring electrodes. Please specify as [length width height] for pad, and [innerRadius outterRadius height] for ring electrode.');
                    end
                    if strcmpi(elecType{i},'pad') && any(elecSize{i}(:,1) < elecSize{i}(:,2))
                        error('For Pad electrodes, the width of the pad should not be bigger than its length. Please enter as [length width height]');
                    end
                    if strcmpi(elecType{i},'pad') && any(elecSize{i}(:,3) < 3)
                        error('For Pad electrodes, the thickness should at least be 3 mm.');
                    end
                    if strcmpi(elecType{i},'pad') && any(elecSize{i}(:) > 80)
                        warning('You''re placing large pad electrodes (one of its dimensions is bigger than 8 cm). For large pads, the size will not be exact in the model because they will be bent to fit the scalp surface.');
                    end
                    if strcmpi(elecType{i},'ring') && any(elecSize{i}(:,1) >= elecSize{i}(:,2))
                        error('For Ring electrodes, the inner radius should be smaller than outter radius. Please enter as [innerRadius outterRadius height]');
                    end
                end
            end
        end
    end
    
    if ~exist('elecOri','var')
        if ~iscellstr(elecType)
            if strcmpi(elecType,'pad')
                elecOri = 'lr';
            else
                elecOri = [];
            end
        else
            elecOri = cell(1,length(elecType));
            for i=1:length(elecOri)
                if strcmpi(elecType{i},'pad')
                    elecOri{i} = 'lr';
                else
                    elecOri{i} = [];
                end
            end
        end
    else
        if ~iscellstr(elecType)
            if ~strcmpi(elecType,'pad')
                warning('You''re not placing pad electrodes; customized orientation options will be ignored.');
                elecOri = [];
            else
                if iscell(elecOri)
                    allChar = 1;
                    for i=1:length(elecOri)
                        if ~ischar(elecOri{i})
                            warning('Looks like you''re only placing pad electrodes. AutoSimTTF will only use the 1st entry of the cell array of ''elecOri''. If this is not what you want and you meant differect orientations for different pad electrodes, just enter ''elecOri'' option as an N-by-3 matrix, or as a cell array of length N (put ''lr'', ''ap'', or ''si'' into the cell element), where N is number of pad electrodes to be placed.');
                            elecOri = elecOri{1};
                            allChar = 0;
                            break;
                        end
                    end
                    if allChar && length(elecOri)~=length(elecName)
                        error('You want different orientations for each pad electrode by using pre-defined keywords in a cell array. Please make sure the cell array has a length equal to the number of pad electrodes.');
                    end
                end
                if ~iscell(elecOri)
                    if ischar(elecOri)
                        if ~any(strcmpi(elecOri,{'lr','ap','si'}))
                            error('Unrecognized pad orientation. Please enter ''lr'', ''ap'', or ''si'' for pad orientation; or just enter the direction vector of the long axis of the pad');
                        end
                    else
                        if size(elecOri,2)~=3
                            error('Unrecognized pad orientation. Please enter ''lr'', ''ap'', or ''si'' for pad orientation; or just enter the direction vector of the long axis of the pad');
                        end
                        if size(elecOri,1)>1 && size(elecOri,1)~=length(elecName)
                            error('You want different orientations for each pad electrode. Please tell AutoSimTTF the orientation for each pad respectively, in a N-by-3 matrix, where N is the number of pads to be placed.');
                        end
                    end
                end
            end
        else
            if ~iscell(elecOri)
                elecOri0 = elecOri;
                elecOri = cell(1,length(elecType));
                if ischar(elecOri0)
                    if ~any(strcmpi(elecOri0,{'lr','ap','si'}))
                        error('Unrecognized pad orientation. Please enter ''lr'', ''ap'', or ''si'' for pad orientation; or just enter the direction vector of the long axis of the pad');
                    end
                    for i=1:length(elecType)
                        if strcmpi(elecType{i},'pad')
                            elecOri{i} = elecOri0;
                        else
                            elecOri{i} = [];
                        end
                    end
                else
                    if size(elecOri0,2)~=3
                        error('Unrecognized pad orientation. Please enter ''lr'', ''ap'', or ''si'' for pad orientation; or just enter the direction vector of the long axis of the pad');
                    end
                    numPad = 0;
                    for i=1:length(elecType)
                        if strcmpi(elecType{i},'pad')
                            numPad = numPad+1;
                        end
                    end
                    if size(elecOri0,1)>1
                        if size(elecOri0,1)~=numPad
                            error('You want different orientations for each pad electrode. Please tell AutoSimTTF the orientation for each pad respectively, in a N-by-3 matrix, where N is the number of pads to be placed.');
                        end
                    else
                        elecOri0 = repmat(elecOri0,numPad,1);
                    end
                    i0=1;
                    for i=1:length(elecType)
                        if strcmpi(elecType{i},'pad')
                            elecOri{i} = elecOri0(i0,:);
                            i0 = i0+1;
                        else
                            elecOri{i} = [];
                        end
                    end
                end
            else
                if length(elecOri)~=length(elecType)
                    error('You want to place another type of electrodes aside from pad. Please tell AutoSimTTF the orienation for each electrode respectively, as the value for option ''elecOri'', in a cell array of length equals to the number of electrodes to be placed (put [] for non-pad electrodes).');
                end
                for i=1:length(elecOri)
                    if strcmpi(elecType{i},'pad')
                        if isempty(elecOri{i})
                            elecOri{i} = 'lr';
                        else
                            if ischar(elecOri{i})
                                if ~any(strcmpi(elecOri{i},{'lr','ap','si'}))
                                    error('Unrecognized pad orientation. Please enter ''lr'', ''ap'', or ''si'' for pad orientation; or just enter the direction vector of the long axis of the pad');
                                end
                            else
                                if size(elecOri{i},2)~=3
                                    error('Unrecognized pad orientation. Please enter ''lr'', ''ap'', or ''si'' for pad orientation; or just enter the direction vector of the long axis of the pad');
                                end
                                if size(elecOri{i},1)>1
                                    error('You''re placing more than 1 type of electrodes. Please put orientation info for each pad electrode as a 1-by-3 vector or one of the three keywords ''lr'', ''ap'', or ''si'' in a cell array for option ''elecOri''.');
                                end
                            end
                        end
                    else
                        elecOri{i} = [];
                    end
                end
            end
        end
    end
    
    elecPara = struct('capType',capType,'elecType',elecType,...
        'elecSize',elecSize,'elecOri',elecOri);
else
    
    fid = fopen('./data/elec72.loc'); C = textscan(fid,'%d %f %f %s'); fclose(fid);
    elecName = C{4}; for i=1:length(elecName), elecName{i} = strrep(elecName{i},'.',''); end % strrep converts '.' in elecName to spaces
    capType = '1010';  % Default cap type: 10-10 system
    elecType = 'disc'; % Default electrode configuration
    elecSize = [8 1];  % Default electrode size
    elecOri = [];
    
    elecPara = struct('capType',capType,'elecType',elecType,...
        'elecSize',elecSize,'elecOri',elecOri);  
end
    
if ~exist('T2','var')
    T2 = [];
else
    T2 = normalizeNiftiInput(T2);
    
    t2Data = load_untouch_nii(T2);
    if t2Data.hdr.hist.qoffset_x == 0 && t2Data.hdr.hist.srow_x(4)==0
        error('The MRI has a bad header. SPM cannot generate the segmentation properly for MRI with bad header. You can manually align the MRI in SPM Display function to fix the header.');
    end
    % check if bad MRI header    
end
   
if ~exist('meshOpt','var')
      meshOpt = struct('radbound',5,'angbound',30,'distbound',0.3,'reratio',3,'maxvol',10);
else
    if ~isstruct(meshOpt), error('Unrecognized format of mesh options. Please enter as a structure, with field names as ''radbound'', ''angbound'', ''distbound'', ''reratio'', and ''maxvol''. Please refer to the iso2mesh documentation for more details.'); end
    meshOptNam = fieldnames(meshOpt);
    if isempty(meshOptNam) || ~all(ismember(meshOptNam,{'radbound';'angbound';'distbound';'reratio';'maxvol'}))
        error('Unrecognized mesh options detected. Supported mesh options are ''radbound'', ''angbound'', ''distbound'', ''reratio'', and ''maxvol''. Please refer to the iso2mesh documentation for more details.');
    end
    if ~isfield(meshOpt,'radbound')
        meshOpt.radbound = 5;
    else
        if ~isnumeric(meshOpt.radbound) || meshOpt.radbound<=0
            error('Please enter a positive number for the mesh option ''radbound''.');
        end
    end
    if ~isfield(meshOpt,'angbound')
        meshOpt.angbound = 30;
    else
        if ~isnumeric(meshOpt.angbound) || meshOpt.angbound<=0
            error('Please enter a positive number for the mesh option ''angbound''.');
        end
    end
    if ~isfield(meshOpt,'distbound')
        meshOpt.distbound = 0.3;
    else
        if ~isnumeric(meshOpt.distbound) || meshOpt.distbound<=0
            error('Please enter a positive number for the mesh option ''distbound''.');
        end
    end
    if ~isfield(meshOpt,'reratio')
        meshOpt.reratio = 3;
    else
        if ~isnumeric(meshOpt.reratio) || meshOpt.reratio<=0
            error('Please enter a positive number for the mesh option ''reratio''.');
        end
    end
    if ~isfield(meshOpt,'maxvol')
        meshOpt.maxvol = 10;
    else
        if ~isnumeric(meshOpt.maxvol) || meshOpt.maxvol<=0
            error('Please enter a positive number for the mesh option ''maxvol''.');
        end
    end
    warning('You''re changing the advanced options of AutoSimTTF. Unless you know what you''re doing, please keep mesh options default.');
end


if ~exist('simTag','var'), simTag = []; end

if ~exist('doResamp','var')
    doResamp = 0;
else
    if ~ischar(doResamp), error('Unrecognized option value. Please enter ''on'' or ''off'' for option ''resampling''.'); end
    if strcmpi(doResamp,'off')
        doResamp = 0;
    elseif strcmpi(doResamp,'on')
        doResamp = 1;
    else
        error('Unrecognized option value. Please enter ''on'' or ''off'' for option ''resampling''.');
    end
end

if ~exist('paddingAmt','var')
    paddingAmt = 0;
else
    if paddingAmt<=0 || mod(paddingAmt,1)~=0
        error('Unrecognized option value. Please enter positive integer value for option ''zeroPadding''. A recommended value is 10.');
    end
end

% frequency
if ~exist('frequency','var')
    frequency = '200000';
else
    if frequency<=0
        error('Please enter a positive number for the frequency.');
    end
end

% conductivities
if ~exist('conductivities','var')
%    conductivities = struct('white',0.08,'gray',0.27,'csf',1.7,'bone',0.02,...
%                           'skin',0.07,'air',2.5e-14,'gel',0.1,'electrode',0.0001,'NT',0.25,'ED',0.25,'ET',0.25); % literature values
    conductivities = struct('white',0.08,'gray',0.27,'csf',1.7,'bone',0.02,...
                           'skin',0.07,'air',2.5e-14,'gel',0.1,'electrode',0.0001,'NT',0.25,'ED',0.175,'ET',0.25); % Tumor coarse segmentation
else
    if ~isstruct(conductivities), error('Unrecognized format of conductivity values. Please enter as a structure, with field names as ''white'', ''gray'', ''csf'', ''bone'', ''skin'', ''air'', ''gel'' and ''electrode''.'); end
    conductivitiesNam = fieldnames(conductivities);
    if isempty(conductivitiesNam) || ~all(ismember(conductivitiesNam,{'white';'gray';'csf';'bone';'skin';'air';'gel';'electrode'}))
        error('Unrecognized tissue names detected. Supported tissue names in the conductivity option are ''white'', ''gray'', ''csf'', ''bone'', ''skin'', ''air'', ''gel'' and ''electrode''.');
    end
    if ~isfield(conductivities,'white')
        conductivities.white = 0.08;
    else
        if ~isnumeric(conductivities.white) || any(conductivities.white(:)<=0)
            error('Please enter a positive number for the white matter conductivity.');
        end
        if length(conductivities.white(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(conductivities,'gray')
        conductivities.gray = 0.27;
    else
        if ~isnumeric(conductivities.gray) || any(conductivities.gray(:)<=0)
            error('Please enter a positive number for the gray matter conductivity.');
        end
        if length(conductivities.gray(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(conductivities,'csf')
        conductivities.csf = 1.7;
    else
        if ~isnumeric(conductivities.csf) || any(conductivities.csf(:)<=0)
            error('Please enter a positive number for the CSF conductivity.');
        end
        if length(conductivities.csf(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(conductivities,'bone')
        conductivities.bone = 0.02;
    else
        if ~isnumeric(conductivities.bone) || any(conductivities.bone(:)<=0)
            error('Please enter a positive number for the bone conductivity.');
        end
        if length(conductivities.bone(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(conductivities,'skin')
        conductivities.skin = 0.07;
    else
        if ~isnumeric(conductivities.skin) || any(conductivities.skin(:)<=0)
            error('Please enter a positive number for the skin conductivity.');
        end
        if length(conductivities.skin(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(conductivities,'air')
        conductivities.air = 2.5e-14;
    else
        if ~isnumeric(conductivities.air) || any(conductivities.air(:)<=0)
            error('Please enter a positive number for the air conductivity.');
        end
        if length(conductivities.air(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(conductivities,'gel')
        conductivities.gel = 4.5;
    else
        if ~isnumeric(conductivities.gel) || any(conductivities.gel(:)<=0)
            error('Please enter a positive number for the gel conductivity.');
        end
        if length(conductivities.gel(:))>1 && length(conductivities.gel(:))~=length(elecName)
           error('You want to assign different conductivities to the conducting media under different electrodes, but didn''t tell AutoSimTTF clearly which conductivity each electrode should use. Please follow the order of electrodes you put in ''recipe'' to give each of them the corresponding conductivity in a vector as the value for the ''gel'' field in option ''conductivities''.');
        end
    end
    if ~isfield(conductivities,'electrode')
        conductivities.electrode = 0.0001;
    else
        if ~isnumeric(conductivities.electrode) || any(conductivities.electrode(:)<=0)
            error('Please enter a positive number for the electrode conductivity.');
        end
        if length(conductivities.electrode(:))>1 && length(conductivities.electrode(:))~=length(elecName)
           error('You want to assign different conductivities to different electrodes, but didn''t tell AutoSimTTF clearly which conductivity each electrode should use. Please follow the order of electrodes you put in ''recipe'' to give each of them the corresponding conductivity in a vector as the value for the ''electrode'' field in option ''conductivities''.');
        end
    end
    warning('You''re changing the advanced options of AutoSimTTF. Unless you know what you''re doing, please keep conductivity values default.');
end

if length(conductivities.gel(:))==1
    conductivities.gel = repmat(conductivities.gel,1,length(elecName));
end
if length(conductivities.electrode(:))==1
    conductivities.electrode = repmat(conductivities.electrode,1,length(elecName));
end

% dielectrics
if ~exist('dielectrics','var')
    % dielectrics = struct('white',1300,'gray',2000,'csf',100,'bone',200,...
    %                        'skin',5000,'air',1,'gel',100,'electrode',16000,'NT',110,'ED',2000,'ET',2000); % literature values
    dielectrics = struct('white',1300,'gray',2000,'csf',100,'bone',200,...
                           'skin',5000,'air',1,'gel',100,'electrode',16000,'NT',1000,'ED',1650,'ET',1000); % Tumor coarse segmentation
else
    if ~isstruct(dielectrics), error('Unrecognized format of conductivity values. Please enter as a structure, with field names as ''white'', ''gray'', ''csf'', ''bone'', ''skin'', ''air'', ''gel'' and ''electrode''.'); end
    conductivitiesNam = fieldnames(dielectrics);
    if isempty(conductivitiesNam) || ~all(ismember(conductivitiesNam,{'white';'gray';'csf';'bone';'skin';'air';'gel';'electrode'}))
        error('Unrecognized tissue names detected. Supported tissue names in the conductivity option are ''white'', ''gray'', ''csf'', ''bone'', ''skin'', ''air'', ''gel'' and ''electrode''.');
    end
    if ~isfield(dielectrics,'white')
        dielectrics.white = 1300;
    else
        if ~isnumeric(dielectrics.white) || any(dielectrics.white(:)<=0)
            error('Please enter a positive number for the white matter conductivity.');
        end
        if length(dielectrics.white(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(dielectrics,'gray')
        dielectrics.gray = 2000;
    else
        if ~isnumeric(dielectrics.gray) || any(dielectrics.gray(:)<=0)
            error('Please enter a positive number for the gray matter conductivity.');
        end
        if length(dielectrics.gray(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(dielectrics,'csf')
        dielectrics.csf = 100;
    else
        if ~isnumeric(dielectrics.csf) || any(dielectrics.csf(:)<=0)
            error('Please enter a positive number for the CSF conductivity.');
        end
        if length(dielectrics.csf(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(dielectrics,'bone')
        dielectrics.bone = 200;
    else
        if ~isnumeric(dielectrics.bone) || any(dielectrics.bone(:)<=0)
            error('Please enter a positive number for the bone conductivity.');
        end
        if length(dielectrics.bone(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(dielectrics,'skin')
        dielectrics.skin = 5000;
    else
        if ~isnumeric(dielectrics.skin) || any(dielectrics.skin(:)<=0)
            error('Please enter a positive number for the skin conductivity.');
        end
        if length(dielectrics.skin(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(dielectrics,'air')
        dielectrics.air = 1;
    else
        if ~isnumeric(dielectrics.air) || any(dielectrics.air(:)<=0)
            error('Please enter a positive number for the air conductivity.');
        end
        if length(dielectrics.air(:))>1, error('Tensor conductivity not supported by AutoSimTTF. Please enter a scalar value for conductivity.'); end
    end
    if ~isfield(dielectrics,'gel')
        dielectrics.gel = 100;
    else
        if ~isnumeric(dielectrics.gel) || any(dielectrics.gel(:)<=0)
            error('Please enter a positive number for the gel conductivity.');
        end
        if length(dielectrics.gel(:))>1 && length(dielectrics.gel(:))~=length(elecName)
           error('You want to assign different dielectrics to the conducting media under different electrodes, but didn''t tell AutoSimTTF clearly which conductivity each electrode should use. Please follow the order of electrodes you put in ''recipe'' to give each of them the corresponding conductivity in a vector as the value for the ''gel'' field in option ''dielectrics''.');
        end
    end
    if ~isfield(dielectrics,'electrode')
        dielectrics.electrode = 16000;
    else
        if ~isnumeric(dielectrics.electrode) || any(dielectrics.electrode(:)<=0)
            error('Please enter a positive number for the electrode conductivity.');
        end
        if length(dielectrics.electrode(:))>1 && length(dielectrics.electrode(:))~=length(elecName)
           error('You want to assign different dielectrics to different electrodes, but didn''t tell AutoSimTTF clearly which conductivity each electrode should use. Please follow the order of electrodes you put in ''recipe'' to give each of them the corresponding conductivity in a vector as the value for the ''electrode'' field in option ''dielectrics''.');
        end
    end
    warning('You''re changing the advanced options of AutoSimTTF. Unless you know what you''re doing, please keep conductivity values default.');
end

if length(dielectrics.gel(:))==1
    dielectrics.gel = repmat(dielectrics.gel,1,length(elecName));
end
if length(dielectrics.electrode(:))==1
    dielectrics.electrode = repmat(dielectrics.electrode,1,length(elecName));
end
%%
% preprocess MRI data
t1Data = load_untouch_nii(subj);
if t1Data.hdr.hist.qoffset_x == 0 && t1Data.hdr.hist.srow_x(4)==0
    error('The MRI has a bad header. SPM cannot generate the segmentation properly for MRI with bad header. You can manually align the MRI in SPM Display function to fix the header.');
end
% check if bad MRI header

if any(t1Data.hdr.dime.pixdim(2:4)<0.8) && ~doResamp
    warning('The MRI has higher resolution (<0.8mm) in at least one direction. This will make the modeling process more computationally expensive and thus slower. If you wish to run faster using just 1-mm model, you can ask AutoSimTTF to re-sample the MRI into 1 mm first, by turning on the ''resampling'' option.');
end
% check if high-resolution MRI (< 0.8 mm in any direction)

if length(unique(t1Data.hdr.dime.pixdim(2:4)))>1 && ~doResamp
    warning('The MRI has anisotropic resolution. It is highly recommended that you turn on the ''resampling'' option, as the electrode size will not be exact if the model is built from an MRI with anisotropic resolution.');
end
% check if anisotropic resolution MRI

[subjRas,isNonRAS] = convertToRAS(subj);
% check if in non-RAS orientation, and if yes, put it into RAS

[subjRasRS,doResamp] = resampToOneMM(subjRas,doResamp);    

if paddingAmt>0
    subjRasRSPD = zeroPadding(subjRasRS,paddingAmt);
else
    subjRasRSPD = subjRasRS;
end

if ~isempty(T2)
    T2 = realignT2(T2,subjRasRSPD);
end
% check if T2 is aligned with T1

%%
% preprocess electrodes
[elecPara,indInUsrInput] = elecPreproc(subj,elecName,elecPara);
    
if any(~strcmpi(recipe,'leadfield'))

    elecName = elecName(indInUsrInput);
    injectCurrent = injectCurrent(indInUsrInput);
    
    configTxt = [];
    for i=1:length(elecName)
        configTxt = [configTxt elecName{i} ' (' num2str(injectCurrent(i)) ' mA), '];
    end
    configTxt = configTxt(1:end-2);

else       

    elecNameOri = elecName; % back up for re-ordering solutions back to .loc file order;
                            % this is ugly, as .loc file has a different order of electrodes
                            % for historical reasons;
                            % HDE follows .loc file; AutoSimTTF follows capInfo.xls
    elecName = elecName(indInUsrInput);
    configTxt = 'leadFieldGeneration';
    
end

conductivities.gel = conductivities.gel(indInUsrInput);
conductivities.electrode = conductivities.electrode(indInUsrInput);
dielectrics.gel = dielectrics.gel(indInUsrInput);
dielectrics.electrode = dielectrics.electrode(indInUsrInput);

% sort elec options
if length(elecPara)==1
    if size(elecSize,1)>1, elecPara.elecSize = elecPara.elecSize(indInUsrInput,:); end
    if ~ischar(elecOri) && size(elecOri,1)>1
        elecPara.elecOri = elecPara.elecOri(indInUsrInput,:);
    end
elseif length(elecPara)==length(elecName)
    elecPara = elecPara(indInUsrInput);
else
    error('Something is wrong!');
end

options = struct('configTxt',configTxt,'elecPara',elecPara,'T2',T2,'meshOpt',meshOpt,'conductivities',conductivities,'dielectrics',dielectrics,'uniqueTag',simTag,'resamp',doResamp,'zeroPad',paddingAmt,'isNonRAS',isNonRAS);

% log tracking
[dirname,baseFilename] = fileparts(subj);
if isempty(dirname), dirname = pwd; end

Sopt = dir([dirname filesep baseFilename '_*_simOptions.mat']);
if isempty(Sopt)
    options = writeSimLog(subj,options,'ttfsim');
else
    isNew = zeros(length(Sopt),1);
    for i=1:length(Sopt)
        load([dirname filesep Sopt(i).name],'opt');
        isNew(i) = isNewOptions(options,opt,'ttfsim');
    end
    % if all(isNew)
    %     options = writeSimLog(subj,options,'ttfsim');
    % else
    %     load([dirname filesep Sopt(find(~isNew)).name],'opt');
    %     if ~isempty(options.uniqueTag) && ~strcmp(options.uniqueTag,opt.uniqueTag)
    %         warning(['The simulation with the same options has been run before under tag ''' opt.uniqueTag '''. The new tag you specified ''' options.uniqueTag ''' will be ignored.']);
    %     end
    %     options.uniqueTag = opt.uniqueTag;
    % end
end
uniqueTag = options.uniqueTag;

fprintf('\n');
disp('======================================================')
disp(['AutoSimTTF ' subj])
disp('USING RECIPE:')
disp(configTxt)
disp('...and simulation options saved in:')
disp([dirname filesep baseFilename '_simLog,'])
disp(['under tag: ' uniqueTag])
disp('======================================================')
fprintf('\n\n');

% warn users lead field will take a long time to generate
if all(strcmpi(recipe,'leadfield'))
    [~,indRef] = ismember('Iz',elecName);
    indStimElec = setdiff(1:length(elecName),indRef);
    [isInSimCore,indInSimCore] = ismember(elecNameOri,elecName(indStimElec));
    isSolved = zeros(length(indStimElec),1);
    for i=1:length(indStimElec)
        if exist([dirname filesep baseFilename '_' uniqueTag '_e' num2str(indStimElec(i)) '.pos'],'file')
            isSolved(i) = 1;
        end
    end
    % only warn users the first time they run for this subject
    if all(~isSolved) && ~exist([dirname filesep baseFilename '_' uniqueTag '_simResult.mat'],'file')
        warning('You specified the ''recipe'' as the ''lead field generation''. Nice choice! Note all customized options on electrodes are overwritten by the defaults. Refer to the readme file for more details. Also this will usually take a long time (>1 day) to generate the lead field for all the candidate electrodes.');
        doLFconfirm = input('Do you want to continue? ([Y]/N)','s');
        if strcmpi(doLFconfirm,'n'), disp('Aborted.'); return; end
    end
end

%%    
[~,baseFilenameRasRSPD] = fileparts(subjRasRSPD);

% Extract base filename (patient ID)
underscoreIndex = strfind(subj, '_');
subjFileName = subj(1:underscoreIndex-1);
t1gd = normalizeNiftiInput([subjFileName '_T1GD']);
flair = normalizeNiftiInput([subjFileName '_FLAIR']);
[t1gdRS,~] = convertToRAS(t1gd);
[flairRS,~] = convertToRAS(flair);
if paddingAmt>0
    t1gdRSPD = zeroPadding(t1gdRS,paddingAmt);
    flairRSPD  = zeroPadding(flairRS,paddingAmt);
else
    t1gdRSPD = t1gdRS;
    flairRSPD = flairRS;
end


if (isempty(T2) && ~exist([dirname filesep 'c1' baseFilenameRasRSPD '_T1orT2.nii'],'file')) ||...
        (~isempty(T2) && ~exist([dirname filesep 'c1' baseFilenameRasRSPD '_T1andT2.nii'],'file'))
    disp('======================================================')
    disp('       STEP 1 (out of 7): SEGMENT THE MRI...          ')
    disp('======================================================')
    start_seg(subjRasRSPD,T2);
else
    disp('======================================================')
    disp('          MRI ALREADY SEGMENTED, SKIP STEP 1          ')
    disp('======================================================')
end

if (isempty(T2) && ~exist([dirname filesep baseFilenameRasRSPD '_T1orT2_masks.nii'],'file')) ||...
        (~isempty(T2) && ~exist([dirname filesep baseFilenameRasRSPD '_T1andT2_masks.nii'],'file'))
    disp('======================================================')
    disp('     STEP 2 (out of 7): SEGMENTATION TOUCHUP...       ')
    disp('======================================================')
    segTouchup(subjRasRSPD,T2);
else
    disp('======================================================')
    disp('    SEGMENTATION TOUCHUP ALREADY DONE, SKIP STEP 2    ')
    disp('======================================================')
end

if ~exist([dirname filesep baseFilename  '_segm.nii'],'file')
    disp('======================================================')
    disp('      STEP 3 (out of 7): SEGMENT TUMOR...       ')
    disp('======================================================')
    if isempty(T2)
        preMasks = [dirname filesep baseFilenameRasRSPD '_T1orT2_masks.nii'];
    else
        preMasks = [dirname filesep baseFilenameRasRSPD '_T1andT2_masks.nii'];
    end
    processAndSegment(subjRasRSPD,T2,t1gdRSPD,flairRSPD,preMasks);
 else
    disp('======================================================')
    disp('          TUMOR ALREADY SEGMENTED, SKIP STEP 3        ')
    disp('======================================================')
 end

if ~exist([dirname filesep baseFilename '_' uniqueTag '_mask_elec.nii'],'file')
    disp('======================================================')
    disp('      STEP 4 (out of 7): ELECTRODE PLACEMENT...       ')
    disp('======================================================')
    hdrInfo = electrodePlacement(subj,subjRasRSPD,T2,elecName,options,uniqueTag);
else
    disp('======================================================')
    disp('         ELECTRODE ALREADY PLACED, SKIP STEP 4       ')
    disp('======================================================')
    load([dirname filesep baseFilenameRasRSPD '_header.mat'],'hdrInfo');
end

if ~exist([dirname filesep baseFilename '_' uniqueTag '.mat'],'file')
    disp('======================================================')
    disp('        STEP 5 (out of 7): MESH GENERATION...         ')
    disp('======================================================')

    masks = load_untouch_nii([dirname filesep baseFilenameRasRSPD '_T1andT2_masks.nii']);
    lesion_mask = load_untouch_nii([dirname filesep baseFilename '_segm.nii']);
    allMask = masks;
    segment_label = [1 2 3];
    mask_label = [7 8 9];
    for i = 1:length(segment_label)
        [r,c,v] = ind2sub(size(lesion_mask.img),find(lesion_mask.img == segment_label(i)));
        allMask.img(sub2ind(size(allMask.img),r,c,v)) = mask_label(i);       
    end
    allMask.hdr.dime.glmax = 9;
    save_untouch_nii(allMask,[dirname filesep baseFilenameRasRSPD '_T1andT2_allmasks.nii']);

    [node,elem,face] = meshByIso2mesh(subj,subjRasRSPD,T2,meshOpt,hdrInfo,uniqueTag);
else
    disp('======================================================')
    disp('          MESH ALREADY GENERATED, SKIP STEP 5         ')
    disp('======================================================')
    load([dirname filesep baseFilename '_' uniqueTag '.mat'],'node','elem','face');
end

if any(~strcmpi(recipe,'leadfield'))

    if ~exist([dirname filesep baseFilename '_' uniqueTag '_v.pos'],'file')
        disp('======================================================')
        disp('       STEP 6 (out of 7): SOLVING THE MODEL...        ')
        disp('======================================================')
        prepareForGetDP(subj,node,elem,elecName,uniqueTag);
        indElecSolve = 1:length(elecName);    
        solveByGetDP(subj,injectCurrent,conductivities,dielectrics,frequency,indElecSolve,uniqueTag,'');
    else
        disp('======================================================')
        disp('           MODEL ALREADY SOLVED, SKIP STEP 6          ')
        disp('======================================================')
    end
    
    
    if ~exist([dirname filesep baseFilename '_' uniqueTag '_simResult.mat'],'file')
        disp('======================================================')
        disp('STEP 7 (final step): SAVING AND VISUALIZING RESULTS...')
        disp('======================================================')
        [vol_all,ef_mag,ef_all] = postGetDP(subj,subjRasRSPD,node,hdrInfo,uniqueTag);       
        visualizeRes(subj,subjRasRSPD,T2,node,elem,face,injectCurrent,hdrInfo,uniqueTag,0,vol_all,ef_mag,ef_all);
    else
        disp('======================================================')
        disp('  ALL STEPS DONE, LOADING RESULTS FOR VISUALIZATION   ')
        disp('======================================================')
        load([dirname filesep baseFilename '_' uniqueTag '_simResult.mat'],'vol_all','ef_mag','ef_all');
        visualizeRes(subj,subjRasRSPD,T2,node,elem,face,injectCurrent,hdrInfo,uniqueTag,1,vol_all,ef_mag,ef_all);
    end

else
    
    if any(~isSolved) && ~exist([dirname filesep baseFilename '_' uniqueTag '_simResult.mat'],'file')
        disp('======================================================')
        disp('    STEP 5 (out of 6): GENERATING THE LEAD FIELD...   ')
        disp('           NOTE THIS WILL TAKE SOME TIME...           ')
        disp('======================================================')
        prepareForGetDP(subj,node,elem,elecName,uniqueTag);
        injectCurrent = ones(length(elecName),1); % 1 mA at each candidate electrode
        injectCurrent(indRef) = 0;
        for i=1:length(indStimElec)
            if ~isSolved(i)
                fprintf('\n======================================================\n');
                disp(['SOLVING FOR ELECTRODE ' num2str(i) ' OUT OF ' num2str(length(indStimElec)) ' ...']);
                fprintf('======================================================\n\n');
                indElecSolve = [indStimElec(i) indRef];
                solveByGetDP(subj,injectCurrent,conductivities,dielectrics,frequency,indElecSolve,uniqueTag,num2str(indStimElec(i)));
            else
                disp(['ELECTRODE ' num2str(i) ' HAS BEEN SOLVED, SKIPPING...']);
            end
        end
    else
        disp('======================================================')
        disp('       LEAD FIELD ALREADY GENERATED, SKIP STEP 5      ')
        disp('======================================================')
        %     load([dirname filesep baseFilename '_' uniqueTag '_elecMeshLabels.mat'],'label_elec');
    end
    
    if ~exist([dirname filesep baseFilename '_' uniqueTag '_simResult.mat'],'file')
        disp('========================================================')
        disp('STEP 6 (final step): ASSEMBLING AND SAVING LEAD FIELD...')
        disp('========================================================')
        postGetDP(subj,[],node,hdrInfo,uniqueTag,indStimElec,indInSimCore(isInSimCore));
    else
        disp('======================================================')
        disp('         ALL STEPS DONE, READY TO DO TARGETING        ')
        disp(['         FOR SUBJECT ' subj])
        disp(['         USING TAG ' uniqueTag])
        disp('======================================================')
    end
    
end

disp('==================ALL DONE AutoSimTTF=======================');
