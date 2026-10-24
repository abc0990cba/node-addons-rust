
%% FDTD 2D with UPML and TF/SF interface example. 


%% Initialize workspace
clear all; close all; clc; format short;

% Matlab array index start
mmm = 1;

%% Fundamental physical constants
% Absolute vacuum permittivity
epsilon_0 = 8.854*1e-12;
% Absulute vacuum permeability
mu_0 = 4*pi*1e-7;
% Light speed in vacuum
light_speed = 1/sqrt(epsilon_0*mu_0);

%% Main parameters
% Calculation area length per x and y axes
area_width = 2.5;
area_height = 2.5;

% Uniform grid points for x and y axes
nx = 500;
ny = 500;

% Perfect match layer (pml_width) thickness in uniform grid cells
pml_width = 10;

% End time [s]
t_end = 15e-9;

% Excitation source amplitude and frequency [Hz]
E0 = 1.0;     
f = 2.0e+9;   % 2 GHz

% Number of materials (include vacuum backrgound)
number_of_materials = 2;
% Background relative permittivity, relative permeability and absolute
% conductivity
eps_back = 1.0;
mu_back = 1.0;
sig_back = 0.0;

% Width of alinea between total field area and calculation area border
% (scattered field interface width) [m]
len_tf_dx = 0.5;
len_tf_dy = 0.5;

% Grid calculation
% X = linspace(0,area_width,nx)-area_width/2;
% Y = linspace(0,area_height,ny)-area_height/2;
% dx = X(nx)-X(nx-1);
% dy = Y(ny)-Y(ny-1);

dx = area_width / nx;
dy = area_width / ny;
X = [];
Y = [];
for i = 1:nx
    X(i) = (i-1)*dx - area_width/2;
    Y(i) = (i-1)*dy - area_height/2;
end


% Time step from CFL condition
CFL_FACTOR = 0.99;
dt = ( 1/light_speed/sqrt( 1/(dx^2) + 1/(dy^2) ) )*CFL_FACTOR;
number_of_iterations = round(t_end/dt);

%% Geometry matrix 
Index = zeros(nx,ny);
IndexX = zeros(nx,ny);
IndexY = zeros(nx,ny);


%% Materials matrix 
Material = zeros(number_of_materials,3);
Material(1,1) = eps_back;
Material(1,2) = mu_back;
Material(1,3) = sig_back;


%% Simple geometry (here metal round cylinder 1/2)
% Diameter [m]
d0 = 0.4;
% Cylinder materials  
Material(2,1) = 3;       % relative permittivity
Material(2,2) = 3;       % relative permeability
Material(2,3) = 3.0e+70; % absolute conductivity

% User material config coordinates in cells
% /////////////////////////////////////////////////////
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
    200, 100, 200, 100;
    
    ];

mat_count = size(mat_conf, 1);
% /////////////////////////////////////////////////////


% Fill geometry matrix for 1/2 cylinder (no vectorization here), but for TE
% mode we need three different Index for Ex, Ey and Hz due to leapfrog
for I = 1:nx
    for J = 1:ny
%         half sphere
%         if ((J-nx/2)^2 + (I-ny/2)^2 <= 0.25*(d0/dx)^2 && (area_width-I*dx<=J*dy))
%             Index(J,I) = 1;
%         end
%         if ((J-nx/2)^2 + (I+0.5-ny/2)^2 <= 0.25*(d0/dx)^2 && (area_width-(I+0.5)*dx<=J*dy))
%             IndexX(J,I) = 1;
%         end
%         if ((J+0.5-nx/2)^2 + (I-ny/2)^2 <= 0.25*(d0/dx)^2 && (area_width-I*dx<=(J+0.5)*dy))
%             IndexY(J,I) = 1;
%         end


