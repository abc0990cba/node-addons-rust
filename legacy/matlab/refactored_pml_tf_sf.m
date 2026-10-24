%% FDTD 2D with UPML and TF/SF interface example. 

clear all; close all; clc; format short;

% Matlab array index start
mmm = 1;

% Physical constants
% Absolute vacuum permittivity
epsilon_0 = 8.854*1e-12;

% Absulute vacuum permeability
mu_0 = 4*pi*1e-7;

% Light speed in vacuum
light_speed = 1/sqrt(epsilon_0*mu_0);

%% Main parameters
% Calculation area length per x and y axes in meters
% area_width = 2.5;
% area_height = 2.5;
area_width = 0.00025;
area_height = 0.00025;

% Uniform grid points for x and y axes
% nx = 500;
% ny = 500;
% nx = 30;
% ny = 30;
nx = 220;
ny = 220;

% Perfect match layer (upml_width) thickness in uniform grid cells
upml_width = 10;
% upml_width = 3;

% End time [s]
t_end = 15e-9;

% Excitation source amplitude and frequency [Hz]
E0 = 1.0;     
% frequency = 2.0e+9;   % 2 GHz - lambda = 15sm
% frequency = 2.0e+12;   % 2 THz - lambda = 150mkm
frequency = 20.0e+12;   % 20 THz - lambda = 15mkm


% Width of alinea between total field area and calculation area border
% (scattered field interface width) [m]
len_tf_dx = 0.5;
len_tf_dy = 0.5;

% Grid calculation
dx = area_width / nx;
dy = area_width / ny;

% C++ ignore
X = zeros(nx);
Y = zeros(ny);

% C++ ignore
for i = 1:nx
    X(i) = (i-1)*dx - area_width/2;
end

% C++ ignore
for i = 1:ny
    Y(i) = (i-1)*dy - area_height/2;
end


% Time step from CFL condition
CFL_FACTOR = 0.99;
dt = ( 1/light_speed/sqrt( 1/(dx^2) + 1/(dy^2) ) )*CFL_FACTOR;

number_of_iterations = round(t_end/dt);
% number_of_iterations = 10;

%% Geometry matrix 
Index = zeros(nx,ny);
IndexX = zeros(nx,ny);
IndexY = zeros(nx,ny);



%% Calculate size of total field area in TF/SF formalism
% nx_a = round(len_tf_dx/dx);
% nx_b = round((area_width-len_tf_dx)/dx);
% ny_a = round(len_tf_dy/dy);
% ny_b = round((area_height-len_tf_dy)/dy);

% nx_a = 6;
% nx_b = 24;
% ny_a = 6;
% ny_b = 24;

nx_a = 60;
nx_b = 160;
ny_a = 60;
ny_b = 160;

%% Pre-allocate 1D fields for TF/SF interface 
% TM components
Ez_1D = zeros(nx_b+1,1);
Fz_1D = zeros(nx_b+1,1);
Hy_1D = zeros(nx_b,1);

k_Fz_a = zeros(nx_b+1,1);
k_Fz_b = zeros(nx_b+1,1);
k_Hy_a = zeros(nx_b,1);

k_Hy_b = zeros(nx_b,1);

% TE components
Hz_1D = zeros(nx_b+1,1);
Ey_1D = zeros(nx_b,1);
k_Hz_a = zeros(nx_b+1,1);
k_Hz_b = zeros(nx_b+1,1); 
k_Ey_a = zeros(nx_b,1);
k_Ey_b = zeros(nx_b,1);


ka_max = 1;
m = 4;
R_err = 1e-16;


%  auxiliary
k_Fz_1_new = zeros(nx-2,ny-2);
k_Fz_2_new = zeros(nx-2,ny-2);
k_Ez_1_new = zeros(nx-2,ny-2);
k_Ez_2_new = zeros(nx-2,ny-2);
k_Gx_1_new = zeros(nx,ny-1);
k_Gx_2_new = zeros(nx,ny-1);
k_Hx_1_new = zeros(nx,ny-1);
k_Hx_2_new = zeros(nx,ny-1);
k_Ex_1_new = zeros(nx,ny-1);
k_Ex_2_new = zeros(nx,ny-1);
k_Gy_1_new = zeros(nx-1,ny);
k_Gy_2_new = zeros(nx-1,ny);
k_Hy_1_new = zeros(nx-1,ny);
k_Hy_2_new = zeros(nx-1,ny);
k_Ey_1_new = zeros(nx-1,ny);
k_Ey_2_new = zeros(nx-1,ny);
k_Hz_1_new = zeros(nx-2,ny-2);
k_Hz_2_new = zeros(nx-2,ny-2);

