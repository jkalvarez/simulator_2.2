function [ ] = generate_environments(sim_path, numberIDs, varargin)
% Generates in files based on inputs
%   numberIDs is a matrix of simulations to generate and saved as ./[i].in
%   sim_path must be a string since MATLAB is weird with character array
%   appending/concatenation
%   varargin are the shape identifiers for random placement

%   Example: generate_environments("./in_files/", [13 14 15 16], "cylinder")
%   Example: generate_environments("./in_files/", [17 18 19 20], "cylinder", "rectangle")

for i = 1:size(numberIDs, 2)
  
    
    generate_in_file(sim_path, numberIDs(i), varargin);
    generate_permittivity_map_function(numberIDs(i));
    
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
domain = [10.2 0.300 0.002];
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
generate_concrete = [0 0 0 10.2 0.25 0.002];
fprintf(fileID,'\n\n#box: %.3f %.3f %.3f %.3f %.3f %.3f concrete\n\n', generate_concrete);

%%
numargcount=size(shape_list,2);

% seed the rng
seed = posixtime(datetime());
rng(seed);

for i=1:numargcount
    shape=shape_list{i};
    if strcmpi(shape, 'rectangle')        
        %% Void (Air) - Randomly generate air voids according to spec
        % AIR VOID SPECIFICATIONS 

        % Starting x distance for randomization
        current_distance = 0;
        air_min_spacing = 100;
        air_max_spacing = 500;
      
        while current_distance <= 10100
            air_x = randi([current_distance + air_min_spacing, current_distance + air_max_spacing]); % in m /1000;
            air_depth_mm = randi([250-150,250-20]); % in m /1000;
            air_depth_mm_2 = randi([air_depth_mm, 250]);
            air_width_mm = randi([2,20]); % width

            % Update current distance now to allow for rebar domain check
            current_distance = air_x;

            % Gross but is a break to stop adding air once last one is added and
            % is actually outside the domain 

            if current_distance > 10100
                break;
            end

            % Convert measurements to m. Now air_x chosen so that current
            % distance stays in mm. Lazy - rewrite plz
            air_x = air_x/1000;
            air_depth = air_depth_mm/1000;
            air_depth_2 = (air_depth_mm_2)/1000;
            air_width = air_width_mm/1000; 

            generate_air = [air_x, air_depth, 0, (air_x + air_width), air_depth_2, 0.002];
            fprintf(fileID,'#box: %.3f %.3f %.3f %.3f %.3f %.3f air\n', generate_air);
        end       
        
    elseif strcmpi(shape, 'cylinder')
        %% Randomly place cylinders in environment. Randomly assign cylinders to materials in permittivity list
    
        cylinder_x = randi([0 10100],1,200)/1000;
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