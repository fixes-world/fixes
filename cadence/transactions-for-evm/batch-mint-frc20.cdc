import "FlowToken"
import "FRC20Indexer"
import "Fixes"
import "FixesInscriptionFactory"

transaction(
    tick: String,
    amt: UFix64,
    repeats: UInt64
) {
    prepare(acct: AuthAccount) {
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
            let newIns <- FixesInscriptionFactory.createFrc20Inscription(insDataStr, <- flowToReserve)

            // save the new Inscription to storage
            let newInsId = newIns.getId()
            let newInsPath = Fixes.getFixesStoragePath(index: newInsId)
            assert(
                acct.borrow<&AnyResource>(from: newInsPath) == nil,
                message: "Inscription with ID ".concat(newInsId.toString()).concat(" already exists!")
            )
            acct.save(<- newIns, to: newInsPath)

            // borrow a reference to the new Inscription
            let insRef = acct.borrow<&Fixes.Inscription>(from: newInsPath)
                ?? panic("Could not borrow reference to the new Inscription!")

            /// Mint the FRC20 token
            indexer.mint(ins: insRef)
        }
    }
}
