%% Main Script for Inputting, Calibrating, and Visualizing Household Electricity Data Consumption 
% Three households from rural village in Jharkhand, India
% Over the course of >6 months from June 2015 - Jan 2016
% Data sampled at 1 minute intervals
clc;
clearvars;

%% SELECT HOUSE NUMBER
% Options are 2,3,4 only for house_number
house_number = 4;


%% Input Raw Data 

%Create strings to be used in importing data
house_string = strcat('House_',num2str(house_number),'_January_2016.csv');
house_date_time_str = strcat('House_',num2str(house_number),'_DT.mat');
date_str = strcat('House_',num2str(house_number),'_Day');
time_str = strcat('House_',num2str(house_number),'_Time');

%Default setup of .csv file
start_row = 17;
width_data = 7;

%Lengths of datasets in .csv file
house_rng = [319751 319772 319700 154569 319730];

%Read in .csv file
datalog=csvread(house_string, 1,1,[start_row 1 house_rng(house_number) width_data]);
num_readings = length(datalog); % readings are minute by minute


%% Import date/time data
date_time = load(house_date_time_str);
field = fieldnames(date_time,'-full');
numfields = length(field);

for f= 1:numfields

    thisfield = field{f};
    command = sprintf('%s = date_time.%s',thisfield,thisfield);
    eval(command);
    
end

%Date and time values

if house_number == 2
date.ymd = eval(date_str);
date.hms = eval(time_str);

elseif house_number == 3
    date.ymd = date_time.date.ymd;
    date.hms = date_time.date.hms;
    
elseif house_number == 4
    date.ymd = House_4_Day(1:num_readings);
    date.hms = House_4_Time(1:num_readings);
    
    
end


%convert to double values
[date.hour, date.minute] = hms(date.hms);
[date.year, date.month, date.day] = ymd(date.ymd);
date.hour_min = datetime(date.hms,'InputFormat','HH:mm');
date.month_day_year = datetime(date.ymd,'InputFormat','HH:mm');
date.seconds = zeros(length(date.day),1);

CnvtDT = @(date) datetime([date.year  date.month  date.day  date.hour  date.minute date.seconds], 'Format', 'MM/dd/yy HH:mm');
date.ymd_hms = CnvtDT(date);



%% Calibrate Current Data  

temperature.vector = datalog(:,2);
pv.voltage = datalog(:, 3);
battery.voltage = datalog(:,5);
pv.current = datalog(:,4);
battery.current = datalog(:,6);

if house_number == 2 || house_number == 3
    temperature.vector=temperature.vector(2:end);
    pv.voltage=pv.voltage(2:end);
    battery.voltage=battery.voltage(2:end);
    pv.current=pv.current(2:end);
    battery.current = battery.current(2:end);
end


%Values of slope and zero are based on experimental data calibrating
%digital readings of current to current values in Amps
[slope, zero] = data_log_load_profile_calibration();

pv.current_adj = (pv.current-zero.channel_2(house_number))*slope.channel_2(house_number);
battery.current_adj = (battery.current-zero.channel_4(house_number))*slope.channel_4(house_number);

%% Adjusting for current values less than zero on PV current only
for k=1:length(pv.current_adj)
    if pv.current_adj(k) < 0
        pv.current_adj(k) = 0;
    end 
end

%% Calculate Load Values

pv.power = pv.voltage.*pv.current_adj;
battery.power = battery.voltage.*battery.current_adj;
load.power = pv.power+battery.power;

% Removing negative load values 
for b=1:length(load.power)
    if load.power(b) < 0
        load.power(b) = 0;
    end
end

%% Calculate Rough Proxy for Irradiance

% Assumptions 
solar.pv_eff = .15; % efficiency
solar.pv_power = 70; %watts, TPS panel
solar.pv_area = .467; %area of panel m2
solar.cc_eff = 0.95; % charge controller efficiency

solar.irradiance_datalog = zeros(length(load.power),1);

for k=1:length(pv.power) 
    solar.irradiance_datalog(k) = (pv.power(k)./(solar.pv_eff*solar.pv_area))*(1/solar.cc_eff);
end

%% Separate Spillage from Load 

load.spillage = zeros(length(load.power),1);

%Only day-time appliance 
fan_spillage = 14; %mean power consumption of fan, Watts 
sigma_fan_spillage = .1*fan_spillage; %assumption on standard deviation of fan power
ci_90 = 1.645;
ci_95 = 1.96; 

% 90% confidence interval 
fan_90_ci = [fan_spillage-ci_90*sigma_fan_spillage, fan_spillage + ci_90*sigma_fan_spillage];

for c=1:length(load.power)
    
    % if solar irrdiance is above 5 W/m2 and load value is NOT in 90% CI
    % range, classify as spillage
    if solar.irradiance_datalog(c) > .05 && (load.power(c) < fan_90_ci(1) || load.power(c) > fan_90_ci(2))
        load.spillage(c) = load.power(c);
        load.power(c) = 0;
        
   
    elseif load.power(c) < fan_90_ci(1)
        load.spillage(c) = load.power(c);
        load.power(c) = 0;
        
    end
    
end

%% Plotting / Visualization 
 
    figure(1);
    plotyy(date.ymd_hms,solar.irradiance_datalog,date.ymd_hms,load.power);
    legend('Solar Irradiance, Calculated','Load+Spillage');
    xlabel('Date & Time');
    ylabel('Watts/M2 and Watts');
    set(gca,'fontsize',12);
    title(strcat('House ',{' '},num2str(house_number),{' '},'June-Jan Irradiance, Load & Spillage'));

    
    figure(2)
    plot(date.ymd_hms,load.power,'c');
    legend('Load');
    xlabel('Date & Time');
    ylabel('Watts/M2 and Watts');
    set(gca,'fontsize',12);
    title(strcat('House ',{' '},num2str(house_number),{' '},'June-Jan Load Profile'));
    
    
    
    figure(3);
    plotyy(date.ymd_hms, battery.voltage,date.ymd_hms,battery.current_adj);
    xlabel('Date & Time');
    legend('Voltage','Current');
    set(gca, 'fontsize',12);
    title(strcat('House ',{' '},num2str(house_number),{' '},'June-Jan Battery Discharging/Charging Cycles'));
   % Note that house 4 has a few transients in voltage/current
    
    
    figure(4);
    plot(date.ymd_hms, battery.power);
    hold on;
    plot(date.ymd_hms, pv.power);
    plot(date.ymd_hms, load.power);
    plot(date.ymd_hms, load.spillage);
    legend('Battery','Solar','Load','Spillage');
    xlabel('Date & Time');
    ylabel('Watts');
    title(strcat('House ',{' '},num2str(house_number),{' '},'June-Jan All Variables'));


    
%% Other notes 
    
% Note that other appliances in each household were 4x9W CFL's
% Battery capacity is 75Ah













