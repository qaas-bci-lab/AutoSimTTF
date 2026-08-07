% Return node coordinate coord and index of nodes closest to target
function [coord, index, dist, dist_s, I] = getCoordinateMNI(target,Fnode)
    % filename_node = 'GBM/GBM005/UPENN-GBM-00005_T1_20240619T105320.mat'; 
    load(Fnode,'node');
    I_WM = find(node(:,4)==1.5);
    I_GM = find(node(:,4)==2.5);
    I = sort([I_WM; I_GM]);
    N = length(I);
    coord = node(I,1:3);
    coord_target = coord - target;
    dist = zeros(N,1);
    for i=1:N
        dist(i) = norm(coord_target(i,:));
    end
    [dist_s,index] = sortrows(dist);
end