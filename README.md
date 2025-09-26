# -MATLAB-Implementation-of-OFDM-and-UFMC-Baseband-Transmitters
This repository implements and compares OFDM and UFMC baseband transmitters in MATLAB. Both use realistic LTE-like numerology and preamble design (Schmidl &amp; Cox or Park)
# OFDM vs UFMC Transmitter Simulation (MATLAB)

This project implements and compares **Orthogonal Frequency Division Multiplexing (OFDM)** and **Universal Filtered Multi-Carrier (UFMC)** transmitters in MATLAB.  
It uses LTE-like numerology and preamble-based synchronization, and visualizes the difference between OFDM and UFMC in the time and frequency domains.

---

## 📌 Features
- **OFDM Transmitter (`tx_ofdm.m`)**
  - Subcarrier indexing (FFT-shifted, symmetric allocation, DC excluded)
  - QAM mapping with Gray coding and unit average power normalization
  - Reshaping into [Nu × numSyms] grid
  - Preamble generation:
    - **Schmidl & Cox** (repeated halves)  
    - **Park-style** (sign-flipped quarters for sharper correlation)
  - IFFT → Cyclic Prefix addition
  - Frame = `[preamble , guard , data_with_CP]`

- **UFMC Transmitter (`tx_ufmc.m`)**
  - Splits `Nu` tones into **Nsb subbands** (default = 10)  
    - If `Nu` is not divisible by `Nsb`, a few tones are dropped (warning shown)
  - QAM mapping into `[Nu_effective × numSyms]` grid
  - Dolph–Chebyshev FIR prototype filter (length = 43, 60 dB sidelobe attenuation)
  - Bandpass modulation of prototype per subband
  - No cyclic prefix (symbols overlap in time due to filtering)
  - Frame = `[preamble (unfiltered), guard , UFMC data]`

- **Main Script (`main_demo_tx_only.m`)**
  - Defines LTE-like numerology (Fs, Nfft, Δf, Ncp, Nu, etc.)
  - Generates random payload bits
  - Calls both transmitters to generate OFDM/UFMC frames
  - Prints system parameters in console
  - Plots time-domain signals and spectra

---

## 📂 Repository Structure
```text
OFDM-UFMC-Simulation/
├── main_demo_tx_only.m
├── main_experiment.m
├── tx_ofdm.m
├── tx_ufmc.m
└── figures/


### Time-Domain Signals
Comparison of OFDM and UFMC baseband signals (preamble + guard + data):

<p align="center">
  <img src="figures/time_ofdm.png" width="420"/>
  <img src="figures/time_ufmc.png" width="420"/>
</p>

### Spectrum
UFMC achieves smoother out-of-band performance compared to OFDM.

<p align="center">
  <img src="figures/spectrum_ofdm.png" width="420"/>
  <img src="figures/spectrum_ufmc.png" width="420"/>
</p>

