import "FlowToken"
import "FungibleToken"
import "FRC20Indexer"

transaction(
    tick: String,
    addr: Address,
    amount: UFix64
) {
    let indexer: auth(FRC20Indexer.Admin) &FRC20Indexer.InscriptionIndexer
    let receiverCap: Capability<&{FungibleToken.Receiver}>

    prepare(acct: auth(Storage, Capabilities) &Account) {
        self.indexer = acct.storage
            .borrow<auth(FRC20Indexer.Admin) &FRC20Indexer.InscriptionIndexer>(from: FRC20Indexer.IndexerStoragePath)
            ?? panic("Could not borrow a reference to the InscriptionIndexer")

        self.receiverCap = getAccount(addr)
            .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }

    execute {
        self.indexer.sponsorship(amount: amount, to: self.receiverCap, forTick: tick)

        log("Done sponsoring")
    }
}
