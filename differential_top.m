clear;clc;
%% Simulation Variables
Tfinal = 10; % ms s?
dt = 0.001; % ms  s?
Nt = ceil(Tfinal/dt); % 4000 steps
cable_length = 4; % cm
length_unit_ratio = 10000.0; % cm/um
node_length = 30./length_unit_ratio; % um to cm, must >= 30um
fiber_r = 1.5/length_unit_ratio; % 1, um to cm
total_nodes = ceil(cable_length/node_length); % 1334 nodes

%% Excitation Initiation Parameters
i_stim = 2e-3; % uA
stim_loc = 0.05; % cm
node_stim_loc = round(stim_loc/cable_length*total_nodes); % 3rd node
I_stim = zeros(total_nodes,Nt); 
T_stim_dur = 0.5; % ms
T_stim_on = 0.05; % ms
this_t = 0;
for i = 1:Nt
    if this_t > T_stim_on && this_t < T_stim_on+T_stim_dur
        I_stim(node_stim_loc,i) = i_stim./(2*pi*fiber_r*node_length);
    end
    this_t = this_t + dt;
end

%% Constants
R = 8310; T = 293; F = 96485;
Cl_e = 2.7; Cl_i = 20;  % mM, E_Cl = 50.5332 mV
K_e = 0.25; K_i = 120; % mM, E_K = -155.7975 mV
Ca_e = 0.5; Ca_i0 = 1e-4; % mM, E_Ca = 107.47 mV;
PMax_Cl = 8e-3; % PMax_Cl = 8e-3;
PMax_K = 1.2e-3; % PMax_K = 1.2e-3;
PMax_Ca = 1e-3; % PMax_Ca = 1e-3;
VL = 0.03; % mV
Cm = 1; % uF/cm^2
sigma = 100; % 10.0; % mS/cm, conductivity 
KK =  3.7e-3; %8e-3; % mM
%% Calcium Dynamics Parameters
r_ER = 0.185; % ratio of endoplasmic reticulum (ER) volume to cytoplasmic volume
g00 = 0.1; % s-1, permeability of Ca2+ store in absence of IP3
g11 = 20.5; % s-1, density of IP3 activated channels
pb11 = 8; % uM.s-1, Hill coefficient p1'
pb22 = 0.065; % uM.s-1, Hill coefficient p2'
c00 = 1.56; % uM, average calcium concentration
k11 = 12.0; % (uM.s)-1,rate constant 
kb22 = 15.0; % k2', rate constant
kb33 = 1.8;  % k3', rate constant
km11 = 8.0; % k-1, rate constant
km22 = 1.65; % k-2, 
km33 = 0.04; % k-3, 
IP3_0 = 2.5;  % 2.5uM, IP3 initial concentration
k22 = kb22*c00; k33 = kb33*c00; % rate constant
x1_0 = 0.0162721; x2_0 = 1.0; x3_0 = 0.0; x4_0 = 0.0; x5_0 = 0.0;
p11 = pb11/c00; p22 = pb22/c00;
% aa = Ca_i0/x1_0; % 0.006145488289772

%% Initial Values
V0 = 0; % mV
Er = -120; % mV
Vm0 = V0+Er;
an = 0.02*(V0-35)/(1-exp((35-V0)/10));
bn = 0.05*(10-V0)/(1-exp((V0-10)/10));
n0 = an/(an+bn);
ah = 0.1*(-10-V0)./(1-exp((V0+10)/6));
bh = 4.5./(1+exp((45-V0)/10));
h0 = ah/(ah+bh);
am = 0.36*(V0-18)./(1-exp((18-V0)/3));
bm = 0.4*(13-V0)./(1-exp((V0-13)/20));
m0 = am/(am+bm);
u20 = Vm0*F/(R*T);
u0 = exp(u20);
PK = PMax_K*n0^2;
IK = PK*F*u20.*(K_e-K_i*u0)./(1-u0);
A = Ca_i0^2./(KK^2+Ca_i0^2);
PCl = PMax_Cl*m0*h0;
ICl = A*PCl*F*u20.*(Cl_i-Cl_e*u0)./(1-u0);
kp1 =  3.1; 
kn1 = 3.7e2; 
kp2 = 2.58*u0./(1-exp(-u0));
kn2 = 2.17e-2*u0.*exp(-u0)./(1-exp(-u0));
IH = 1000*(kp1*kp2 - kn1*kn2)./(kp1+kn1+kp2+kn2);
ahCa = 0.1*(-10-V0)./(1-exp((V0+10)/6));
bhCa = 4.5./(1+exp((45-V0)/10));
amCa = 0.36*(V0-30)./(1-exp((30-V0)/3));
bmCa = 0.4*(13-V0)./(1-exp((V0-13)/20));
hCa0 = ahCa./(ahCa+bhCa);
mCa0 = amCa./(amCa+bmCa);
PCa = PMax_Ca*mCa0*hCa0;
ICa = 4*PCa*F*u0*(Ca_e - Ca_i0*exp(2*u0))./(1-exp(2*u0)); % 0.003555259649236
gL = (IK + ICl + IH + ICa)/VL;

