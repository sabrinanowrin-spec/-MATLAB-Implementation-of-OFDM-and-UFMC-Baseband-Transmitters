function [x, meta] = tx_ufmc(bits, P)
% ===============================================================
% tx_ufmc.m
% PURPOSE: Build a UFMC baseband frame: preamble + filtered subbands.
% NOTES:
%   - Preamble is same style as OFDM (SC or Park) but sent *unfiltered*
%     to preserve its timing/CFO properties.
%   - Data symbols are shaped by a Dolph-Chebyshev FIR per subband (no CP).
% ===============================================================

%% ----- Unpack parameters -----
Fs       = P.Fs;
Nfft     = P.Nfft;
Nu       = P.Nu;
M        = P.M;
numSyms  = P.numSyms;
pType    = P.preambleType;

%% ----- Choose # of subbands and their widths -----
% We split the Nu used tones into Nsb contiguous subbands of equal size.
Nsb         = 10;                   % number of subbands (tweakable)
tonesPerSb  = floor(Nu / Nsb);      % tones in each subband
Nu_effective = tonesPerSb*Nsb;      % we might drop a few tones to be even
dropTones    = Nu - Nu_effective;   % how many we dropped
if dropTones>0
    warning('UFMC: Dropping %d tones to fit %d subbands evenly.', dropTones, Nsb);
end

%% ----- FFT bin index setup (FFT-shifted) -----
k = (-Nfft/2 : Nfft/2-1).';

%% We'll choose the "used" bins symmetrical around DC, skipping DC itself.
kUsedNeg = -ceil(Nu_effective/2):-1;
kUsedPos = 1:floor(Nu_effective/2);
kUsed    = [kUsedNeg kUsedPos];      % total used bins (length = Nu_effective)

%% Partition those used bins into contiguous subbands:
sbEdges = reshape(1:Nu_effective, tonesPerSb, Nsb);  % columns are subbands
% Map those positions to actual FFT bin indices (k-values):
kUsedList = kUsed(:).';
kSb = zeros(tonesPerSb, Nsb);
for m = 1:Nsb
    idxRange = sbEdges(:,m);
    kSb(:,m) = kUsedList(idxRange);
end
%% Now, subband m occupies FFT bins in vector kSb(:,m).

% ----- Helper: bits -> QAM symbols -----
bitsPerQAM = log2(M);
assert(mod(numel(bits), bitsPerQAM)==0, 'bits length must be multiple of log2(M).');
bitsPerQAM = log2(M);
symIdx = bi2de(reshape(bits, bitsPerQAM, []).','left-msb');
qamSyms = qammod(symIdx, M, 'gray', 'UnitAveragePower', true);

%% Arrange QAM into a [tonesPerSb*Nsb x numSyms] grid, then split per sb
assert(mod(numel(qamSyms), Nu_effective)==0, 'QAM length must match tones used.');
qamGridAll = reshape(qamSyms, Nu_effective, numSyms);  % per OFDM-like symbol

%% ----- Design a Dolph-Chebyshev prototype FIR (linear phase) -----
Lf     = 43;       % filter length (odd number typical for UFMC)
Astop  = 60;       % desired sidelobe attenuation [dB]
%% We make a *lowpass* prototype; each subband will use a *frequency-shifted*
% version of this prototype to align the passband with its center frequency.
g_proto = fir1(Lf-1, (tonesPerSb/Nfft), chebwin(Lf, Astop));
% fir1 cutoff is normalized (0..1) = (tonesPerSb/Nfft) ~ width of sb
% chebwin gives Dolph-Chebyshev-like window w/ sidelobe control

%% ----- Build preamble (unfiltered) -----
switch upper(pType)
    case 'SC'
        a = (randn(Nfft/2,1) + 1j*randn(Nfft/2,1))/sqrt(2);
        pre_noFilt = [a; a];
    case 'PARK'
        a1 = (randn(Nfft/4,1)+1j*randn(Nfft/4,1))/sqrt(2);
        a2 = (randn(Nfft/4,1)+1j*randn(Nfft/4,1))/sqrt(2);
        oneHalf  = [a1; -a2];
        pre_noFilt = [oneHalf; oneHalf];
    otherwise
        error('Unknown preambleType. Use ''SC'' or ''PARK''.');
end

%% ----- Generate UFMC data: subband-by-subband filtering, then sum -----
x_data = [];                 % will store concatenation over time symbols
for t = 1:numSyms
    % For symbol t, start with an all-zeros frequency vector (FFT-shifted)
    X_total = zeros(Nfft,1);

    % Fill this symbol's data onto used tones:
    thisFrameData = qamGridAll(:,t);   % size [Nu_effective x 1]

    % We will build time-domain per-subband signals -> filter -> sum.
    x_sum = zeros(Nfft + Lf - 1, 1);   % convolution length for each sb

    for m = 1:Nsb
        %% ---- Frequency mapping for subband m ----
        Xk = zeros(Nfft,1);
        bins_m = kSb(:,m);                             % FFT bins for sb m
        Xk(ismember(k, bins_m)) = thisFrameData( (m-1)*tonesPerSb + (1:tonesPerSb) );

        %% ---- Time-domain subband signal (unfiltered) ----
        x_sb = ifft(ifftshift(Xk), Nfft);              % IDFT to time domain

        %% ---- Build a bandpass filter for this subband by *modulating*
        %      the lowpass prototype to the subband's center frequency.
        kCenter = round(mean(bins_m));                 % subband center bin (approx)
       n = (0:Lf-1).';
expShift = exp(1j*2*pi*(kCenter/Nfft)*n);   % 43x1
g_m = g_proto(:) .* expShift(:);            % force 43x1 vector

        %% ---- Filter the subband in time domain ----
        x_sb = ifft(ifftshift(Xk), Nfft);
        x_sb = x_sb(:); 


        y_m = conv(x_sb, g_m);                         % linear convolution

       % % ---- Accumulate all subbands (they overlap in time) ----
        x_sum = x_sum + y_m;
    end

    % ---- Concatenate symbol t (no CP in UFMC) ----
    x_data = [x_data ; x_sum];
end

%% ----- Final frame = [preamble (unfiltered), guard, UFMC data] -----
guard = zeros(Lf-1,1);  % protects preamble from filter tails
x = [pre_noFilt ; guard ; x_data];

%% ----- Return metadata -----
meta = struct();
meta.Nsb        = Nsb;
meta.tonesPerSb = tonesPerSb;
meta.kSb        = kSb;
meta.filterLen  = Lf;
meta.stopAtt    = Astop;
meta.protoLP    = g_proto;
meta.frameLen   = numel(x);
meta.Nfft       = Nfft;
end
