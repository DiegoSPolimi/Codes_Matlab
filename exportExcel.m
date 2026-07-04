function exportExcel(time,Joint,JointName)

T = table;

T.Time = time(:);

T.FlexExt = Joint.FlexExt(:);

if isfield(Joint,'AbdAdd')

    T.AbdAdd = Joint.AbdAdd(:);

end

if isfield(Joint,'VarusValgus')

    T.VarusValgus = Joint.VarusValgus(:);

end

if isfield(Joint,'IntExt')

    T.IntExt = Joint.IntExt(:);

end

filename = [JointName '_Angles.xlsx'];

writetable(T,filename);

fprintf('%s exported.\n',filename)

end