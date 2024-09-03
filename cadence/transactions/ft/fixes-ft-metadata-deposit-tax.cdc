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
    let managerRef: auth(FungibleTokenManager.Sudo) &FungibleTokenManager.Manager

    prepare(acct: auth(Storage, Capabilities) &Account) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.storage.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.storage
            .borrow<auth(Fixes.Manage) &Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */


        /** ------------- Prepare the Fungible Token Manager - Start ----------- */
        let managerPath = FungibleTokenManager.getManagerStoragePath()
        if acct.storage.borrow<&FungibleTokenManager.Manager>(from: managerPath) == nil {
            acct.storage.save(<- FungibleTokenManager.createManager(), to: managerPath)

            // create the public capability for the manager
            let managerPubPath = FungibleTokenManager.getManagerPublicPath()
            acct.capabilities.unpublish(managerPubPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FungibleTokenManager.Manager>(managerPath),
                at: managerPubPath
            )
        }

        self.managerRef = acct.storage.borrow<auth(FungibleTokenManager.Sudo) &FungibleTokenManager.Manager>(from: managerPath)
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