M0 = zeros(nx-2,ny-2);
M1 = zeros(nx-2,ny-2);
M2 = zeros(nx,ny-1);
M3 = zeros(nx-1,ny);

Fz_1D_r = zeros(nx_b-1, 1);
Fz_r1 = zeros(nx-2, ny-2);
Fz_r = zeros(nx-2, ny-2);
Tz_r = zeros(nx-2, ny-2);

Gy_r = zeros(nx-1, ny);
Gx_r = zeros(nx, ny-1);
Gx_r1 = zeros(nx, ny-1);
Gy_r1 = zeros(nx-1, ny);

K_a_new = zeros(nx-2, ny-2);
K_b_new = zeros(nx-2, ny-2);

%% Allocate 2D arrays
% TM physical and auxiliary fields
Fz = zeros(nx,ny);
Tz = zeros(nx,ny);
Gx = zeros(nx,ny-1); Gy = zeros(nx-1,ny);
Ez = zeros(nx,ny); Hx = zeros(nx,ny-1); Hy = zeros(nx-1,ny);
% TE physical and auxiliary fields
Wz = zeros(nx,ny); Mx = zeros(nx,ny-1); My = zeros(nx-1,ny);
Hz = zeros(nx,ny); Ex = zeros(nx,ny-1); Ey = zeros(nx-1,ny);

%% Allocate UPML FDTD 1D coefficient arrays
% TM coefficients
k_Fz_1 = zeros(ny,1);   k_Fz_2 = zeros(ny,1);   
k_Ez_1 = zeros(nx,1);   k_Ez_2 = zeros(nx,1);   
k_Gx_1 = zeros(ny-1,1); k_Gx_2 = zeros(ny-1,1);
k_Hx_1 = zeros(nx,1);   k_Hx_2 = zeros(nx,1);   
k_Gy_1 = zeros(nx-1,1); k_Gy_2 = zeros(nx-1,1); 
k_Hy_1 = zeros(ny,1);   k_Hy_2 = zeros(ny,1);
% TM coefficients
k_Hz_1 = zeros(nx,1);   k_Hz_2 = zeros(nx,1);   
k_Ex_1 = zeros(nx,1);   k_Ex_2 = zeros(nx,1);   
k_Ey_1 = zeros(ny,1);   k_Ey_2 = zeros(ny,1);






% ////////////////////////////// INIT ////////////////////////////////////
% ////////////////////////////// INIT ////////////////////////////////////
% ////////////////////////////// INIT ////////////////////////////////////
% ////////////////////////////// INIT ////////////////////////////////////


%% Free space FDTD coefficients
k_Fz_1(:) = 1.0;      k_Fz_2(:) = dt;
k_Ez_1(:) = 1.0;      k_Ez_2(:) = 1.0/epsilon_0;
k_Gx_1(:) = 1.0;      k_Gx_2(:) = dt/dy;
k_Hx_1(:) = 1.0/mu_0; k_Hx_2(:) = 1.0/mu_0;
k_Gy_1(:) = 1.0;      k_Gy_2(:) = dt/dx;
k_Hy_1(:) = 1.0/mu_0; k_Hy_2(:) = 1.0/mu_0;
k_Hz_1(:) = 1.0;      k_Hz_2(:) = 1.0/mu_0;
k_Ex_1(:) = 2.0;      k_Ex_2(:) = 2.0;
k_Ey_1(:) = 2.0;      k_Ey_2(:) = 2.0;




% Number of materials (include vacuum backrgound)
number_of_materials = 2;
%% Materials matrix 
Material = zeros(number_of_materials,3);

% eps, mu, sigma
% Background relative permittivity, relative permeability and absolute
% conductivity
Material = [
        1.0, 1.0, 0.0; %vacuum
        3, 3, 3.0e+70;
    ]
k_Ez_a = (2.0*epsilon_0*Material(1,1) - Material(1,3)*dt)/(2.0*epsilon_0*Material(1,1) + Material(1,3)*dt);
k_Ez_b =  2.0/(2.0*epsilon_0*Material(1,1) + Material(1,3)*dt);

% Free space plane wave coefficients
k_Hy_a(:) = 1.0;
k_Hy_b(:) = dt/(mu_0*Material(1,2)*dx);
k_Fz_a(:) = 1.0;
k_Fz_b(:) = dt/dx;

k_Hz_a(:) = 1.0;
k_Hz_b(:) = dt/(mu_0*Material(1,2)*dx);
k_Ey_a(:) = 1.0;
k_Ey_b(:) = dt/(epsilon_0*Material(1,1)*dx);
eta = sqrt(mu_0*Material(1,2)/epsilon_0/Material(1,1));


