import "FungibleToken"
import "FlowToken"
import "stFlowToken"
// Fixes Imports
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FungibleTokenManager"

// This transaction is used to setup airdrop pool for a token
transaction(
    symbol: String,
    mintableSupply: UFix64,
) {
    let tickerName: String
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        /** ------------- Prepare the Inscription Store - Start ---------------- */
        let storePath = Fixes.getFixesStoreStoragePath()
        if acct.borrow<&Fixes.InscriptionsStore>(from: storePath) == nil {
            acct.save(<- Fixes.createInscriptionsStore(), to: storePath)
        }

        let store = acct.borrow<&Fixes.InscriptionsStore>(from: storePath)
            ?? panic("Could not borrow a reference to the Inscriptions Store!")
        /** ------------- End -------------------------------------------------- */

        // Get a reference to the signer's stored vault
        let flowVaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        self.tickerName = "$".concat(symbol)

        /** ------------- Create the Inscription - Start ------------- */
        let fields: {String: String} = {}
        fields["supply"] = mintableSupply.toString()

        let dataStr = FixesInscriptionFactory.buildPureExecuting(
            tick: self.tickerName,
            usage: "setup-airdrop",
            fields
        )
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(self.tickerName) == true: "Token symbol is not enabled"
    }

    execute {
        FungibleTokenManager.setupAirdropsPool(self.ins)
    }
}
