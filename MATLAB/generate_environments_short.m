function [ ] = generate_environments_short(sim_path, numberIDs, varargin)
% Generates in files based on inputs
%   numberIDs is a matrix of simulations to generate and saved as ./[i].in
%   sim_path must be a string since MATLAB is weird with character array
%   appending/concatenation
%   varargin are the shape identifiers for random placement

%   Example: generate_environments_short("./in_files/", [13 14 15 16], "cylinder")
%   Example: generate_environments_short("./in_files/", [17 18 19 20], "cylinder", "box")

% in_files = [41:1:60]
% generate_environments_short("./in_files/", [71 72 73 74 75 76 77 78 79 80], "box")
%

% Short environment is only 1m long

for i = 1:size(numberIDs, 2)
  
    
    generate_in_file(sim_path, numberIDs(i), varargin);
    generate_permittivity_map_function_short(numberIDs(i));
    
    pause(1);
end

end

function generate_in_file(sim_path, numberID, shape_list)

%% Setup - General setup of environment
fname = char(sprintf(sim_path + 'sim%d.in', numberID));
fileID = fopen(fname,'w');
fprintf(fileID, 'testingplz \n');

% Specify title of environment
title = 'Randomly Generated Environment';

% Specify domain [x y z]
% Note add extra 100mm on both sides in x direction, 50mm on y
% Domain size is 10000mm x 250mm 2D
domain = [1.2 0.300 0.002];
fprintf(fileID, '#domain: %.3f %.3f %.3f \n', domain);

% Specify discretization [x y z]
discretization =  [0.002 0.002 0.002];
fprintf(fileID, '#dx_dy_dz: %.3f %.3f %.3f \n', discretization);

% Specify time window [s]
time_window = 5e-9;
fprintf(fileID, '#time_window: %d \n', time_window);

%% Sources - Setup source waveforms

% Name of source excitation file
excitation_file = 'mala_source_modified.txt';
fprintf(fileID,'\n#excitation_file: %s \n', excitation_file);

% Source type (Hertzian Dipole) [polarization x y z ID ]
% x offset = 0.1 - 0.04/2 | 0.1 + 0.04/2
source = 'z 0.080 0.250 0 mala_source';
fprintf(fileID,'#hertzian_dipole: %s \n', source);

% Receiver location, and distance to move source and receiver
% x offset = 0.08 from left for source, receiver + 0.02 for 40mm antenna gap 
% y offset = 0.05 from top / 0.25 from bottom
rx = [0.120 0.250 0];
src_steps = [0.002 0 0];
rx_steps =  [0.002 0 0];

fprintf(fileID, '#rx: %.3f %.3f %.3f \n', rx);
fprintf(fileID, '#src_steps: %.3f %.3f %.3f \n', src_steps);
fprintf(fileID, '#rx_steps: %.3f %.3f %.3f \n', rx_steps);


%%  Materials - define materials. Must be randomized into a list 
% #material: relative_perm conductivity(S/m) relative_permeability magnetic_loss(Ohm/m) ID

% Keep everything the same (conductivity 0) but make the permittivities random. For
% simplicity, increase in whole numbers. Keep most of the concentration
% around 1 to 20 as they are of most concern

% changed conrete permittivity to 5 to speed up and let deeper features
% into the scan
concrete = [5 0.22 1 0];
air =  [1 0 1 0];
water = [80 0.5 1 0];

fprintf(fileID, '\n#material: %.3f %.3f %.3f %.3f concrete\n', concrete);
fprintf(fileID, '#material: %.3f %.3f %.3f %.3f air\n', air);
fprintf(fileID, '#material: %.3f %.3f %.3f %.3f water\n', water);

% run through for loop, m(x) for material, store in matrix
permittivity_list = (1:1:20);
for i=1:size(permittivity_list,2)
    fprintf(fileID, '\n#material: %.3f 0.000 1.000 0.000 m%s', permittivity_list(i), int2str(i));
end    

%% Concrete - Generate concrete box
% CONCRETE SPECIFICATIONS
% Domain = 10000mm (travel) x 250mm (depth)
% #box: 0 0 0 10.200 0.250 0.002 concrete
generate_concrete = [0 0 0 1.2 0.25 0.002];
fprintf(fileID,'\n\n#box: %.3f %.3f %.3f %.3f %.3f %.3f concrete\n\n', generate_concrete);

%%
numargcount=size(shape_list,2);

% seed the rng
seed = posixtime(datetime());
rng(seed);

for i=1:numargcount
    shape=shape_list{i};
    if strcmpi(shape, 'box')        
        %% Randomly place boxes in environment. Randomly assign boxes to materials in permittivity list
        
        box_x = randi([0 1100],1,200)/1000;
        box_y = randi([150 250],1,200)/1000;
        box_width = randi([4,40],1,200)/1000; 
        box_depth = randi([20,50],1,200)/1000;
        box_material = randi([1 20],1,200);

        for j=1:size(box_x,2)
            fprintf(fileID,'#box: %.3f %.3f %.3f %.3f %.3f %.3f m%s\n',...
                box_x(j), (box_y(j)-box_depth(j)), 0, (box_x(j)+box_width(j)), box_y(j),...
                0.002, int2str(box_material(j)));
        end         
               
        
    elseif strcmpi(shape, 'cylinder')
        %% Randomly place cylinders in environment. Randomly assign cylinders to materials in permittivity list
    
        cylinder_x = randi([0 1100],1,200)/1000;
        cylinder_y = randi([100 220],1,200)/1000;
        cylinder_r = randi([4,20],1,200)/2000; % Radius
        cylinder_material = randi([1 20],1,200);

        for j=1:size(cylinder_x,2)
            fprintf(fileID,'#cylinder: %.3f %.3f %.3f %.3f %.3f %.3f %.3f m%s\n',...
                cylinder_x(j), cylinder_y(j), 0, cylinder_x(j), cylinder_y(j), 0.002, cylinder_r(j), int2str(cylinder_material(j)));
        end 
    
                
    elseif strcmpi(shape, 'rebar')   
        %% Rebar - Randomly generate rebar according to spec

        % Starting x distance for randomization
        current_distance = 0;
        rebar_min_spacing = 100;
        rebar_max_spacing = 300;       

        while current_distance <= 10100
            rebar_x = randi([current_distance + rebar_min_spacing, current_distance + rebar_max_spacing]); % in m /1000;
            rebar_depth_mm = randi([250-150,250-30]);
            rebar_size_mm = randi([10,20])/2; % Radius 

            % Update current distance now to allow for rebar domain check
            current_distance = rebar_x;

            % Gross but is a break to stop adding rebar once last one is added and
            % is actually outside the domain 

            if current_distance > 10100
                break;
            end

            % Convert measurements to m. Notw rebar_x chosen so that current
            % distance stays in mm. Lazy - rewrite plz
            rebar_x = rebar_x/1000;
            rebar_depth = rebar_depth_mm/1000;
            rebar_size = rebar_size_mm/1000; 

            generate_rebar = [rebar_x, rebar_depth, 0, rebar_x, rebar_depth, 0.002, rebar_size];
            fprintf(fileID,'#cylinder: %.3f %.3f %.3f %.3f %.3f %.3f %.3f pec\n', generate_rebar);
        end 
                      
    end
end

end