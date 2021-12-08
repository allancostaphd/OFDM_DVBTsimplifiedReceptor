%% EDC - Trabajo final - MatLab
% Alumno: Pablo Linares Serrano

clear all;
close all;
% Leemos los vectores que se usarán para calcular el canal:
load('MatCanal.mat');
% (Obtenidos a partir del estándar de DVBT)

tic
%% Declaración de parámetros

% Definimos el tiempo de muestreo:
T = 224e-6/2^11;
% Definimos el número de símbolos que se enviarán
NUM_SYMB = 101;
% Definición de semilla para los número pseudoaleatorios
SEED=10;
% Constelación enviada
CONSTEL = 'QPSK';
%CONSTEL = 'BPSK';
% Símbolo empleado
MODE = '2k';
% Prefijo cíclico empleado
PC = 1/32;
 %SNR en dB
SNR = 40;
% Tipo de canal de la transmisión
% CANAL = 'F1';
CANAL = 'P1';

%% Código del transmisor

if MODE == '2k'
    % Establecemos los parámetros del modo
    NFFT=2^11;
    NCP = NFFT*PC;
    NCARRIER = 1705;
    % variable que contiene los índices donde se encontrarán los pilotos
    % dentro de un símbolo
    PILOTOS = 1:12:NCARRIER;
    NDATA=NCARRIER-length(PILOTOS);
    % Identificamos las posiciones que ocupan los datos en cada símbolo
    DATAP = ones(1,NCARRIER);
    DATAP(PILOTOS) = zeros(1,length(PILOTOS)); 
    DATAP = find(DATAP);
   
    % Generamos la secuencia PRBS y modulamos los que nos interesan
    PRBS = ones(1,NCARRIER);
    for j = 12:NCARRIER
        PRBS = [PRBS(1:j-1),xor(PRBS(j-11),PRBS(j-9)),PRBS(j+1:end)];
    end
    % Exportamos la secuencia PRBS a un fichero
    dlmwrite('PRBS2k_ML.dat',PRBS,'\n');
    dlmwrite('pilotos2k.dat',PILOTOS,'\n');
    % A partir de aquí la variable PRBS contendrá los pilotos que se
    % emplearán
    PRBS = PRBS(PILOTOS);
    PRBS = (8/3)*(0.5-PRBS);
end
if MODE == '8k'
    % Establecemos los parámetros del modo
    NFFT=2^13;
    NCP = NFFT*PC;
    NCARRIER = 6817;
    % variable que contiene los índices donde se encontrarán los pilotos
    % dentro de un símbolo
    PILOTOS = 1:12:NCARRIER;
    NDATA=NCARRIER-length(PILOTOS);
    % Identificamos las posiciones que ocupan los datos en cada símbolo
    DATAP = ones(1,NCARRIER);
    DATAP(PILOTOS) = zeros(1,length(PILOTOS)); 
    % Posiciones que ocupan los datos
    DATAP = find(DATAP);
    % Generamos la secuencia PRBS y modulamos los que nos interesan
    PRBS = ones(1,NCARRIER);
    for j = 12:NCARRIER
        PRBS = [PRBS(1:j-1),xor(PRBS(j-11),PRBS(j-9)),PRBS(j+1:end)];
    end
    % Exportamos la secuencia PRBS a un fichero
    % dlmwrite('PRBS8k_ML.dat',PRBS,'\n');
    % dlmwrite('pilotos8k.dat',PILOTOS,'\n');
    % A partir de aquí la variable PRBS contendrá los pilotos que se
    % emplearán
    PRBS = PRBS(PILOTOS);
    PRBS = (4/3)*(1-2*PRBS); % es lo mismo de arriba jeje
end

rand('seed', SEED);
randn('seed', SEED);

% Definición de la constelación
switch CONSTEL
    case 'BPSK'
        M=1;
        C=[1 -1];        
    case 'QPSK'
        C=[1+1i 1-1i -1+1i -1-1i]/sqrt(2);
        M=2;      
end

if isreal(C)
   C=complex(C);
end
plot(C, 'or');
grid
axis([-1.5 1.5 -1.5 1.5]);
title('Constelación')
xlabel('I');
ylabel('Q');

% Generación bits
numbits = NUM_SYMB*NDATA*M; 
bits_tx = rand(numbits, 1);
bits_tx = bits_tx>0.5;

% Bits to symbols
aux  = reshape(bits_tx, M, []).';
symb = zeros(size(aux, 1),1);
for k=1:M
    symb = symb + (2^(k-1))*aux(:,k);
end

% Mapper
const_points = C(symb+1);

if isreal(const_points)
   const_points=complex(const_points);
end

% figure
% plot(const_points, 'or');
% grid
% axis([-1.5 1.5 -1.5 1.5]);
% title('Constelación transmitida')
% xlabel('I');
% ylabel('Q');

