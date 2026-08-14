import Foundation

nonisolated enum UITestSessionValidationMode: Equatable, Sendable {
    case disabled
    case scripted
}

nonisolated struct UITestSessionSeed: Equatable, Sendable {
    let keychainData: Data?

    let validationMode: UITestSessionValidationMode

    init(
        keychainData: Data?,
        validationMode: UITestSessionValidationMode = .disabled
    ) {
        self.keychainData = keychainData
        self.validationMode = validationMode
    }
}

nonisolated struct UITestLocalDatabaseSeed: Equatable, Sendable {
    let examples: [ExampleRecord]
    let favorites: [FavoriteProductSnapshot]
    let cart: CartAggregate?

    init(
        examples: [ExampleRecord],
        favorites: [FavoriteProductSnapshot] = [],
        cart: CartAggregate? = nil
    ) {
        self.examples = examples
        self.favorites = favorites
        self.cart = cart
    }
}

nonisolated struct UITestPreferencesSeed: Equatable, Sendable {
    let encodedValues: [String: Data]
}

nonisolated struct UITestNotificationSeed: Equatable, Sendable {
    let authorizationStatus: LocalNotificationAuthorizationStatus
    let pendingRequests: [LocalNotificationRequest]
    let labSteps: [UITestNotificationLabStep]

    init(
        authorizationStatus: LocalNotificationAuthorizationStatus,
        pendingRequests: [LocalNotificationRequest],
        labSteps: [UITestNotificationLabStep] = []
    ) {
        self.authorizationStatus = authorizationStatus
        self.pendingRequests = pendingRequests
        self.labSteps = labSteps
    }
}

nonisolated enum UITestNotificationLabStep: Equatable, Sendable {
    case authorization(UInt)
    case replaceCategories([String])
    case resetCategories
    case schedule(String)
    case removePending([String])
    case removeDelivered([String])
    case resetLabData
    case removeAllPending
    case removeAllDelivered
    case setBadge(Int)
    case clearBadge
}

nonisolated struct UITestImageSeed: Equatable, Sendable {
    let steps: [ScriptedImageStep]
}

nonisolated enum UITestSeedError: Error, Equatable, Sendable {
    case unknownPreferenceKey
}

nonisolated extension UITestPreferencesSeed {
    func apply(to service: any IUserDefaultsService) throws {
        let decoder = JSONDecoder()
        for (name, data) in encodedValues {
            switch name {
            case "Store.CatalogLayout":
                try service.set(
                    try decoder.decode(String.self, from: data),
                    for: .string(name)
                )
            case "Store.CatalogSort":
                try service.set(
                    try decoder.decode(String.self, from: data),
                    for: .string(name)
                )
            case "Store.RemotePageSize":
                try service.set(
                    try decoder.decode(Int.self, from: data),
                    for: .int(name)
                )
            default:
                throw UITestSeedError.unknownPreferenceKey
            }
        }
    }
}

nonisolated extension UITestScenario {
    func preparedForLaunch() -> UITestScenario {
        switch id {
        case .guestStore:
            GuestStoreUITestFixture.scenario
        case .protectedFavorite:
            ProtectedFavoriteUITestFixture.scenario
        case .productReminder:
            ProductReminderUITestFixture.scenario
        case .servicesBasic:
            ServicesBasicUITestFixture.scenario
        case .accessibilitySmoke:
            AccessibilitySmokeUITestFixture.scenario
        }
    }
}

