import "Fixes"
import "FungibleToken"
import "FlowToken"

pub fun main(
    mimeType: String,
    data: String,
    protocol: String,
    payer: Address
): Estimated {
    let cost = Fixes.estimateValue(
        index: Fixes.totalInscriptions + 1,
        mimeType: mimeType,
        data: data.utf8,
        protocol: protocol,
        encoding: nil
    ) + 0.0003

    let vaultRef = getAccount(payer)
        .getCapability(/public/flowTokenBalance)
        .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
        ?? panic("Could not borrow Balance reference to the Vault")

    return Estimated(cost: cost, balance: vaultRef.balance)
}

pub struct Estimated {
    pub let cost: UFix64
    pub let balance: UFix64

    init(
        cost: UFix64,
        balance: UFix64
    ) {
        self.cost = cost
        self.balance = balance
    }
}
