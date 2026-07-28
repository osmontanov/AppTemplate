actor SessionService: ISessionService {
    private var session: UserSession?

    init(initialSession: UserSession?) {
        session = initialSession
    }

    func currentSession() -> UserSession? {
        session
    }

    func signIn() -> UserSession {
        let session = UserSession(
            id: "template-user",
            displayName: "Template User"
        )
        self.session = session
        return session
    }

    func signOut() {
        session = nil
    }
}
