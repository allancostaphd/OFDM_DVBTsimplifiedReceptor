%% test3.m
% Fichero para obtener la BER de los datos ecualizados en vhdl

close all;

tic
% parametros de la comparación:
L = length(channel(:,1))-1;
if L == 1704
    modo = '2k';
else
    modo = '8k';
end
[n1, n2] = size(channel);
nsimb = min(n1,n2)-1;


if modo == '8k'
    ecR = dlmread('v2ec8kR_VHDL.dat', '\n');
    ecI = dlmread('v2ec8kI_VHDL.dat', '\n');
end
if modo == '2k'
    ecR = dlmread('v2ec2kR_VHDL.dat', '\n');
    ecI = dlmread('v2ec2kI_VHDL.dat', '\n');
end


simbs = ecR+ecI*1i;
figure, stem(abs(simbs(1:L)))
simbs = simbs(1:nsimb*L);
simbs = reshape(simbs, [], nsimb).';
rec = reshape(simbs(:,DATAP).', 1, []);
figure, plot(simbs(:,DATAP),'r.');

switch CONSTEL
    case 'BPSK'
        bits_rec = real(rec)<0;
    case 'QPSK'
        bits_rec = zeros(1,length(rec)*2);
        bits_rec(2:2:end) = real(rec)<0;
        bits_rec(1:2:end) = imag(rec)<0;
end
a = length(bits_rec);
BER = mean(xor(bits_rec, bits_tx(1:a).'));
fprintf(1, 'BER = %f\n', BER);
toc

figure, stem(xor(bits_rec, bits_tx(1:a).'));
figure, stem(xor(bits_rec(3:end), bits_tx(1:a-2).'));













