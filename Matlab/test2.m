%% test.m
%       Autor: Pablo Linares Serrano
%
%       Descripción: Este script sirve para recuperar el canal que se ha
%       obtenido en las simulaciones de VHDL de EDC a partir de los
%       ficheros que se generan con el test bench realizado.
%       Se debe ejecutar después del código del sistema completo.

close all;


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
    VhdlR = dlmread('v2canal8kR_VHDL.dat', '\n');
    VhdlI = dlmread('v2canal8kI_VHDL.dat', '\n');
end
if modo == '2k'
    VhdlR = dlmread('v2canal2kR_VHDL.dat', '\n');
    VhdlI = dlmread('v2canal2kI_VHDL.dat', '\n');
end
vhdl = VhdlR + 1i*VhdlI;
vhdl2 = vhdl(1:L);
rms1 = rms(abs(vhdl2));
rms2 = rms(abs(channel(1:end-1,1)));
vhdl3 = rms2*vhdl2/rms1;

% representamos el canal obtenido en el primer símbolo junto con el
% recibido en ML.
figure
subplot(2,1,1);
plot(10*log10(abs(vhdl3)));

hold on
plot(10*log10(abs(channel(:,1))));

subplot(2,1,2);
plot(angle(vhdl3));
hold on
plot(angle(channel(:,1)));

errAbs = rms(abs(channel(1:L,1)-vhdl3.'));

% errores para el primer símbolo
disp('error absoluto rms:');
disp(errAbs);
disp('error relativo rms (%)');

errRel = errAbs/rms2;
disp(errRel*100);

% errores para el total de símbolos
nErrAbs = zeros(1,nsimb);
nErrRel = zeros(1,nsimb);
for i = 0:nsimb-1
    rms1 = rms(abs(vhdl(1+i*L:(1+i)*L)));
    rms2 = rms(abs(channel(i*(L+1)+1:(i+1)*(L+1))));
    nErrAbs(i+1) = rms(abs(vhdl(1+i*L:(1+i)*L)*rms2/rms1-channel(i*(L+1)+1:(i+1)*(L+1)-1)));
    nErrRel(i+1) = nErrAbs(i+1)/rms2*100;
end
disp('Errores absolutos en cada símbolo');
disp(nErrAbs);
disp('Errores relativos (%) en cada símbolo');
disp(nErrRel);