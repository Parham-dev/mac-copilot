import Foundation

protocol SidecarHealthDataFetching {
    func fetchHealthData(port: Int, timeout: TimeInterval) -> Data?
}

protocol BlockingDelaySleeping {
    func sleep(seconds: TimeInterval)
}

struct URLSessionSidecarHealthDataFetcher: SidecarHealthDataFetching {
    func fetchHealthData(port: Int, timeout: TimeInterval) -> Data? {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?

        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }

            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  let data
            else {
                return
            }

            result = data
        }

        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 0.4)
        return result
    }
}

struct ThreadBlockingDelaySleeper: BlockingDelaySleeping {
    func sleep(seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: max(0, seconds))
    }
}
