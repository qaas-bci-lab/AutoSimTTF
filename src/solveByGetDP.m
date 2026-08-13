function solveByGetDP(P,current,sigma,epsilon,frequency,indUse,uniTag,LFtag)
% solveByGetDP(P,current,sigma,indUse,uniTag,LFtag)
% 
% Solve in getDP, a free FEM solver available at 
% http://getdp.info/

[dirname,baseFilename] = fileparts(P);
if isempty(dirname), dirname = pwd; end

load([dirname filesep baseFilename '_' uniTag '_usedElecArea.mat'],'area_elecNeeded'); 

numOfTissue = 9; % hard coded across ROAST.
numOfElec = length(area_elecNeeded);
currentTol = 1e-12;

% A signed current pattern is a Neumann boundary condition.  In that
% case the prescribed currents must balance; otherwise no steady-state
% solution exists.  The old code silently ignored negative currents.
activeCurrent = current(indUse);
if any(activeCurrent < -currentTol) && abs(sum(activeCurrent)) > 1e-6
    error('Signed electrode currents must sum to zero. Current sum: %g mA.', sum(activeCurrent));
end
hasZeroReference = any(abs(current(indUse)) <= currentTol);

% The all-current-controlled case has a free additive voltage constant.
% prepareForGetDP adds one point region for this gauge constraint.
gaugeRegion = numOfTissue + 3*numOfElec + 1;

fid = fopen([dirname filesep baseFilename '_' uniTag '.pro'],'w');

fprintf(fid,'%s\n\n','Group {');
fprintf(fid,'%s\n','white = Region[1];');
fprintf(fid,'%s\n','gray = Region[2];');
fprintf(fid,'%s\n','csf = Region[3];');
fprintf(fid,'%s\n','bone = Region[4];');
fprintf(fid,'%s\n','skin = Region[5];');
fprintf(fid,'%s\n','air = Region[6];');
fprintf(fid,'%s\n','NT = Region[7];');
fprintf(fid,'%s\n','ED = Region[8];');
fprintf(fid,'%s\n','ET = Region[9];');
for i=1:length(indUse)
    fprintf(fid,'%s\n',['gel' num2str(i) ' = Region[' num2str(numOfTissue+indUse(i)) '];']);
end
for i=1:length(indUse)
    fprintf(fid,'%s\n',['elec' num2str(i) ' = Region[' num2str(numOfTissue+numOfElec+indUse(i)) '];']);
end

gelStr = [];
elecStr = [];
usedElecStr = [];
for i=1:length(indUse)
    usedElecStr = [usedElecStr 'usedElec' num2str(i) ', '];
    fprintf(fid,'%s\n',['usedElec' num2str(i) ' = Region[' num2str(numOfTissue+2*numOfElec+indUse(i)) '];']);
    gelStr = [gelStr 'gel' num2str(i) ', '];
    elecStr = [elecStr 'elec' num2str(i) ', '];
end
fprintf(fid,'%s\n',['gauge = Region[' num2str(gaugeRegion) '];']);

