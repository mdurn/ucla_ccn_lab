% 2011 Michael Durnhofer, mdurn@ucla.edu


%% set parameters
rootdir = pwd;
% KEYBOARD_DEVICE             = FindKeyboard    ;
par.ITI                     = 0.25            ;
par.bgcolor                 = 128             ;
par.timeout                 = 999          ; % 1


%% Get subject initials and make ID
% warning!!! If the same subject initials are used in the same day (for the
% same task & run), the previously recorded files will be overwritten!!!

par.DEBUG          = true;
par.ramptime       = 0.5;
par.stimtime       = 5.5;
par.numruns        = 1;
par.expname        = 'recall';
par.bgcolor        = 126;
par.nimages        = 14;
par.imagetime       = 0.125; % 1
par.initfix        = 5; % 10
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

filename = [par.expname '_' subject '_survey'];
fid = fopen(filename);


%% Load the Questions
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
list1 = importdata('list1');
list2 = importdata('list2');
list3 = importdata('list3');
list4 = importdata('list4');

i=1;
for j=1:length(list1.textdata)
    total_list{i} = list1.textdata{j};
    total_list_num(i) = list1.data(j);
    i = i+1;
end
for j=1:length(list2.textdata)
    total_list{i} = list2.textdata{j};
    total_list_num(i) = list2.data(j);
    i = i+1;
end
for j=1:length(list3.textdata)
    total_list{i} = list3.textdata{j};
    total_list_num(i) = list3.data(j);
    i = i+1;
end
for j=1:length(list4.textdata)
    total_list{i} = list4.textdata{j};
    total_list_num(i) = list4.data(j);
    i = i+1;
end

%% set up the condition order
list_len = length(total_list);
total_list_order(1:list_len,1)=randperm(list_len);

useqs=144; % use 144 questions...this variable looks useless


%% set up the screen
w = SetUpTheScreen;

%% show introduction
% Screen 1
Screen('TextSize',w,24);
Screen(w,'FillRect',par.bgcolor);
introtext=['In this experiment, you will respond to several words. \n \n' ... 
    'For each image, please try to respond accurately when the word appears.. \n \n' ...
    'Press any key.'];
DrawFormattedText(w,introtext,'center','center',0);
Screen('Flip',w);
GetKeyWithTimeout(999);

samedif=[0 1 2];

introtext = ['For each word, you may respond with the following\n\n' ...
    'to indicate if you recall seeing the word in the experiment:\n\n'];
introtext = [introtext '     NO               or             YES     \n'];
introtext = [introtext     '      F                                J      '];
DrawFormattedText(w, introtext, 'center', 'center', 0);
Screen('Flip',w);
GetKeyWithTimeout(999);


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
    
    while i<list_len+1
        
        cnt=cnt+1;
        
        thisword=total_list{total_list_order(i)};
        DrawFormattedText(w, thisword, 'center', 'center', 0);
        onset=GetSecs;
        Screen('Flip',w);
        [choice,RT] = GetKeyWithTimeout(par.timeout);
        
        
        switch choice
            case 'f'
                choicenum = samedif(1);
            case 'j'
                choicenum = samedif(2);
            case 'q'
                disp 'erroring out';
                GiveBackTheScreen;
            otherwise
                choicenum = -1;
        end
        
        correct_resp=0;
        if (choicenum == 1 && (total_list_num(total_list_order(i)) == self_list_num || total_list_num(total_list_order(i)) == syll_list_num))
            correct_resp=1;
        end
        if (choicenum == 0 && (total_list_num(total_list_order(i)) ~= self_list_num && total_list_num(total_list_order(i)) ~= syll_list_num))
            correct_resp=1;
        end

        
        RTs(cnt).word             = thisword;
        RTs(cnt).wordlist         = total_list_num(total_list_order(i));
        RTs(cnt).correct          = correct_resp;
        RTs(cnt).response         = choicenum;
        RTs(cnt).answer           = choicenum~=2;
        RTs(cnt).choice           = choice;
        RTs(cnt).onset            = onset;
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
    save(filename,'RTs');
end

%% write out data file
useqs(:,3:4)=useqs(:,3:4); 
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
save(filename,'RTs');
