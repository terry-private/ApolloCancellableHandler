import Apollo
import ApolloAPI

class DummyQuery: GraphQLQuery {
    struct Data: RootSelectionSet {
        enum Schema: SchemaMetadata {
            enum SchemaConfiguration: ApolloAPI.SchemaConfiguration {
                static func cacheKeyInfo(for type: ApolloAPI.Object, object: ApolloAPI.ObjectData) -> CacheKeyInfo? { nil }
            }
            static var configuration: ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self
            static func objectType(forTypename typename: String) -> ApolloAPI.Object? { nil }
        }
        static var __parentType: ApolloAPI.ParentType = Object(typename: "Query", implementedInterfaces: [])
        let __data: DataDict
        init(_dataDict: DataDict) { __data = _dataDict }
    }
    static var operationName: String { "Query" }
    static var operationDocument: ApolloAPI.OperationDocument { .init() }
}
