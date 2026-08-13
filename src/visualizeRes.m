function visualizeRes(P1,P2,T2,node,elem,face,inCurrent,hdrInfo,uniTag,showAll,varargin)
% visualizeRes(P1,P2,T2,node,elem,face,inCurrent,hdrInfo,uniTag,showAll,varargin)
%
% Display the simulation results. The 3D rendering is displayed in the
% world space, while the slice view is done in the voxel space.
%
% (c) Yu (Andy) Huang, Parra Lab at CCNY
% yhuang16@citymail.cuny.edu
% April 2018
% August 2019 callable by ttf_target()

outputStem = [];
if numel(varargin) >= 4 && (ischar(varargin{end}) || isstring(varargin{end}))
    outputStem = varargin{end};
    varargin(end) = [];
end

if ndims(varargin{1})==3
    isSim = 1;
    ef_mag = varargin{2}; ef_all = varargin{3};
else
    isSim = 0;
    C = varargin{1}; ef_mag = varargin{2}; ef_all = varargin{3}; targetCoord = varargin{4}; 
end

[dirname,baseFilename] = fileparts(P1);
if isempty(dirname), dirname = pwd; end
if isempty(outputStem)
    [~,baseFilenameRasRSPD] = fileparts(P2);
else
    [~,baseFilenameRasRSPD] = fileparts(char(outputStem));
end
if isempty(T2)
    baseFilenameRasRSPD = [baseFilenameRasRSPD '_T1orT2'];
else
    baseFilenameRasRSPD = [baseFilenameRasRSPD '_T1andT2'];
end

mappingFile = [dirname filesep baseFilenameRasRSPD '_seg8.mat'];
if ~exist(mappingFile,'file')
    error(['Mapping file ' mappingFile ' from SPM not found. Please check if you run through SPM segmentation in AutoSimTTF.']);
else
    load(mappingFile,'image','Affine');
    mri2mni = Affine*image(1).mat;
    % mapping from MRI voxel space to MNI space
end

if showAll    
    if ~strcmp(baseFilename,'nyhead')
        disp('showing MRI and segmentations...');
        data = load_untouch_nii(P2); sliceshow(data.img,[],'gray',[],[],'MRI: Click anywhere to navigate.',[],mri2mni); drawnow
        
        if ~isempty(T2) %T2 specified
            data = load_untouch_nii(T2);
            sliceshow(data.img,[],'gray',[],[],'MRI: T2. Click anywhere to navigate.',[],mri2mni); drawnow
        end
    else
        disp('NEW YORK HEAD selected, there is NO MRI for it to show.')
    end    
end

masks = load_untouch_nii([dirname filesep baseFilenameRasRSPD '_allmasks.nii']);
allMask = masks.img;
numOfTissue = 9; % hard coded across ROAST.  max(allMask(:));
if isSim
    gel = load_untouch_nii([dirname filesep baseFilename '_' uniTag '_mask_gel.nii']);
    numOfGel = max(gel.img(:));
    elec = load_untouch_nii([dirname filesep baseFilename '_' uniTag '_mask_elec.nii']);
    % numOfElec = max(elec.img(:));
else
    numOfGel = length(inCurrent);
    indMonElec = find(abs(inCurrent)>1e-3); % this is not perfect
end

if showAll
    allMaskShow = masks.img;
    allMaskShow(gel.img>0) = numOfTissue + 1;
    allMaskShow(elec.img>0) = numOfTissue + 2;
    sliceshow(allMaskShow,[],[],[],'Tissue index','Segmentation. Click anywhere to navigate.',[],mri2mni)
    drawnow
end

% node = node + 0.5; already done right after mesh

% scrsz = get(groot,'ScreenSize');

disp('generating 3D renderings...')

for i=1:3, node(:,i) = node(:,i)/hdrInfo.pixdim(i); end
% convert pseudo-world coordinates back to voxel coordinates so that the
% following conversion to pure-world space is meaningful

