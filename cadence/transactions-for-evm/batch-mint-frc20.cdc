import "FlowToken"
import "Fixes"
import "FixesInscriptionFactory"
import "FRC20Indexer"
import "EVMAgent"

transaction(
    tick: String,
    amt: UFix64,
    repeats: UInt64,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    prepare(signer: AuthAccount) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "batch-mint-frc20(String|UFix64|UInt64)",
            params: [tick, amt.toString(), repeats.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

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
