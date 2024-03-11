import "FlowToken"

import "Fixes"
import "FRC20Indexer"
import "FixesInscriptionFactory"

transaction(
    tick: String,
    max: UFix64,
    limit: UFix64,
    burnable: Bool,
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

        // build data string
        let dataStr = FixesInscriptionFactory.buildDeployFRC20(tick: tick, max: max, limit: limit, burnable: burnable)

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw tokens from the signer's stored vault
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
            dataStr,
            <- (flowToReserve as! @FlowToken.Vault),
            store
        )

        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow a reference to the new Inscription!")
    }

    execute {
        let indexer = FRC20Indexer.getIndexer()
        indexer.deploy(ins: self.ins)
    }
}