% squares
        for mat_idx = mmm:mat_count
            conf = mat_conf(mat_idx);
            x = mat_conf(mat_idx, 1);
            x_cells = mat_conf(mat_idx, 2);
            y = mat_conf(mat_idx, 3);
            y_cells = mat_conf(mat_idx, 4);

            if ((I > x) &&  (I < (x + x_cells))...
                && (J > y) &&  (J < (y + y_cells)))
                Index(J,I) = 1;
            end
            if ((I+0.5 > x) &&  (I+0.5 < (x + x_cells))...
                && (J > y) &&  (J < (y + y_cells)))
                IndexX(J,I) = 1;
            end
            if ((I > x) &&  (I < (x + x_cells))...
                && (J+0.5 > y) &&  (J+0.5 < (y + y_cells)))
                IndexY(J,I) = 1;
            end
        end
    end
end


%% Calculate size of total field area in TF/SF formalism
nx_a = round(len_tf_dx/dx);
nx_b = round((area_width-len_tf_dx)/dx);
ny_a = round(len_tf_dy/dy);
ny_b = round((area_height-len_tf_dy)/dy);

%% Pre-allocate 1D fields for TF/SF interface 
% TM components
Ez_1D = zeros(nx_b+1,1);
Fz_1D = zeros(nx_b+1,1);
Hy_1D = zeros(nx_b,1);

k_Fz_a = zeros(nx_b+1,1);
k_Fz_b = zeros(nx_b+1,1);
k_Hy_a = zeros(nx_b,1);

k_Hy_b = zeros(nx_b,1);
k_Ez_a = (2.0*epsilon_0*Material(1,1) - Material(1,3)*dt)/(2.0*epsilon_0*Material(1,1) + Material(1,3)*dt);
k_Ez_b =  2.0/(2.0*epsilon_0*Material(1,1) + Material(1,3)*dt);

% TE components
Hz_1D = zeros(nx_b+1,1);
Ey_1D = zeros(nx_b,1);
k_Hz_a = zeros(nx_b+1,1);
k_Hz_b = zeros(nx_b+1,1); 
k_Ey_a = zeros(nx_b,1);
k_Ey_b = zeros(nx_b,1);

% Free space plane wave coefficients
k_Hy_a(:) = 1.0;
k_Hy_b(:) = dt/(mu_0*Material(1,2)*dx);
k_Fz_a(:) = 1.0;
k_Fz_b(:) = dt/dx;

k_Hz_a(:) = 1.0;
k_Hz_b(:) = dt/(mu_0*Material(1,2)*dx);
k_Ey_a(:) = 1.0;
k_Ey_b(:) = dt/(epsilon_0*Material(1,1)*dx);

ka_max = 1;
m = 4;
R_err = 1e-16;
eta = sqrt(mu_0*Material(1,2)/epsilon_0/Material(1,1));

sigma_max = -(m+1)*log(R_err)/(2*eta*pml_width*dx);
sigma_x = zeros(1, pml_width);
ka_x = zeros(1, pml_width);

for ii = 0:(pml_width-1)
    sigma_x(ii+mmm) = sigma_max*((pml_width - ii)/ pml_width).^m;
    ka_x(ii+mmm) = 1 + (ka_max - 1)*((pml_width - ii)/ pml_width).^m;

    k_Fz_a(end-ii) = (2*epsilon_0*ka_x(ii+mmm) - sigma_x(ii+mmm)*dt)./...
                        (2*epsilon_0*ka_x(ii+mmm) + sigma_x(ii+mmm)*dt);
                
    k_Fz_b(end-ii) = 2*epsilon_0*dt./(2*epsilon_0*ka_x(ii+mmm)+sigma_x(ii+mmm)*dt)/dx;
    k_Hz_a(end-ii) = (2*epsilon_0*ka_x(ii+mmm) - sigma_x(ii+mmm)*dt)./(2*epsilon_0*ka_x(ii+mmm) + sigma_x(ii+mmm)*dt);
    k_Hz_b(end-ii) = 2*epsilon_0*dt./(2*epsilon_0*ka_x(ii+mmm)+sigma_x(ii+mmm)*dt)/(mu_0*Material(1,2)*dx);
end

