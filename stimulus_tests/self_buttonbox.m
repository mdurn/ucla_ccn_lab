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

%% which run? run 1 also creates the list for run 2
run_number = input('Enter run number (1 or 2)?');
verbose=0;

%% set parameters
rootdir = pwd;
% KEYBOARD_DEVICE             = FindKeyboard    ;
par.ITI                     = 0.25            ;
par.bgcolor                 = 128             ;
par.timeout                 = 6               ; % 6

%% Get subject initials and make ID
% warning!!! If the same subject initials are used in the same day (for the
% same task & run), the previously recorded files will be overwritten!!!

par.DEBUG          = true;
par.ramptime       = 0.5;
par.stimtime       = 5.5;
par.numruns        = 1;
if (run_number == 1)
    par.expname = 'self1';
elseif (run_number == 2)
    par.expname = 'self2';
else
    fprintf('\nInvalid Run Number!')
    return
end

par.bgcolor        = 126;
%par.nimages        = 14;
par.wordtime       = 6; % 6 
par.typetime       = 2; % 2
par.initfix        = 10; % 10
par.interfix       = 2; % 2
par.endfix         = 14; % 14
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

filename = [par.expname '_' subject '_survey'];
fid = fopen(filename);


%% Load the word lists
if (run_number == 1)
    self_list_num = input('Enter the list number to use for the self task (1,2,3,4):');
    while (self_list_num < 1 || self_list_num > 4)
        fprintf('\nInvalid number!\n')
        self_list_num = input('Enter the list number to use for the self task (1,2,3,4):');
    end
    syll_list_num = input('Enter the list number to use for syllable task (1,2,3,4):');
    while (syll_list_num < 1 || syll_list_num > 4)
        fprintf('\nInvalid number!\n')
        syll_list_num = input('Enter the list number to use for the syll task (1,2,3,4):');
    end
    while (self_list_num == syll_list_num)
        fprintf('\nList numbers for self and syllables tasks must be different!\n')
        self_list_num = input('Enter the list number to use for the self task (1,2,3,4):');
        syll_list_num = input('Enter the list number to use for syllable task (1,2,3,4):');
    end
    
    if (self_list_num == 1)
        selfstruct = importdata('list1');
    elseif (self_list_num == 2)
        selfstruct = importdata('list2');
    elseif (self_list_num == 3)
        selfstruct = importdata('list3');
    else
        selfstruct = importdata('list4');
    end
    
    if (syll_list_num == 1)
        syllstruct = importdata('list1');
    elseif (syll_list_num == 2)
        syllstruct = importdata('list2');
    elseif (syll_list_num == 3)
        syllstruct = importdata('list3');
    else
        syllstruct = importdata('list4');
    end
    
    %% Randomize the order for self and syll lists
    % each run gets half of each list
    list_len = length(selfstruct.textdata);
    self_order(1:list_len,1)=randperm(list_len);
    syll_order(1:list_len,1)=randperm(list_len);
    
    for i=1:list_len/2
        self1.textdata(i) = selfstruct.textdata(self_order(i));
        self1.data(i) = selfstruct.data(self_order(i));
        syll1.textdata(i) = syllstruct.textdata(syll_order(i));
        syll1.data(i) = syllstruct.data(syll_order(i));
        self2.textdata(i) = selfstruct.textdata(self_order(i+list_len/2));
        self2.data(i) = selfstruct.data(self_order(i+list_len/2));
        syll2.textdata(i) = syllstruct.textdata(syll_order(i+list_len/2));
        syll2.data(i) = syllstruct.data(syll_order(i+list_len/2));
    end
    
    save('self1', 'self1');
    save('self2', 'self2');
    save('syll1', 'syll1');
    save('syll2', 'syll2');
    
    load('self1');
    self = self1;
    load('syll1');
    syll = syll1;
else
    load('self2');
    self = self2;
    load('syll2');
    syll = syll2;
    list_len = length(self.textdata);
end
    
useqs=36; % use 36 questions...this variable looks useless


