import Foundation
@preconcurrency import Apollo
import ApolloAPI

/// Task.cancell()をハンドリングしてApollo.Cancellable.cancel()を実行する仕組み
/// 並列でキャンセルを実行したとしてもcontinuationがリークしたり二重で呼ばれないようにスレッドセーフに扱うためにactorで定義している
public actor ApolloCancellableHandler<Client: ApolloClientProtocol> {
    enum State: Sendable, Equatable {
        case beforeStart
        case running(setCancellingTask: Task<(@Sendable () -> Void)?, Never>)
        case completed
        case cancelled
    }
    private var state: State = .beforeStart
    private let apollo: Client
    public init(apollo: Client) {
        self.apollo = apollo
    }
    /// stateがcancelleの場合はcompletedにしない
    /// - Returns: completedに変更できたかどうか
    private func trySetComplete() -> Bool {
        switch state {
        case .beforeStart, .running:
            state = .completed
            return true
        case .cancelled, .completed:
            return false
        }
    }
    private func cancel() async {
        switch state {
        case .beforeStart:
            state = .cancelled
        case .running(let setCancellingTask):
            state = .cancelled
            let cancelling = await setCancellingTask.value
            cancelling?()
        case .completed, .cancelled:
            return
        }
    }
    /// Task.cancell()をハンドリングしてApollo.Cancellable.cancel()を実行
    /// withCheckedThrowingContinuationが呼ばれてからcancelling処理をセットするまでをTask化して
    /// 並列でキャンセルが呼ばれたとしても、cancellingのセットを待ってから実行できる仕組みになっている
    /// - Parameter operation: fetch, mutation などCancellableを返すoperationメソッド
    /// - Returns: operationのresult
    func handle<Data: RootSelectionSet>(operation: @Sendable @escaping (GraphQLResultHandler<Data>?) -> any Cancellable) async throws -> GraphQLResult<Data> {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state = .running(setCancellingTask: Task {
                    // このTask内は利用側のTaskとは隔離されているのでTask.isCancelledが伝搬されないため別途FetchState.cancelledで判定
                    // withTaskCancellationHandlerが呼ばれた後でwithCheckedThrowingContinuationがまだ呼ばれていないタイミングでcancelされた場合を考慮して
                    // 明示的にCancellationErrorをthrow
                    if state == .cancelled {
                        continuation.resume(throwing: CancellationError())
                        return nil
                    }
                    let apolloCancellable = operation { result in
                        Task {
                            // onCancelが呼ばれてから cancelメソッドを呼ぶ間が非同期なので、その間にここに来た場合に２重でresumeされてしまうため、もしcancelledだった場合にreturnする仕組み
                            guard self.trySetComplete() else { return }
                            continuation.resume(with: result)
                        }
                    }
                    // ApolloClientのcancelだけだとcontinuationがリークするので、ちゃんとerrorをthrowする
                    return {
                        apolloCancellable.cancel()
                        continuation.resume(throwing: CancellationError())
                    }
                })
            }
        } onCancel: {
            Task {
                await cancel()
            }
        }
    }
}
