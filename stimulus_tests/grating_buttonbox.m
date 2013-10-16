% 2011 Michael Durnhofer, mdurn@ucla.edu

KbName('UnifyKeyNames');

%% device for button presses
fprintf('\n\n===============');
fprintf('\nCHOOSE DEVICE FOR SUBJECT RESPONSES:')
fprintf('\n===============\n');
inputDevice = hid_probe;        
fprintf('\n\n')

fprintf('\n\n===============');
fprintf('\nEXPERIMENTER RESPONSE - CHOOSE DEVICE:')
fprintf('\n===============\n');
experimenter_device = hid_probe;
fprintf('\n')

%% which run?
run_number = input('Enter run number (1 or 2)?');
verbose=0;

%% set parameters
rootdir = pwd;
% KEYBOARD_DEVICE             = FindKeyboard    ;
par.ITI                     = 0.25            ;
par.bgcolor                 = 128             ;
par.timeout                 = 1.875               ; % 1


%% Get subject initials and make ID
% warning!!! If the same subject initials are used in the same day (for the
% same task & run), the previously recorded files will be overwritten!!!

par.DEBUG          = true;
par.ramptime       = 0.5;
par.stimtime       = 5.5;
par.numruns        = 1;
if (run_number == 1)
    par.expname = 'grating1';
elseif (run_number == 2)
    par.expname = 'grating2';
else
    fprintf('\nInvalid Run Number!')
    return
end

par.bgcolor        = 126;
par.nimages        = 14;
par.imagetime       = 0.125; % 1
par.initfix        = 10; % 10
par.interfix       = 2; % 2
PsychJavaTrouble;

% Connect, Sync, start recording in Net Station
%NetStation('Connect', '10.44.186.15', 55513);
%NetStation('Synchronize');
%NetStation('StartRecording');

subject = subjectid(input('subject initials? ','s'));
filename = sprintf('%s_%s.txt',par.expname,subject);
fid = fopen(filename);
if fid ~= -1
    fclose(fid);
    disp 'warning, subject already exists ... C-c now or file will be overwritten';
    disp 'otherwise press enter to continue';
    pause;
end

filename = [par.expname '_' subject '_survey.txt'];
fid = fopen(filename);


%% set up the condition order
useqs=60; % use 60 questions...this variable looks useless
conditions=[ 2 2 2 2 2 1 1 1 2 1 1 2 1 1 2 1 2 1 2 2 1 2 1 2 2 2 2 1 1 2 1 1 1 2 1 1 2 1 1 2 2 1 1 1 1 2 2 1 2 2 1 2 2 1 2 2 2 1 1 1 ];
tr_mult=   [ 3 3 2 5 2 4 2 4 3 6 4 5 2 2 3 6 4 6 3 6 4 5 5 6 5 4 2 3 6 4 3 5 6 2 3 4 2 2 2 3 4 5 5 6 6 5 4 5 4 6 6 3 3 6 2 5 2 3 5 4 ];
task_length=length(conditions);
cond_order(1:task_length,1)=randperm(task_length);

%% set up the screen
w = SetUpTheScreen;

%% build gratings
white = WhiteIndex(w); % pixel value for white
black = BlackIndex(w); % pixel value for black
gray = (white+black)/2;
inc = white-gray;
[x,y] = meshgrid(-100:100, -100:100);
horiz = exp(-((x/50).^2)-((y/50).^2)) .* cos(0.03*2*pi*y);
vert = exp(-((x/50).^2)-((y/50).^2)) .* cos(0.03*2*pi*x);

%% show introduction
% Screen 1
Screen('TextSize',w,24);
Screen(w,'FillRect',par.bgcolor);
introtext=['In this experiment, you will respond to several images. \n \n' ... 
    'For each image, please try to respond accurately when ? appears.. \n \n' ...
    'Press any key.'];
DrawFormattedText(w,introtext,'center','center',0);
Screen('Flip',w);

[choice,RT, baseTime] = GetKeyWithTimeout_A(inputDevice, par.timeout);

samedif=[0 1 2];

introtext = ['For each image, you may respond:\n\n'];
introtext = [introtext '   HORIZONTAL     or     VERTICAL   \n\n'];
introtext = [introtext     '       A                        B       '];
DrawFormattedText(w, introtext, 'center', 'center', 0);
Screen('Flip',w);
noresp=1;

%% Trigger - comment out to test without scanner  
KbTriggerWait(KbName('5%'),inputDevice);
DisableKeysForKbCheck(KbName('5%'));

%% Initial Fixation
useqs=zeros(useqs,4);
count=zeros(4,1);

onset = 0;

crx=('+');
DrawFormattedText(w, crx, 'center', 'center', 0);
Screen('Flip',w);
WaitSecs(par.initfix);

%% show the stimuli and get RTs
cnt=0;
marc=10;
Screen('TextSize',w,44);
try
    RTs = [];
    cnt=0;
    i=1;
    while i<61
        
        if conditions(cond_order(i)) == 1
            m = horiz;
        else
            m = vert;
        end
        Screen(w, 'PutImage', gray+inc*m)
        Screen('Flip',w);
        WaitSecs(par.imagetime);
        
        cnt=cnt+1;

        crx=('?');
        DrawFormattedText(w, crx, 'center', 'center', 0);
        Screen('Flip',w);

	    [choice,RT, baseTime] = GetKeyWithTimeout_A(inputDevice, par.timeout);


        if RT ~= -999
            WaitSecs(par.timeout - RT);
        end
        
        crx=('+');
        DrawFormattedText(w, crx, 'center', 'center', 0);
        Screen('Flip',w);
        WaitSecs(par.interfix*tr_mult(cond_order(i)));
        

        switch choice
            case 30
                choicenum = samedif(1);
            case 31
                choicenum = samedif(2);
            case 'q'
                disp 'erroring out';
                GiveBackTheScreen;
            otherwise
                choicenum = -1;
        end

        RTs(cnt).quest            = conditions(cond_order(i));
        RTs(cnt).subject          = 0;
        RTs(cnt).response         = choicenum;
        RTs(cnt).answer           = choicenum~=2;
        RTs(cnt).choice           = choice;
        RTs(cnt).onset            = baseTime;
        RTs(cnt).RT               = RT;

        Screen('Flip',w);
        
        i=i+1;
        
        
        % Send event to Net Station
        %if RTs(cnt).response == 0
		%	resp_code = '0#';
		%elseif RTs(cnt).response == 1
		%	resp_code = '1#';
		%else
		%	resp_code = 'none';
        %end
		%NetStation('Event', resp_code, RTs(cnt).onset, RTs(cnt).RT);
    end
catch
    disp 'erroring out';
    GiveBackTheScreen;
    rethrow(lasterror);
    WriteStructsToText(filename,RTs);
end

%% write out data file
useqs(:,3:4)=useqs(:,3:4); %% Fix indexing for belief/disbelief questions
GiveBackTheScreen;

% Send Events to NetStation
%for i=1:cnt
%	resp_code = 'none';
%	if RTs(i).response == 0
%		resp_code = '0#';
%	elseif RTs(i).response == 1
%		resp_code = '1#';
%	else
%		resp_code = 'none';
%	end
%	NetStation('Event', resp_code, RTs(i).onset, RTs(i).RT);
%end

%NetStation('StopRecording');
%NetStation('Disconnect');
WriteStructsToText(filename,RTs);
