import "FRC20Indexer"
import "FRC20NFTWrapper"
import "FlowToken"

transaction(
    amt: UFix64,
) {
    prepare(acct: AuthAccount) {
        // Get a reference to the signer's stored vault
        let vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")
        let toDonate <- vaultRef.withdraw(amount: amt)

        let addr = FRC20Indexer.getAddress()
        FRC20NFTWrapper.donate(addr: addr, <- (toDonate as! @FlowToken.Vault))
    }
}
