function focality = compute_focality(p,E,locs)

Nlocs = p.Nlocs; % Nlocs is the number of nodes

targetCoord = p.targetCoord;
numOfTargets = p.numOfTargets;

focality = zeros(1,numOfTargets);
node_distances = zeros(Nlocs,numOfTargets);
sorted_nodes = zeros(Nlocs,numOfTargets); 
distances_to_target = zeros(Nlocs,numOfTargets);
for n = 1:numOfTargets
    tmp = locs - repmat(targetCoord(n,:),size(locs,1),1);
    distances_to_target(:,n) = sqrt(sum(tmp.*tmp,2));
    [node_distances(:,n),sorted_nodes(:,n)] = sort(distances_to_target(:,n));
    
    
    for i = 1:size(sorted_nodes(:,n),1)
        if E(i) >= 1
            E(i) = 0;
        end
    end
    E_mag = zeros(size(sorted_nodes(:,n)));
    for i = 1:length(sorted_nodes(:,n))
        E_mag(i) = norm([E(i),E(i+Nlocs),E(i+2*Nlocs)]);   
    end
    E_total = norm(E_mag,1);
    E_around = 0;
    loop = 0;
    for i=1:size(sorted_nodes(:,n),1)
        E_around = E_around + abs(E_mag(sorted_nodes(i,n)));
        if E_around >= 0.5 * E_total && loop == 0
           focality(1,n) = node_distances(i,n);
           loop = 1;
%             break;
        end
%         if (mod(i,100) == 0)
%             E_around100((i/100),1) = E_around;
%         end
    end
%     save('focality\O1\fengtaoO1.mat','E_around100');
%     save('focality\node_distances\nd_O1\nd_fengtaoO1.mat','node_distances');
%     focality(1,n) = node_distances(i,n);
%     figure;
%     j = 1:1:size(E_around100,1);
%     plot(E_around100/E_around,node_distances(j*100,n),'-*','MarkerIndices',1:100:length(E_around100));
%     set(gca,'xtick',0:0.1:1);
%     set(gca,'xticklabel',{'0','r0.1','r0.2','r0.3','r0.4','r0.5','r0.6','r0.7','r0.8','r0.9','r1.0'},'Fontsize',10);
%     title('Focality Curve','FontSize',25);
%     ylabel('Distance from target','FontSize',20);
%     xlabel('Electric field energy','FontSize',20);
%     axis on; grid on;
%     axis([-inf,inf,0,max(node_distances(j*100,n))]);
end
    focality = mean(focality);
end
