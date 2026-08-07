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

if ndims(varargin{1})==3
    isSim = 1;
    vol_all = varargin{1}; ef_mag = varargin{2}; ef_all = varargin{3};
else
    isSim = 0;
    C = varargin{1}; ef_mag = varargin{2}; ef_all = varargin{3}; targetCoord = varargin{4}; 
end

[dirname,baseFilename] = fileparts(P1);
if isempty(dirname), dirname = pwd; end
[~,baseFilenameRasRSPD] = fileparts(P2);
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
indNode_brainFace = face(find(face(:,4) <= 2 | face(:,4) == 7 | face(:,4) == 8 | face(:,4) == 9 ),1:3);
indNode_brainElm = elem(find(elem(:,5) <= 2 | elem(:,5) == 7 | elem(:,5) == 8 | elem(:,5) == 9),1:4);
indNode_tumorFace = face(find(face(:,4) == 7 | face(:,4) == 9),1:3);
indNode_tumorElm = elem(find(elem(:,5) == 7 | elem(:,5) == 9),1:4);
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
    
    fid = fopen([dirname filesep baseFilename '_' uniTag '_v.pos']);
    fgetl(fid);
    C = textscan(fid,'%d %f %f');
    fclose(fid);
    C{2} = sqrt(C{2}.^2+C{3}.^2);
    C{2} = C{2} - min(C{2}); % re-reference the voltage
    
    % dataShow = [node(C{1},1:3) C{2}];
    color = nan(size(node,1),1);
    color(C{1}) = C{2};
    dataShow = [node(:,1:3) color];
    
    figName = ['Voltage in Simulation: ' uniTag];
    figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
    set(gcf,'color','w');
    colormap(jet);
    plotmesh(dataShow,indNode_grayFace,indNode_grayElm,'LineStyle','none');
    dataShowRange = [min(dataShow(unique(indNode_grayElm(:)),4)) max(dataShow(unique(indNode_grayElm(:)),4))];
    dataShowForElec = interp1(inCurrentRange,dataShowRange,inCurrent);
    for i=1:length(inCurrent)
        %     indNodeTemp = indNode_elecElm(find(label_elec==i),:);
        %     dataShow(unique(indNodeTemp(:)),4) = dataShowForElec(i);
        dataShow(unique(elem(find(elem(:,5) == numOfTissue+numOfGel+i),1:4)),4) = dataShowForElec(i);
    end % to show injected current intensities properly
    hold on;
    plotmesh(dataShow,indNode_elecFace,indNode_elecElm,'LineStyle','none');
    axis off; rotate3d on;
    % set(hp1,'SpecularColorReflectance',0,'SpecularExponent',50);
    caxis(dataShowRange);
    lightangle(-90,45)
    lightangle(90,45)
    lightangle(-90,-45)
    hc1 = colorbar; set(hc1,'FontSize',18,'YAxisLocation','right');
    title(hc1,'Voltage (mV)','FontSize',18);
    a1 = gca;
    a2 = axes('Color','none','Position',get(a1,'Position'),'XLim',get(a1,'XLim'),'YLim',get(a1,'YLim'),'ZLim',get(a1,'ZLim'));
    axis off;
    hc2 = colorbar; set(hc2,'FontSize',18,'YAxisLocation','right','Location','westoutside');
    title(hc2,'Injected current (mA)','FontSize',18);
    caxis(inCurrentRange);
    axes(a1);
    drawnow
    
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
    
    figName = ['Electric field in Simulation: ' uniTag];
    figure('Name',[figName '. Move your mouse to rotate.'],'NumberTitle','off');
    set(gcf,'color','w');
    colormap(jet);
    plotmesh(dataShow,indNode_grayFace,indNode_grayElm,'LineStyle','none');
%     dataShowVal = dataShow(unique(indNode_grayElm(:)),4);
    dataShowRange = [min(dataShow(unique(indNode_grayElm(:)),4)) prctile(dataShow(unique(indNode_grayElm(:)),4),95)];

    % plotmesh(dataShow,indNode_brainFace,indNode_brainElm,'LineStyle','none');
    % dataShowRange = [min(dataShow(unique(indNode_brainElm(:)),4)) prctile(dataShow(unique(indNode_brainElm(:)),4),95)];
    
    dataShowForElec = interp1(inCurrentRange,dataShowRange,inCurrent);
    for i=1:length(inCurrent)
        %     indNodeTemp = indNode_elecElm(find(label_elec==i),:);
        %     dataShow(unique(indNodeTemp(:)),4) = dataShowForElec(i);
        dataShow(unique(elem(find(elem(:,5) == numOfTissue+numOfGel+i),1:4)),4) = dataShowForElec(i);
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

    plotmesh(dataShow,indNode_tumorFace,indNode_tumorElm,'LineStyle','none');
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
WM = (allMask==1);
GM = (allMask==2);
CSF = (allMask==3);
Air = (allMask==6);
NCR = (allMask==7);
ED = (allMask==8);
ET = (allMask==9);
tumor = (allMask==7|allMask==8|allMask==9);
nan_mask_brain = nan(size(brain));
nan_mask_brain(brain) = 1;
nan_mask_tumor = nan(size(tumor));
nan_mask_tumor(tumor) = 1;

nan_mask_brain1 = nan(size(brain));
nan_mask_brain1(WM) = 0.08;
nan_mask_brain1(GM) = 0.27;
nan_mask_brain1(CSF) = 1.7;
nan_mask_brain1(Air) = 2.5e-14;
nan_mask_brain1(NCR) = 1;
nan_mask_brain1(ED) = 1.7;
nan_mask_brain1(ET) = 0.24;

cm = colormap(jet(2^11)); cm = [1 1 1;cm];

if isSim
    figName = ['Voltage in Simulation: ' uniTag];
    sliceshow(vol_all.*nan_mask_brain,[],cm,[],'Voltage (mV)',[figName '. Click anywhere to navigate.'],[],mri2mni); drawnow
end

for i=1:size(ef_all,4), ef_all(:,:,:,i) = ef_all(:,:,:,i).*nan_mask_brain; end
ef_mag_E = ef_mag.*nan_mask_brain;
ef_mag_E = ef_mag_E./100;
% ef_tumor = zeros(size(ef_all));
% for i=1:size(ef_all,4), ef_tumor(:,:,:,i) = ef_all(:,:,:,i).*nan_mask_tumor; end
% ef_mag_T = ef_mag.*nan_mask_tumor;
% ef_mag_T = ef_mag_T./100;
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