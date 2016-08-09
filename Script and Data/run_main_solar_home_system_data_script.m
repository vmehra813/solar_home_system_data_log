%% Main Script for Household Electricity Data Consumption 

clc;
clearvars;

%% SELECT HOUSE NUMBER
% 2,3,4 are only used here for house_number
house_number = 4;
%house_string = strcat('House_',num2str(house_number),' October 2015.csv');
house_string = strcat('House_',num2str(house_number),'_January_2016.csv');
house_date_time_str = strcat('House_',num2str(house_number),'_DT.mat');
date_str = strcat('House_',num2str(house_number),'_Day');
time_str = strcat('House_',num2str(house_number),'_Time');



%% INPUT DATA
%NOTE: ALL OF THE SPREADSHEETS ARE DIFFERENT SIZES
%house 1-5 range of data in eload.powercel
%house_range = {'A18:H161454','A18:H161420', 'A18:H161411', 'A18:H161429', 'A18:H161401'};
%sheet_name = strcat('House_',num2str(house_number),' October 2015.csv');

start_row = 17;
width_data = 7;

%house_rng = [161454 161419 161410 161428 161395];
% start time and end time, each data point is one minute
% house 2 : 161403 readings
%went one less than final row in excel spreadsheet

%house_range = {'A18:H319751','A18:H319772', 'A18:H319700', 'A18:H319729', 'A18:H319730'};
house_range = {'A18:H319751','A18:H319772', 'A18:H319700', 'A18:H154569', 'A18:H319730'};
%for house 4, need to stitch together.
%march-june 2016, versus june-feb 

sheet_name = strcat('House_',num2str(house_number),'_January_2016.csv');

%house_rng = [319751 319772 319700 319729 319730];
house_rng = [319751 319772 319700 154569 319730];


datalog=csvread(house_string, 1,1,[17 1 house_rng(house_number) 7]);
%remove 0 0 and do 18, 1 for R1 and C1
date_time = load(house_date_time_str);

field = fieldnames(date_time,'-full');
numfields = length(field);

for f= 1:numfields

    thisfield = field{f};
    command = sprintf('%s = date_time.%s',thisfield,thisfield);
    eval(command);
    
end




% total hours
num_readings = length(datalog); % readings are minute by minute
total_mins = 60*floor(num_readings/60);
total_hours = total_mins/60;


%house 1 data looks okay // irradiance levels are low
%notes: house 2 sign flipped on PV (not sure about battery, leave as is)
%notes: house 3 battery usage fluctuates between positive and negative
%nicely
%house 4 similar to house 3
% house 5 - pv must be negative, battery values are only one sign? need to
% calibrate zero value
%% Calibrate Data
%data_time_vector = datalog(:,1); %take column -- unused yet.
%[h m s] = hms(datalog(:,1)) second column
%[y m d] = ymd(datalog(:,0)) first column
%use datenum to get a value

%date time values

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


%data_time_vector=data_time_vector(2:end); %trim length to be even mulitple of hours
temperature.vector = datalog(:,2);
temperature.vector=temperature.vector(2:end);
pv.voltage = datalog(:, 3);
pv.voltage=pv.voltage(2:end);
battery.voltage = datalog(:,5);
battery.voltage=battery.voltage(2:end);

% CAN USE BATTERY DATA FOR SOC ESTIMATION!

pv.current = datalog(:,4);
pv.current=pv.current(2:end);
battery.current = datalog(:,6);
battery.current = battery.current(2:end);


[slope, zero] = data_log_load_profile_calibration();

pv.current_adj = (pv.current-zero.channel_2(house_number))*slope.channel_2(house_number);
battery.current_adj = (battery.current-zero.channel_4(house_number))*slope.channel_4(house_number);

%% Adjusting for current values less than zero (noise) on pv current only
for k=1:length(pv.current_adj)
    if pv.current_adj(k) < 0
        pv.current_adj(k) = 0;
    end
    
end

%% Calculate Load Values (w/ temp adjustment)

pv.power = pv.voltage.*pv.current_adj;
battery.power = battery.voltage.*battery.current_adj;
load.power = pv.power+battery.power;


for b=1:length(load.power)
    if load.power(b) < 0
        load.power(b) = 0;
    end
    

    
end


%% Calculate Irradiance

addpath('/Users/vmehra813/Dropbox (MIT)/[uLink]/Simulation/MatLab/uLink/Modeling Analysis/TPS');

solar.pv_eff = .15; % efficiency
solar.pv_power = 70; %watts, TPS panel
solar.pv_area = .467; %area of panel m2
solar.cc_eff = 0.95; % charge controller efficiency

solar.irradiance_datalog = zeros(length(load.power),1);

for k=1:length(pv.power)
    
    solar.irradiance_datalog(k) = pv.power(k)./(solar.pv_eff*solar.pv_area);
    
end



%% Adjust for Spillage


load.spillage = zeros(length(load.power),1);

fan_spillage = 14; %mean power consumption of fan
sigma_fan_spillage = .15*fan_spillage;

%fan_95_ci = [fan_spillage-1.96*sigma_fan_spillage, fan_spillage + 1.96*sigma_fan_spillage];
fan_95_ci = [12, 16];

for c=1:length(load.power)
    %if load.power(c) < 11.5
    if solar.irradiance_datalog(c) > .05 && (load.power(c) < fan_95_ci(1) || load.power(c) > fan_95_ci(2))
        load.spillage(c) = load.power(c);
        load.power(c) = 0;
        
    elseif load.power(c) < fan_95_ci(1)
        load.spillage(c) = load.power(c);
        load.power(c) = 0;
        
    end
    %end
    
   
end

    
    figure;
    plotyy(date.ymd_hms(1:end-1),solar.irradiance_datalog,date.ymd_hms(1:end-1),load.power);
    legend('Solar Irradiance, Calculated','Load+Spillage');
    xlabel('Time');
    ylabel('Watts/M2 and Watts');
    
    figure;
    %plotyy(date.ymd_hms,solar.irradiance_datalog,date.ymd_hms,load.spillage);
    plot(date.ymd_hms(1:end-1),solar.irradiance_datalog);
    hold on;
    plot(date.ymd_hms(1:end-1),load.spillage);
    plot(date.ymd_hms(1:end-1),load.power,'c');
    legend('Solar Irradiance, Calculated','Spillage','Load');
    xlabel('Time');
    ylabel('Watts/M2 and Watts');
    















