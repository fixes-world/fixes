import "FRC20Indexer"
import "FRC20NFTWrapper"
import "FlowToken"
import "FungibleToken"

transaction(
    amt: UFix64,
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        // Get a reference to the signer's stored vault
        let vaultRef = acct.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")
        let toDonate <- vaultRef.withdraw(amount: amt)

        let addr = FRC20Indexer.getAddress()
        FRC20NFTWrapper.donate(addr: addr, <- (toDonate as! @FlowToken.Vault))
    }
}
