import "FlowToken"
import "FungibleToken"
// Fixes Imports
import "FungibleTokenManager"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20FTShared"
import "FRC20Indexer"

transaction(
    tick: String,
    amount: UFix64,
) {
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

        /** ------------- Create the Inscription - Start ------------- */
        let insDataStr = FixesInscriptionFactory.buildFungibleTokenConvertFromIndexer(tick: tick, amount: amount)
        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(insDataStr)
        // get reserved cost
        let flowToReserve <- (flowVaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)
        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            insDataStr,
            <- flowToReserve,
            store
        )
        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the newly created Inscription!")
        /** ------------- End --------------------------------------- */
    }

    pre {
        FungibleTokenManager.isTokenSymbolEnabled(tick) == true: "Token Symbol is not enabled"
    }

    execute {
        // TODO
    }
}
