import requests
import time
from concurrent.futures import ThreadPoolExecutor
import os

# 配置参数
url = "https://tts-ai.wl1.heiyu.space/v1/audio/speech"
num_requests = 100
concurrent_requests = 10
output_dir = "stress_test_results"
save_audio = False

# 创建输出目录
if save_audio and not os.path.exists(output_dir):
    os.makedirs(output_dir)


def make_request(i):
    start_time = time.time()
    try:
        response = requests.post(
            url,
            json={
                "model": "kokoro",
                "input": "Hello, world! This is stress test request number " + str(i),
                "voice": "zf_094",
                "response_format": "wav",
                "stream": True,
                "speed": 1.0,
            },
            timeout=30,
        )

        elapsed = time.time() - start_time

        if response.status_code == 200:
            if save_audio:
                with open(f"{output_dir}/output_{i}.wav", "wb") as f:
                    f.write(response.content)
            print(f"Request {i}: Success - {elapsed:.2f}s")
            return True, elapsed
        else:
            print(
                f"Request {i}: Failed with status code {response.status_code} - {elapsed:.2f}s"
            )
            return False, elapsed
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"Request {i}: Error - {str(e)} - {elapsed:.2f}s")
        return False, elapsed


# 使用线程池并行执行请求
print(
    f"Starting stress test with {num_requests} requests ({concurrent_requests} concurrent)..."
)
start_time = time.time()

with ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
    results = list(executor.map(make_request, range(num_requests)))

total_time = time.time() - start_time
success_count = sum(1 for success, _ in results if success)
avg_time = sum(elapsed for _, elapsed in results) / len(results)

print(f"\nStress test completed in {total_time:.2f} seconds")
print(
    f"Success rate: {success_count}/{num_requests} ({success_count / num_requests * 100:.2f}%)"
)
print(f"Average request time: {avg_time:.2f} seconds")
