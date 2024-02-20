import "FlowToken"
import "FungibleToken"

import "Fixes"
import "FRC20Indexer"
import "FixesInscriptionFactory"

transaction(
    tick: String,
    amt: UFix64,
) {
    let ins: &Fixes.Inscription
    let recipient: &FlowToken.Vault{FungibleToken.Receiver}

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
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")

        let dataStr = FixesInscriptionFactory.buildBurnFRC20(tick: tick, amt: amt)

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Withdraw tokens from the signer's stored vault
        let flowToReserve <- (vaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)

        // Create the Inscription first
        let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(dataStr, <- flowToReserve, store)

        // borrow a reference to the new Inscription
        self.ins = store.borrowInscriptionWritableRef(newInsId)
            ?? panic("Could not borrow reference to the new Inscription!")

        // reference to the recipient's receiver
        self.recipient = acct.getCapability(/public/flowTokenReceiver)
            .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
            ?? panic("Could not borrow receiver reference to the recipient's Vault")
    }

    execute {
        let indexer = FRC20Indexer.getIndexer()
        let received <- indexer.burn(ins: self.ins)

        if received.balance > 0.0 {
            // Deposit the withdrawn tokens in the recipient's receiver
            self.recipient.deposit(from: <- received)
        } else {
            destroy received
        }
    }
}
