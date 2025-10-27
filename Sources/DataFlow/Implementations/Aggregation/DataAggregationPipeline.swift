import Foundation

public struct DataAggregationPipeline<SubRequest: Sendable>: ModelProvider {
    public let request: AggregationRequest<SubRequest>
    public var source: DataSource<AggregationRequest<SubRequest>>
    public var transformer: AggregationTransformer

    public init(
        request: AggregationRequest<SubRequest>,
        source: DataSource<AggregationRequest<SubRequest>>
    ) {
        self.request = request
        self.source = source
        self.transformer = AggregationTransformer()
    }

    public func loadData() async throws -> Data {
        try await source.fetch(request)
    }
}

public struct AggregationTransformer: DataTransformer {
    public init() { }

    public func transform(_ data: Data) throws -> Data {
        // Passthrough transformer - data is already aggregated
        data
    }
}

public extension DataSource {
    static func aggregating<SubRequest: Sendable>(
        pipelines: [DataSource<SubRequest>],
        parallelFetch: Bool = true
    ) -> DataSource<AggregationRequest<SubRequest>>
    where Type == AggregationRequest<SubRequest> {
        DataSource { request in
            if parallelFetch {
                let tasks = request.subRequests.enumerated().map { index, subRequest in
                    Task {
                        try await pipelines[index % pipelines.count].fetch(subRequest)
                    }
                }

                var results: [Data] = []
                for task in tasks {
                    let data = try await task.value
                    results.append(data)
                }

                let combined = try JSONSerialization.data(
                    withJSONObject: results.map { data in
                        try JSONSerialization.jsonObject(with: data)
                    }
                )
                return combined
            } else {
                var results: [Data] = []
                for (index, subRequest) in request.subRequests.enumerated() {
                    let data = try await pipelines[index % pipelines.count].fetch(subRequest)
                    results.append(data)
                }

                let combined = try JSONSerialization.data(
                    withJSONObject: results.map { data in
                        try JSONSerialization.jsonObject(with: data)
                    }
                )
                return combined
            }
        }
    }
}