%% set up the condition order
for i=1:list_len/2
    if (i <= list_len/4)
        conditions(i) = 1;
    else
        conditions(i) = 2;
    end
end
conditions = shuffle(conditions);
conditions = shuffle(conditions);

%% set up the screen
w = SetUpTheScreen;

%% show introduction
% Screen 1
Screen('TextSize',w,24);
Screen(w,'FillRect',par.bgcolor);
introtext=['In this experiment, you will respond to several words. \n \n' ... 
    'For each word, please try to respond accurately.. \n \n' ...
    'Press any key.'];
DrawFormattedText(w,introtext,'center','center',0);
Screen('Flip',w);
status = false;
[choice,RT, baseTime] = GetKeyWithTimeout_A(inputDevice, par.timeout);

samedif=[0 1 2];

introtext = ['For each word, you may respond:\n\n'];
introtext = [introtext '     NO               or             YES     \n'];
introtext = [introtext 'syllables <= 3        or        syllables > 3\n\n'];
introtext = [introtext     '      A                                B      '];
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
cnt=1;
marc=10;
Screen('TextSize',w,44);
try
    RTs = [];
    cnt=1;
    i=1;
    self_count = 1;
    syll_count = 1;
    
    while i<=length(conditions)
        
        if conditions(i) == 1
            crx=('SELF');
            thisframe=self.textdata{self_count};
            list_num=self.data(self_count);
            self_count = self_count+1;
        else
            crx=('SYLLABLES');
            thisframe=syll.textdata{syll_count};
            list_num=syll.data(syll_count);
            syll_count = syll_count+1;
        end
        
        DrawFormattedText(w, crx, 'center', 'center', 0);
        Screen('Flip',w);
        WaitSecs(par.typetime);
        thisword=thisframe;
        DrawFormattedText(w, thisword, 'center', 'center', 0);
        Screen('Flip',w);
            
           
        [choice,RT, baseTime] = GetKeyWithTimeout_A(inputDevice, par.timeout);
        if RT ~= -999
            WaitSecs(par.wordtime-RT);
        end
        
        
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
        RTs(cnt).word             = thisword;
        RTs(cnt).listnum          = list_num;
        RTs(cnt).task             = conditions(i);
        RTs(cnt).response         = choicenum;
        RTs(cnt).answer           = choicenum~=2;
        RTs(cnt).choice           = choice;
        RTs(cnt).onset            = baseTime;
        RTs(cnt).RT               = RT;

        Screen('Flip',w);
        
        crx=('+');
        DrawFormattedText(w, crx, 'center', 'center', 0);
        Screen('Flip',w);
        WaitSecs(par.interfix);
        
        cnt=cnt+1;

        if conditions(i) == 1
            thisframe=self.textdata{self_count};
            list_num=self.data(self_count);
            self_count = self_count+1;
        else
            thisframe=syll.textdata{syll_count};
            list_num=syll.data(syll_count);
            syll_count = syll_count+1;
        end
        
        thisword=thisframe;
        DrawFormattedText(w, thisword, 'center', 'center', 0);
        onset = GetSecs;
        Screen('Flip',w);
           
        [choice,RT, baseTime] = GetKeyWithTimeout_A(inputDevice, par.timeout);
        
        if RT ~= -999
            WaitSecs(par.wordtime-RT);
        end
        
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
        RTs(cnt).word             = thisword;
        RTs(cnt).wordlist          = list_num;
        RTs(cnt).task             = conditions(i);
        RTs(cnt).response         = choicenum;
        RTs(cnt).answer           = choicenum~=2;
        RTs(cnt).choice           = choice;
        RTs(cnt).onset            = baseTime;
        RTs(cnt).RT               = RT;

        Screen('Flip',w);
        
        crx=('+');
        DrawFormattedText(w, crx, 'center', 'center', 0);
        Screen('Flip',w);
        WaitSecs(par.endfix);
        
        i=i+1;
        cnt=cnt+1;
        
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
    save(filename, 'RTs');
end

%% write out data file
useqs(:,3:4)=useqs(:,3:4); %% ?
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
save(filename, 'RTs');
