import "FlowToken"
import "FungibleToken"
import "FRC20Indexer"

transaction(
    tick: String,
    addr: Address,
    amount: UFix64
) {
    let indexer: &FRC20Indexer.InscriptionIndexer
    let receiverCap: Capability<&FlowToken.Vault{FungibleToken.Receiver}>

    prepare(acct: AuthAccount) {
        self.indexer = acct.borrow<&FRC20Indexer.InscriptionIndexer>(from: FRC20Indexer.IndexerStoragePath)
            ?? panic("Could not borrow a reference to the InscriptionIndexer")

        self.receiverCap = getAccount(addr)
            .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }

    execute {
        self.indexer.sponsorship(amount: amount, to: self.receiverCap, forTick: tick)

        log("Done sponsoring")
    }
}