%% Field transformation coefficients in upml_width areas for TM ans TE modes
% Along x-axis

sigma_max = -(m+1)*log(R_err)/(2*eta*upml_width*dx);

for i = mmm:upml_width
    sigma_x = sigma_max*((upml_width-i+1)/upml_width).^m;
    ka_x = 1+(ka_max-1)*((upml_width-i+1)/upml_width).^m;

    k_Ez_1(i) = (2*epsilon_0*ka_x-sigma_x*dt)./(2*epsilon_0*ka_x+sigma_x*dt);
    k_Ez_1(end-(i)+1) = k_Ez_1(i);
    k_Ez_2(i) = 2./(2*epsilon_0*ka_x + sigma_x*dt);
    k_Ez_2(end-(i)+1) = k_Ez_2(i);
    k_Hx_1(i) = (2*epsilon_0*ka_x+sigma_x*dt)/(2*epsilon_0*mu_0);
    k_Hx_1(end-(i)+1) = k_Hx_1(i);
    k_Hx_2(i) = (2*epsilon_0*ka_x-sigma_x*dt)/(2*epsilon_0*mu_0);
    k_Hx_2(end-(i)+1) = k_Hx_2(i);
    k_Hz_1(i) = (2*epsilon_0*ka_x-sigma_x*dt)./(2*epsilon_0*ka_x+sigma_x*dt);
    k_Hz_1(end-(i)+1) = k_Hz_1(i);
    k_Hz_2(i) = 2*epsilon_0./(2*epsilon_0*ka_x+sigma_x*dt)/mu_0;
    k_Hz_2(end-(i)+1) = k_Hz_2(i);
    k_Ex_1(i) = (2*epsilon_0*ka_x+sigma_x*dt)/epsilon_0;
    k_Ex_1(end-(i)+1) = k_Ex_1(i);
    k_Ex_2(i) = (2*epsilon_0*ka_x-sigma_x*dt)/epsilon_0;
    k_Ex_2(end-(i)+1) = k_Ex_2(i);

    sigma_x = sigma_max*((upml_width-(i)+0.5)/upml_width).^m;
    ka_x = 1+(ka_max-1)*((upml_width-(i)+0.5)/upml_width).^m;

    k_Gy_1(i) = (2*epsilon_0*ka_x-sigma_x*dt)./(2*epsilon_0*ka_x+sigma_x*dt);
    k_Gy_1(end-(i)+1) = k_Gy_1(i);
    k_Gy_2(i) = 2*epsilon_0*dt./(2*epsilon_0*ka_x+sigma_x*dt)/dx;
    k_Gy_2(end-(i)+1) = k_Gy_2(i);
end




% Along y-axis
sigma_max = -(m+1)*log(R_err)/(2*eta*upml_width*dy);
for i = mmm:upml_width
    sigma_y = sigma_max*((upml_width-(i)+1)/upml_width).^m;
    ka_y = 1+(ka_max-1)*((upml_width-(i)+1)/upml_width).^m;

    

    k_Fz_1(i) = (2*epsilon_0*ka_y-sigma_y*dt)./(2*epsilon_0*ka_y+sigma_y*dt);
    k_Fz_1(end-(i)+1) = k_Fz_1(i);
    k_Fz_2(i) = 2*epsilon_0*dt./(2*epsilon_0*ka_y+sigma_y*dt);
    k_Fz_2(end-(i)+1) = k_Fz_2(i);
    k_Hy_1(i) = (2*epsilon_0*ka_y+sigma_y*dt)/(2*epsilon_0*mu_0);
    k_Hy_1(end-(i)+1) = k_Hy_1(i);
    k_Hy_2(i) = (2*epsilon_0*ka_y-sigma_y*dt)/(2*epsilon_0*mu_0);
    k_Hy_2(end-(i)+1) = k_Hy_2(i);
    k_Ey_1(i) = (2*epsilon_0*ka_y+sigma_y*dt)/epsilon_0;
    k_Ey_1(end-(i)+1) = k_Ey_1(i);
    k_Ey_2(i) = (2*epsilon_0*ka_y-sigma_y*dt)/epsilon_0;
    k_Ey_2(end-(i)+1) = k_Ey_2(i);

    sigma_y = sigma_max*((upml_width-(i)+0.5)/upml_width).^m;
    ka_y = 1+(ka_max-1)*((upml_width-(i)+0.5)/upml_width).^m;
    k_Gx_1(i) = (2*epsilon_0*ka_y-sigma_y*dt)./(2*epsilon_0*ka_y+sigma_y*dt);
    k_Gx_1(end-(i)+1) = k_Gx_1(i);
    k_Gx_2(i) = 2*epsilon_0*dt./(2*epsilon_0*ka_y+sigma_y*dt)/dy;
    k_Gx_2(end-(i)+1) = k_Gx_2(i);    
