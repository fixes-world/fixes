import "Fixes"
import "FRC20Indexer"
import "FlowToken"

transaction(
    tick: String,
    amt: UFix64,
    repeats: UInt64
) {
    prepare(acct: AuthAccount) {
        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        let dataStr = "op=mint,tick=".concat(tick).concat(",amt=").concat(amt.toString())
        let metadata = dataStr.utf8

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
        ?? panic("Could not borrow reference to the owner's Vault!")

        // Get a reference to the Fixes Indexer
        let indexer = FRC20Indexer.getIndexer()
        let tokenMeta = indexer.getTokenMeta(tick: tick)
        assert(tokenMeta != nil, message: "TokenMeta for tick ".concat(tick).concat(" does not exist!"))

        var i = 0 as UInt64
        while i < repeats {
            i = i + 1

            let tokenMeta = indexer.getTokenMeta(tick: tick)
            if tokenMeta!.max == tokenMeta!.supplied {
                break
            }

            // estimate the required storage
            let estimatedReqValue = Fixes.estimateValue(
                index: Fixes.totalInscriptions,
                mimeType: mimeType,
                data: metadata,
                protocol: metaProtocol,
                encoding: nil
            )

            let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

            // Create the Inscription first
            let newIns <- Fixes.createInscription(
                // Withdraw tokens from the signer's stored vault
                value: <- (flowToReserve as! @FlowToken.Vault),
                mimeType: mimeType,
                metadata: metadata,
                metaProtocol: metaProtocol,
                encoding: nil,
                parentId: nil
            )
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
