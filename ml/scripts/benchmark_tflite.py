#!/usr/bin/env python3
"""Benchmark TFLite inference latency and report model size.

Caveat, front and center: this measures single-threaded CPU latency on the
machine running this script, not a physical low-cost Android device (Section
3, Week 3's literal deliverable — "benchmark ... on a low-cost Android
device"). No such device is available in this environment. Treat these
numbers as a rough floor/proxy, not the on-device figure — real-device
benchmarking (e.g. via Android Studio's TFLite Benchmark Tool on a sub-$100
phone) is a follow-up needed before trusting the <2s latency target.

Usage:
    python scripts/benchmark_tflite.py --run-name v1
"""

import argparse
import json
import time
from pathlib import Path

import numpy as np
import tensorflow as tf

ML_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = ML_DIR / "models"

N_WARMUP = 10
N_TIMED = 100


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-name", default="v1")
    parser.add_argument("--model-file", default="model_int8.tflite")
    args = parser.parse_args()

    model_path = MODELS_DIR / args.run_name / args.model_file
    size_mb = model_path.stat().st_size / (1024 * 1024)

    interpreter = tf.lite.Interpreter(model_path=str(model_path), num_threads=1)
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]

    rng = np.random.default_rng(42)
    sample = rng.integers(0, 256, size=input_detail["shape"], dtype=np.uint8)

    for _ in range(N_WARMUP):
        interpreter.set_tensor(input_detail["index"], sample)
        interpreter.invoke()
        interpreter.get_tensor(output_detail["index"])

    latencies_ms = []
    for _ in range(N_TIMED):
        t0 = time.perf_counter()
        interpreter.set_tensor(input_detail["index"], sample)
        interpreter.invoke()
        interpreter.get_tensor(output_detail["index"])
        latencies_ms.append((time.perf_counter() - t0) * 1000)

    latencies_ms = np.array(latencies_ms)
    results = {
        "model_size_mb": round(size_mb, 3),
        "n_runs": N_TIMED,
        "threads": 1,
        "latency_ms": {
            "mean": round(float(latencies_ms.mean()), 2),
            "p50": round(float(np.percentile(latencies_ms, 50)), 2),
            "p95": round(float(np.percentile(latencies_ms, 95)), 2),
            "min": round(float(latencies_ms.min()), 2),
            "max": round(float(latencies_ms.max()), 2),
        },
        "caveat": "Single-threaded CPU on the dev machine, not a physical low-cost "
        "Android device. Proxy measurement only.",
    }

    print(json.dumps(results, indent=2))

    out_path = MODELS_DIR / args.run_name / "eval" / "tflite_benchmark.json"
    out_path.parent.mkdir(exist_ok=True)
    out_path.write_text(json.dumps(results, indent=2))
    print(f"\nWrote {out_path}")


if __name__ == "__main__":
    main()
