import "FungibleToken"
import "FlowToken"
import "FRC20Indexer"
import "Fixes"
import "FixesInscriptionFactory"

transaction(
    tick: String,
    amt: UFix64,
    repeats: UInt64
) {
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

        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
        ?? panic("Could not borrow reference to the owner's Vault!")

        // Get a reference to the Fixes Indexer
        let indexer = FRC20Indexer.getIndexer()
        let tokenMeta = indexer.getTokenMeta(tick: tick)
        assert(tokenMeta != nil, message: "TokenMeta for tick ".concat(tick).concat(" does not exist!"))

        let insDataStr = FixesInscriptionFactory.buildMintFRC20(tick: tick, amt: amt)

        var i = 0 as UInt64
        while i < repeats {
            i = i + 1

            let tokenMeta = indexer.getTokenMeta(tick: tick)
            if tokenMeta!.max == tokenMeta!.supplied {
                break
            }

            // estimate the required storage
            let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(insDataStr)

            // get reserved cost
            let flowToReserve <- (vaultRef.withdraw(amount: estimatedReqValue) as! @FlowToken.Vault)

            // Create the Inscription first
            let newInsId = FixesInscriptionFactory.createAndStoreFrc20Inscription(
                insDataStr,
                <- flowToReserve,
                store
            )

            // borrow a reference to the new Inscription
            let insRef = store.borrowInscriptionWritableRef(newInsId)
                ?? panic("Could not borrow a reference to the newly created Inscription!")

            /// Mint the FRC20 token
            indexer.mint(ins: insRef)
        }
    }
}
