function [xf,cvx_status] = optimize_electrodes(A,d,Cf,~,tar_nodes,targetCoord,Fnode,verbose)

lambda = 0.01; % Increase field intensity: Lambda down; increase focality: Lambda up 
lambda2 = 0.1 ;
numElec = 18; % numElec is the required number of electrodes
ub = 100; % Single electrode current limit
utotal = 1800; % Total current limit

[~, ~, dist, ~, ~] = getCoordinateMNI(targetCoord,Fnode); % Return node coordinate coord and index of nodes closest to target
n = size(Cf,1);
Nlocs = size(A,1)/3; % Number of mesh nodes
numOfROI = length(tar_nodes); % Number of targets
d_s = find(1/4 * max(dist) < dist < 1/3 * max(dist)); % ��е�ľ������1/3*��Զ����������1500������dist_s�е�λ��
index_s = d_s(randperm(numel(d_s),1500));
% save index_s
% index_s = find(dist > 1/3 * dist_s(end), 1500 );

if verbose
    cvx_begin
else
    cvx_begin quiet
end
        variable x(n);
        E = A * x; % �������괦�ĳ�ǿ
        expression  E_mag_s(length(index_s)); % Define field intensity at coordinate points from previous line (i.e., field to suppress) 
        for i = 1:length(index_s)
             E_mag_s(i) = norm([E(index_s(i)), E(index_s(i)+Nlocs), E(index_s(i)+2*Nlocs)]);
        end        
        maximize( sum(Cf'*x) - lambda * sum(E_mag_s) );        
           subject to
              norm([x;-sum(x)],1) <= utotal;
              norm([x;-sum(x)],inf) <= ub; 
              % abs(sum(x)) < 1e-5;
cvx_end
    
[~,xn] = sort(abs(x),'descend');

xn = xn(1:numElec); 

cvx_clear
if verbose
    cvx_begin
else
    cvx_begin quiet
end
        variable y(size(xn,1));
        EE = A(:,xn) * y; % �������괦�ĳ�ǿ
        expression  E_mag_ss(length(index_s)); % ������һ�еõ�������㴦�ĳ�ǿ
        for i = 1:length(index_s)
             E_mag_ss(i) = norm([EE(index_s(i)), EE(index_s(i)+Nlocs), EE(index_s(i)+2*Nlocs)]);
        end
        maximize( sum(Cf(xn,:)'*y) - lambda2 * lambda * sum(E_mag_ss) );        
           subject to
              norm([y;-sum(y)],1) <= utotal;
              norm([y;-sum(y)],inf) <= ub;
              % abs(sum(y)) < 1e-5;
    cvx_end
        
xf = zeros(n,1);
xf(xn,1) = y; 

end

            

    
    

    