for ii = 0:(pml_width-1)
    sigma_x(ii+mmm) = sigma_max*((pml_width - ii - 0.5)/ pml_width).^m;
    ka_x(ii+mmm) = 1 + (ka_max - 1)*((pml_width - ii - 0.5)/ pml_width).^m;
    k_Hy_a(end-ii) = (2*epsilon_0*ka_x(ii+mmm) - sigma_x(ii+mmm)*dt)./(2*epsilon_0*ka_x(ii+mmm) + sigma_x(ii+mmm)*dt);
    k_Hy_b(end-ii) = 2*epsilon_0*dt./(2*epsilon_0*ka_x(ii+mmm) + sigma_x(ii+mmm)*dt)/(mu_0*Material(1,2)*dx);
    k_Ey_a(end-ii) = (2*epsilon_0*ka_x(ii+mmm) - sigma_x(ii+mmm)*dt)./(2*epsilon_0*ka_x(ii+mmm) + sigma_x(ii+mmm)*dt);
    k_Ey_b(end-ii) = 2*dt./(2*epsilon_0*ka_x(ii+mmm) + sigma_x(ii+mmm)*dt)/(Material(1,1)*dx);
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

% size(K_a)
% ?????????????????????????
% ?????????????????????????
% ?????????????????????????
% K_a_new = K_a(Index(mmm+1:nx-1,mmm+1:ny-1)+1);                                                 
K_a_new = Index(mmm+1:nx-1,mmm+1:ny-1)+1;
K_b_new = Index(mmm+1:nx-1,mmm+1:ny-1)+1;                                               
% K_old = K_a_new;

% K_b_new = K_b(K_b_new);
% K_a_new = K_a(K_a_new);
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





% ssssssssssssssssssssssssssssssssssssssssssssss
% pppp = 0;
% io = 0;
% jo=0;
% for i = mmm:nx-2
%     for j = mmm:ny-2
%       if(K_a_new(i,j) ~= K_old(i,j))
%         pppp = pppp+1;
%         io = i;
%         jo = j;
%       end
%     end
% end   
% pppp
% io;
% jo;
% ssssssssssssssssssssssssssssssssssssssssssssss

% aaa = [1, 1];
% bbb = [1,2,3,4; 5,6,7,8; 9,10,11,12; 13,14,15,16;];
% aaa(Index(100:104-1,100:104-1)+1);

% Index(100:104-1,100:104-1)+2
% BB = aaa()


% size(K_a)
% ?????????????????????????
% K_a_new = zeros(nx-2,ny-2);
% K_b_new = zeros(nx-2,ny-2);
% for i = mmm+1:nx-1
%     for j = mmm+1:ny-1
%         K_a_new = Index(i,j)+1;                                                 
%         K_b_new = Index(i,j)+1;
%     end
% end


%% Allocate 2D arrays
% TM physical and auxiliary fields
Fz = zeros(nx,ny); Tz = zeros(nx,ny);   Gx = zeros(nx,ny-1); Gy = zeros(nx-1,ny);
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

% //////////////////// LABEL ////////////////////////

%% Field transformation coefficients in pml_width areas for TM ans TE modes
% Along x-axis
sigma_max = -(m+1)*log(R_err)/(2*eta*pml_width*dx);

