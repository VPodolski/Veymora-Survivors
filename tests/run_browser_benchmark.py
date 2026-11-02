import subprocess
import time
import json
import os
import sys
import http.server
import socketserver
import threading

class QuietHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="build/web_pikabu", **kwargs)

    def log_message(self, format, *args):
        pass

    def end_headers(self):
        # Enable SharedArrayBuffer and Cross-Origin Isolation if needed
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

def run_benchmark(output_filename="build/benchmark_browser_baseline.json"):
    port = 8089
    server = socketserver.TCPServer(("127.0.0.1", port), QuietHTTPHandler)
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    print(f"[BENCHMARK] Local web server listening on http://localhost:{port}/")

    chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    if not os.path.exists(chrome_path):
        print(f"Error: Chrome executable not found at {chrome_path}")
        server.shutdown()
        return None

    user_data_dir = os.path.join(os.environ.get("TEMP", "."), "chrome_bench_profile")
    os.makedirs(user_data_dir, exist_ok=True)

    cmd = [
        chrome_path,
        "--headless=new",
        "--use-gl=angle",
        f"--user-data-dir={user_data_dir}",
        "--window-size=1280,720",
        "--enable-logging=stderr",
        "--v=1",
        f"http://localhost:{port}/index.html?benchmark=1"
    ]

    print("[BENCHMARK] Launching Chromium headless with ANGLE WebGL2...")
    proc = subprocess.Popen(
        cmd,
        stderr=subprocess.PIPE,
        stdout=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace"
    )

    benchmark_data = None
    start_time = time.time()
    timeout = 90 # 90 seconds max

    try:
        while True:
            if time.time() - start_time > timeout:
                print("[BENCHMARK] Timeout waiting for browser benchmark!")
                break

            line = proc.stderr.readline()
            if not line:
                if proc.poll() is not None:
                    break
                time.sleep(0.05)
                continue

            line = line.strip()
            if "[BENCHMARK_WEB]" in line:
                print(line)
            elif "[BENCHMARK_BROWSER_DATA]" in line:
                start_brace = line.find("{")
                end_brace = line.rfind("}")
                if start_brace != -1 and end_brace != -1:
                    raw_json = line[start_brace:end_brace + 1]
                    try:
                        benchmark_data = json.loads(raw_json)
                        print("[BENCHMARK] Received browser benchmark data successfully!")
                        break
                    except Exception as e:
                        print(f"[BENCHMARK] Error parsing JSON: {e}, raw: {raw_json}")
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        server.shutdown()

    if benchmark_data:
        os.makedirs(os.path.dirname(output_filename), exist_ok=True)
        with open(output_filename, "w", encoding="utf-8") as f:
            json.dump(benchmark_data, f, indent=2)
        print(f"[BENCHMARK] Saved results to {output_filename}")
        _print_table(benchmark_data)
        return benchmark_data
    else:
        print("[BENCHMARK] Failed to capture benchmark data from browser.")
        return None

def _print_table(data):
    print("\n" + "=" * 65)
    print(" CHROMIUM BROWSER BENCHMARK RESULTS (WebGL2 - 1280x720)")
    print("=" * 65)
    for sc_key, sc in data.items():
        print(f"\nScenario: {sc_key}")
        print(f"  Avg FPS:          {sc['avg_fps']:6.1f}")
        print(f"  1% Low FPS:       {sc['low_1pct_fps']:6.1f}")
        print(f"  Avg Frame Time:   {sc['avg_frame_time_ms']:6.2f} ms")
        print(f"  P99 Frame Time:   {sc['p99_frame_time_ms']:6.2f} ms")
        print(f"  Peak Frame Time:  {sc['peak_frame_time_ms']:6.2f} ms")
        print(f"  Script Process:   {sc['script_process_ms']:6.2f} ms")
        print(f"  Physics Process:  {sc['physics_process_ms']:6.2f} ms")
        print(f"  Draw Calls:       {sc['avg_draw_calls']:6.1f}")
        print(f"  Active Enemies:   {sc['active_enemies']}")
        print(f"  Active Proj:      {sc['active_projectiles']}")
        print(f"  Active Gems:      {sc['active_gems']}")
        print(f"  Active FX:        {sc['active_fx']}")
        print(f"  Total Nodes:      {sc['total_nodes']}")
        print(f"  Memory Static:    {sc['memory_mb']:.2f} MB")
    print("=" * 65 + "\n")

if __name__ == "__main__":
    out_file = sys.argv[1] if len(sys.argv) > 1 else "build/benchmark_browser_baseline.json"
    run_benchmark(out_file)
