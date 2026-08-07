function processAndSegment(t1,t2,t1gd,fl,mask)
[filepath, basename] = fileparts(t1);
% Get base filename (patient ID)
underscoreIndex = strfind(basename, '_');
baseFileName = basename(1:underscoreIndex-1);
% Load four modalities and remove scalp and skull
data = {t1, t2, t1gd, fl};
output_suffix = {'_T1.nii', '_T2.nii', '_T1GD.nii', '_FLAIR.nii'};
masks = load_untouch_nii(mask);
label_img = masks.img;
label = (label_img==0 | label_img==4 | label_img==5);
for i = 1:numel(data)
    img_data = load_untouch_nii(data{i});
    img_data.img(label) = 0;
    parentFolder = './Unet/data/';  % Parent folder path
    % Create subfolder
    folderPath = fullfile(parentFolder, baseFileName);
    if ~isfolder(folderPath)
        mkdir(folderPath);
    end
    % Save to UNet folder for UNet segmentation
    save_untouch_nii(img_data, fullfile(folderPath,[baseFileName output_suffix{i}]));
end
%% UNet segmentation
% Open data text file to write data to process (clear file)
fileID = fopen('./Unet/data/data.txt', 'w');
% Write content to file
fprintf(fileID, '%s', baseFileName);
% Close file
fclose(fileID);
% Open inference text file to write files for inference (clear file)
fileID = fopen('./Unet/inference.txt', 'w');
% Write content to file
fprintf(fileID, '%s', [baseFileName '_mri_norm2.h5']);
% Close file
fclose(fileID);
% Call external Python program
pyrunfile("./Unet/segment.py")

%% Move segmentation results to original data directory and rename
% Build full path and name of target file
newFileName = [baseFileName '_T1_segm.nii']; %New filename
sourceFolder = './Unet/prediction/';  % Source folder path
targetFilePath = fullfile(filepath, newFileName);
% Copy and rename file
copyfile([sourceFolder filesep '00_pred.nii'], targetFilePath);

