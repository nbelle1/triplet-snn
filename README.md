# Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

# Commands

```bash
make train      # training sim
make test       # testing sim
make verbose    # training & testing with STDP debug info included in console output
make all        # both training and testing
make wave-train # open training waveform in GTKWave
make wave-test  # open testing waveform in GTKWave
make plot       # generate weight heatmaps
make clean      # remove build artifacts
```
