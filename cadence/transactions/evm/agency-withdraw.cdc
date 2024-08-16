import "FlowToken"
import "FungibleToken"
// Import the Fixes contract
import "EVMAgent"

transaction(
    amt: UFix64
) {
    let manager: auth(EVMAgent.Manage) &EVMAgent.AgencyManager
    let receiver: &{FungibleToken.Receiver}

    prepare(acct: auth(Storage, Capabilities) &Account) {
        // Borrow the manager
        self.manager = acct.storage
            .borrow<auth(EVMAgent.Manage) &EVMAgent.AgencyManager>(from: EVMAgent.evmAgencyManagerStoragePath)
            ?? panic("Could not borrow the manager")

        self.receiver = acct
            .capabilities.get<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            .borrow() ?? panic("Could not borrow receiver capability")
    }

    execute {
        self.receiver.deposit(from: <- self.manager.withdraw(amt: amt))
        log("Deposited into account")
    }
}
