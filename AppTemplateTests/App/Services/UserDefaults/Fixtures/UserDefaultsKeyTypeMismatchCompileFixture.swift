#if USER_DEFAULTS_KEY_TYPE_MISMATCH_COMPILE_FIXTURE
@testable import AppTemplate

nonisolated func userDefaultsKeyMismatch(
    service: any IUserDefaultsService,
    key: UserDefaultsKey<Bool>
) throws {
    try service.set("wrong", for: key)
}
#endif
