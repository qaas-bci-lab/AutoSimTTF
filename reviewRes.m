function reviewRes(subj,simTag,tissue,fastRender,tarTag)
% reviewRes(subj,simTag,tissue,fastRender,tarTag)
%
% A simpler interface to visualize the simulations/targetings that are already done.
% Users do not have to enter all the parameters as they would have in
% ttfsim() or ttf_target() main function. Instead, they just need to enter the path
% to the input MRI and the unique simulation/targeting tag for that MRI.
%
% Please refer to the README.md on the github repo for better formated
% documentations: https://github.com/xiexu-auto/AutoSimTTF
%
% If you use AutoSimTTF in your research, please cite these:
% 
% Huang, Y., Datta, A., Bikson, M., Parra, L.C., Realistic vOlumetric-Approach
% to Simulate Transcranial Electric Stimulation -- ROAST -- a fully automated
% open-source pipeline, Journal of Neural Engineering, Vol. 16, No. 5, 2019 (prefered reference)
% 
% Huang, Y., Datta, A., Bikson, M., Parra, L.C., ROAST: an open-source,
% fully-automated, Realistic vOlumetric-Approach-based Simulator for TES,
% Proceedings of the 40th Annual International Conference of the IEEE Engineering
% in Medicine and Biology Society, Honolulu, HI, July 2018
% 
% If you use New York head to run simulation, please also cite the following:
% Huang, Y., Parra, L.C., Haufe, S.,2016. The New York Head - A precise
% standardized volume conductor model for EEG source localization and tES
% targeting, NeuroImage,140, 150-162
% 
% If you also use the targeting feature (`ttf_target`), please cite these:
% 
% Dmochowski, J.P., Datta, A., Bikson, M., Su, Y., Parra, L.C., Optimized 
% multi-electrode stimulation increases focality and intensity at target,
% Journal of Neural Engineering 8 (4), 046011, 2011
% 
% Dmochowski, J.P., Datta, A., Huang, Y., Richardson, J.D., Bikson, M.,
% Fridriksson, J., Parra, L.C., Targeted transcranial direct current stimulation 
% for rehabilitation after stroke, NeuroImage, 75, 12-19, 2013
% 
% Huang, Y., Thomas, C., Datta, A., Parra, L.C., Optimized tDCS for Targeting
% Multiple Brain Regions: An Integrated Implementation. Proceedings of the 40th
% Annual International Conference of the IEEE Engineering in Medicine and Biology
% Society, Honolulu, HI, July 2018, 3545-3548
% 
% ROAST was supported by NIH through grants R01MH111896, R01MH111439, 
% R01NS095123, R44NS092144, R41NS076123, and by Soterix Medical Inc.
% 
% Licensed under the MIT License. See LICENSE.md for details.
%
% This software uses free packages from the Internet, except Matlab, which
% is a proprietary software by the MathWorks. You need a valid Matlab license
% to run this software.
%
% AutoSimTTF is built upon ROAST (Huang et al., 2017-2019), which is
% considered as an "aggregate" rather than "derived work", based on
% the definitions in GPL FAQ. The MIT license applies only to the scripts,
% documentation and the individual MRI data under example/ folder in this
% package and excludes those programs stored in the lib/ directory. The software
% under lib/ follow their respective licenses.
% 
% (c) Yu (Andy) Huang, Parra Lab at CCNY
% yhuang16@citymail.cuny.edu
% September 2019

fprintf('\n\n');
disp('=============================================================')
disp('AutoSimTTF -- fully automatic TTF simulation & treatment planning')
disp('Built upon ROAST by Yu (Andy) Huang, Parra Lab at CCNY')
disp('Licensed under MIT. See LICENSE.md for details.')
disp('=============================================================')

addpath(genpath([fileparts(which(mfilename)) filesep 'lib/']));
addpath(genpath([fileparts(which(mfilename)) filesep 'src/']));

% check subject name
if nargin<1 || isempty(subj)
    subj = 'example/MNI152_T1_1mm.nii';
end

subj = normalizeNiftiInput(subj);

% check simulation tag
if nargin<2 || isempty(simTag)
    error(['Please provide a valid simulation tag for Subject ' subj]);
end

if strcmpi(subj,'nyhead')
    subj = 'example/nyhead.nii';
end

% check tissue to be visualized
if nargin<3 || isempty(tissue)
    tissue = 'brain';
end

