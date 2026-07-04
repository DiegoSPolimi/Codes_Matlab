function qMean = meanQuaternion(Q)

Q = Q./vecnorm(Q,2,2);

A = zeros(4);

for i=1:size(Q,1)

    q = Q(i,:)';

    A = A + q*q';

end

[V,D]=eig(A);

[~,idx]=max(diag(D));

qMean = V(:,idx);

qMean=qMean';

end