%% Dependent Variables Initialization
V = V0.*ones(total_nodes,1);
m = m0.*ones(total_nodes,1); 
h = h0.*ones(total_nodes,1); 
n = n0.*ones(total_nodes,1); 
hCa = hCa0.*ones(total_nodes,1); 
mCa = mCa0.*ones(total_nodes,1); 
x1 = x1_0.*ones(total_nodes,1); 
x2 = x2_0.*ones(total_nodes,1); 
x3 = x3_0.*ones(total_nodes,1); 
x4 = x4_0.*ones(total_nodes,1); 
x5 = x5_0.*ones(total_nodes,1); 

data_Vm = zeros(total_nodes,Nt);
data_Vm(:,1) = Vm0;
data_Imem = zeros(total_nodes,Nt);

a = dt/Cm;
b = fiber_r*sigma/2/node_length^2;
for tt = 1:Nt-1
    Vm = V+Er;
    u2 = Vm*F/(R*T);
    u = exp(u2);
    PCl = PMax_Cl*m.*h;
    Ca_i = 0.1*(x1-x1_0)+Ca_i0;
    A = Ca_i.^2./(KK^2+Ca_i.^2);
    ICl = A.*PCl*F.*u2.*(Cl_i-Cl_e*u)./(1-u);
    PK = PMax_K*n.^2;
    IK = PK*F.*u2.*(K_e-K_i*u)./(1-u);
    IL = gL*(V-VL);
    kp2 = 2.58*u./(1-exp(-u));
    kn2 = 2.17e-2*u.*exp(-u)./(1-exp(-u));
    IH = 1000*(kp1.*kp2 - kn1.*kn2)./(kp1+kn1+kp2+kn2);
    PCa = PMax_Ca*mCa.*hCa;
    ICa = 4*PCa*F.*u.*(Ca_e - Ca_i.*exp(2*u))./(1-exp(2*u));
    I_ion = ICl+IK+IL+IH+ICa;
    
    IP3 = IP3_0./(1+exp((ICa+0.8e-2)/1e-3));
    x1 = x1 + dt*((1+r_ER)*(g00+g11*x4).*(1-x1)-(p11*x1.^4./(p22^4+x1.^4)));
    x2 = x2 + dt*(-k11*IP3.*x2+km11*x3);
    x3 = x3 + dt*(-(km11+k22*x1).*x3+k11*IP3.*x2+km22*x4);
    x4 = x4 + dt*(k22*x1.*x3+km33*x5-(km22+k33*x1).*x4);
    x5 = x5 + dt*(k33*x1.*x4-km33*x5);  

    an = 0.008*(V-35)./(1-exp((35-V)/6));
    bn = 0.02*(10-V)./(1-exp((V-10)/6));   
    ah = 0.1*(-30-V)./(1-exp((V+30)/6));
    bh = 4.5./(1+exp((45-V)/10));  % sensitive parameter
    am = 0.36*(V-18)./(1-exp((18-V)/3));
    bm = 0.5*(15-V)./(1-exp((V-15)/20));
    ahCa = 0.1*(-10-V)./(1-exp((V+10)/6));
    bhCa = 4.5./(1+exp((45-V)/10));
    amCa = 0.36*(V-30)./(1-exp((30-V)/3));
    bmCa = 0.4*(13-V)./(1-exp((V-13)/20));
    n = n + dt*(an.*(1-n)-bn.*n);
    h = h + dt*(ah.*(1-h)-bh.*h);
    m = m  + dt*(am.*(1-m)-bm.*m); 
    hCa = hCa + dt*(ahCa.*(1-hCa)-bhCa.*hCa);
    mCa = mCa + dt*(amCa.*(1-mCa)-bmCa.*mCa);

    V(1) = V(1)+a*(I_stim(1,tt)-I_ion(1)+b*(V(2)-V(1)));
    for ii = 2:1:total_nodes-1
        V(ii) = V(ii) + a*(I_stim(ii,tt) - I_ion(ii) + b*(V(ii+1)-2*V(ii)+V(ii-1)));
    end
    V(total_nodes) = V(total_nodes-1);
    data_Vm(:,tt+1) = V + Er;   
    data_Imem(:,tt+1) = I_ion;
