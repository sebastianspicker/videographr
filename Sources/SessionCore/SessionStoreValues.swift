import Foundation

extension SessionStore {
    struct Values {
        var rootDirectory: URL?
        var policyVerificationHook: ((URL) throws -> Void)?
        var importSourceOpenedHook: (() throws -> Void)?
        var persistenceFaultHook: ((PersistenceFaultPoint) throws -> Void)?
    }

    convenience init(_ values: Values) {
        self.init(rootDirectory: values.rootDirectory)
        policyVerificationHook = values.policyVerificationHook
        importSourceOpenedHook = values.importSourceOpenedHook
        persistenceFaultHook = values.persistenceFaultHook
    }
}