end



% Vectorize transformation coefficients
k_Fz_1_new(:) = k_Fz_1(upml_width+1);
k_Fz_2_new(:) = k_Fz_2(upml_width+1);

% left right border
for i = mmm:nx-2
    for j = mmm:upml_width-1
        % left
        k_Fz_1_new(i,j) = k_Fz_1(j+1);
        k_Fz_2_new(i,j) = k_Fz_2(j+1);

        % right
        % ?????? index
        k_Fz_1_new(i,end-j+1) = k_Fz_1(j+1);
        k_Fz_2_new(i,end-j+1) = k_Fz_2(j+1);
    end
end

k_Ez_1_new(:) = k_Ez_1(upml_width+1);
k_Ez_2_new(:) = k_Ez_2(upml_width+1);

% up down border
for i = mmm:upml_width-1
    for j = mmm:ny-2
        % up
        k_Ez_1_new(i,j) = k_Ez_1(i+1);
        k_Ez_2_new(i,j) = k_Ez_2(i+1);

        % down
        % ?????? index
        k_Ez_1_new(end-i+1,j) = k_Ez_1(i+1);
        k_Ez_2_new(end-i+1,j) = k_Ez_2(i+1);
    end
end

k_Gx_1_new(:) = k_Gx_1(upml_width+1);
k_Gx_2_new(:) = k_Gx_2(upml_width+1);


% left right border
for i = mmm:nx
    for j = mmm:upml_width
        % left
        k_Gx_1_new(i,j) = k_Gx_1(j);
        k_Gx_2_new(i,j) = k_Gx_2(j);

        % right
        % ?????? index
        k_Gx_1_new(i,end-j+1) = k_Gx_1(j);
        k_Gx_2_new(i,end-j+1) = k_Gx_2(j);
    end
end


k_Hx_1_new(:) = k_Hx_1(upml_width+1);
k_Hx_2_new(:) = k_Hx_2(upml_width+1);
k_Ex_1_new(:) = k_Ex_1(upml_width+1);
k_Ex_2_new(:) = k_Ex_2(upml_width+1);

% up down border
for i = mmm:upml_width
    for j = mmm:ny-1
        % up
        k_Hx_1_new(i,j) = k_Hx_1(i);
        k_Hx_2_new(i,j) = k_Hx_2(i);

        k_Ex_1_new(i,j) = k_Ex_1(i);
        k_Ex_2_new(i,j) = k_Ex_2(i);

        % down
        % ?????? index
        k_Hx_1_new(end-i+1,j) = k_Hx_1(i);
        k_Hx_2_new(end-i+1,j) = k_Hx_2(i);

        k_Ex_1_new(end-i+1,j) = k_Ex_1(i);
        k_Ex_2_new(end-i+1,j) = k_Ex_2(i);
    end
end

k_Gy_1_new(:) = k_Gy_1(upml_width+1);
k_Gy_2_new(:) = k_Gy_2(upml_width+1);


% up down border
for i = mmm:upml_width
    for j = mmm:ny
        % up
        k_Gy_1_new(i,j) = k_Gy_1(i);
        k_Gy_2_new(i,j) = k_Gy_2(i);

        % down
        % ?????? index
        k_Gy_1_new(end-i+1,j) = k_Gy_1(i);
        k_Gy_2_new(end-i+1,j) = k_Gy_2(i);
    end
end

k_Hy_1_new(:) = k_Hy_1(upml_width+1);
k_Hy_2_new(:) = k_Hy_2(upml_width+1);
k_Ey_1_new(:) = k_Ey_1(upml_width+1);
k_Ey_2_new(:) = k_Ey_2(upml_width+1);


% left right border
for i = mmm:nx-1
    for j = mmm:upml_width
        % left
        k_Hy_1_new(i,j) = k_Hy_1(j);
        k_Hy_2_new(i,j) = k_Hy_2(j);

        k_Ey_1_new(i,j) = k_Ey_1(j);
        k_Ey_2_new(i,j) = k_Ey_2(j);

        % right
        % ?????? index
        k_Hy_1_new(i,end-j+1) = k_Hy_1(j);
        k_Hy_2_new(i,end-j+1) = k_Hy_2(j);

        k_Ey_1_new(i,end-j+1) = k_Ey_1(j);
        k_Ey_2_new(i,end-j+1) = k_Ey_2(j);
    end
end

k_Hz_1_new(:) = k_Hz_1(upml_width+1);
k_Hz_2_new(:) = k_Hz_2(upml_width+1);