% Símbolos OFDM en frecuencia
ofdm_freq = zeros(NFFT, NUM_SYMB);
ofdm_freq(ceil((NFFT-NCARRIER)/2)+DATAP,:) = reshape(const_points, NDATA, NUM_SYMB);
ofdm_freq(ceil((NFFT-NCARRIER)/2)+PILOTOS,:) = repmat(complex(PRBS).',1,NUM_SYMB);
figure
stem(abs(ofdm_freq(:,1)));
grid
xlabel('Portadoras OFDM');
ylabel('Amplitud');
title('Espectro OFDM')

ofdm_freq=ifftshift(ofdm_freq, 1);

% Modulacion OFDM

ofdm_time = ifft(ofdm_freq, NFFT, 1);

%% Canal, ruido, PC...
% Definimos el vector de tiempo
t = (0:NFFT-1)*T;
% Definimos el vector de frecuencias
f = ((0:NFFT-1)-NFFT/2-1).'/(NFFT*T);
% Obtenemos el canal
ro0 = sqrt(10*sum(ro.^2));
if CANAL == 'F1'
    H = (ro0+(ro.*exp(-1i*fi))*exp(-1i*2*pi.*f.*pos*1e-6).')/sqrt(ro0^2+sum(ro.^2));
end
if CANAL == 'P1'
    H = (ro.*exp(-1i*fi))*exp(-1i*2*pi.*f.*pos*1e-6).'/sqrt(ro0^2+sum(ro.^2));
end
% Representación del canal en frecuencia
figure;
hold on;
subplot(2,1,1);
plot(f, real(H))
title('parte real de H(f)')
xlabel('f (Hz)')
subplot(2,1,2);
plot(f, imag(H))
title('parte imaginaria de H(f)')
xlabel('f (Hz)')

figure;
subplot(2,1,1);
plot(f, 20*log10(abs(H)));
title('Magnitud H(f) [dB]');
xlabel('f [Hz]');
subplot(2,1,2);
plot(f, abs(H));
title('Fase de H(f) [Radianes]');
xlabel('f [Hz]');

H = ifft(ifftshift(H));


% Convolución símbolo y canal

ofdm_time = conv2(H, 1, ofdm_time);
ofdm_time = ofdm_time(1: NFFT,:);

% Prefijo cíclico

ofdm_time = [ofdm_time(end-(NCP-1):end, :); ofdm_time];
tx = ofdm_time(:);

figure
plot(real(tx), 'b-');
hold on
plot(imag(tx), 'r-');
xlabel('Muestras temporales');
ylabel('Amplitud');
legend('real', 'imag');
grid
title('Señal OFDM en el tiempo')


% Espectro
% figure
% pwelch(tx);

% Ruido
noise = (randn(size(tx))+1i*randn(size(tx))) / sqrt(2);
Ps = mean(tx.*conj(tx));
nsr = 10^(-SNR/10); % Pn/Ps
noise = sqrt(Ps*nsr).*noise;
rx = tx+noise;

%% Código del Receptor
rx = reshape(rx, NCP+NFFT,[]);
rx_time = rx(NCP+1:end, :).';
% Hacemos la fft a los símbolos
rx_frec = ifftshift(fft(rx_time, NFFT, 2),2);
% Exportamos el símbolo recibido a un fichero para poder compararlo con el
% VHDL
rx_expR = reshape(real(rx_frec.'),1,[]);
rx_expI = reshape(imag(rx_frec.'),1,[]);
maximo = max(max(abs(rx_expR)),max(abs(rx_expI)));
rx_expR = round(rx_expR*511/maximo);
rx_expI = round(rx_expI*511/maximo);
if MODE == '8k'
    dlmwrite('simb8kR_ML.dat', rx_expR, '\n');
    dlmwrite('simb8kI_ML.dat', rx_expI, '\n');
end
if MODE == '2k'
    dlmwrite('simb2kR_ML.dat', rx_expR, '\n');
    dlmwrite('simb2kI_ML.dat', rx_expI, '\n');
end
% Extraemos las portadoras que se corresponden con los datos
x = rx_frec(:,ceil((NFFT-NCARRIER)/2)+DATAP).';
% Extraemos los pilotos
pilotosRx = rx_frec(:,ceil((NFFT-NCARRIER)/2)+PILOTOS).';
% Dividimos los pilotos para obtener H
H1 = pilotosRx./repmat(complex(PRBS).',1,NUM_SYMB);

% Estimación del canal

[a,b] = size(H1(2:end,:));
pesos = (1/12:1/12:11/12)';
H2 = pesos*reshape((H1(2:end,:)-H1(1:end-1,:)).', 1, a*b);
H2 = reshape(H2, length(pesos), b, a)+ repmat(permute(H1(1:end-1,:), [3, 2, 1]),length(pesos),1,1);
H2 = reshape(permute(H2, [1,3,2]), a*length(pesos), b);

% Montamos el canal completo
channel = zeros(NCARRIER, NUM_SYMB);
channel(DATAP, :) = H2;
channel(PILOTOS, :) = H1;

% Representación del canal
figure(3);
subplot(2,1,1);
hold on;
plot(f(floor((length(f)-length(channel))/2:end-(length(f)-length(channel))/2-1)),real(channel(:,1)));
title('canal en cada portadora (real)');
subplot(2,1,2);
hold on;
plot(f(floor((length(f)-length(channel))/2:end-(length(f)-length(channel))/2-1)),imag(channel(:,1)));
title('canal en cada portadora (imaginaria)');

figure(4);
subplot(2,1,1);
hold on;
plot(f(floor((length(f)-length(channel))/2:end-(length(f)-length(channel))/2-1)), 20*log10(abs(channel(:,1))));
title('Magnitud H(f) [dB]');
xlabel('f [Hz]');
subplot(2,1,2);
hold on;
plot(f(floor((length(f)-length(channel))/2:end-(length(f)-length(channel))/2-1)), abs(channel(:,1)));
title('Fase de H(f) [Radianes]');
xlabel('f [Hz]');


% Dividimos los datos entre el canal
x = x./H2;

rx_constel = reshape(x, 1, []);
figure, plot(rx_constel, "or");
title("puntos recibidos");
grid on;

figure(4);

% Demap

switch CONSTEL
    case 'BPSK'
        bits_rx = rx_constel<0;
    case 'QPSK'
        bits_rx = zeros(1,length(rx_constel)*2);
        bits_rx(2:2:end) = real(rx_constel)<0;
        bits_rx(1:2:end) = imag(rx_constel)<0;
end

BER = mean(xor(bits_rx, bits_tx.'));
fprintf(1, 'BER = %f\n', BER);
toc