for i = mmm:pml_width
    sigma_x(i) = sigma_max*((pml_width-i+1)/pml_width).^m;
    ka_x(i) = 1+(ka_max-1)*((pml_width-i+1)/pml_width).^m;

    k_Ez_1(i) = (2*epsilon_0*ka_x(i)-sigma_x(i)*dt)./(2*epsilon_0*ka_x(i)+sigma_x(i)*dt);
    k_Ez_1(end-(i)+1) = k_Ez_1(i);
    k_Ez_2(i) = 2./(2*epsilon_0*ka_x(i) + sigma_x(i)*dt);
    k_Ez_2(end-(i)+1) = k_Ez_2(i);
    k_Hx_1(i) = (2*epsilon_0*ka_x(i)+sigma_x(i)*dt)/(2*epsilon_0*mu_0);
    k_Hx_1(end-(i)+1) = k_Hx_1(i);
    k_Hx_2(i) = (2*epsilon_0*ka_x(i)-sigma_x(i)*dt)/(2*epsilon_0*mu_0);
    k_Hx_2(end-(i)+1) = k_Hx_2(i);
    k_Hz_1(i) = (2*epsilon_0*ka_x(i)-sigma_x(i)*dt)./(2*epsilon_0*ka_x(i)+sigma_x(i)*dt);
    k_Hz_1(end-(i)+1) = k_Hz_1(i);
    k_Hz_2(i) = 2*epsilon_0./(2*epsilon_0*ka_x(i)+sigma_x(i)*dt)/mu_0;
    k_Hz_2(end-(i)+1) = k_Hz_2(i);
    k_Ex_1(i) = (2*epsilon_0*ka_x(i)+sigma_x(i)*dt)/epsilon_0;
    k_Ex_1(end-(i)+1) = k_Ex_1(i);
    k_Ex_2(i) = (2*epsilon_0*ka_x(i)-sigma_x(i)*dt)/epsilon_0;
    k_Ex_2(end-(i)+1) = k_Ex_2(i);
end

for i = mmm:pml_width
    sigma_x(i) = sigma_max*((pml_width-(i)+0.5)/pml_width).^m;
    ka_x(i) = 1+(ka_max-1)*((pml_width-(i)+0.5)/pml_width).^m;
    k_Gy_1(i) = (2*epsilon_0*ka_x(i)-sigma_x(i)*dt)./(2*epsilon_0*ka_x(i)+sigma_x(i)*dt);
    k_Gy_1(end-(i)+1) = k_Gy_1(i);
    k_Gy_2(i) = 2*epsilon_0*dt./(2*epsilon_0*ka_x(i)+sigma_x(i)*dt)/dx;
    k_Gy_2(end-(i)+1) = k_Gy_2(i);
end



% Along y-axis
sigma_max = -(m+1)*log(R_err)/(2*eta*pml_width*dy);
for i = mmm:pml_width
    sigma_y(i) = sigma_max*((pml_width-(i)+1)/pml_width).^m;
    ka_y(i) = 1+(ka_max-1)*((pml_width-(i)+1)/pml_width).^m;
    k_Fz_1(i) = (2*epsilon_0*ka_y(i)-sigma_y(i)*dt)./(2*epsilon_0*ka_y(i)+sigma_y(i)*dt);
    k_Fz_1(end-(i)+1) = k_Fz_1(i);
    k_Fz_2(i) = 2*epsilon_0*dt./(2*epsilon_0*ka_y(i)+sigma_y(i)*dt);
    k_Fz_2(end-(i)+1) = k_Fz_2(i);
    k_Hy_1(i) = (2*epsilon_0*ka_y(i)+sigma_y(i)*dt)/(2*epsilon_0*mu_0);
    k_Hy_1(end-(i)+1) = k_Hy_1(i);
    k_Hy_2(i) = (2*epsilon_0*ka_y(i)-sigma_y(i)*dt)/(2*epsilon_0*mu_0);
    k_Hy_2(end-(i)+1) = k_Hy_2(i);
    k_Ey_1(i) = (2*epsilon_0*ka_y(i)+sigma_y(i)*dt)/epsilon_0;
    k_Ey_1(end-(i)+1) = k_Ey_1(i);
    k_Ey_2(i) = (2*epsilon_0*ka_y(i)-sigma_y(i)*dt)/epsilon_0;
    k_Ey_2(end-(i)+1) = k_Ey_2(i);
end

for i = mmm:pml_width
    sigma_y(i) = sigma_max*((pml_width-(i)+0.5)/pml_width).^m;
    ka_y(i) = 1+(ka_max-1)*((pml_width-(i)+0.5)/pml_width).^m;
    k_Gx_1(i) = (2*epsilon_0*ka_y(i)-sigma_y(i)*dt)./(2*epsilon_0*ka_y(i)+sigma_y(i)*dt);
    k_Gx_1(end-(i)+1) = k_Gx_1(i);
    k_Gx_2(i) = 2*epsilon_0*dt./(2*epsilon_0*ka_y(i)+sigma_y(i)*dt)/dy;
    k_Gx_2(end-(i)+1) = k_Gx_2(i);    