% up down border
for i = mmm:upml_width-1
    for j = mmm:ny-2
        % up
        k_Hz_1_new(i,j) = k_Hz_1(i+1);
        k_Hz_2_new(i,j) = k_Hz_2(i+1);

        % down
        % ?????? index
        k_Hz_1_new(end-i+1,j) = k_Hz_1(i+1);
        k_Hz_2_new(end-i+1,j) = k_Hz_2(i+1);
    end
end

% User material config coordinates in cells
% [i, cells_i, j, cells_j]
% mat_conf = [
%     160, 9, 240, 20;
%     180, 15, 240, 20;
%     200, 10, 240, 20;
%     220, 10, 240, 20;
%     240, 10, 240, 20;
%     260, 10, 240, 20;
%     280, 10, 240, 20;
%     300, 10, 240, 20;
%     320, 10, 240, 20;
%     ];
mat_conf = [
    80, 15, 100, 20;
    100, 10, 100, 20;
    120, 10, 100, 20;
    140, 10, 100, 20;
    ];

mat_count = size(mat_conf, 1);
% /////////////////////////////////////////////////////


% Fill geometry matrix for 1/2 cylinder (no vectorization here), but for TE
% mode we need three different Index for Ex, Ey and Hz due to leapfrog
for i = 1:nx
    for j = 1:ny
        for mat_idx = mmm:mat_count
            % conf = mat_conf(mat_idx);
            x = mat_conf(mat_idx, 1);
            x_cells = mat_conf(mat_idx, 2);
            y = mat_conf(mat_idx, 3);
            y_cells = mat_conf(mat_idx, 4);

            if ((i > x) &&  (i < (x + x_cells))...
                && (j > y) &&  (j < (y + y_cells)))
                Index(i,j) = 1;
            end
            if ((i+0.5 > x) &&  (i+0.5 < (x + x_cells))...
                && (j > y) &&  (j < (y + y_cells)))
                IndexX(i,j) = 1;
            end
            if ((i > x) &&  (i < (x + x_cells))...
                && (j+0.5 > y) &&  (j+0.5 < (y + y_cells)))
                IndexY(i,j) = 1;
            end
        end
    end
end





for ii = 0:(upml_width-1)
    sigma_x = sigma_max*((upml_width - ii)/ upml_width).^m;
    ka_x = 1 + (ka_max - 1)*((upml_width - ii)/ upml_width).^m;

    k_Fz_a(end-ii) = (2*epsilon_0*ka_x - sigma_x*dt)./...
                        (2*epsilon_0*ka_x + sigma_x*dt);
                
    k_Fz_b(end-ii) = 2*epsilon_0*dt./(2*epsilon_0*ka_x+sigma_x*dt)/dx;
    k_Hz_a(end-ii) = (2*epsilon_0*ka_x - sigma_x*dt)./(2*epsilon_0*ka_x + sigma_x*dt);
    k_Hz_b(end-ii) = 2*epsilon_0*dt./(2*epsilon_0*ka_x+sigma_x*dt)/(mu_0*Material(1,2)*dx);

    sigma_x = sigma_max*((upml_width - ii - 0.5)/ upml_width).^m;
    ka_x = 1 + (ka_max - 1)*((upml_width - ii - 0.5)/ upml_width).^m;
    
    k_Hy_a(end-ii) = (2*epsilon_0*ka_x - sigma_x*dt)./(2*epsilon_0*ka_x + sigma_x*dt);
    k_Hy_b(end-ii) = 2*epsilon_0*dt./(2*epsilon_0*ka_x + sigma_x*dt)/(mu_0*Material(1,2)*dx);
    k_Ey_a(end-ii) = (2*epsilon_0*ka_x - sigma_x*dt)./(2*epsilon_0*ka_x + sigma_x*dt);
    k_Ey_b(end-ii) = 2*dt./(2*epsilon_0*ka_x + sigma_x*dt)/(Material(1,1)*dx);
end

%% Another transformation coefficients
for ii = mmm:number_of_materials
    K_a(ii) = (2*epsilon_0*Material(ii,1) - ...
    Material(ii,3)*dt)./(2*epsilon_0*Material(ii,1) + ...
    Material(ii,3)*dt);
    K_b(ii) = 2*epsilon_0*Material(ii,1)./ ...
    (2*epsilon_0*Material(ii,1) + Material(ii,3)*dt);

    K_a1(ii) = 1./(2*epsilon_0*Material(ii,1) + ...
                                Material(ii,3)*dt);
    K_b1(ii) = 2*epsilon_0*Material(ii,1) - ...
                                Material(ii,3)*dt;
