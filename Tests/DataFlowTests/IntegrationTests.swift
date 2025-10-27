import Testing
import Foundation
@testable import DataFlow

// MARK: - Cross-Pipeline Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {

    // MARK: Complete Pipeline Tests

    @Test("Complete pipeline from request to model")
    func completePipeline() async throws {
        let mockNetworkSource = DataSource<RESTRequest> { request in
            #expect(request.path == "/api/users/1")
            return MockDataFixtures.userJSON
        }

        let pipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/api/users/1"),
            source: mockNetworkSource
        )

        let user = try await pipeline.loadData()

        #expect(user.id == 1)
        #expect(user.name == "John Doe")
        #expect(user.email == "john@example.com")
    }

    @Test("Mixed pipeline types working together")
    func mixedPipelineTypes() async throws {
        let restSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }
        let restPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: restSource
        )

        let customSource = DataSource<CustomDataRequest> { _ in MockDataFixtures.userJSON }
        let customPipeline = CustomDataPipeline<User>(
            request: CustomDataRequest(identifier: "cache", parameters: [:]),
            source: customSource
        )

        let restUser = try await restPipeline.loadData()
        let customUser = try await customPipeline.loadData()

        #expect(restUser == customUser)
    }

    @Test("Sequential data loading from multiple sources")
    func sequentialDataLoading() async throws {
        let userSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }
        let postSource = DataSource<RESTRequest> { _ in MockDataFixtures.postJSON }

        let userPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: userSource
        )

        let postPipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/posts/101"),
            source: postSource
        )

        let user = try await userPipeline.loadData()
        let post = try await postPipeline.loadData()

        #expect(user.id == 1)
        #expect(post.author.name == "John Doe")
    }

    // MARK: Advanced Integration Scenarios

    @Test("Pipeline orchestration with dependent requests")
    func dependentRequests() async throws {
        let userSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }
        let postSource = DataSource<RESTRequest> { request in
            #expect(request.path.contains("/posts"))
            return MockDataFixtures.postJSON
        }

        let userPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: userSource
        )

        let user = try await userPipeline.loadData()

        let postPipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/users/\(user.id)/posts/101"),
            source: postSource
        )

        let post = try await postPipeline.loadData()

        #expect(post.author.id == user.id)
    }

    @Test("Multi-stage data transformation pipeline")
    func multiStageTransformation() async throws {
        let source = DataSource<RESTRequest> { _ in MockDataFixtures.usersJSON }

        let data = try await source.fetch(RESTRequest(path: "/users"))
        let transformer = ArrayTransformer<User>()
        let users = try transformer.transform(data)

        let sortedUsers = users.sorted { $0.id < $1.id }
        let firstUser = sortedUsers.first

        #expect(firstUser?.id == 1)
        #expect(sortedUsers.count == 2)
    }

    @Test("Parallel pipeline execution with different models")
    func parallelPipelineExecution() async throws {
        let userSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }
        let postSource = DataSource<RESTRequest> { _ in MockDataFixtures.postJSON }

        let userPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: userSource
        )

        let postPipeline = RESTPipeline<Post>(
            request: RESTRequest(path: "/posts/101"),
            source: postSource
        )

        async let user = userPipeline.loadData()
        async let post = postPipeline.loadData()

        let (loadedUser, loadedPost) = try await (user, post)

        #expect(loadedUser.id == 1)
        #expect(loadedPost.id == 101)
    }

    // MARK: Real-World Integration Scenarios

    @Test("Simulate REST API with fallback to cache")
    func restAPIWithCacheFallback() async throws {
        enum NetworkError: Error {
            case unavailable
        }

        let networkSource = DataSource<RESTRequest> { _ in
            throw NetworkError.unavailable
        }

        let cacheSource = DataSource<CustomDataRequest> { _ in MockDataFixtures.userJSON }

        let networkPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: networkSource
        )

        do {
            _ = try await networkPipeline.loadData()
            Issue.record("Network should have failed")
        } catch {
            let cachePipeline = CustomDataPipeline<User>(
                request: CustomDataRequest(identifier: "user-1", parameters: [:]),
                source: cacheSource
            )

            let cachedUser = try await cachePipeline.loadData()
            #expect(cachedUser.id == 1)
        }
    }

    @Test("Complex data aggregation from multiple sources")
    func dataAggregation() async throws {
        let userSource = DataSource<RESTRequest> { _ in MockDataFixtures.userJSON }
        let usersSource = DataSource<RESTRequest> { _ in MockDataFixtures.usersJSON }

        let singleUserPipeline = RESTPipeline<User>(
            request: RESTRequest(path: "/users/1"),
            source: userSource
        )

        let data = try await usersSource.fetch(RESTRequest(path: "/users"))
        let transformer = ArrayTransformer<User>()
        let allUsers = try transformer.transform(data)

        let singleUser = try await singleUserPipeline.loadData()

        let combinedUsers = [singleUser] + allUsers.filter { $0.id != singleUser.id }

        #expect(combinedUsers.count == 2)
    }

    @Test("Pipeline with custom request routing")
    func customRequestRouting() async throws {
        enum Route {
            case users(id: Int)
            case posts(id: Int)
        }

        let router = DataSource<Route> { route in
            switch route {
            case .users:
                return MockDataFixtures.userJSON
            case .posts:
                return MockDataFixtures.postJSON
            }
        }

        let userData = try await router.fetch(.users(id: 1))
        let postData = try await router.fetch(.posts(id: 101))

        let userTransformer = JSONTransformer<User>()
        let postTransformer = JSONTransformer<Post>()

        let user = try userTransformer.transform(userData)
        let post = try postTransformer.transform(postData)

        #expect(user.id == 1)
        #expect(post.id == 101)
    }

    // MARK: Error Recovery Integration

    @Test("Pipeline error recovery with retry logic")
    func errorRecoveryWithRetry() async throws {
        actor RetryCounter {
            private var count = 0

            func increment() -> Int {
                count += 1
                return count
            }
        }

        let counter = RetryCounter()

        let source = DataSource<RESTRequest> { _ in
            let attempt = await counter.increment()
            if attempt < 2 {
                throw URLError(.networkConnectionLost)
            }
            return MockDataFixtures.userJSON
        }

        var lastError: Error?
        var user: User?

        for _ in 0..<3 {
            do {
                let pipeline = RESTPipeline<User>(
                    request: RESTRequest(path: "/users/1"),
                    source: source
                )
                user = try await pipeline.loadData()
                lastError = nil
                break
            } catch {
                lastError = error
            }
        }

        #expect(user?.id == 1)
        #expect(lastError == nil)
    }
}
