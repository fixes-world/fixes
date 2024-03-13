import "Fixes"
import "FixesInscriptionFactory"

transaction(
) {
    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let storeRef = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        let limit = 1000
        var i = 0
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == Type<@Fixes.Inscription>() {
                if let ins <- acct.load<@Fixes.Inscription>(from: path) {
                    storeRef.store(<- ins)
                    i = i + 1
                    if i > limit {
                        return false
                    }
                }
            }
            return true
        })
    }
}