switch lower(tissue)
    case 'white'
        indSurfShow = 1;
        indSliceShow = 1;
    case 'gray'
        indSurfShow = 2;
        indSliceShow = 2;
    case 'csf'
        indSurfShow = 3;
        indSliceShow = 3;
    case 'bone'
        indSurfShow = 4;
        indSliceShow = 4;
    case 'skin'
        indSurfShow = 5;
        indSliceShow = 5;
    case 'air'
        indSurfShow = 6;
        indSliceShow = 6;         
    case 'brain'
        indSurfShow = 2;
        indSliceShow = [1,2,3,7,8,9];
    case 'tumor' 
        indSurfShow = 8;
        indSliceShow = 7:9;        
    case 'all'
        indSurfShow = 5;
        indSliceShow = 1:9;
    otherwise
        error('Supported tissues to be displayed are: ''white'', ''gray'', ''CSF'', ''bone'', ''skin'', ''air'', ''brain'', ''tumor'' and ''all''.');
end

% check if do fast rendering
if nargin<4 || isempty(fastRender)
    fastRender = 1; % no smoothing on surface
end

[dirname,baseFilename,ext] = fileparts(subj);
optionFile = [dirname filesep baseFilename '_' simTag '_simOptions.mat'];
if ~exist(optionFile,'file')
    error(['Option file not found. Simulation ' simTag ' may never be run. Please run it first.']);
else
    load(optionFile,'opt');
    optSim = opt;
end

% check if visualizing results from ttfsim() or ttf_target()
if ~strcmp(optSim.configTxt,'leadFieldGeneration')
    
    isSim = 1;
    if exist('tarTag','var')
        warning(['Simulation ' simTag ' was not run for generating the lead field for subject ' subj ', so targeting tag ' tarTag ' will be ignored.']);
    end
    
    disp(['Showing results for Simulation ' simTag ' ...']);
    
else
    
    isSim = 0;
    
    if nargin<5 || isempty(tarTag)
        error(['Simulation ' simTag ' was run for generating the lead field for subject ' subj '. reviewRes() will visualize the results from ttf_target(), but no targeting tag was provided.']);
    end
    
    optionFile = [dirname filesep baseFilename '_' tarTag '_targetOptions.mat'];
    if ~exist(optionFile,'file')
        error(['Option file not found. Targeting ' tarTag ' may never be run. Please run it first.']);
    else
        load(optionFile,'opt');
        optTarget = opt;
    end
    
    disp(['Showing results for Targeting ' tarTag ' ...']);
    
    resFile = [dirname filesep baseFilename '_' tarTag '_targetResult.mat'];
    if ~exist(resFile,'file')
        error(['Result file ' resFile ' not found. Check if you run through targeting under tag ' tarTag '.']);
    else
        load(resFile,'r');
    end
    
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

[~,paddedBaseFilenameRasRSPD] = fileparts(subjRasRSPD);
[~,resampledBaseFilenameRasRSPD] = fileparts(subjRasRS);
if isempty(optSim.T2)
    modalitySuffix = '_T1orT2';
else
    modalitySuffix = '_T1andT2';
end

% With the default zero padding, ttfsim uses the padded MRI internally but
% keeps derived segmentation/header files under the unpadded public stem.
% Prefer that naming scheme, while retaining compatibility with older runs.
baseFilenameRasRSPD = paddedBaseFilenameRasRSPD;
if optSim.zeroPad>0 && exist([dirname filesep resampledBaseFilenameRasRSPD modalitySuffix '_seg8.mat'],'file')
    baseFilenameRasRSPD = resampledBaseFilenameRasRSPD;
end

mappingFile = [dirname filesep baseFilenameRasRSPD modalitySuffix '_seg8.mat'];
if ~exist(mappingFile,'file')
    error(['Mapping file ' mappingFile ' from SPM not found. Please check if you run through SPM segmentation in AutoSimTTF.']);
else
    load(mappingFile,'image','Affine');
    mri2mni = Affine*image(1).mat;
    % mapping from MRI voxel space to MNI space
end

if isSim
    
    lp = strfind(optSim.configTxt,'(');
    rp = strfind(optSim.configTxt,')');
    
    inCurrent = zeros(length(lp),1);
    for i=1:length(lp)
        inCurrent(i) = str2num(optSim.configTxt(lp(i)+1:rp(i)-4));
    end
    
    if ~strcmp(baseFilename,'nyhead')
        
        disp('showing MRI and segmentations...');
        if ~exist(subjRasRSPD,'file')
            error(['The subject MRI you provided ' subjRasRSPD ' does not exist. Check if you run through resampling or zero-padding if you tried to do that.']);
        else
            data = load_untouch_nii(subjRasRSPD); sliceshow(data.img,[],'gray',[],[],'MRI: Click anywhere to navigate.',[],mri2mni); drawnow
        end
        
        if ~isempty(optSim.T2) %T2 specified
            if ~exist(optSim.T2,'file')
                error(['T2 file ' optSim.T2 ' does not exist. You used that to run AutoSimTTF but maybe later deleted it.']);
            else
                data = load_untouch_nii(optSim.T2);
                sliceshow(data.img,[],'gray',[],[],'MRI: T2. Click anywhere to navigate.',[],mri2mni); drawnow
            end
        end
    else
        disp('NEW YORK HEAD selected, there is NO MRI for it to show.')
    end
    
