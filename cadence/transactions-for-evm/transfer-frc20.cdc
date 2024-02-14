import "FlowToken"

import "Fixes"
import "FRC20Indexer"
import "FixesInscriptionFactory"

transaction(
    tick: String,
    amt: UFix64,
    to: Address,
) {
    let ins: &Fixes.Inscription

    prepare(acct: AuthAccount) {
        // The Inscription's metadata
        let dataStr = FixesInscriptionFactory.buildTransferFRC20(tick: tick, to: to, amt: amt)

        // estimate the required storage
        let estimatedReqValue = FixesInscriptionFactory.estimateFrc20InsribeCost(dataStr)

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        // Withdraw tokens from the signer's stored vault
        let flowToReserve <- vaultRef.withdraw(amount: estimatedReqValue)

        // Create the Inscription first
        let newIns <- FixesInscriptionFactory.createFrc20Inscription(
            dataStr,
            <- (flowToReserve as! @FlowToken.Vault)
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
        self.ins = acct.borrow<&Fixes.Inscription>(from: newInsPath)
            ?? panic("Could not borrow reference to the new Inscription!")
    }

    execute {
        let indexer = FRC20Indexer.getIndexer()
        indexer.transfer(ins: self.ins)
    }
}
