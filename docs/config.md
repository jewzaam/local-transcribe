# Configuration

## Config File

A JSON config file sets defaults for model, device, and precision. The file
is never loaded implicitly — pass `--config PATH` on every invocation.

### Location

The recommended path is `~/.config/local-transcribe-config.json`. Any path
works.

### Keys

| Key | Values | Default | Description |
|-----|--------|---------|-------------|
| `model` | tiny, base, small, medium, large | small | Whisper model size |
| `compute_device` | cpu, cuda, auto | cpu | Inference device |
| `compute_type` | int8, float16, float32 | int8 | Model precision |
| `silence_threshold` | 0.0-1.0 | 0.08 | Audio level below which is silence |
| `silence_duration` | seconds | 1.0 | Continuous silence before chunk flush |
| `min_chunk_seconds` | seconds | 10.0 | Minimum audio before silence flush triggers |

#### Tuning silence_threshold

The audio level is a normalized value (0.0-1.0) derived from the raw
microphone peak with a 4x gain boost. To find the right threshold for your
environment, record with `--debug --log-file` and look for the callback
lines:

```
DEBUG local_transcribe.recording: callback=50, chunks=50, peak=196, level=0.0239
DEBUG local_transcribe.recording: callback=100, chunks=100, peak=3483, level=0.4252
```

The `level` value during ambient silence (no speech) is your floor. Set
`silence_threshold` above that floor but below speech levels. Typical
values:

| Environment | Ambient level | Suggested threshold |
|-------------|--------------|---------------------|
| Quiet room | 0.01-0.03 | 0.05 |
| Office / fan noise | 0.03-0.06 | 0.08 (default) |
| Noisy environment | 0.06-0.10 | 0.12 |

### Example

```json
{
    "model": "large",
    "compute_device": "cuda",
    "compute_type": "float16",
    "silence_duration": 0.5,
    "min_chunk_seconds": 8.0
}
```

### Creating

Write the JSON file manually. Only include keys you want to override —
omitted keys fall back to built-in defaults.

```bash
cat > ~/.config/local-transcribe-config.json << 'EOF'
{
    "model": "large",
    "compute_device": "cuda",
    "compute_type": "float16"
}
EOF
```

### Precedence

CLI arguments override config file values, which override built-in defaults.

```bash
# Uses config: model=large, compute_device=cuda, compute_type=float16
local-transcribe record --config ~/.config/local-transcribe-config.json

# Overrides model from config, keeps cuda/float16
local-transcribe record --config ~/.config/local-transcribe-config.json --model tiny

# No config — uses built-in defaults (small, cpu, int8)
local-transcribe record
```

## GPU Setup

### Requirements

GPU acceleration requires an NVIDIA GPU with CUDA support. Install the CUDA
runtime libraries:

```bash
# Development venv
pip install nvidia-cublas-cu12 nvidia-cudnn-cu12

# pipx install
make install-pipx-cuda
```

The DLL paths are registered automatically on Windows — no PATH changes
needed.

### Performance

Benchmarks with 31.5s of audio, model `large`:

| Config | Transcription Time | Realtime Factor |
|--------|-------------------|-----------------|
| CPU int8 | 19.0s | 1.7x |
| CUDA float16 | 1.4s | 22.5x |
| CUDA float32 | 1.9s | 16.3x |
| CUDA int8 | 1.9s | 16.6x |

CUDA float16 is recommended — fastest transcription with good accuracy.

### Troubleshooting

**`RuntimeError: Library cublas64_12.dll is not found`**

The CUDA runtime libraries are not installed. Run:

```bash
pip install nvidia-cublas-cu12 nvidia-cudnn-cu12
```

**Model loads but transcription fails on CUDA**

The model may load on CUDA without error but fail at inference time if
cuBLAS is missing. The error appears during the first `transcribe()` call,
not during model construction.