%     for x = 1:4
%         x_loc = 0.01*x; % cm
%         for y = 1:7
%             x_loc = 2e-2; % cm
%             y_loc = 1 + 0.1*y;
%             dscale = 4*pi*sigma*sqrt(x_loc^2+(y_loc-ycenter).^2);
%             phi(x,y,tt+1) = sum(I_ion./dscale);
%         end
%     end
end

%% Reduce data size and plot transmembrane potential
[X, Y] = meshgrid((0:dt:Tfinal-dt),(0:node_length:cable_length));
new_t = 0:20*dt:Tfinal-dt;
new_x = 0:2*node_length:cable_length;
[Xq, Yq] = meshgrid(new_t,new_x);
data_Vm_2 = interp2(X,Y,data_Vm,Xq,Yq);
figure(1);
tt = [0 10]; 
xx = [0 4];
% imagesc(tt, xx, data_Vm_2);
% xlabel('Time (s)'); ylabel('Length (cm)');
% ax2 = gca;
% ax2.FontSize = 30;
% ax2.PlotBoxAspectRatio = [1 1 1];
% ax2.LineWidth = 1.5;
% ax2.TickDir = 'out';
% ax2.YTick = 0:1:4;

%% Differential 1-6 electrode------stimulate before 1, ref is 6-----10-1 before 1 6_ref
data_Iex = diff(data_Vm_2);
distance = new_x(1:end-1);
electrode_number = 7;
electrode_start = 2;  % cm 
electrode_separation = 0.12; % cm
ref_e_position = electrode_start + (electrode_number+1)*electrode_separation; % cm
electrode_signal = zeros(size(data_Iex,2),electrode_number);
decay_coefficient = ones(size(data_Iex));
decay_start = 7;
for i = 1:size(decay_coefficient,2)
    if new_t(i) > decay_start
        decay_coefficient(:,i) = 0.5*exp(-(new_t(i)-decay_start)/4);
    end
end
% surf(decay_coefficient,'EdgeColor','none');
data_Iex2 = data_Iex.*decay_coefficient;
for i = 1:electrode_number
    electrode_position = electrode_start + i*electrode_separation;
    electrode_position_next = electrode_position + electrode_separation;
    lead_field = (distance>electrode_position).*(distance<electrode_position_next);
    electrode_signal(:,i) = lead_field*data_Iex2;
end
trim_start = 80;
electrode_signal_2 = electrode_signal(trim_start:trim_start+299,:);
electrode_signal_t = linspace(0,6,length(electrode_signal_2));

plot(electrode_signal_t, electrode_signal_2,'LineWidth',2);
lg = legend('1','2','3','4','5','6','7', 'location','southeast'); lg.Box = 'off';
xlabel('Time (s)'); ylabel('Potential (mV)');
ax2 = gca;
ax2.FontSize = 30;
ax2.PlotBoxAspectRatio = [1.3 1 1];
ax2.LineWidth = 1.5;
ax2.TickDir = 'out';
ax2.XLim = [0 6];
% ax2.YLim = [-150 100];

% exportgraphics(gcf, 'differential top sim.pdf','ContentType','vector');