else
    
    fid = fopen('./data/elec72.loc'); C = textscan(fid,'%d %f %f %s'); fclose(fid);
    elecName = C{4}; for i=1:length(elecName), elecName{i} = strrep(elecName{i},'.',''); end
    elecPara = struct('capType','1010');
    
    [~,indInUsrInput] = elecPreproc(subj,elecName,elecPara);
    inCurrent = r.mon(indInUsrInput);
    
end

masksFile = [dirname filesep baseFilenameRasRSPD modalitySuffix '_masks.nii'];
if ~exist(masksFile,'file')
    error(['Segmentation masks ' masksFile ' not found. Check if you run through MRI segmentation.']);
else
    % masks = load_untouch_nii(masksFile);
    masks = load_untouch_nii([dirname filesep baseFilenameRasRSPD modalitySuffix '_allmasks.nii']);
end

numOfTissue = 9; % hard coded across ROAST.  max(allMask(:));

if isSim
    
    gelMask = [dirname filesep baseFilename '_' simTag '_mask_gel.nii'];
    if ~exist(gelMask,'file')
        error(['Gel mask ' gelMask ' not found. Check if you run through electrode placement.']);
    else
        gel = load_untouch_nii(gelMask);
        numOfGel = max(gel.img(:));
    end
    elecMask = [dirname filesep baseFilename '_' simTag '_mask_elec.nii'];
    if ~exist(elecMask,'file')
        error(['Electrode mask ' elecMask ' not found. Check if you run through electrode placement.']);
    else
        elec = load_untouch_nii(elecMask);
        % numOfElec = max(elec.img(:));
    end
    
    allMaskShow = masks.img;
    allMaskShow(gel.img>0) = numOfTissue + 1;
    allMaskShow(elec.img>0) = numOfTissue + 2;
    sliceshow(allMaskShow,[],[],[],'Tissue index','Segmentation. Click anywhere to navigate.',[],mri2mni)
    drawnow
    
else
    
    numOfGel = length(inCurrent);
    indMonElec = find(abs(inCurrent)>1e-3); % this is not perfect
    
    cm = colormap(jet(64));
    if strcmpi(optTarget.optType,'max-l1') || strcmpi(optTarget.optType,'max-l1per')
        cm(3:62,:) = ones(60,3);
    end
    figure('Name',['Montage in Targeting: ' tarTag],'NumberTitle','off');
    mytopoplot(r.mon,'./data/elec72.loc','numcontour',0,'plotrad',0.9,'shading','flat','gridscale',1000,'whitebk','off','colormap',cm);
    hc = colorbar; set(hc,'FontSize',18,'YAxisLocation','right');
    title(hc,'Injected current (mA)','FontSize',18);
    caxis([min(r.mon) max(r.mon)]);
    drawnow
    
    disp('Electrodes used are:')
    disp(strrep(r.montageTxt,', ',newline));
    
end

% node = node + 0.5; already done right after mesh

disp('generating 3D renderings...')

meshFile = [dirname filesep baseFilename '_' simTag '.mat'];
if ~exist(meshFile,'file')
    error(['Mesh file ' meshFile ' not found. Check if you run through meshing.']);
else
    load(meshFile,'node','elem','face');
end

% Tissue labels: gray matter = 2, NCR = 7, ED = 8, ET = 9.
% The field renderings below always use the same two views, independent of
% the legacy tissue argument: ET with translucent gray matter, and gray
% matter with the complete tumor.
indNode_grayFace = face(face(:,4) == 2,1:3);
indNode_grayElm = elem(elem(:,5) == 2,1:4);
indNode_tumorFace = face(ismember(face(:,4),[7 8 9]),1:3);
indNode_tumorElm = elem(ismember(elem(:,5),[7 8 9]),1:4);
indNode_ETFace = face(face(:,4) == 9,1:3);
indNode_ETElm = elem(elem(:,5) == 9,1:4);

if ~fastRender
    node(:,1:3) = sms(node(:,1:3),[indNode_grayFace; indNode_tumorFace]);
    % Smooth only for display; the saved mesh and field data are unchanged.
