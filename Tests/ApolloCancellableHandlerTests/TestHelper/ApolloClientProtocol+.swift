import Foundation
import Apollo
import ApolloAPI

final class CancellableForTest: Apollo.Cancellable, Sendable {
    let canceling: @Sendable () async -> Void
    init(canceling: @Sendable @escaping () async -> Void = { print("Apollo.Cancellable called") }) {
        self.canceling = canceling
    }
    func cancel() {
        Task {
            await canceling()
        }
    }
}

// 不要な実装を省くためのデフォルト実装
extension ApolloClientProtocol {
    var store: Apollo.ApolloStore { .init() }
    func clearCache(callbackQueue: DispatchQueue, completion: ((Result<Void, Error>) -> Void)?) {}
    func fetch<Query>(query: Query, cachePolicy: Apollo.CachePolicy, contextIdentifier: UUID?, context: Apollo.RequestContext?, queue: DispatchQueue, resultHandler: Apollo.GraphQLResultHandler<Query.Data>?) -> Apollo.Cancellable where Query : ApolloAPI.GraphQLQuery {
        resultHandler?(.success(.init(data: nil, extensions: nil, errors: nil, source: .cache, dependentKeys: nil)))
        return CancellableForTest()
    }
    func watch<Query>(query: Query, cachePolicy: Apollo.CachePolicy, context: Apollo.RequestContext?, callbackQueue: DispatchQueue, resultHandler: @escaping Apollo.GraphQLResultHandler<Query.Data>) -> Apollo.GraphQLQueryWatcher<Query> where Query : ApolloAPI.GraphQLQuery {
        .init(client: self, query: query, resultHandler: resultHandler)
    }
    func perform<Mutation>(mutation: Mutation, publishResultToStore: Bool, context: Apollo.RequestContext?, queue: DispatchQueue, resultHandler: Apollo.GraphQLResultHandler<Mutation.Data>?) -> Apollo.Cancellable where Mutation : ApolloAPI.GraphQLMutation {
        resultHandler?(.success(.init(data: nil, extensions: nil, errors: nil, source: .cache, dependentKeys: nil)))
        return CancellableForTest()
    }
    func upload<Operation>(operation: Operation, files: [Apollo.GraphQLFile], context: Apollo.RequestContext?, queue: DispatchQueue, resultHandler: Apollo.GraphQLResultHandler<Operation.Data>?) -> Apollo.Cancellable where Operation : ApolloAPI.GraphQLOperation {
        resultHandler?(.success(.init(data: nil, extensions: nil, errors: nil, source: .cache, dependentKeys: nil)))
        return CancellableForTest()
    }
    func subscribe<Subscription>(subscription: Subscription, context: Apollo.RequestContext?, queue: DispatchQueue, resultHandler: @escaping Apollo.GraphQLResultHandler<Subscription.Data>) -> Apollo.Cancellable where Subscription : ApolloAPI.GraphQLSubscription {
        resultHandler(.success(.init(data: nil, extensions: nil, errors: nil, source: .cache, dependentKeys: nil)))
        return CancellableForTest()
    }
}
