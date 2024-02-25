/// Concurrency版 Semaphore
///
/// [cookpadさんの記事](https://techlife.cookpad.com/entry/2022/10/24/090000)を参考に作成
/// - キャンセルした場合の挙動や使い方によっては未定義な挙動を起こす可能性があるためテストにのみ利用
/// - 使い方はほぼDispatchSemaphoreと同じだがTimeoutはない
actor Semaphore {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var value: Int

    init(value: Int) {
        assert(value >= 0)
        self.value = value
    }

    private func ensureValidState() {
        assert((value >= 0 && waiters.isEmpty) || (waiters.count == -value))
    }

    func wait() async {
        value -= 1
        if value < 0 {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
                ensureValidState()
            }
        }
        ensureValidState()
    }

    func signal() {
        value += 1
        if value <= 0 {
            let waiter = waiters.removeFirst()
            ensureValidState()
            waiter.resume()
        }
        ensureValidState()
    }
}
