function [ slope, zero ] = data_log_load_profile_calibration()
%takes calibaration data from data logger and converts

% calibration slope for 3 amps
slope.channel_2 = [ -0.0190226, -0.0181098, -0.018034, -0.0184049, 0.0185455]; 
slope.channel_4 = [ 0.017730, -0.01779, -0.01845, -0.018519, 0.018765];

zero.channel_2 = [32766, 32786, 32776, 32771, 32774];
zero.channel_4 = [32775, 32785, 32777, 32771, 32775];

%32771 house 3 channel 2 zero original
%32774 house 3 channel 4 zero original
%+ battery current means discharging; - means charging

%house 1, 32773 channel 2 zero original


%house 2, 32776 channel 2 zero original
%house 2, 32773 channel 4 zero original
%house 3: + battery current means discharging ; - means charging


%house 4, 32772 channel 2 zero original (didnt change)
%house 4, 32772 channel 4 zero original (didnt change)

end

