function ttf_target(subj,simTag,targetCoord,varargin)

addpath(genpath([fileparts(which(mfilename)) filesep 'lib/']));
addpath(genpath([fileparts(which(mfilename)) filesep 'src/']));

fprintf('\n\n');
disp('======================================================')
disp('CHECKING INPUTS...')
disp('======================================================')
fprintf('\n');
 
warning('off','MATLAB:nargchk:deprecated');

% check subject name
if nargin<1 || isempty(subj)
    error(['Please Check Inputs']);
end

% check simulation tag
if nargin<2 || isempty(simTag)
    error(['Please provide a valid simulation tag for Subject ' subj ', so that TTF_target() can locate the corresponding lead field.']);
end

[dirname,baseFilename,ext] = fileparts(subj);
optionFile = [dirname filesep baseFilename '_' simTag '_simOptions.mat'];
if ~exist(optionFile,'file')
    error(['Option file not found. Simulation ' simTag ' may never be run. Please run it first.']);
else
    load(optionFile,'opt');
    optSim = opt;
end

if ~strcmp(optSim.configTxt,'leadFieldGeneration')
    error(['Simulation ' simTag ' was NOT run for generating the lead field for subject ' subj '. TTF_target() cannot work without a proper lead field. Please run AutoSimTTF with ''leadField'' as the recipe first.']);
end

% to locate related files (e.g. MRI header, *_seg8 mapping, tissue masks)
if optSim.isNonRAS
    subjRas = [dirname filesep baseFilename '_ras' ext];
else
    subjRas = subj;
end

if optSim.resamp
    [dirname2,baseFilename2,ext2] = fileparts(subjRas);
    subjRasRS = [dirname filesep baseFilename2 '_1mm' ext];
else
    subjRasRS = subjRas;
end

if optSim.zeroPad>0
    [dirname2,baseFilename2,ext2] = fileparts(subjRasRS);
    subjRasRSPD = [dirname2 filesep baseFilename2 '_padded' num2str(optSim.zeroPad) ext2];
    %     subjRasRSPD = ['example/nyhead_padded' num2str(paddingAmt) '.nii'];
else
    subjRasRSPD = subjRasRS;
end

meshFile = [dirname filesep baseFilename '_' simTag '.mat'];
if ~exist(meshFile,'file')
    error(['Mesh file ' meshFile ' not found. Check if you run through meshing in AutoSimTTF.']);
else
    load(meshFile,'node','elem','face');
end

[~,baseFilenameRasRSPD] = fileparts(subjRasRSPD);
hdrFile = [dirname filesep baseFilenameRasRSPD '_header.mat'];
if ~exist(hdrFile,'file')
    error(['Header file ' hdrFile ' not found. Check if you run through electrode placement in AutoSimTTF.']);
else
    load(hdrFile,'hdrInfo');
end

% check target coordinates
if nargin<3 || isempty(targetCoord)
    error(['fault targetCoord']);
end

if size(targetCoord,2) ~= 3
    error('Unrecognized format of target coordinates. Please enter as [x y z].');
end
if size(unique(targetCoord,'rows'),1) < size(targetCoord,1)
    error('Duplicated target locations. Please make sure each target is at a different location in the brain.');
end
numOfTargets = size(targetCoord,1);

% take in user-specified options
if mod(length(varargin),2)~=0 % varargin: variable-length input argument list
    error('Unrecognized format of options. Please enter as property-value pair.');
end

indArg = 1;
while indArg <= length(varargin)
    switch lower(varargin{indArg})
        case 'coordtype'
            coordType = varargin{indArg+1};
            indArg = indArg+2;
        case 'opttype'
            optType = varargin{indArg+1};
            indArg = indArg+2;
        case 'orient'
            orient = varargin{indArg+1};
            indArg = indArg+2;
        case 'desiredintensity'
            desiredIntensity = varargin{indArg+1};
            indArg = indArg+2; 
        case 'elecnum'
            elecNum = varargin{indArg+1};
            indArg = indArg+2;
        case 'targetradius'
            targetRadius = varargin{indArg+1};
            indArg = indArg+2;
        case 'k'
            k = varargin{indArg+1};
            indArg = indArg+2;
        case 'targetingtag'
            tarTag = varargin{indArg+1};
            indArg = indArg+2;
        otherwise
            error('Supported options are: ''coordType'', ''optType'', ''orient'', ''desiredIntensity'', ''elecNum'', ''targetRadius'', ''k'', and ''targetingtag''.');
    end