fprintf(fid,'%s\n',['DomainC = Region[{white, gray, csf, bone, skin, air, NT, ED, ET,' gelStr elecStr(1:end-2) '}];']);
fprintf(fid,'%s\n\n',['AllDomain = Region[{white, gray, csf, bone, skin, air, NT, ED, ET,' gelStr elecStr usedElecStr(1:end-2) '}];']);
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n\n','Function {');
fprintf(fid,'%s\n','eps0 = 8.854187818e-12 ;');
fprintf(fid,'%s\n',['epsilon[white] = ' num2str(epsilon.white) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[gray] = ' num2str(epsilon.gray) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[csf] = ' num2str(epsilon.csf) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[bone] = ' num2str(epsilon.bone) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[skin] = ' num2str(epsilon.skin) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[air] = ' num2str(epsilon.air) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[NT] = ' num2str(epsilon.NT) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[ED] = ' num2str(epsilon.ED) '* eps0;']);
fprintf(fid,'%s\n',['epsilon[ET] = ' num2str(epsilon.ET) '* eps0;']);

fprintf(fid,'%s\n',['sigma[white] = ' num2str(sigma.white) ';']);
fprintf(fid,'%s\n',['sigma[gray] = ' num2str(sigma.gray) ';']);
fprintf(fid,'%s\n',['sigma[csf] = ' num2str(sigma.csf) ';']);
fprintf(fid,'%s\n',['sigma[bone] = ' num2str(sigma.bone) ';']);
fprintf(fid,'%s\n',['sigma[skin] = ' num2str(sigma.skin) ';']);
fprintf(fid,'%s\n',['sigma[air] = ' num2str(sigma.air) ';']);
fprintf(fid,'%s\n',['sigma[NT] = ' num2str(sigma.NT) ';']);
fprintf(fid,'%s\n',['sigma[ED] = ' num2str(sigma.ED) ';']);
fprintf(fid,'%s\n',['sigma[ET] = ' num2str(sigma.ET) ';']);

for i=1:length(indUse)
    fprintf(fid,'%s\n',['epsilon[gel' num2str(i) '] = ' num2str(epsilon.gel(indUse(i))) '* eps0;']);
    fprintf(fid,'%s\n',['sigma[gel' num2str(i) '] = ' num2str(sigma.gel(indUse(i))) ';']);
end
for i=1:length(indUse)
    fprintf(fid,'%s\n',['epsilon[elec' num2str(i) '] = ' num2str(epsilon.electrode(indUse(i))) '* eps0;']); 
    fprintf(fid,'%s\n',['sigma[elec' num2str(i) '] = ' num2str(sigma.electrode(indUse(i))) ';']);
end

for i=1:length(indUse)
    if abs(current(indUse(i))) > currentTol
        fprintf(fid,'%s\n',['du_dn' num2str(i) '[] = ' num2str(1000*current(indUse(i))/area_elecNeeded(indUse(i))) ';']);
    end
    
end

fprintf(fid,'%s\n',['Freq = ' num2str(frequency) ';']);
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n\n','Constraint {');
fprintf(fid,'%s\n','{ Name Dirichlet_Ele; Type Assign;');
fprintf(fid,'%s\n','  Case {');
for i=1:length(indUse)
    if abs(current(indUse(i))) <= currentTol
        fprintf(fid,'%s\n',['    { Region usedElec' num2str(i) '; Value 0; }']);
    end    
end
if ~hasZeroReference
    % Fix only the otherwise-undetermined additive voltage constant. This
    % is a point constraint, not an extra electrode or current path.
    fprintf(fid,'%s\n','    { Region gauge; Value 0; }');
end
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n\n','}');
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n','Jacobian {');
fprintf(fid,'%s\n','  { Name Vol ;');
fprintf(fid,'%s\n','    Case {');
fprintf(fid,'%s\n','      { Region All ; Jacobian Vol ; }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n','  { Name Sur ;');
fprintf(fid,'%s\n','    Case {');
fprintf(fid,'%s\n','      { Region All ; Jacobian Sur ; }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n','Integration {');
fprintf(fid,'%s\n','  { Name GradGrad ;');
fprintf(fid,'%s\n','    Case { {Type Gauss ;');
fprintf(fid,'%s\n','            Case { { GeoElement Triangle     ; NumberOfPoints  3  ; }');
fprintf(fid,'%s\n','                   { GeoElement Triangle2    ; NumberOfPoints  7  ; }');
fprintf(fid,'%s\n','                   { GeoElement Quadrangle   ; NumberOfPoints  4  ; }');
fprintf(fid,'%s\n','                   { GeoElement Tetrahedron  ; NumberOfPoints  4  ; }');
fprintf(fid,'%s\n','                   { GeoElement Tetrahedron2 ; NumberOfPoints  16 ; }');
fprintf(fid,'%s\n','                   { GeoElement Hexahedron   ; NumberOfPoints  6  ; }');
fprintf(fid,'%s\n','                   { GeoElement Prism        ; NumberOfPoints  9  ; } }');
fprintf(fid,'%s\n','           }');
fprintf(fid,'%s\n','         }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n','FunctionSpace {');
fprintf(fid,'%s\n','  { Name Hgrad_v_Ele; Type Form0;');
fprintf(fid,'%s\n','    BasisFunction {');
fprintf(fid,'%s\n','      // v = v  s   ,  for all nodes');
fprintf(fid,'%s\n','      //      n  n');
fprintf(fid,'%s\n','      { Name sn; NameOfCoef vn; Function BF_Node;');
fprintf(fid,'%s\n','        Support AllDomain; Entity NodesOf[ All ]; }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','    Constraint {');
fprintf(fid,'%s\n','      { NameOfCoef vn; EntityType NodesOf; ');
fprintf(fid,'%s\n','        NameOfConstraint Dirichlet_Ele; }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n','Formulation {');
fprintf(fid,'%s\n','  { Name Electrostatics_v; Type FemEquation;');
fprintf(fid,'%s\n','    Quantity {');
fprintf(fid,'%s\n','      { Name v; Type Local; NameOfSpace Hgrad_v_Ele; }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','    Equation {');
fprintf(fid,'%s\n','      Galerkin { [ sigma[] * Dof{d v} , {d v} ]; In DomainC; ');
fprintf(fid,'%s\n','                 Jacobian Vol; Integration GradGrad; }');
fprintf(fid,'%s\n','      Galerkin { DtDof[ epsilon[] * Dof{d v} , {d v} ]; In DomainC; ');
fprintf(fid,'%s\n\n','                 Jacobian Vol; Integration GradGrad; }');

for i=1:length(indUse)
    if abs(current(indUse(i))) > currentTol
        fprintf(fid,'%s\n',['      Galerkin{ [ -du_dn' num2str(i) '[], {v} ]; In usedElec' num2str(i) ';']);
        fprintf(fid,'%s\n','                 Jacobian Sur; Integration GradGrad;}');
    end   
end

fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n','Resolution {');
fprintf(fid,'%s\n','  { Name EleSta_v;');
fprintf(fid,'%s\n','    System {');
fprintf(fid,'%s\n','      { Name Sys_Ele; NameOfFormulation Electrostatics_v; Frequency Freq; }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','    Operation { ');
fprintf(fid,'%s\n','      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n\n','}');

fprintf(fid,'%s\n','PostProcessing {');
fprintf(fid,'%s\n','  { Name EleSta_v; NameOfFormulation Electrostatics_v;');
fprintf(fid,'%s\n','    Quantity {');
fprintf(fid,'%s\n','      { Name v; ');
fprintf(fid,'%s\n','        Value { ');
fprintf(fid,'%s\n','          Local { [ {v} ]; In AllDomain; Jacobian Vol; } ');
fprintf(fid,'%s\n','        }');
fprintf(fid,'%s\n','      }');
fprintf(fid,'%s\n','      { Name e; ');
fprintf(fid,'%s\n','        Value { ');
fprintf(fid,'%s\n','          Local { [ -{d v} ]; In AllDomain; Jacobian Vol; }');
fprintf(fid,'%s\n','        }');
fprintf(fid,'%s\n','      }');
fprintf(fid,'%s\n','    }');
fprintf(fid,'%s\n','  }');
fprintf(fid,'%s\n','}');

fprintf(fid,'%s\n\n','PostOperation {');
fprintf(fid,'%s\n','{ Name Map; NameOfPostProcessing EleSta_v;');
fprintf(fid,'%s\n','   Operation {');
if isempty(LFtag)
    fprintf(fid,'%s\n',['     Print [ v, OnElementsOf DomainC, File "' baseFilename '_' uniTag '_v.pos", Format NodeTable ];']);
end
fprintf(fid,'%s\n',['     Print [ e, OnElementsOf DomainC, File "' baseFilename '_' uniTag '_e' LFtag '.pos", Format NodeTable ];']);
fprintf(fid,'%s\n','   }');
fprintf(fid,'%s\n\n','}');
fprintf(fid,'%s\n','}');

fclose(fid);

str = computer('arch');
switch str
    case 'win64'
        solverPath = 'lib\getdp-3.5.0\bin\getdp.exe';
    case 'glnxa64'
        solverPath = 'lib/getdp-3.5.0/bin/getdp';
    case 'maci64'
        solverPath = 'lib/getdp-3.5.0/bin/getdpMac';
    otherwise
        error('Unsupported operating system!');
end

% cmd = [fileparts(which(mfilename)) filesep solverPath ' '...
%     fileparts(which(mfilename)) filesep dirname filesep baseFilename '_' uniTag '.pro -solve EleSta_v -msh '...
%     fileparts(which(mfilename)) filesep dirname filesep baseFilename '_' uniTag '_ready.msh -pos Map'];
cmd = [solverPath ' "' dirname filesep baseFilename '_' uniTag '.pro" -solve EleSta_v -msh "' dirname filesep baseFilename '_' uniTag '_ready.msh" -pos Map'];
try
    status = system(cmd);
catch
end

if status
    error('getDP solver cannot work properly on your system. Please check any error message you got.');
else % after solving, delete intermediate files
    delete([dirname filesep baseFilename '_' uniTag '.pre']);
    delete([dirname filesep baseFilename '_' uniTag '.res']);
end
