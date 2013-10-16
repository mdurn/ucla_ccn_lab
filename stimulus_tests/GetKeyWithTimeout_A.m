function [choice,RT, baseTime] = GetKeyWithTimeout_A(inputDevice, timeout)
% RT = GetSameDiff(timeout,allowedkeys)
%
% waits for a response, and returns the choice and RT when it gets it
% or returns -999,-999 if timeout seconds pass
%
% 2011 Michael Durnhofer, mdurn@ucla.edu

baseTime = GetSecs;
RT=-999;
choice=-999;

gotgood=false;
while ~gotgood
    % while no key is pressed, wait until timeout is reached


    %    while ~KbCheck(KEYBOARD_DEVICE)
    if (GetSecs-baseTime) > timeout
        choice=-999;
        RT=-999;
        return
    end
    %    end

    % got here? a key is down! retrieve the key and RT
    [keyIsDown, secs, keyCode] = KbCheck(inputDevice); %Changed by wei: from KEYBOARD_DEVICE to allowedkeys
    if ((keyIsDown))%Changed by wei, so that we can get out of the loop
        gotgood=true;
    end
end
RT = secs - baseTime;

choice = find(keyCode);

% 
% % do not pass control back until the key has been released
% while KbCheck_A(KEYBOARD_DEVICE)
%     WaitSecs(0.001);
% end
end
