import "Fixes"
import "FRC20Indexer"
import "FlowToken"
import "FungibleToken"

transaction(
    tick: String,
    amt: UFix64,
) {
    let ins: &Fixes.Inscription
    let recipient: &FlowToken.Vault{FungibleToken.Receiver}

    prepare(acct: AuthAccount) {
        // basic attributes
        let mimeType = "text/plain"
        let metaProtocol = "frc20"
        let dataStr = "op=burn,tick=".concat(tick).concat(",amt=").concat(amt.toString())
        let metadata = dataStr.utf8

        // estimate the required storage
        let estimatedReqValue = Fixes.estimateValue(
            index: Fixes.totalInscriptions,
            mimeType: mimeType,
            data: metadata,
            protocol: metaProtocol,
            encoding: nil
        )

        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to the owner's Vault!")
        // Withdraw tokens from the signer's stored vault
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
        self.ins = acct.borrow<&Fixes.Inscription>(from: newInsPath)
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
