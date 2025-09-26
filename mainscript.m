% main_experiment.m
% PURPOSE: Full OFDM/UFMC link with channel + impairments + receiver.
% ===============================================================

clear; close all; clc;

%% ---------- System Parameters ----------
Fs = 3.84e6; Nfft = 256; DeltaF = Fs/Nfft; 
Ncp = Nfft/8; Nu = 200; M = 16; numSyms = 20;
preambleType = 'SC'; % or 'PARK'
rng(42);
% ===============================================================
% main_demo_tx_only.m
% PURPOSE: Run OFDM and UFMC transmitters, show waveforms and spectra.
% AUTHOR: You :)
% ===============================================================

clear; close all; clc;

% ---------- Global, "real-life" inspired numerology ----------
Fs      = 3.84e6;     % Sampling rate [Hz] = 256 * 15 kHz (LTE-like)
Nfft    = 256;        % IFFT/FFT length
DeltaF  = Fs/Nfft;    % Subcarrier spacing [Hz] (= 15 kHz if Fs=3.84 MHz)
Ncp     = Nfft/8;     % Cyclic prefix length (1/8th of N)
Nu      = 200;        % Number of used (non-zero) subcarriers (drop DC+guards)
M       = 4;          % QAM order (4 = QPSK; keep simple for first run)
numSyms = 10;         % Number of data OFDM/UFMC symbols in one frame
preambleType = 'SC';  % 'SC' (Schmidl&Cox) or 'PARK' (Park-style)
rng(42);              % Fix random seed for repeatability
% Pack these into a struct so we pass one object around
P = struct('Fs',Fs,'Nfft',Nfft,'DeltaF',DeltaF,'Ncp',Ncp, ...
           'Nu',Nu,'M',M,'numSyms',numSyms,'preambleType',preambleType);

% ---------- Make some random payload bits ----------
bitsPerSymPerOFDM = Nu * log2(M);                  % bits carried by one data symbol
totalBits = numSyms * bitsPerSymPerOFDM;           % total bits in this frame
bits = randi([0 1], totalBits, 1);                  % i.i.d. random bits (our "message")

% ---------- Build an OFDM baseband frame ----------
[x_ofdm, meta_ofdm] = tx_ofdm(bits, P);

% ---------- Build a UFMC baseband frame ----------
[x_ufmc, meta_ufmc] = tx_ufmc(bits, P);

% ---------- Display a few human-friendly numbers ----------
fprintf('\nOFDM frame: %d data symbols, Fs = %.2f MHz, Nfft = %d, CP = %d (%.2f us)\n', ...
    P.numSyms, P.Fs/1e6, P.Nfft, P.Ncp, 1e6*P.Ncp/P.Fs);
fprintf('UFMC frame: %d data symbols (no CP), subbands = %d x %d tones\n', ...
    P.numSyms, meta_ufmc.Nsb, meta_ufmc.tonesPerSb);

% ---------- Plot time-domain waveforms ----------
t_ofdm = (0:length(x_ofdm)-1)/Fs;
t_ufmc = (0:length(x_ufmc)-1)/Fs;

figure('Name','Time-domain amplitude');
subplot(2,1,1);
plot(t_ofdm*1e3, abs(x_ofdm)); grid on;
xlabel('Time [ms]'); ylabel('|x_{OFDM}(n)|');
title('OFDM (preamble + CP + data)');

subplot(2,1,2);
plot(t_ufmc*1e3, abs(x_ufmc)); grid on;
xlabel('Time [ms]'); ylabel('|x_{UFMC}(n)|');
title('UFMC (note smoother edges due to subband filtering)');

% ---------- Plot PSDs side-by-side (Welch) ----------
figure('Name','Power Spectral Density (PSD)');
[PSD_ofdm, f_ofdm] = pwelch(x_ofdm, hann(2048), 1024, 4096, Fs, 'centered');
[PSD_ufmc, f_ufmc] = pwelch(x_ufmc, hann(2048), 1024, 4096, Fs, 'centered');
plot(f_ofdm/1e6, 10*log10(PSD_ofdm+eps), 'LineWidth', 1.0); hold on; grid on;
plot(f_ufmc/1e6, 10*log10(PSD_ufmc+eps), 'LineWidth', 1.0);
xlabel('Frequency [MHz]'); ylabel('PSD [dB/Hz]');
legend('OFDM','UFMC','Location','best');
title('UFMC typically shows lower out-of-band (OOB) emissions');