function [x, meta] = tx_ofdm(bits, P)
% ===============================================================
% tx_ofdm.m
% PURPOSE: Build a baseband OFDM frame with a sync preamble + data.
% INPUTS:
%   bits : column vector of payload bits (length = numSyms*Nu*log2(M))
%   P    : struct of system parameters (see main_demo_tx_only.m)
% OUTPUTS:
%   x    : baseband complex waveform: [preamble , data_with_CP]
%   meta : helpful metadata (indices, used subcarriers, etc.)
% ===============================================================

% ----- Unpack parameters for readability -----
Fs       = P.Fs;        % sampling rate (Hz)
Nfft     = P.Nfft;      % IFFT size
Ncp      = P.Ncp;       % cyclic prefix length (samples)
Nu       = P.Nu;        % number of used subcarriers (data tones; DC unused)
M        = P.M;         % QAM order
numSyms  = P.numSyms;   % number of OFDM data symbols
pType    = P.preambleType; % 'SC' or 'PARK'

% ----- Subcarrier indexing (FFT-shifted convention: -N/2 ... N/2-1) -----
k = (-Nfft/2 : Nfft/2-1).';             % column vector of bin indices
% We'll use symmetric allocation around DC but exclude k=0 (DC).
kUsedNeg = -ceil(Nu/2):-1;              % negative-frequency bins
kUsedPos = 1:floor(Nu/2);               % positive-frequency bins
kUsed    = [kUsedNeg kUsedPos];         % total "used" bins (length = Nu)

% ----- Helper: bits -> QAM symbols (Gray, unit avg power) -----
bitsPerQAM = log2(M);
assert(mod(numel(bits), bitsPerQAM)==0, 'bits length must be multiple of log2(M).');
qamSyms = qammod( bi2de(reshape(bits, bitsPerQAM, []).','left-msb'), ...
                  M, 'gray', 'UnitAveragePower', true );
% qammod arguments explained:
%  - reshape bits to rows of log2(M); convert to integers 0..M-1 via bi2de
%  - 'gray' mapping (standard in practice)
%  - 'UnitAveragePower' true normalizes average symbol energy to 1

% ----- Split QAM stream into OFDM symbols (each uses Nu tones) -----
assert(mod(numel(qamSyms), Nu)==0, 'QAM stream length must be multiple of Nu.');
qamGrid = reshape(qamSyms, Nu, numSyms);     % size [Nu x numSyms]

% ----- Build one preamble time-domain symbol for synchronization -----
switch upper(pType)
    case 'SC'
        % --- Schmidl & Cox: time-domain halves repeat: [a ; a] ---
        a = (randn(Nfft/2,1) + 1j*randn(Nfft/2,1))/sqrt(2); % random complex
        pre_noCP = [a; a];                                  % repetition
        % NOTE: We send the preamble *without* CP (common in practice).
        
    case 'PARK'
        % --- Park-style: two halves, but we flip signs inside each half
        % to create a sharper correlation peak than S&C.
        % We build [a1; -a2] || [a1; -a2], where a1,a2 are random quarters.
        a1 = (randn(Nfft/4,1)+1j*randn(Nfft/4,1))/sqrt(2);
        a2 = (randn(Nfft/4,1)+1j*randn(Nfft/4,1))/sqrt(2);
        oneHalf  = [a1; -a2];             % intra-half sign flip
        pre_noCP = [oneHalf; oneHalf];    % half repetition preserved
        % This preserves the S&C periodicity (good CFO/timing) but the
        % quarter sign flip makes the correlation peak narrower in practice.
        
    otherwise
        error('Unknown preambleType. Use ''SC'' or ''PARK''.');
end

% ----- Map data onto subcarriers, IFFT, add CP -----
x_data = [];                         % will hold concatenated CP+symbol blocks
for t = 1:numSyms
    % Start with all-zeros in frequency domain (FFT-shifted indexing)
    Xk = zeros(Nfft,1);
    % Fill our used tone positions with data for this symbol
    Xk(ismember(k, kUsed)) = qamGrid(:,t);
    % Convert to time domain; ifftshift places DC at index 1 as MATLAB expects
    x_noCP = ifft(ifftshift(Xk), Nfft);
    % Add cyclic prefix by copying the last Ncp samples to the front
    x_withCP = [x_noCP(end-Ncp+1:end) ; x_noCP];
    % Stack into the stream
    x_data = [x_data ; x_withCP];
end

% ----- Concatenate final frame: [preamble, small guard, data] -----
guard = zeros(Ncp,1);  % short silence so preamble does not bleed into data
x = [pre_noCP ; guard ; x_data];

% ----- Return some metadata that’s handy later -----
meta = struct();
meta.k          = k;
meta.kUsed      = kUsed;
meta.bitsPerQAM = bitsPerQAM;
meta.M          = M;
meta.Nfft       = Nfft;
meta.Ncp        = Ncp;
meta.Nu         = Nu;
meta.numSyms    = numSyms;
meta.preamble   = pre_noCP;
meta.frameLen   = numel(x);
meta.Fs         = Fs;

end