end


% Vectorize transformation coefficients
k_Fz_1_old = k_Fz_1;
k_Fz_1_new = zeros(nx-2,ny-2);
k_Fz_1_new(:) = k_Fz_1(pml_width+1);

k_Fz_2_old = k_Fz_2;
k_Fz_2_new = zeros(nx-2,ny-2);
k_Fz_2_new(:) = k_Fz_2(pml_width+1);


% left right border
for i = mmm:nx-2
    for j = mmm:pml_width-1
        % left
        k_Fz_1_new(i,j) = k_Fz_1(j+1);
        k_Fz_2_new(i,j) = k_Fz_2(j+1);

        % right
        % ?????? index
        k_Fz_1_new(i,end-j+1) = k_Fz_1(j+1);
        k_Fz_2_new(i,end-j+1) = k_Fz_2(j+1);
    end
end


k_Ez_1_old = k_Ez_1;
k_Ez_1_new = zeros(nx-2,ny-2);
k_Ez_1_new(:) = k_Ez_1(pml_width+1);

k_Ez_2_old = k_Ez_2;
k_Ez_2_new = zeros(nx-2,ny-2);
k_Ez_2_new(:) = k_Ez_2(pml_width+1);


% up down border
for i = mmm:pml_width-1
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


k_Gx_1_old = k_Gx_1;
k_Gx_1_new = zeros(nx,ny-1);
k_Gx_1_new(:) = k_Gx_1(pml_width+1);

k_Gx_2_old = k_Gx_2;
k_Gx_2_new = zeros(nx,ny-1);
k_Gx_2_new(:) = k_Gx_2(pml_width+1);


% left right border
for i = mmm:nx
    for j = mmm:pml_width
        % left
        k_Gx_1_new(i,j) = k_Gx_1(j);
        k_Gx_2_new(i,j) = k_Gx_2(j);

        % right
        % ?????? index
        k_Gx_1_new(i,end-j+1) = k_Gx_1(j);
        k_Gx_2_new(i,end-j+1) = k_Gx_2(j);
    end
end


k_Hx_1_old = k_Hx_1;
k_Hx_1_new = zeros(nx,ny-1);
k_Hx_1_new(:) = k_Hx_1(pml_width+1);

k_Hx_2_old = k_Hx_2;
k_Hx_2_new = zeros(nx,ny-1);
k_Hx_2_new(:) = k_Hx_2(pml_width+1);


k_Ex_1_old = k_Ex_1;
k_Ex_1_new = zeros(nx,ny-1);
k_Ex_1_new(:) = k_Ex_1(pml_width+1);

k_Ex_2_old = k_Ex_2;
k_Ex_2_new = zeros(nx,ny-1);
k_Ex_2_new(:) = k_Ex_2(pml_width+1);

% up down border
for i = mmm:pml_width
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

k_Gy_1_old = k_Gy_1;
k_Gy_1_new = zeros(nx-1,ny);
k_Gy_1_new(:) = k_Gy_1(pml_width+1);

k_Gy_2_old = k_Gy_2;
k_Gy_2_new = zeros(nx-1,ny);
k_Gy_2_new(:) = k_Gy_2(pml_width+1);


% up down border
for i = mmm:pml_width
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


k_Hy_1_old = k_Hy_1;
k_Hy_1_new = zeros(nx-1,ny);
k_Hy_1_new(:) = k_Hy_1(pml_width+1);

k_Hy_2_old = k_Hy_2;
k_Hy_2_new = zeros(nx-1,ny);
k_Hy_2_new(:) = k_Hy_2(pml_width+1);


k_Ey_1_old = k_Ey_1;
k_Ey_1_new = zeros(nx-1,ny);
k_Ey_1_new(:) = k_Ey_1(pml_width+1);