voxCoord = [node(:,1:3) ones(size(node,1),1)];
worldCoord = (hdrInfo.v2w*voxCoord')';
% do the 3D rendering in world space, to avoid confusion in left-right;
% sliceshow below is still in voxel space though
node(:,1:3) = worldCoord(:,1:3);

indNode_grayFace = face(find(face(:,4) == 2),1:3);
indNode_grayElm = elem(find(elem(:,5) == 2),1:4);
% Tumor labels: NCR = 7, ED = 8, ET = 9.
indNode_tumorFace = face(ismember(face(:,4),[7 8 9]),1:3);
indNode_tumorElm = elem(ismember(elem(:,5),[7 8 9]),1:4);
indNode_ETFace = face(face(:,4) == 9,1:3);
indNode_ETElm = elem(elem(:,5) == 9,1:4);
% indNode_NCRFace = face(find(face(:,4) == 7),1:3);
% indNode_NCRElm = elem(find(elem(:,5) == 7),1:4);
% indNode_ERFace = face(find(face(:,4) == 9),1:3);
% indNode_ERElm = elem(find(elem(:,5) == 9),1:4);


% node(:,1:3) = sms(node(:,1:3),indNode_grayFace);
% % smooth the surface that's to be displayed
% % just for display, the output data is not smoothed
% % very slow if mesh is big
if isSim
    
    indNode_elecFace = face(find(face(:,4) > numOfTissue+numOfGel),1:3);
    indNode_elecElm = elem(find(elem(:,5) > numOfTissue+numOfGel),1:4);
    inCurrentRange = [min(inCurrent) max(inCurrent)];
    
    fid = fopen([dirname filesep baseFilename '_' uniTag '_e.pos']);
    fgetl(fid);
    C = textscan(fid,'%d %f %f %f %f %f %f');
    fclose(fid);
    
    % dataShow = [node(C{1},1:3), C_ef_mag];
    color = nan(size(node,1),1);
    C{2} = sqrt(C{2}.^2+C{5}.^2);
    C{3} = sqrt(C{3}.^2+C{6}.^2);
    C{4} = sqrt(C{4}.^2+C{7}.^2);
    color(C{1}) = sqrt(C{2}.^2+C{3}.^2+C{4}.^2);
    dataShow = [node(:,1:3) color];
    
    figName = ['Electric field in ET with translucent gray matter: ' uniTag];
    figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
    set(gcf,'color','w');
    colormap(jet);
    % Use a common range for both field renderings, based on gray matter
    % and the complete tumor (NCR + ED + ET).
    fieldNodes = unique([indNode_grayElm(:); indNode_tumorElm(:)]);
    fieldValues = dataShow(fieldNodes,4);
    fieldValues = fieldValues(~isnan(fieldValues));
    if isempty(fieldValues)
        error('No electric-field values were found on gray matter or tumor elements.');
    end
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
    plotmesh(dataShow,indNode_ETFace,indNode_ETElm,'LineStyle','none');
    hold on;
    plotmesh(node(:,1:3),indNode_grayFace,indNode_grayElm, ...
        'facecolor',[0.5 0.5 0.5],'facealpha',0.15,'LineStyle','none');
    plotmesh(dataShow,indNode_elecFace,indNode_elecElm,'LineStyle','none');
    axis off; rotate3d on;
    % set(hp2,'SpecularColorReflectance',0,'SpecularExponent',50);
    caxis(dataShowRange);
    lightangle(-90,45)
    lightangle(90,45)
    lightangle(-90,-45)
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

    % Figure 2: field on gray matter plus the complete tumor.
    figName = ['Electric field in gray matter + tumor (NCR+ED+ET): ' uniTag];
    figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
    set(gcf,'color','w');
    colormap(jet);
    plotmesh(dataShow,indNode_grayFace,indNode_grayElm,'LineStyle','none');
    hold on;
    plotmesh(dataShow,indNode_tumorFace,indNode_tumorElm,'LineStyle','none');
    plotmesh(dataShow,indNode_elecFace,indNode_elecElm,'LineStyle','none');
    axis off; rotate3d on;
    caxis(dataShowRange);
    lightangle(-90,45)
    lightangle(90,45)
    lightangle(-90,-45)
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
    
else
    
    indNode_elecFace = face(ismember(face(:,4),numOfTissue+numOfGel+indMonElec),1:3);
    indNode_elecElm = elem(ismember(elem(:,5),numOfTissue+numOfGel+indMonElec),1:4);
    inCurrentRange = [min(inCurrent) max(inCurrent)];
    
    color = nan(size(node,1),1);
    color(C(:,1)) = sqrt(sum(C(:,2:4).^2,2));
    dataShow = [node(:,1:3) color];
    
    figName = ['Electric field in Targeting: ' uniTag];
    figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
    set(gcf,'color','w');
    colormap(jet);
    % plotmesh(dataShow,indNode_brainFace,indNode_brainElm,'LineStyle','none');
    %  % dataShowVal = dataShow(unique(indNode_grayElm(:)),4);
    % dataShowRange = [min(dataShow(unique(indNode_grayElm(:)),4)) prctile(dataShow(unique(indNode_grayElm(:)),4),95)];   

    plotmesh(dataShow,indNode_ETFace,indNode_ETElm,'LineStyle','none');
    % dataShowRange = [min(dataShow(unique(indNode_tumorElm(:)),4)) prctile(dataShow(unique(indNode_tumorElm(:)),4),95)];  
    dataShowRange = [0 400]; 
    hold on;
    plotmesh(node(:,1:3),indNode_grayFace,indNode_grayElm,'facecolor','k','facealpha','0.1','LineStyle','none');

    dataShowForElec = interp1(inCurrentRange,dataShowRange,inCurrent(indMonElec));
    for i=1:length(indMonElec)
            % indNodeTemp = indNode_elecElm(find(label_elec==i),:);
            % dataShow(unique(indNodeTemp(:)),4) = dataShowForElec(i);
        dataShow(unique(elem(find(elem(:,5) == numOfTissue+numOfGel+indMonElec(i)),1:4)),4) = dataShowForElec(i);
    end % to show injected current intensities properly
    hold on;
    plotmesh(dataShow,indNode_elecFace,indNode_elecElm,'LineStyle','none');
    axis off; rotate3d on;
    % set(hp2,'SpecularColorReflectance',0,'SpecularExponent',50);
    caxis(dataShowRange);
    lightangle(-90,45)
    lightangle(90,45)
    lightangle(-90,-45)
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
    
end
disp('generating slice views...');

brain = (allMask==1 | allMask==2 | allMask==3 | allMask==6 | allMask==7 | allMask==8 | allMask==9);
nan_mask_brain = nan(size(brain));
nan_mask_brain(brain) = 1;

cm = colormap(jet(2^11)); cm = [1 1 1;cm];

for i=1:size(ef_all,4), ef_all(:,:,:,i) = ef_all(:,:,:,i).*nan_mask_brain; end
ef_mag_E = ef_mag.*nan_mask_brain;
ef_mag_E = ef_mag_E./100;
dataShowVal = ef_mag_E(~isnan(ef_mag_E(:)));
if isSim
    figName = ['Electric field in Simulation: ' uniTag];
    sliceshow(ef_mag_E,[],cm,[min(dataShowVal) prctile(dataShowVal,95)],'Electric field (V/cm)',[figName '. Click anywhere to navigate.'],ef_all,mri2mni); drawnow
else
    
    for i=1:size(targetCoord,1)
        figName = ['Electric field at Target ' num2str(i) ' in Targeting: ' uniTag];
        sliceshow(ef_mag_E,targetCoord(i,:),cm,[0 2],'Electric field (V/cm)',[figName '. Click anywhere to navigate.'],ef_all,mri2mni); drawnow
        % sliceshow(ef_mag_T,targetCoord(i,:),cm,[0 2],'Electric field (V/cm)',[figName '. Click anywhere to navigate.'],ef_tumor,mri2mni); drawnow
    end
end