end

% Header files generated with T2 use the same modality suffix as the
% segmentation and mapping files (e.g. *_ras_T1andT2_header.mat).
hdrFile = [dirname filesep baseFilenameRasRSPD modalitySuffix '_header.mat'];
if ~exist(hdrFile,'file')
    % Keep compatibility with older runs that used *_ras_header.mat.
    legacyHdrFile = [dirname filesep baseFilenameRasRSPD '_header.mat'];
    if exist(legacyHdrFile,'file')
        hdrFile = legacyHdrFile;
    else
        error(['Header file ' hdrFile ' not found. Check if you run through electrode placement.']);
    end
end
load(hdrFile,'hdrInfo');

for i=1:3, node(:,i) = node(:,i)/hdrInfo.pixdim(i); end
% convert pseudo-world coordinates back to voxel coordinates so that the
% following conversion to pure-world space is meaningful
voxCoord = [node(:,1:3) ones(size(node,1),1)];
worldCoord = (hdrInfo.v2w*voxCoord')';
% do the 3D rendering in world space, to avoid confusion in left-right;
% sliceshow below is still in voxel space though
node(:,1:3) = worldCoord(:,1:3);

if isSim
    
    indNode_elecFace = face(find(face(:,4) > numOfTissue+numOfGel),1:3);
    indNode_elecElm = elem(find(elem(:,5) > numOfTissue+numOfGel),1:4);
    
    inCurrentRange = [min(inCurrent) max(inCurrent)];

    efFile = [dirname filesep baseFilename '_' simTag '_e.pos'];
    if ~exist(efFile,'file')
        error(['Solution file ' efFile ' not found. Check if you run through solving.']);
    else
        fid = fopen(efFile);
        fgetl(fid);
        C = textscan(fid,'%d %f %f %f %f %f %f');
        fclose(fid);
    end
    C{2} = sqrt(C{2}.^2+C{5}.^2);
    C{3} = sqrt(C{3}.^2+C{6}.^2);
    C{4} = sqrt(C{4}.^2+C{7}.^2);
    C_ef_mag = sqrt(C{2}.^2+C{3}.^2+C{4}.^2);
    % dataShow = [node(C{1},1:3), C_ef_mag];
    color = nan(size(node,1),1);
    color(C{1}) = C_ef_mag;
    dataShow = [node(:,1:3) color];
    
    fieldNodes = unique([indNode_grayElm(:); indNode_tumorElm(:)]);
    fieldValues = dataShow(fieldNodes,4);
    fieldValues = fieldValues(~isnan(fieldValues));
    dataShowRange = [min(fieldValues) prctile(fieldValues,95)];
    if dataShowRange(1) == dataShowRange(2)
        dataShowRange = dataShowRange + [-0.5 0.5];
    end
    dataShowForElec = interp1(inCurrentRange,dataShowRange,inCurrent);
    for i=1:length(inCurrent)
        %     indNodeTemp = indNode_elecElm(find(label_elec==i),:);
        %     dataShow(unique(indNodeTemp(:)),4) = dataShowForElec(i);
        dataShow(unique(elem(find(elem(:,5) == numOfTissue+numOfGel+i),1:4)),4) = dataShowForElec(i);
    end % to show injected current intensities properly
else
    
    indNode_elecFace = face(ismember(face(:,4),numOfTissue+numOfGel+indMonElec),1:3);
    indNode_elecElm = elem(ismember(elem(:,5),numOfTissue+numOfGel+indMonElec),1:4);
    inCurrentRange = [min(inCurrent) max(inCurrent)];
    
    color = nan(size(node,1),1);
    C = r.xopt;
    color(C(:,1)) = sqrt(sum(C(:,2:4).^2,2));
    dataShow = [node(:,1:3) color];
    
    fieldNodes = unique([indNode_grayElm(:); indNode_tumorElm(:)]);
    fieldValues = dataShow(fieldNodes,4);
    fieldValues = fieldValues(~isnan(fieldValues));
    dataShowRange = [min(fieldValues) prctile(fieldValues,95)];
    if dataShowRange(1) == dataShowRange(2)
        dataShowRange = dataShowRange + [-0.5 0.5];
    end
    dataShowForElec = interp1(inCurrentRange,dataShowRange,inCurrent(indMonElec));
    for i=1:length(indMonElec)
        %     indNodeTemp = indNode_elecElm(find(label_elec==i),:);
        %     dataShow(unique(indNodeTemp(:)),4) = dataShowForElec(i);
        dataShow(unique(elem(find(elem(:,5) == numOfTissue+numOfGel+indMonElec(i)),1:4)),4) = dataShowForElec(i);
    end % to show injected current intensities properly
end

% Render two electric-field views. Voltage is intentionally not displayed.
fieldTag = simTag;
if ~isSim, fieldTag = tarTag; end

figName = ['Electric field in ET with translucent gray matter: ' fieldTag];
figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
set(gcf,'color','w');
colormap(jet);
plotmesh(dataShow,indNode_ETFace,indNode_ETElm,'LineStyle','none');
hold on;
plotmesh(node(:,1:3),indNode_grayFace,indNode_grayElm, ...
    'facecolor',[0.5 0.5 0.5],'facealpha',0.15,'LineStyle','none');
plotmesh(dataShow,indNode_elecFace,indNode_elecElm,'LineStyle','none');
axis off; rotate3d on;
caxis(dataShowRange);
lightangle(-90,45); lightangle(90,45); lightangle(-90,-45);
hc1 = colorbar; set(hc1,'FontSize',18,'YAxisLocation','right');
title(hc1,'Electric field (V/m)','FontSize',18);
a1 = gca;
a2 = axes('Color','none','Position',get(a1,'Position'),'XLim',get(a1,'XLim'),'YLim',get(a1,'YLim'),'ZLim',get(a1,'ZLim'));
axis off;
hc2 = colorbar; set(hc2,'FontSize',18,'YAxisLocation','right','Location','westoutside');
title(hc2,'Injected current (mA)','FontSize',18);
caxis(inCurrentRange);
axes(a1);
drawnow

figName = ['Electric field in gray matter + tumor (NCR+ED+ET): ' fieldTag];
figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
set(gcf,'color','w');
colormap(jet);
plotmesh(dataShow,indNode_grayFace,indNode_grayElm,'LineStyle','none');
hold on;
plotmesh(dataShow,indNode_tumorFace,indNode_tumorElm,'LineStyle','none');
plotmesh(dataShow,indNode_elecFace,indNode_elecElm,'LineStyle','none');
axis off; rotate3d on;
caxis(dataShowRange);
lightangle(-90,45); lightangle(90,45); lightangle(-90,-45);
hc1 = colorbar; set(hc1,'FontSize',18,'YAxisLocation','right');
title(hc1,'Electric field (V/m)','FontSize',18);
a1 = gca;
a2 = axes('Color','none','Position',get(a1,'Position'),'XLim',get(a1,'XLim'),'YLim',get(a1,'YLim'),'ZLim',get(a1,'ZLim'));
axis off;
hc2 = colorbar; set(hc2,'FontSize',18,'YAxisLocation','right','Location','westoutside');
title(hc2,'Injected current (mA)','FontSize',18);
caxis(inCurrentRange);
axes(a1);
drawnow

disp('generating slice views...');

allMask = masks.img;
mask = zeros(size(allMask));
for i=1:length(indSliceShow)
    mask = (mask | allMask==indSliceShow(i));
end
nan_mask = nan(size(mask));
nan_mask(find(mask)) = 1;

cm = colormap(jet(2^11)); cm = [1 1 1;cm];

if isSim
    
    resFile = [dirname filesep baseFilename '_' simTag '_simResult.mat'];
    if ~exist(resFile,'file')
        error(['Result file ' resFile ' not found. Check if you run through post processing after solving.']);
    else
        load(resFile,'vol_all','ef_mag','ef_all');
    end
    
    figName = ['Electric field in Simulation: ' simTag];
    for i=1:size(ef_all,4), ef_all(:,:,:,i) = ef_all(:,:,:,i).*nan_mask; end
    ef_mag = ef_mag.*nan_mask;
    dataShowVal = ef_mag(~isnan(ef_mag(:)));
    sliceshow(ef_mag,[],cm,[min(dataShowVal) prctile(dataShowVal,95)],'Electric field (V/m)',[figName '. Click anywhere to navigate.'],ef_all,mri2mni); drawnow
    
else
    
    for i=1:size(r.ef_all,4), r.ef_all(:,:,:,i) = r.ef_all(:,:,:,i).*nan_mask; end
    r.ef_mag = r.ef_mag.*nan_mask;
    dataShowVal = r.ef_mag(~isnan(r.ef_mag(:)));
    for i=1:size(r.targetCoord,1)
        figName = ['Electric field at Target ' num2str(i) ' in Targeting: ' tarTag];
        sliceshow(r.ef_mag,r.targetCoord(i,:),cm,[min(dataShowVal) prctile(dataShowVal,95)],'Electric field (V/m)',[figName '. Click anywhere to navigate.'],r.ef_all,mri2mni); drawnow
    end
end