k_Ey_2_old = k_Ey_2;
k_Ey_2_new = zeros(nx-1,ny);
k_Ey_2_new(:) = k_Ey_2(pml_width+1);


% left right border
for i = mmm:nx-1
    for j = mmm:pml_width
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

k_Hz_1_old = k_Hz_1;
k_Hz_1_new = zeros(nx-2,ny-2);
k_Hz_1_new(:) = k_Hz_1(pml_width+1);

k_Hz_2_old = k_Hz_2;
k_Hz_2_new = zeros(nx-2,ny-2);
k_Hz_2_new(:) = k_Hz_2(pml_width+1);


% up down border
for i = mmm:pml_width-1
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


% k_Fz_1 = repmat(k_Fz_1(2:ny-1)',nx-2,1);
% k_Fz_2 = repmat(k_Fz_2(2:ny-1)',nx-2,1);

% k_Ez_1 = repmat(k_Ez_1(2:nx-1),1,ny-2);
% k_Ez_2 = repmat(k_Ez_2(2:nx-1),1,ny-2);

% k_Gx_1 = repmat(k_Gx_1(1:ny-1)',nx,1);
% k_Gx_2 = repmat(k_Gx_2_new(1:ny-1)',nx,1);

% k_Hx_1 = repmat(k_Hx_1(1:nx),1,ny-1);
% k_Hx_2 = repmat(k_Hx_2(1:nx),1,ny-1);

% k_Gy_1 = repmat(k_Gy_1(1:nx-1),1,ny);
% k_Gy_2 = repmat(k_Gy_2(1:nx-1),1,ny);

% k_Hy_1 = repmat(k_Hy_1(1:ny)',nx-1,1);
% k_Hy_2 = repmat(k_Hy_2(1:ny)',nx-1,1);

% k_Hz_1 = repmat(k_Hz_1(2:nx-1),1,ny-2);
% k_Hz_2 = repmat(k_Hz_2(2:nx-1),1,ny-2);

% k_Ex_1 = repmat(k_Ex_1(1:nx),1,ny-1);
% k_Ex_2 = repmat(k_Ex_2(1:nx),1,ny-1);


% k_Ey_1 = repmat(k_Ey_1(1:ny)',nx-1,1);
% k_Ey_2 = repmat(k_Ey_2(1:ny)',nx-1,1);


% M0_old = Material(Index(2:nx-1,2:ny-1)+1,1);

% M0 = reshape(Material(Index(2:nx-1,2:ny-1)+1,1),nx-2,[]);
% M1 = reshape(Material(Index(2:nx-1,2:ny-1)+1,2),nx-2,[]);
% M2 = reshape(Material(Index(1:nx,1:ny-1)+1,2),nx,[]);
% M3 = reshape(Material(Index(1:nx-1,1:ny)+1,2),[],ny);


M0 = zeros(nx-2,ny-2);
M1 = zeros(nx-2,ny-2);

for i = mmm:nx-2
    for j = mmm:ny-2
        M0(i,j) = Material(Index(i+1,j+1)+1, 1);
        M1(i,j) = Material(Index(i+1,j+1)+1, 2);
    end
end


M2 = zeros(nx,ny-1);

for i = mmm:nx
    for j = mmm:ny-1
        M2(i,j) = Material(Index(i,j)+1, 2);
    end
end

M3 = zeros(nx-1,ny);

for i = mmm:nx-1
    for j = mmm:ny
        M3(i,j) = Material(Index(i,j)+1, 2);
    end
end

% M0 = reshape(Material(Index(2:nx-1,2:ny-1)+1,1),nx-2,ny-2);
% M1 = reshape(Material(Index(2:nx-1,2:ny-1)+1,2),nx-2,ny-2);
% M2 = reshape(Material(Index(1:nx,1:ny-1)+1,2),nx,ny-1);
% M3 = reshape(Material(Index(1:nx-1,1:ny)+1,2),nx-1,ny);




%% Create fullscreen figure and set a double-buffer
figure('units','normalized','outerposition',[0 0 1 1]);
set(gcf,'doublebuffer','on');

tic; 

Fz_1D_r = zeros(nx_b-1, 1);
Fz_r1 = zeros(nx-2, ny-2);
Fz_r = zeros(nx-2, ny-2);
Tz_r = zeros(nx-2, ny-2);

Gy_r = zeros(nx-1, ny);
Gx_r = zeros(nx, ny-1);
Gx_r1 = zeros(nx, ny-1);
Gy_r1 = zeros(nx-1, ny);


%% Main FDTD UPML routine with TF/SF excitation interface calculates TE and
%% TM modes simultaneously
for T = 1:number_of_iterations
    %% Calculate incident 1D plain waves for TF/SF implementation
    % TE mode (Hz)
    for i = mmm:nx_b
        Ey_1D(i) = k_Ey_a(i)*Ey_1D(i) ...
                  - k_Ey_b(i)*(Hz_1D(i+1)-Hz_1D(i));
    end
    

    Hz_1D(1) = E0*sin(2*pi*f*(T-1)*dt);
    
    for i = mmm+1:nx_b
        Hz_1D(i) = k_Hz_a(i)*Hz_1D(i) ...
                    - k_Hz_b(i)*(Ey_1D(i)-Ey_1D(i-1));
    end

    % TM mode (Ez)  
    for i = mmm:nx_b          
        Hy_1D(i) = k_Hy_a(i)*Hy_1D(i) + ...
		            k_Hy_b(i)*(Ez_1D(i+1)-Ez_1D(i));
    end

    Ez_1D(1) = E0*sin(2*pi*f*(T-1)*dt);
    
    % Fz_1D_r = Fz_1D(2:nx_b);
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
                        
            Hz(i,j) = k_Hz_1_new(i-1,j-1)*Hz(i,j) + ...
                        k_Hz_2_new(i-1,j-1) * ( Wz(i,j)-Fz_r1(i-1,j-1) )/M1(i-1,j-1);
        end
    end
    % Wz(2:nx-1,2:ny-1) = k_Fz_1_new.*Wz(2:nx-1,2:ny-1) + ...
    %                     k_Fz_2_new.*( (Ex(2:nx-1,2:ny-1)-Ex(2:nx-1,1:ny-2))/dy - ...
    %                     (Ey(2:nx-1,2:ny-1)-Ey(1:nx-2,2:ny-1))/dx );
    % Hz(2:nx-1,2:ny-1) = k_Hz_1_new.*Hz(2:nx-1,2:ny-1) + ...
    %                     k_Hz_2_new.*( Wz(2:nx-1,2:ny-1)-Fz_r1 )./M1;


    % TM: Fz -> Tz -> Ez          
    % //////////////////////////////////////////////// label 2  
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
        end
    end

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

    %% Calculate Hy and Ey total fields 
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

    %% Calculate scattered field Hx and Ex in TF/SF
    % TE mode
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
    for j = j
        Hy(i,j) = Hy(i,j) + ...
            dt/(mu_0*dx*Material(Index(i,j)+1,2))*Ez_1D(nx_b-nx_a+2);
    end

    %% Plot Ez and Hz fields dynamics
    if (mod(T,8) == 0)
    subplot(1,2,1);    
	pcolor(Y(pml_width:ny-pml_width),X(pml_width:nx-pml_width),Ez(pml_width:nx-pml_width,pml_width:ny-pml_width));
	shading interp;
	caxis([-E0 E0]);
	axis image;
	colorbar;
	title('E_{z}(x,y)', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	xlabel('x, [m]', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
	ylabel('y, [m]', 'FontSize',18, 'FontName', 'Arial', 'FontWeight', 'Bold');
    subplot(1,2,2);    
	pcolor(Y(pml_width:ny-pml_width),X(pml_width:nx-pml_width),Hz(pml_width:nx-pml_width,pml_width:ny-pml_width));
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
