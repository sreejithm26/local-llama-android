import os
import sys
import urllib.request
import time

MODEL_URL = "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "models")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "qwen2.5-1.5b-instruct-q4_k_m.gguf")

def format_size(bytes_num):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_num < 1024.0:
            return f"{bytes_num:.2f} {unit}"
        bytes_num /= 1024.0
    return f"{bytes_num:.2f} TB"

def download():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    if os.path.exists(OUTPUT_PATH):
        existing_size = os.path.getsize(OUTPUT_PATH)
        print(f"File already exists with size {format_size(existing_size)}.")
        if existing_size > 1_000_000_000: # ~1GB+
            print("Model appears already fully downloaded.")
            return

    print(f"Downloading Qwen2.5-1.5B-Instruct Q4_K_M GGUF from:\n  {MODEL_URL}")
    print(f"Destination: {OUTPUT_PATH}")

    start_time = time.time()
    last_print = 0

    def reporthook(block_num, block_size, total_size):
        nonlocal last_print
        downloaded = block_num * block_size
        now = time.time()
        if now - last_print >= 2.0 or downloaded >= total_size:
            percent = (downloaded / total_size * 100) if total_size > 0 else 0
            speed = downloaded / (now - start_time) if (now - start_time) > 0 else 0
            print(f"Progress: {format_size(downloaded)} / {format_size(total_size)} ({percent:.1f}%) @ {format_size(speed)}/s", flush=True)
            last_print = now

    urllib.request.urlretrieve(MODEL_URL, OUTPUT_PATH, reporthook)
    print(f"\nDownload completed in {time.time() - start_time:.1f}s.")

if __name__ == "__main__":
    download()
