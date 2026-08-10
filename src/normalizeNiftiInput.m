function niiPath = normalizeNiftiInput(niiPath)
% normalizeNiftiInput Accept .nii and .nii.gz input paths.
%
% The bundled NIFTI_20110921 reader expects an uncompressed .nii file.
% When a .nii.gz path is supplied, create an adjacent .nii working copy
% (if necessary) and return that path. A path without an extension is also
% accepted, with .nii.gz preferred over .nii.

if isstring(niiPath)
    niiPath = char(niiPath);
end

if ~ischar(niiPath) || isempty(niiPath)
    error('A valid NIfTI file path must be provided.');
end

% Resolve extension-less modality names such as <subject>_T1GD.
if exist(niiPath,'file') ~= 2
    if exist([niiPath '.nii.gz'],'file') == 2
        niiPath = [niiPath '.nii.gz'];
    elseif exist([niiPath '.nii'],'file') == 2
        niiPath = [niiPath '.nii'];
    else
        error(['The NIfTI file ' niiPath ' does not exist. Expected either ' ...
            niiPath '.nii.gz or ' niiPath '.nii.']);
    end
end

[~,name,ext] = fileparts(niiPath);
isGzippedNifti = strcmpi(ext,'.gz') && length(name) >= 4 && ...
    strcmpi(name(end-3:end),'.nii');

if isGzippedNifti
    niiPath = niiPath(1:end-3); % remove only the .gz suffix
    if exist(niiPath,'file') ~= 2
        disp(['Decompressing ' [niiPath '.gz'] ' to ' niiPath ' ...']);
        gunzip([niiPath '.gz']);
    end
end

