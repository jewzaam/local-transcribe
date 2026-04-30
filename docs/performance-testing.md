# Performance Testing

How to benchmark transcription speed across different compute configurations
on your machine.

## Overview

Record a WAV file once, then replay it through `local-transcribe transcribe`
with different `--compute-device` and `--compute-type` combinations. The CLI
logs elapsed time and realtime factor, so you can compare directly from log
output. All test artifacts go to `/tmp/`.

## Step 1: Record a test WAV

```bash
local-transcribe record --wav-output /tmp/test-audio.wav
```

Speak naturally for 30-60 seconds. Longer clips give more stable timing but
take longer per run. The existing benchmarks in `config.md` used 31.5s of
audio.

Alternatively, use any existing WAV file. The file must be 16 kHz mono
16-bit PCM (the format `record` produces).

## Step 2: Run all configurations

Loop over model, compute-device, and compute-type:

```bash
for model in tiny base small medium large; do
    for device in cpu cuda; do
        for ctype in int8 float16 float32; do
            echo "Running: ${model}/${device}/${ctype}"
            local-transcribe transcribe /tmp/test-audio.wav \
                --model "$model" \
                --compute-device "$device" \
                --compute-type "$ctype" \
                --debug --log-file "/tmp/perf-${model}-${device}-${ctype}.log" \
                > /dev/null 2>&1 || echo "  FAILED (${model}/${device}/${ctype})"
        done
    done
done
```

Skip the `cuda` iterations if you don't have an NVIDIA GPU — those runs
will fail with a model load error. Remove models you don't care about from
the list to save time.

Note: `float16` on CPU falls back to `float32` on most x86 systems. Expect
identical results between the two on CPU.

Each log file captures timing lines like:

```
DEBUG local_transcribe.transcription: model loaded in 1.23s
DEBUG local_transcribe.transcription: transcription complete: 4.56s elapsed, 6.9x realtime, 12 segments
INFO local_transcribe_ui.__main__: Transcribed 31.5s audio in 4.56s (model=small, device=cpu, compute=int8)
```

## Step 3: Compare results

```bash
printf "%-20s %s\n" "Config" "Result"
printf "%-20s %s\n" "------" "------"
for f in /tmp/perf-*.log; do
    name=$(basename "$f" .log | sed 's/^perf-//')
    result=$(grep "Transcribed" "$f" 2>/dev/null | sed 's/.*Transcribed //' || echo "FAILED")
    printf "%-20s %s\n" "$name" "$result"
done
```

Example output:

```
Config               Result
------               ------
small-cpu-int8       31.5s audio in 4.5s (model=small, device=cpu, compute=int8)
small-cpu-float32    31.5s audio in 8.1s (model=small, device=cpu, compute=float32)
small-cuda-float16   31.5s audio in 0.8s (model=small, device=cuda, compute=float16)
large-cpu-int8       31.5s audio in 19.0s (model=large, device=cpu, compute=int8)
large-cuda-float16   31.5s audio in 1.4s (model=large, device=cuda, compute=float16)
```

## Tips

- **Cold vs warm model cache**: Each `transcribe` invocation is a separate
  process, so every run pays the model load cost. This matches real-world
  single-file usage.

- **Run each config 2-3 times** to account for variance from background
  system load.

- **Model download**: The first time you use a model size, faster-whisper
  downloads it. Run once before benchmarking to avoid counting download
  time.

- **Realtime factor**: A 10x realtime factor means 30s of audio is
  transcribed in 3s. Higher is better.
