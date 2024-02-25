import Foundation
@preconcurrency import Apollo
import ApolloAPI

public extension ApolloClientProtocol where Self: Sendable {
    /// ApolloCancellableHandlerを利用してキャンセル可能 & GraphQLResultをGraphQLOperation.Data?に変換して返す
    /// - Parameter operation: fetch, mutation などCancellableを返すoperationメソッド
    /// - Returns: GraphQLOperation.Data?
    func withApolloCancellableHandler<Data: RootSelectionSet>(operation: @Sendable @escaping (GraphQLResultHandler<Data>?) -> any Cancellable) async throws -> Data? {
        let handler = ApolloCancellableHandler(apollo: self)
        let result = try await handler.handle(operation: operation)
        // TODO: Errorハンドリングの実装によってerrorの優先順位はつけた方が良さそう
        if let errors = result.errors, let error = errors.first {
            throw error
        } else {
            return result.data
        }
    }
}

// 各種オペレーションメソッドのasyncバージョン
// ⚠️ ApolloClient, Query, Query.Data がSendableに準拠しないと生えない
public extension ApolloClientProtocol where Self: Sendable {
    func fetch<Query: GraphQLQuery>(
        query: Query,
        cachePolicy: CachePolicy = .fetchIgnoringCacheCompletely,
        contextIdentifier: UUID? = nil,
        context: RequestContext? = nil,
        queue: DispatchQueue = .global()
    ) async throws -> Query.Data? where Query: Sendable, Query.Data: Sendable {
        try await withApolloCancellableHandler { resultHandler in
            self.fetch(query: query, cachePolicy: cachePolicy, contextIdentifier: contextIdentifier, context: context, queue: queue, resultHandler: resultHandler)
        }
    }
    func perform<Mutation: GraphQLMutation>(
        mutation: Mutation,
        publishResultToStore: Bool = true,
        context: RequestContext? = nil,
        queue: DispatchQueue = .global()
    ) async throws -> Mutation.Data? where Mutation: Sendable, Mutation.Data: Sendable {
        try await withApolloCancellableHandler { resultHandler in
            self.perform(mutation: mutation, publishResultToStore: publishResultToStore, context: context, queue: queue, resultHandler: resultHandler)
        }
    }
    // TODO: その他のオペレーションメソッドの実装
}
