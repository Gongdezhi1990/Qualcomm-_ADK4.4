%--------------------------------------------------------------------------
% Copyright (c) 2015 Qualcomm Technologies International, Ltd.
%--------------------------------------------------------------------------
% create FIR filter coefficients for use in my_second_dsp_app
% uses 'fir1()' which is part of the signal processing toolbox
%--------------------------------------------------------------------------

function create_fir_coefs()

    command = 'b = fir1(110,0.1,''high'');';
    
    % create and plot filter
    eval(command);
    plot(b);
    figure;
    freqz(b,1);
    
    % create data file for use in kalimba code
    fid=fopen('fir_coefs.dat','w');
    fprintf(fid,'// filter coefficients for use in my_second_dsp_app\n');
    fprintf(fid,'// created in matlab using : %s\n',command);
    for i = 1:length(b-1)
        fprintf(fid,'%12.9f',b(i));
        if (i ~= length(b))
            fprintf(fid,',\n');
        else
            fprintf(fid,'\n');
        end
    end
    fclose(fid);

end