private nonisolated enum AccessibilitySmokeUITestFixture {
    static var scenario: UITestScenario {
        UITestScenario(
            id: .accessibilitySmoke,
            appState: .initial,
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(
                examples: [],
                cart: CartAggregate(
                    id: CartAggregate.singletonID,
                    revision: 0,
                    lines: []
                )
            ),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [
                "Store.CatalogLayout": Data(#""list""#.utf8),
                "Store.CatalogSort": Data(#""featured""#.utf8),
                "Store.RemotePageSize": Data("10".utf8)
            ]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .notDetermined,
                pendingRequests: []
            ),
            imageSeed: UITestImageSeed(steps: []),
            networkPolicy: .failClosed,
            remoteSteps: remoteSteps
        )
    }

    static var remoteSteps: [ScriptedNetworkStep] {
        [
                jsonStep(
                    path: "/products/categories",
                    body: #"[{"slug":"phones","name":"Phones","url":"https://dummyjson.com/products/category/phones"}]"#
                ),
                jsonStep(
                    path: "/products",
                    queryItems: [
                        URLQueryItem(name: "limit", value: "10"),
                        URLQueryItem(name: "skip", value: "0")
                    ],
                    body: #"{"products":[{"id":88,"title":"Accessibility Phone","description":"Offline accessibility fixture","category":"phones","price":49,"rating":4.5,"stock":5,"brand":"Demo","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":null}],"total":1,"skip":0,"limit":10}"#
                )
        ]
    }

    private static func jsonStep(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: String
    ) -> ScriptedNetworkStep {
        ScriptedNetworkStep(
            origin: RemoteService.defaultDummyJSONBaseURL,
            method: .get,
            path: path,
            queryItems: queryItems,
            headers: [:],
            shouldHandleCookies: true,
            body: .none,
            result: .response(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data(body.utf8)
            )
        )
    }
}

private nonisolated enum ServicesBasicUITestFixture {
    static var scenario: UITestScenario {
        UITestScenario(
            id: .servicesBasic,
            appState: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(examples: examples),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [
                "Store.CatalogLayout": Data(#""list""#.utf8),
                "Store.CatalogSort": Data(#""featured""#.utf8),
                "Store.RemotePageSize": Data("10".utf8)
            ]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .authorized,
                pendingRequests: [LocalNotificationRequest(
                    id: try! LocalNotificationID("store.services-seed"),
                    content: LocalNotificationContent(
                        title: "Store seed",
                        body: "Preserved by Services reset"
                    ),
                    trigger: .immediate
                )],
                labSteps: [
                    .schedule("services.lab.immediate"),
                    .resetLabData
                ]
            ),
            imageSeed: UITestImageSeed(steps: []),
            networkPolicy: .failClosed,
            remoteSteps: AccessibilitySmokeUITestFixture.remoteSteps + [
                jsonStep(
                    path: "/products/search",
                    queryItems: [
                        URLQueryItem(name: "q", value: "phone"),
                        URLQueryItem(name: "limit", value: "10"),
                        URLQueryItem(name: "skip", value: "0")
                    ],
                    body: #"{"products":[{"id":88,"title":"Services Phone","description":"Offline Services fixture","category":"phones","price":49,"rating":4.5,"stock":5,"brand":"Demo","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":null}],"total":1,"skip":0,"limit":10}"#
                )
            ]
        )
    }

    private static var examples: [ExampleRecord] {
        (1...21).map {
            ExampleRecord(
                id: String(format: "services-%02d", $0),
                payload: "Offline service record \($0)"
            )
        }
    }

    private static func jsonStep(
        path: String,
        queryItems: [URLQueryItem],
        body: String
    ) -> ScriptedNetworkStep {
        ScriptedNetworkStep(
            origin: RemoteService.defaultDummyJSONBaseURL,
            method: .get,
            path: path,
            queryItems: queryItems,
            headers: [:],
            shouldHandleCookies: true,
            body: .none,
            result: .response(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data(body.utf8)
            )
        )
    }
}

actor ScriptedLocalNotificationLabService:
    ILocalNotificationLabService,
    ILocalNotificationAppWideCapabilities
{
    private let lab: any ILocalNotificationLabService
    private let appWide: any ILocalNotificationAppWideCapabilities
    private let tracker: UITestScriptConsumptionTracker
    private var steps: [UITestNotificationLabStep]

    init(
        lab: any ILocalNotificationLabService,
        appWide: any ILocalNotificationAppWideCapabilities,
        steps: [UITestNotificationLabStep],
        tracker: UITestScriptConsumptionTracker
    ) {
        self.lab = lab
        self.appWide = appWide
        self.steps = steps
        self.tracker = tracker
    }

    func settings() async -> LocalNotificationSettings { await lab.settings() }

    func requestAuthorization(
        _ options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        try await require(.authorization(options.rawValue))
        return try await lab.requestAuthorization(options)
    }

    func replaceLabCategories(
        _ categories: [LocalNotificationCategory]
    ) async throws {
        try await require(.replaceCategories(categories.map(\.id.value)))
        try await lab.replaceLabCategories(categories)
    }

    func resetLabCategories() async throws {
        try await require(.resetCategories)
        try await lab.resetLabCategories()
    }

    func scheduleLab(_ request: LocalNotificationRequest) async throws {
        try await require(.schedule(request.id.value))
        try await lab.scheduleLab(request)
    }

    func pendingLab() async -> [LocalNotificationPendingSnapshot] {
        await lab.pendingLab()
    }

    func deliveredLab() async -> [LocalNotificationDeliveredSnapshot] {
        await lab.deliveredLab()
    }

    func removeLabPending(_ ids: Set<LocalNotificationID>) async {
        guard await accept(.removePending(ids.map(\.value).sorted())) else { return }
        await lab.removeLabPending(ids)
    }

    func removeLabDelivered(_ ids: Set<LocalNotificationID>) async {
        guard await accept(.removeDelivered(ids.map(\.value).sorted())) else { return }
        await lab.removeLabDelivered(ids)
    }

    func resetLabData() async throws {
        try await require(.resetLabData)
        try await lab.resetLabData()
    }

    func pendingAppOwned() async -> [LocalNotificationPendingSnapshot] {
        await appWide.pendingAppOwned()
    }

    func deliveredAppOwned() async -> [LocalNotificationDeliveredSnapshot] {
        await appWide.deliveredAppOwned()
    }

    func removeAllPending() async {
        guard await accept(.removeAllPending) else { return }
        await appWide.removeAllPending()
    }

    func removeAllDelivered() async {
        guard await accept(.removeAllDelivered) else { return }
        await appWide.removeAllDelivered()
    }

    func setBadgeCount(_ count: Int) async throws {
        try await require(.setBadge(count))
        try await appWide.setBadgeCount(count)
    }

    func clearBadge() async throws {
        try await require(.clearBadge)
        try await appWide.clearBadge()
    }

    private func require(_ step: UITestNotificationLabStep) async throws {
        guard await accept(step) else {
            throw LocalNotificationServiceError.system(
                operation: .schedule,
                domain: "UITestNotificationScript",
                code: 1
            )
        }
    }

    private func accept(_ step: UITestNotificationLabStep) async -> Bool {
        guard steps.first == step else {
            await tracker.didFail(.notification)
            return false
        }
        steps.removeFirst()
        await tracker.didConsume(.notification)
        return true
    }
}

private nonisolated enum ProductReminderUITestFixture {
    static var scenario: UITestScenario {
        UITestScenario(
            id: .productReminder,
            appState: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(
                examples: [],
                cart: CartAggregate(
                    id: CartAggregate.singletonID,
                    revision: 0,
                    lines: []
                )
            ),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [
                "Store.CatalogLayout": Data(#""list""#.utf8),
                "Store.CatalogSort": Data(#""featured""#.utf8),
                "Store.RemotePageSize": Data("10".utf8)
            ]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .authorized,
                pendingRequests: []
            ),
            imageSeed: UITestImageSeed(
                steps: [imageStep]
            ),
            networkPolicy: .failClosed,
            remoteSteps: [
                jsonStep(
                    path: "/products/categories",
                    body: #"[{"slug":"phones","name":"Phones","url":"https://dummyjson.com/products/category/phones"}]"#
                ),
                jsonStep(
                    path: "/products",
                    queryItems: pageQuery,
                    body: pageJSON
                ),
                jsonStep(path: "/products/7", body: productJSON),
                jsonStep(
                    path: "/products/category/phones",
                    queryItems: relatedQuery,
                    body: pageJSON
                ),
                jsonStep(path: "/products/7", body: productJSON)
            ]
        )
    }

    private static var imageStep: ScriptedImageStep {
        ScriptedImageStep(
            url: URL(string: "https://dummyjson.com/image/reminder-phone.png")!,
            result: .success(LoadedImage(
                data: Data(base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
                )!,
                mimeType: "image/png",
                pixelWidth: 1,
                pixelHeight: 1
            ))
        )
    }

    private static func jsonStep(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: String
    ) -> ScriptedNetworkStep {
        ScriptedNetworkStep(
            origin: RemoteService.defaultDummyJSONBaseURL,
            method: .get,
            path: path,
            queryItems: queryItems,
            headers: [:],
            shouldHandleCookies: true,
            body: .none,
            result: .response(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data(body.utf8)
            )
        )
    }

    private static let pageQuery = [
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(name: "skip", value: "0")
    ]
    private static let relatedQuery = [
        URLQueryItem(name: "limit", value: "26"),
        URLQueryItem(name: "skip", value: "0")
    ]
    private static let productJSON =
        #"{"id":7,"title":"Reminder Phone","description":"A scripted reminder product","category":"phones","price":49,"rating":4.5,"stock":5,"brand":"Demo","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":"https://dummyjson.com/image/reminder-phone.png"}"#
    private static let pageJSON =
        #"{"products":["# + productJSON + #"],"total":1,"skip":0,"limit":10}"#
}

private nonisolated enum ProtectedFavoriteUITestFixture {
    static var scenario: UITestScenario {
        UITestScenario(
            id: .protectedFavorite,
            appState: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(
                examples: [],
                favorites: [],
                cart: CartAggregate(
                    id: CartAggregate.singletonID,
                    revision: 0,
                    lines: []
                )
            ),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [
                "Store.CatalogLayout": Data(#""list""#.utf8),
                "Store.CatalogSort": Data(#""featured""#.utf8),
                "Store.RemotePageSize": Data("10".utf8)
            ]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .notDetermined,
                pendingRequests: []
            ),
            imageSeed: UITestImageSeed(steps: []),
            networkPolicy: .failClosed,
            remoteSteps: [
                jsonStep(
                    path: "/products/categories",
                    body: #"[{"slug":"phones","name":"Phones","url":"https://dummyjson.com/products/category/phones"}]"#
                ),
                jsonStep(
                    path: "/products",
                    queryItems: pageQuery,
                    body: pageJSON
                ),
                jsonStep(path: "/products/1", body: productJSON),
                jsonStep(
                    path: "/products/category/phones",
                    queryItems: relatedQuery,
                    body: pageJSON
                ),
                jsonStep(
                    method: .post,
                    path: "/auth/login",
                    shouldHandleCookies: false,
                    bodyExpectation: .json(Data(
                        #"{"username":"invalid-user","password":"invalid-password","expiresInMins":30}"#.utf8
                    )),
                    statusCode: 400,
                    body: #"{"message":"Invalid credentials"}"#
                ),
                jsonStep(
                    method: .post,
                    path: "/auth/login",
                    shouldHandleCookies: false,
                    bodyExpectation: .json(Data(
                        #"{"username":"emilys","password":"emilyspass","expiresInMins":30}"#.utf8
                    )),
                    body: loginJSON
                ),
                jsonStep(path: "/products/1", body: productJSON)
            ]
        )
    }

    private static func jsonStep(
        method: HTTPMethod = .get,
        path: String,
        queryItems: [URLQueryItem] = [],
        shouldHandleCookies: Bool? = true,
        bodyExpectation: ScriptedBodyExpectation = .none,
        statusCode: Int = 200,
        body: String
    ) -> ScriptedNetworkStep {
        ScriptedNetworkStep(
            origin: RemoteService.defaultDummyJSONBaseURL,
            method: method,
            path: path,
            queryItems: queryItems,
            headers: [:],
            shouldHandleCookies: shouldHandleCookies,
            body: bodyExpectation,
            result: .response(
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"],
                body: Data(body.utf8)
            )
        )
    }

    private static let pageQuery = [
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(name: "skip", value: "0")
    ]
    private static let relatedQuery = [
        URLQueryItem(name: "limit", value: "26"),
        URLQueryItem(name: "skip", value: "0")
    ]
    private static let productJSON =
        #"{"id":1,"title":"Protected Phone","description":"Favorite after login","category":"phones","price":49,"rating":4.5,"stock":5,"brand":"Demo","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":null}"#
    private static let pageJSON =
        #"{"products":["# + productJSON + #"],"total":1,"skip":0,"limit":10}"#
    private static let loginJSON =
        #"{"id":1,"username":"emilys","firstName":"Emily","lastName":"Johnson","email":"emily@example.com","image":null,"accessToken":"access","refreshToken":"refresh"}"#
}

private nonisolated enum GuestStoreUITestFixture {
    static var scenario: UITestScenario {
        let favoriteProduct = ProductSnapshot(
            id: 2,
            title: "Offline Phone Two",
            price: Decimal(79),
            thumbnailURL: nil
        )
        return UITestScenario(
            id: .guestStore,
            appState: AppState(
                hasCompletedOnboarding: true,
                isMaintenanceEnabled: false
            ),
            sessionSeed: UITestSessionSeed(keychainData: nil),
            localDatabaseSeed: UITestLocalDatabaseSeed(
                examples: [
                    ExampleRecord(
                        id: "guest-store-example",
                        payload: "offline"
                    )
                ],
                favorites: [
                    FavoriteProductSnapshot(
                        canonicalID: FavoriteProductSnapshot.canonicalID(
                            userID: 1,
                            productID: favoriteProduct.id
                        ),
                        userID: 1,
                        product: favoriteProduct
                    )
                ],
                cart: CartAggregate(
                    id: CartAggregate.singletonID,
                    revision: 0,
                    lines: []
                )
            ),
            preferencesSeed: UITestPreferencesSeed(encodedValues: [
                "Store.CatalogLayout": Data(#""list""#.utf8),
                "Store.CatalogSort": Data(#""featured""#.utf8),
                "Store.RemotePageSize": Data("10".utf8)
            ]),
            notificationSeed: UITestNotificationSeed(
                authorizationStatus: .notDetermined,
                pendingRequests: []
            ),
            imageSeed: UITestImageSeed(
                steps: [imageStep]
            ),
            networkPolicy: .failClosed,
            remoteSteps: remoteSteps
        )
    }

    private static var imageStep: ScriptedImageStep {
        ScriptedImageStep(
            url: URL(string: "https://dummyjson.com/image/phone-one.png")!,
            result: .success(LoadedImage(
                data: Data(base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
                )!,
                mimeType: "image/png",
                pixelWidth: 1,
                pixelHeight: 1
            ))
        )
    }

    private static var remoteSteps: [ScriptedNetworkStep] {
        [
            jsonStep(
                path: "/products/categories",
                body: #"[{"slug":"phones","name":"Phones","url":"https://dummyjson.com/products/category/phones"}]"#
            ),
            jsonStep(
                path: "/products",
                queryItems: pageQuery(skip: 0),
                body: pageJSON(products: [productOne, productTwo], skip: 0)
            ),
            jsonStep(
                path: "/products",
                queryItems: pageQuery(skip: 2),
                body: pageJSON(products: [productThree], skip: 2)
            )
        ]
            + detailSteps(productID: 1, body: productOne)
            + detailSteps(productID: 2, body: productTwo)
            + detailSteps(productID: 1, body: productOne)
            + [jsonStep(path: "/products/1", body: productOne)]
    }

    private static func detailSteps(
        productID: Int,
        body: String
    ) -> [ScriptedNetworkStep] {
        [
            jsonStep(path: "/products/\(productID)", body: body),
            jsonStep(
                path: "/products/category/phones",
                queryItems: relatedQuery,
                body: relatedPageJSON
            )
        ]
    }

    private static func jsonStep(
        path: String,
        queryItems: [URLQueryItem] = [],
        body: String
    ) -> ScriptedNetworkStep {
        ScriptedNetworkStep(
            origin: RemoteService.defaultDummyJSONBaseURL,
            method: .get,
            path: path,
            queryItems: queryItems,
            headers: [:],
            shouldHandleCookies: true,
            body: .none,
            result: .response(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data(body.utf8)
            )
        )
    }

    private static func pageQuery(skip: Int) -> [URLQueryItem] {
        [
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "skip", value: String(skip))
        ]
    }

    private static var relatedQuery: [URLQueryItem] {
        [
            URLQueryItem(name: "limit", value: "26"),
            URLQueryItem(name: "skip", value: "0")
        ]
    }

    private static func pageJSON(
        products: [String],
        skip: Int
    ) -> String {
        #"{"products":["# + products.joined(separator: ",")
            + #"],"total":3,"skip":"# + String(skip)
            + #", "limit":10}"#
    }

    private static var relatedPageJSON: String {
        #"{"products":["# + [productOne, productTwo].joined(separator: ",")
            + #"],"total":2,"skip":0,"limit":26}"#
    }

    private static let productOne =
        #"{"id":1,"title":"Offline Phone One","description":"First scripted phone","category":"phones","price":49,"rating":4.5,"stock":5,"brand":"Demo","availabilityStatus":"In Stock","reviews":[{"rating":5,"comment":"Works offline","date":"1970-01-01T00:00:00Z","reviewerName":"Sample Reviewer"}],"images":[],"thumbnail":"https://dummyjson.com/image/phone-one.png"}"#

    private static let productTwo =
        #"{"id":2,"title":"Offline Phone Two","description":"Related scripted phone","category":"phones","price":79,"rating":4,"stock":3,"brand":"Demo","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":null}"#

    private static let productThree =
        #"{"id":3,"title":"Offline Phone Three","description":"Second catalog page","category":"phones","price":99,"rating":3.5,"stock":2,"brand":"Demo","availabilityStatus":"In Stock","reviews":[],"images":[],"thumbnail":null}"#
}