end

% set up defaults and check on option conflicts
if ~exist('coordType','var')
    coordType = 'mni';
else
    if ~any(strcmpi(coordType,{'mni','voxel'}))
        error('Please enter either ''mni'' or ''voxel'' for option ''coordType''.');
    end
end

if ~exist('optType','var')
    optType = 'optimize_electrodes';
else
    if ~any(strcmpi(optType,{'optimize_electrodes'}))
        error('Supported targeting optimization is: ''optimize_electrodes''.');
    end
end

if ~exist('orient','var')
    orient = cell(numOfTargets,1);
    for i=1:numOfTargets, orient{i} = 'radial-in'; end
else
    if ~iscell(orient)
        if ischar(orient)
            if ~ismember(lower(orient),{'radial-in','radial-out','right','left','anterior','posterior','right-anterior','right-posterior','left-anterior','left-posterior','optimal'})
                error('Supported orientations of electric field at the target are: ''radial-in'',''radial-out'',''right'',''left'',''anterior'',''posterior'',''right-anterior'',''right-posterior'',''left-anterior'',''left-posterior'',''optimal''.');
            end
            orient0 = orient;
            orient = cell(numOfTargets,1);
            for i=1:numOfTargets, orient{i} = orient0; end
        else
            if size(orient,2)~=3
                error('Unrecognized customized orientation. Please enter the customized orientation vector for each target as a 1-by-3 vector.');
            end
            if size(orient,1)>1 && size(orient,1)~=numOfTargets
                error('You want different customized orientations at each target. Please tell ttf_target() the customized orientation for each target respectively, in a N-by-3 matrix, where N is the number of targets.');
            end
            if size(orient,1)==1 && numOfTargets>1
                orient = repmat(orient,numOfTargets,1);
            end
        end
    else
        if length(orient)~=numOfTargets
            error('You want different orientations at each target. Please tell ttf_target() the orientation for each target respectively, in a N-by-1 cell, where N is the number of targets.');
        end
        nOptimal = 0;
        for i=1:numOfTargets
            if ischar(orient{i})
                if ~ismember(lower(orient{i}),{'radial-in','radial-out','right','left','anterior','posterior','right-anterior','right-posterior','left-anterior','left-posterior','optimal'})
                    error('Supported orientations of electric field at the target are: ''radial-in'',''radial-out'',''right'',''left'',''anterior'',''posterior'',''right-anterior'',''right-posterior'',''left-anterior'',''left-posterior'',''optimal''.');
                end
                if strcmpi(orient{i},'optimal'), nOptimal = nOptimal + 1; end
            else
                if size(orient{i},2)~=3
                    error('Unrecognized customized orientation. Please enter the customized orientation vector for each target as a 1-by-3 vector.');
                end
                if size(orient{i},1)>1
                    error('You want different customized orientations at each target. Please tell ttf_target() the customized orientation in a 1-by-3 vector.');
                end
            end
        end
        if nOptimal>0 && nOptimal~=numOfTargets
            error('ttf_target() cannot perform targeting for mixed optimal and unoptimal orientations. Please specify either all-optimal or all-unoptimal orientations for all the targets.');
        end
    end
end

needOrigin = 0;
if iscell(orient)
    for i=1:numOfTargets
        if ischar(orient{i}) && ismember(lower(orient{i}),{'radial-in','radial-out','optimal'})
            needOrigin = 1;
            break;
        end
    end
end

if ~exist('desiredIntensity','var') % Set desired field intensity
    desiredIntensity = 500; 
end

if ~exist('targetRadius','var')
    targetRadius = 10;
else
    if targetRadius<=0 || mod(targetRadius,1)~=0
        error('Unrecognized option value. Please enter positive integer value for option ''targetRadius''.');
    end
    warning('You''re changing the advanced options of AutoSimTTF-TARGET. Unless you know what you''re doing, please keep the ''targetRadius'' value default.');
end

if ~exist('tarTag','var'), tarTag = []; end

% to locate related files (e.g. MRI header, *_seg8 mapping, tissue masks)
if isempty(optSim.T2)
    baseFilenameRasRSPD = [baseFilenameRasRSPD '_T1orT2'];
else
    baseFilenameRasRSPD = [baseFilenameRasRSPD '_T1andT2'];
