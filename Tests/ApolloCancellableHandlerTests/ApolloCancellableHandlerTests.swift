import XCTest
@testable import ApolloCancellableHandler
import Apollo
import ApolloAPI

// 各種Sendableに準拠しないとasync版fetchが生えない
extension DataDict: @unchecked Sendable {}
extension DummyQuery: @unchecked Sendable {}
extension DummyQuery.Data: @unchecked Sendable {}

private final class ApolloStub: ApolloClientProtocol, Sendable {
    // async版のfetchを呼んでから内部のApolloClient.fetchが呼ばれるまで外側で待つためのSemaphore
    let fetchStartedSemaphore: Semaphore = .init(value: 0)
    // fetch仮想通信処理の完了を外側で制御するためのSemaphore
    let fetchCompleteSemaphore: Semaphore = .init(value: 0)
    // cancel後にlogger.sendの完了を外側で待つためのSemaphore
    let afterCancelSemaphore: Semaphore = .init(value: 0)
    // fetchCompleteされた回数をカウント
    let completeCounter: Counter = .init()
    // cancelされた回数をカウント
    let cancelCounter: Counter = .init()

    func fetch<Query>(query: Query, cachePolicy: Apollo.CachePolicy, contextIdentifier: UUID?, context: Apollo.RequestContext?, queue: DispatchQueue, resultHandler: Apollo.GraphQLResultHandler<Query.Data>?) -> Apollo.Cancellable where Query: ApolloAPI.GraphQLQuery {
        let task = Task {
            await fetchStartedSemaphore.signal()
            await fetchCompleteSemaphore.wait()
            await completeCounter.increment()
            resultHandler?(.success(.init(data: nil, extensions: nil, errors: nil, source: .cache, dependentKeys: nil)))
        }
        return CancellableForTest { [weak self] in
            await self?.cancelCounter.increment()
            task.cancel()
            await self?.afterCancelSemaphore.signal()
        }
    }
}

final class ApolloCancellableHandlerTests: XCTestCase {
    func test_CancelしなければcompleteCounterがincrementされる() async throws {
        let stub = ApolloStub()
        let query = DummyQuery()
        let task = Task {
            try await stub.fetch(query: query)
        }
        await stub.fetchStartedSemaphore.wait()
        await stub.fetchCompleteSemaphore.signal()
        do {
            _ = try await task.value
            let (completeCount, cancelCount) = await (stub.completeCounter.value, stub.cancelCounter.value)
            XCTAssertEqual(completeCount, 1)
            XCTAssertEqual(cancelCount, 0)
        } catch {
            XCTFail("成功するはず")
        }
    }
    func test_fetchが始まる前にcancelするとCancellableは呼ばれない() async throws {
        let stub = ApolloStub()
        let query = DummyQuery()
        let task = Task {
            await Task.yield() // taskのキャンセルを先にしたいためにサスペンションポイントを挟む
            return try await stub.fetch(query: query)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("キャンセルされると完了しないはず")
        } catch {
            let (completeCount, cancelCount) = await (stub.completeCounter.value, stub.cancelCounter.value)
            XCTAssertEqual(completeCount, 0)
            XCTAssertEqual(cancelCount, 0, "Cancellableが呼ばれないはず")
            XCTAssertTrue(error is CancellationError)
        }
    }
    func test_ApolloClientのfetchの後Cancellableが呼ばれてキャンセルした後に通信処理が終わった場合() async throws {
        let stub = ApolloStub()
        let query = DummyQuery()
        let task = Task {
            try await stub.fetch(query: query)
        }
        await stub.fetchStartedSemaphore.wait()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("キャンセルされると完了しないはず")
        } catch {
            await stub.afterCancelSemaphore.wait()
            await stub.fetchCompleteSemaphore.signal() // キャンセル後に通信が返ってきた想定
            let (completeCount, cancelCount) = await (stub.completeCounter.value, stub.cancelCounter.value)
            XCTAssertEqual(completeCount, 0, "キャンセル後にcomplete.signalしてもincrementされないはず")
            XCTAssertEqual(cancelCount, 1)
            XCTAssertTrue(error is CancellationError)
        }
    }
}
