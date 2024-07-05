import "FlowToken"
import "FungibleToken"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20AccountsPool"

transaction(
    symbol: String,
    taxRatio: UFix64,
    taxRecipient: Address?,
) {
    let tickerName: String
    let managerRef: &FungibleTokenManager.Manager

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        /** ------------- Prepare the Fungible Token Manager - Start ----------- */
        let managerPath = FungibleTokenManager.getManagerStoragePath()
        if acct.borrow<&FungibleTokenManager.Manager>(from: managerPath) == nil {
            acct.save(<- FungibleTokenManager.createManager(), to: managerPath)

            // create the public capability for the manager
            let managerPubPath = FungibleTokenManager.getManagerPublicPath()
            acct.unlink(managerPubPath)
            acct.link<&FungibleTokenManager.Manager{FungibleTokenManager.ManagerPublic}>(
                managerPubPath,
                target: managerPath
            )
        }

        self.managerRef = acct.borrow<&FungibleTokenManager.Manager>(from: managerPath)
            ?? panic("Could not borrow a reference to the Fungible Token Manager")
        /** ------------- End -------------------------------------------------- */

        self.tickerName = "$".concat(symbol)
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == true: "Token is not enabled"
        taxRatio >= 0.0 && taxRatio <= 1.0: "Tax ratio must be between 0 and 1"
    }

    execute {
        let store = self.managerRef.borrowManagedFTStore(self.tickerName)
            ?? panic("Could not borrow a reference to the Fungible Token Store")

        let tokenSymbol = store.getByEnum(FRC20FTShared.ConfigType.FungibleTokenSymbol) as! String?
            ?? panic("Symbol is not set")
        assert(symbol == tokenSymbol, message: "Symbol is not set correctly")

        // Set the tax ratio
        store.set("fungibleToken:Settings:DepositTax", value: taxRatio)

        // Set the tax recipient
        if taxRecipient != nil {
            // If tax recipient is nil, then the tax will be burned
            store.set("fungibleToken:Settings:DepositTaxRecipient", value: taxRecipient!)
        }
    }
}