end

                                         
for i = mmm:nx-2
    for j = mmm:ny-2
        K_a_new(i,j) = K_a_new(i,j) + 1;
        K_b_new(i,j) = K_b_new(i,j) + 1;
    end
end

% Replace [1,2] -> [1,-1]
for i = mmm:nx-2
    for j = mmm:ny-2
      if(K_a_new(i,j) == 2)
        K_a_new(i,j) = K_a(2);
      end
      if(K_b_new(i,j) == 2)
        K_b_new(i,j) = K_b(2);
      end
    end
end  



for i = mmm:nx-2
    for j = mmm:ny-2
        M0(i,j) = Material(Index(i+1,j+1)+1, 1);
        M1(i,j) = Material(Index(i+1,j+1)+1, 2);
    end
end

for i = mmm:nx
    for j = mmm:ny-1
        M2(i,j) = Material(Index(i,j)+1, 2);
    end
end

for i = mmm:nx-1
    for j = mmm:ny
        M3(i,j) = Material(Index(i,j)+1, 2);
    end
end


%% Create fullscreen figure and set a double-buffer
figure('units','normalized','outerposition',[0 0 1 1]);
set(gcf,'doublebuffer','on');

tic; 

% /////////////////// LOOP /////////////////////////////////////////////
%% Main FDTD UPML routine with TF/SF excitation interface calculates TE and
%% TM modes simultaneously
for T = 1:number_of_iterations
    %% Calculate incident 1D plain waves for TF/SF implementation
    % TE mode (Hz)
    for i = mmm:nx_b
        Ey_1D(i) = k_Ey_a(i)*Ey_1D(i) ...
                  - k_Ey_b(i)*(Hz_1D(i+1)-Hz_1D(i));
    end
    
    t0 = 5
    tau = 15
    E0 = 2
    % Hz_1D(1) = E0*sin(2*pi*frequency*(T-1)*dt);
    Hz_1D(1) = -E0 * ((T - t0) / tau) * exp(-1.0 * (((T - t0) / tau) ^ 2));
    
    for i = mmm+1:nx_b
        Hz_1D(i) = k_Hz_a(i)*Hz_1D(i) ...
                    - k_Hz_b(i)*(Ey_1D(i)-Ey_1D(i-1));
    end

    % TM mode (Ez)  
    for i = mmm:nx_b          
        Hy_1D(i) = k_Hy_a(i)*Hy_1D(i) + ...
		            k_Hy_b(i)*(Ez_1D(i+1)-Ez_1D(i));
    end

    % Ez_1D(1) = E0*sin(2*pi*frequency*(T-1)*dt);
    Ez_1D(1) = -E0 * ((T - t0) / tau) * exp(-1.0 * (((T - t0) / tau) ^ 2));

    for i = mmm:nx_b-1
        Fz_1D_r(i) = Fz_1D(i+1);
    end
    
    for i = mmm+1:nx_b
        Fz_1D(i) = k_Fz_a(i)*Fz_1D(i) + ...
                        k_Fz_b(i)*( Hy_1D(i) - Hy_1D(i-1) );
    end

    for i = mmm+1:nx_b
        Ez_1D(i) = k_Ez_a*Ez_1D(i) + k_Ez_b*( Fz_1D(i) - Fz_1D_r(i-1));
    end

    %% Calculate Ez (TM mode) and Hz (TE mode) total fields 
    % TE: Wz -> Hz    
    for i = mmm+1:nx-1
        for j = mmm+1:ny-1
            Fz_r1(i-1,j-1) = Wz(i,j);
        end
    end

    
    for i = mmm+1:nx-1
        for j = mmm+1:ny-1


            Wz(i,j) = k_Fz_1_new(i-1,j-1) * Wz(i,j) + ...
                        k_Fz_2_new(i-1,j-1) * ((Ex(i,j)-Ex(i,j-1))/dy - ...
                        (Ey(i,j)-Ey(i-1,j))/dx );
                        
                        % if(T == 10 && i == 10 && j == 10 ) 
                            % k_Fz_1_new(i-1,j-1) * Wz(i,j)
                            % ((Ex(i,j)-Ex(i,j-1))/dy - (Ey(i,j)-Ey(i-1,j))/dx )
                            % Wz(i,j)
                        % end
            
                        
            Hz(i,j) = k_Hz_1_new(i-1,j-1)*Hz(i,j) + ...
                        k_Hz_2_new(i-1,j-1) * ( Wz(i,j)-Fz_r1(i-1,j-1) )/M1(i-1,j-1);
        end
    end
    

    
    % TM: Fz -> Tz -> Ez          
    for i = mmm+1:nx-1
        for j = mmm+1:ny-1    
            Fz_r(i-1,j-1) = Fz(i,j);
            Tz_r(i-1,j-1) = Tz(i,j);
        end
    end

    for i = mmm+1:nx-1
        for j = mmm+1:ny-1    
            Fz(i,j) = k_Fz_1_new(i-1,j-1) * Fz(i,j) + k_Fz_2_new(i-1,j-1)*( (Hy(i,j) - ...
                        Hy(i-1,j))/dx - (Hx(i,j) - ...
                        Hx(i,j-1))/dy );
        end
    end
    

    for i = mmm:nx-2
        for j = mmm:ny-2
            Tz(i+1,j+1) = K_a_new(i,j)* ...
                        Tz(i+1,j+1) + ...
                        K_b_new(i,j)*( Fz(i+1,j+1) - Fz_r(i,j));
        end
    end         
    

    for i = mmm+1:nx-1
        for j = mmm+1:ny-1
            Ez(i,j) = k_Ez_1_new(i-1,j-1)*Ez(i,j) + ...
                        k_Ez_2_new(i-1,j-1)*( Tz(i,j) - Tz_r(i-1,j-1) )/ M0(i-1,j-1);                   
        end
    end

    %% Calculate scattered field Ez and Hz in TF/SF
    % TE mode             
    i = nx_a+1;
    for j = ny_a+1:ny_b+1        
        Hz(i,j) = Hz(i,j) + ...
            dt / (mu_0*Material(Index(i,j)+1, 2)*dx) * Ey_1D(1);
        
    end

    i = nx_b+1;
    for j = ny_a+1:ny_b+1
        Hz(i,j) = Hz(i,j) - ...
            dt/(mu_0*Material(Index(i,j)+1, 2)*dx)*Ey_1D(nx_b-nx_a+2);
            % j
    end

    % TM mode 
    i = nx_a+1;
    for j = ny_a+1:ny_b+1                      
        Ez(i,j) = Ez(i,j) - ...
            dt./(epsilon_0*Material(Index(i,j)+1,1)*dx)*Hy_1D(1);
    end

    i = nx_b+1;
    for j = ny_a+1:ny_b+1
        Ez(i,j) = Ez(i,j) + ...
        dt/(epsilon_0*Material(Index(i,j)+1,1)*dx)*Hy_1D(nx_b-nx_a+2);
    end

    %% Calculate Hx and Ex total fields 
    % TE mode
    for i = mmm:nx
        for j = mmm:ny-1
            Gx_r1(i,j) = Mx(i,j);
        end
    end
    
    for i = mmm:nx
        for j = mmm:ny-1
            Mx(i,j) = k_Gx_1_new(i,j) * Mx(i,j) + ...
                      k_Gx_2_new(i,j)*( Hz(i,j+1)-Hz(i,j) );
        end
    end

    for i = mmm:nx
        for j = mmm:ny-1
            Ex(i,j) = K_a1(IndexX(i,j)+1)*( K_b1(IndexX(i,j)+1)*...
                      Ex(i,j) + k_Ex_1_new(i,j)*Mx(i,j)-k_Ex_2_new(i,j)*Gx_r1(i,j) );
            % if(T == 10 && i == 2 && j == 2 ) 
                        % k_Fz_1_new(i-1,j-1) * Wz(i,j)
                        % ((Ex(i,j)-Ex(i,j-1))/dy - (Ey(i,j)-Ey(i-1,j))/dx )
                        % ( K_b1(IndexX(i,j)+1)*...
                        % Ex(i,j) + k_Ex_1_new(i,j)*Mx(i,j)-k_Ex_2_new(i,j)*Gx_r1(i,j) )
            % end
        end
    end

    % /// tmp comm start
    % TM mode
    for i = mmm:nx
        for j = mmm:ny-1 
            Gx_r(i,j) = Gx(i,j);
        end
    end

    for i = mmm:nx
        for j = mmm:ny-1 
            Gx(i,j) = k_Gx_1_new(i,j) * Gx(i,j) - ...
                      k_Gx_2_new(i,j) * ( Ez(i,j+1)-Ez(i,j) );
        end
    end

    for i = mmm:nx
        for j = mmm:ny-1 
            Hx(i,j) = Hx(i,j) + (k_Hx_1_new(i,j) * Gx(i,j) - k_Hx_2_new(i,j)*Gx_r(i,j)) / M2(i,j);
        end
    end

    % %% Calculate Hy and Ey total fields 
    % TE mode
    for i = mmm:nx-1
        for j = mmm:ny 
            Gy_r1(i,j) = My(i,j);
        end
    end
    
    for i = mmm:nx-1
        for j = mmm:ny 
            My(i,j) = k_Gy_1_new(i,j)*My(i,j) - ...
                      k_Gy_2_new(i,j)*( Hz(i+1,j)-Hz(i,j));
        end
    end

    for i = mmm:nx-1
        for j = mmm:ny 
            Ey(i,j) = K_a1(IndexY(i,j)+1)*( K_b1(IndexY(i,j)+1)*...
                      Ey(i,j) + k_Ey_1_new(i,j)*My(i,j)-k_Ey_2_new(i,j)*Gy_r1(i,j) );
        end
    end

    % TM mode
    for i = mmm:nx-1
        for j = mmm:ny 
            Gy_r(i,j) = Gy(i,j);
        end
    end 
    
    for i = mmm:nx-1
        for j = mmm:ny 
            Gy(i,j) = k_Gy_1_new(i,j)*Gy(i,j) + ...
                      k_Gy_2_new(i,j)*(Ez(i+1,j)-Ez(i,j));
        end
    end

    for i = mmm:nx-1
        for j = mmm:ny
            Hy(i,j) = Hy(i,j) + ...
                      (k_Hy_1_new(i,j)*Gy(i,j) - k_Hy_2_new(i,j)*Gy_r(i,j))/M3(i,j);
        end
    end

    % %% Calculate scattered field Hx and Ex in TF/SF
    % % TE mode
    j = ny_a;
    for i = nx_a+1:nx_b+1
        Ex(i,j) = Ex(i,j) - ...
            2*dt/dy*K_a1(Index(i,j)+1)*Hz_1D(i-nx_a+1);
    end            

    j = ny_b+1;
    for i = nx_a+1:nx_b+1
        Ex(i,j) = Ex(i,j) + ...
            2*dt/dy*K_a1(Index(i,j)+1)*Hz_1D(i-nx_a+1);

    end

    % TM mode            
    j = ny_a;
    for i = nx_a+1:nx_b+1         
        Hx(i,j) = Hx(i,j) + ...
            dt/(mu_0*dy*Material(Index(i,j)+1,2))*Ez_1D(i-nx_a+1);
    end

    j = ny_b+1;
    for i = nx_a+1:nx_b+1         
        Hx(i,j) = Hx(i,j) - ...
            dt/(mu_0*dy*Material(Index(i,j)+1,2))*Ez_1D(i-nx_a+1);
    end

    %% Calculate scattered field Hy and Ey in TF/SF
    % TE mode
    i = nx_a;
    for j = ny_a+1:ny_b+1         
        Ey(i,j) = Ey(i,j) + ...
        2*dt/dx*K_a1(Index(i,j)+1,1)*Hz_1D(mmm+1);
    end

    i = nx_b+1;
    for j = ny_a+1:ny_b+1         
        Ey(i,j) = Ey(i,j) - ...
            2*dt/dx*K_a1(Index(i,j)+1,1)*Hz_1D(nx_b-nx_a+2);

    end

    % TM mode                     
    i = nx_a;
    for j = ny_a+1:ny_b+1
        Hy(i,j) = Hy(i,j) - ...
            dt/(mu_0*dx*Material(Index(i,j)+1,2))*Ez_1D(2);
    end

    i = nx_b+1;
    for j = ny_a+1:ny_b+1
        Hy(i,j) = Hy(i,j) + ...
            dt/(mu_0*dx*Material(Index(i,j)+1,2))*Ez_1D(nx_b-nx_a+2);

            if(T == 10) 
                j
                dt/(mu_0*dx*Material(Index(i,j)+1,2))*Ez_1D(nx_b-nx_a+2)
            end
    end
    % /// tmp comm end

    %% Plot Ez and Hz fields dynamics
    if (mod(T,8) == 0)
    subplot(1,2,1);    
	pcolor(Y(upml_width:ny-upml_width),X(upml_width:nx-upml_width),Ez(upml_width:nx-upml_width,upml_width:ny-upml_width));
	shading interp;
	caxis([-E0 E0]);
	axis image;
	colorbar;
	title('E_{z}(x,y)', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	xlabel('x, [m]', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	ylabel('y, [m]', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
    subplot(1,2,2);    
	pcolor(Y(upml_width:ny-upml_width),X(upml_width:nx-upml_width),Hz(upml_width:nx-upml_width,upml_width:ny-upml_width));
    shading interp;
	caxis([-E0 E0]);
	axis image;
	colorbar;
	title('H_{z}(x,y)', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	xlabel('x, [m]', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	ylabel('y, [m]', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	drawnow;
    end
end
disp(['Time elapsed - ',num2str(toc/60),' minutes']);