end

if strcmpi(coordType,'mni') || needOrigin
    mappingFile = [dirname filesep baseFilenameRasRSPD '_seg8.mat'];
    if ~exist(mappingFile,'file')
        error(['Mapping file ' mappingFile ' from SPM not found. Please check if you run through SPM segmentation in AutoSimTTF.']);
    else
        load(mappingFile,'image','Affine');
        mni2mri = inv(image(1).mat)*inv(Affine);
        % mapping from MNI space to individual MRI
    end
end

if strcmpi(coordType,'mni')
    targetCoordMNI = targetCoord;
    targetCoordOriginal = [];
    for i=1:numOfTargets
        temp = mni2mri*[targetCoord(i,:) 1]';
        targetCoord(i,:) = round(temp(1:3)'); % model voxel coord
    end
else
    targetCoordMNI = [];
    if any(mod(targetCoord(:),1)~=0) || any(targetCoord(:)<=0)
        error('Voxel coordinates should be entered as positive integers');
    end
    targetCoordOriginal = targetCoord;
    % save original MRI voxel coord, before updating them into model voxel coord
    % according to options of isNonRAS, resamp, and zeroPad
    if optSim.isNonRAS
        [targetCoord,perm] = convertToRASpointCloud(subj,targetCoord);
    else
        perm = [1 2 3];
    end
    if optSim.resamp
        data = load_untouch_nii(subj);
        temp = data.hdr.dime.pixdim(2:4);
        temp = temp(perm);
        targetCoord = round(targetCoord.*repmat(temp,size(targetCoord,1),1));
    end
    if optSim.zeroPad>0
        targetCoord = targetCoord + optSim.zeroPad;
    end
end

if any(targetCoord(:)<=0) || any(targetCoord(:,1)>hdrInfo.dim(1)) || ...
        any(targetCoord(:,2)>hdrInfo.dim(2)) || any(targetCoord(:,3)>hdrInfo.dim(3))
    error('Voxel coordinates should not go beyond image boundary. Please check if you entered voxel coordinates but specified MNI coordinates, or the other way around.');
end

if needOrigin
    temp = mni2mri*[0 0 0 1]';
    origin = round(temp(1:3)'); % model voxel coord
end

% prepare data
p.numOfTargets = numOfTargets;
p.I_max = 2; % 2 mA
p.targetCoord = targetCoord;
p.optType = lower(optType);
p.targetRadius = targetRadius/mean(hdrInfo.pixdim); % to voxel space
p.desiredIntensity = desiredIntensity;

if ~iscell(orient)
    u0 = orient;
else
    u0 = zeros(numOfTargets,3);
    for i=1:numOfTargets
        if ischar(orient{i})
            switch lower(orient{i})
                case {'radial-in','optimal'}
                    u0(i,:) = origin-targetCoord(i,:);
                case 'radial-out'
                    u0(i,:) = targetCoord(i,:)-origin;
                case 'right'
                    u0(i,:) = [1 0 0];
                case 'left'
                    u0(i,:) = [-1 0 0];
                case 'anterior'
                    u0(i,:) = [0 1 0];
                case 'posterior'
                    u0(i,:) = [0 -1 0];
                case 'right-anterior'
                    u0(i,:) = [1 1 0];
                case 'right-posterior'
                    u0(i,:) = [1 -1 0];
                case 'left-anterior'
                    u0(i,:) = [-1 1 0];
                case 'left-posterior'
                    u0(i,:) = [-1 -1 0];
            end
        else
            u0(i,:) = orient{i};
        end
    end
end

for i=1:size(u0,1)
    u0(i,:) = u0(i,:)/norm(u0(i,:)); % unit vector
    if any(isnan(u0(i,:)))
        error(['Orientation vector at target ' num2str(i) ' has a length close to 0. It could be that you picked a target too close to the brain center.']);
    end
end
p.u = u0;

options = struct('targetCoordMNI',targetCoordMNI,'targetCoordOriginal',targetCoordOriginal,'targetCoord',targetCoord,'optType',optType,'desiredIntensity',desiredIntensity,'targetRadius',targetRadius,'u0',u0,'uniqueTag',tarTag,'simTag',simTag);
options.orient = orient; % make sure options is a 1x1 struct

% log tracking here
Sopt = dir([dirname filesep baseFilename '_*_targetOptions.mat']);
if isempty(Sopt)
    options = writeSimLog(subj,options,'target');
else
    isNew = zeros(length(Sopt),1);
    for i=1:length(Sopt)
        load([dirname filesep Sopt(i).name],'opt');
        isNew(i) = isNewOptions(options,opt,'target');
    end
    % if all(isNew)
    %     options = writeSimLog(subj,options,'target');
    % else
    %     load([dirname filesep Sopt(find(~isNew)).name],'opt');
    %     if ~isempty(options.uniqueTag) && ~strcmp(options.uniqueTag,opt.uniqueTag)
    %         warning(['The targeting with the same options has been run before under tag ''' opt.uniqueTag '''. The new tag you specified ''' options.uniqueTag ''' will be ignored.']);
    %     end
    %     options.uniqueTag = opt.uniqueTag;
    % end
end
uniqueTag = options.uniqueTag;

fprintf('\n');
disp('======================================================')
disp(['AutoSimTTF-TARGET ' subj]);

if ~isempty(targetCoordMNI)
    disp('AT MNI COORDINATES:')
    for i=1:numOfTargets, fprintf('[%d %d %d]\n',targetCoordMNI(i,1),targetCoordMNI(i,2),targetCoordMNI(i,3)); end
else
    disp('AT ORIGINAL MRI VOXEL COORDINATES:')
    for i=1:numOfTargets, fprintf('[%d %d %d]\n',targetCoordOriginal(i,1),targetCoordOriginal(i,2),targetCoordOriginal(i,3)); end
end
disp('...using targeting options saved in:')
disp([dirname filesep baseFilename '_targetLog,'])
disp(['under tag: ' uniqueTag])
disp('======================================================')
fprintf('\n\n');

if ~exist([dirname filesep baseFilename '_' uniqueTag '_targetResult.mat'],'file')
    
    leadFieldFile = [dirname filesep baseFilename '_' simTag '_simResult.mat'];
    if ~exist(leadFieldFile,'file')
        error(['Lead field not found for subject ' subj ' under simulation tag ' simTag '. Please check if you ran AutoSimTTF with ''leadField'' as the recipe first.']);
    else
        disp('Loading the lead field for targeting...');
        load(leadFieldFile,'A_all');
    end
    
    % extract A matrix corresponding to the brain
    indBrain = elem((elem(:,5)==1 | elem(:,5)==2 | elem(:,5)==7 | elem(:,5)==8 | elem(:,5)==9),1:4); % Extract columns 1-4 of rows where elem column 5 equals 1,2,7,8,9
    indBrain = unique(indBrain(:));% Extract unique values
    A = A_all(indBrain,:,:);
    
    %---- Judge whether A is NaN,if yes, then error is reported ------%
    if all(isnan(A)), fprintf('\n A is all NaN,solving was not done properly =_=\n'); end
    %------------------------------------------------------------------%
    
    % convert pseudo-world coordinates back to voxel coordinates for targeting,
    % as targeting code works in the voxel space
    nodeV = zeros(size(node,1),3);
    for i=1:3, nodeV(:,i) = node(:,i)/hdrInfo.pixdim(i); end
    locs = nodeV(indBrain,1:3);
    
    isNaNinA = isnan(sum(sum(A,3),2)); % make sure no NaN is in matrix A or in locs
    if any(isNaNinA), A = A(~isNaNinA,:,:); locs = locs(~isNaNinA,:); end
    
    Nlocs = size(locs,1);
    p.Nlocs = Nlocs;
    
    Nelec = size(A,3);
    A = reshape(A,Nlocs*3,Nelec);
    
    % start targeting code
    p = optimize_prepare(p,A,locs);
    
    if iscell(orient) && ismember('optimal',lower(orient(1))) % optimal indicates orientation optimization needed
        % u = zeros(numOfTargets,3);
        % t0 = zeros(numOfTargets,2); % t0 stores the converted spherical coordinates
        % for i=1:numOfTargets
        %     [t0(i,1),t0(i,2)] = cart2sph(u0(i,1),u0(i,2),u0(i,3));
        %     t0(i,2) = pi/2-t0(i,2);
        % end
        % fun = @(t)optimize_anon(p,t,A);
        % fprintf('============================\nSearching for the optimal orientation...\n')
        % % fprintf('with optimization performed inside...\n')
        % % fprintf('Below only outputs outer optimization info:\n============================\n')
        % warning('off','MATLAB:optim:fminunc:SwitchingMethod');
        % t_opt = fminunc(fun,t0,optimoptions('fminunc','display','iter'));
        % for i=1:numOfTargets
        %     u(i,:) = [cos(t_opt(i,1))*sin(t_opt(i,2)) sin(t_opt(i,1))*sin(t_opt(i,2)) cos(t_opt(i,2))];
        % end
        % p.u = u;
        error(['============================\n Maintenance in progress... \n'])
    end

    if strcmpi(uniqueTag,'OPT')
        % Fnode = load([dirname filesep baseFilename '_LF.mat']);
        Fnode = [dirname filesep baseFilename '_' simTag '.mat'];
        [E_opt,I_opt] = optimize(p,A,Fnode);
    else
        error(['Unrecognized targeting tag: ' uniqueTag]);
    end

    mon = [I_opt; -sum(I_opt)]; % Ref electrode Iz is in the last one in .loc file
    r.mon = mon;
    numOfTargets = p.numOfTargets;
    target_nodes = p.target_nodes;
    % Compute focality
    focality = compute_focality(p,E_opt,locs);
    % Compute target field intensity
    for n = 1:numOfTargets
        for i = 1:size(target_nodes{n},1)
            x_t(i,n) = norm( [E_opt( target_nodes{n}(i,1),1 ),E_opt( target_nodes{n}(i,1)+Nlocs,1 ),E_opt( target_nodes{n}(i,1)+2*Nlocs,1 )]); 
            x_target(n) = mean(x_t(:,n));
        end
    end
    % Compute ATV
    ET_locs = nodeV((node(:,4)==9.5),1:3);
    [rows_ET_index,~] = ismember(locs,ET_locs);
    [rows_ET,~] = find(rows_ET_index);
    ET_nodes = unique(rows_ET);
    for i = 1:size(ET_nodes,1)
            x_et(i,1) = norm( [E_opt( ET_nodes(i,1),1 ),E_opt( ET_nodes(i,1)+Nlocs,1 ),E_opt( ET_nodes(i,1)+2*Nlocs,1 )]); 
    end
    ATV1 = sum(x_et >= 100)/size(ET_nodes,1); % Ratio of ET field intensity > 1 V/cm
    ATV2 = sum(x_et >= 200)/size(ET_nodes,1); % Ratio of ET field intensity > 2 V/cm
    ATV3 = sum(x_et >= 300)/size(ET_nodes,1); % Ratio of ET field intensity > 3 V/cm

    disp('Optimization DONE!');
    disp('======================================================');
    disp('Results are saved as:');
    disp([dirname filesep baseFilename '_' uniqueTag '_targetResult.mat']);
    disp('======================================================');
    disp('Stats at target locations are also saved in the log file: ');
    disp([dirname filesep baseFilename '_targetLog,']);
    disp(['under tag: ' uniqueTag]);
    for n = 1:numOfTargets
        fprintf('The electric field intensity of the target node:%.4f V/m' , x_target(n));
        fprintf('\n');
    end
    fprintf('The electric field focality of the target node:%.2f mm' , focality);
    fprintf('\n');
    fprintf('ATV1:%.2f ' , ATV1);
    fprintf('\n');
    fprintf('ATV2:%.2f ' , ATV2);
    fprintf('\n');
    fprintf('ATV3:%.2f ' , ATV3);
    fprintf('\n');
    
else
    
    disp(['The targeting under tag ''' uniqueTag ''' has been run before']);
    disp([' and saved in ' dirname filesep baseFilename '_' uniqueTag '_targetResult.mat']);
    disp('Loading the results for visualization...');
    load([dirname filesep baseFilename '_' uniqueTag '_targetResult.mat'],'r');
    mon = r.mon;
    
end

fid = fopen('./data/elec72.loc'); C = textscan(fid,'%d %f %f %s'); fclose(fid);
elecName = C{4}; for i=1:length(elecName), elecName{i} = strrep(elecName{i},'.',''); end
elecPara = struct('capType','1010');

indMonElec = find(abs(mon)>1e-3);
fprintf('============================\n\n')
disp('Electrodes used are:')
for i=1:length(indMonElec), fprintf('%s (%.3f mA)\n',elecName{indMonElec(i)},mon(indMonElec(i))); end, fprintf('\n');

if ~exist([dirname filesep baseFilename '_' uniqueTag '_targetResult.mat'],'file')
    
    % compute the optimized E-field
    disp('Computing the optimized electric field (this may take a while) ...');
    [xi,yi,zi] = ndgrid(1:hdrInfo.dim(1),1:hdrInfo.dim(2),1:hdrInfo.dim(3));
    r.ef_all = zeros([hdrInfo.dim 3]);
    isNaNinA = isnan(sum(sum(A_all,3),2)); % handle NaN properly
    r.xopt = zeros(sum(~isNaNinA),4);
    r.xopt(:,1) = find(~isNaNinA);
    for i=1:size(A_all,2), r.xopt(:,i+1) = squeeze(A_all(~isNaNinA,i,:))*I_opt; end
    
    F = TriScatteredInterp(nodeV(~isNaNinA,1:3), r.xopt(:,2));
    r.ef_all(:,:,:,1) = F(xi,yi,zi);
    F = TriScatteredInterp(nodeV(~isNaNinA,1:3), r.xopt(:,3));
    r.ef_all(:,:,:,2) = F(xi,yi,zi);
    F = TriScatteredInterp(nodeV(~isNaNinA,1:3), r.xopt(:,4));
    r.ef_all(:,:,:,3) = F(xi,yi,zi);
    r.ef_mag = sqrt(sum(r.ef_all.^2,4));
    
    % output intensities and focalities at targets
    masksFile = [dirname filesep baseFilenameRasRSPD '_masks.nii'];
    if ~exist(masksFile,'file')
        error(['Segmentation masks ' masksFile ' not found. Check if you run through MRI segmentation in AutoSimTTF.']);
    else
        masks = load_untouch_nii(masksFile);
    end
    brain = (masks.img==1 | masks.img==2);
    nan_mask_brain = nan(size(brain));
    nan_mask_brain(find(brain)) = 1;
    
    r.targetMag = zeros(numOfTargets,1); r.targetInt = zeros(numOfTargets,1);
    r.targetMagFoc = zeros(numOfTargets,1);
    ef_mag = r.ef_mag.*nan_mask_brain; ef_magTemp = ef_mag(~isnan(ef_mag(:)));
    for i=1:numOfTargets
        r.targetMag(i) = ef_mag(targetCoord(i,1),targetCoord(i,2),targetCoord(i,3));
        r.targetMagFoc(i) = (sum(ef_magTemp(:) >= r.targetMag(i)*0.5))^(1/3) * mean(hdrInfo.pixdim) / 10; % in cm
        r.targetInt(i) = dot(squeeze(r.ef_all(targetCoord(i,1),targetCoord(i,2),targetCoord(i,3),:))',p.u(i,:));
    end
    
    r.targetCoord = targetCoord;

    % also record the results as text in the log file
    montageTxt = [];
    for i=1:length(indMonElec), montageTxt = [montageTxt elecName{indMonElec(i)} ' (' num2str(mon(indMonElec(i)),'%.3f') ' mA), ']; end
    montageTxt = montageTxt(1:end-2);
    r.montageTxt = montageTxt;
    writeSimLog(subj,r,'target-results');
    
    % save r
    save([dirname filesep baseFilename '_' uniqueTag '_targetResult.mat'],'r','-v7.3');
    
end

% visualize the results
disp('Visualizing the results...')
cm_mon = colormap(jet(64));
if strcmpi(optType,'max-l1') || strcmpi(optType,'max-l1per')
    cm_mon(3:62,:) = ones(60,3);
end
figure('Name',['Montage in Targeting: ' uniqueTag],'NumberTitle','off');

mytopoplot(mon,'./data/elec72.loc','numcontour',0,'plotrad',0.9,'shading','flat','gridscale',1000,'whitebk','off','colormap',cm_mon);
hc = colorbar; set(hc,'FontSize',18,'YAxisLocation','right');
title(hc,'Injected current (mA)','FontSize',18);
caxis([min(mon) max(mon)]);
drawnow

[~,indInUsrInput] = elecPreproc(subj,elecName,elecPara);
visualizeRes(subj,subjRasRSPD,optSim.T2,node,elem,face,mon(indInUsrInput),hdrInfo,uniqueTag,0,r.xopt,r.ef_mag,r.ef_all,r.targetCoord);

disp('==================ALL DONE AutoSimTTF-TARGET=======================');
