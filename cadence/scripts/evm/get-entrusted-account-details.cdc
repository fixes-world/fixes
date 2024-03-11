import "FungibleToken"
import "FlowToken"
import "HybridCustody"
import "EVMAgent"

access(all)
fun main(
    addr: Address
): EntrustedAccountDetails? {
    if let status = EVMAgent.borrowEntrustStatus(addr) {
        let acct = getAuthAccount(addr)
        let owned = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let flowRef = acct.getCapability(/public/flowTokenBalance)
                .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
        return EntrustedAccountDetails(
            address: addr,
            entrustedBy: status.key,
            flowBalance: flowRef?.balance ?? 0.0,
            feeSpent: status.getFeeSpent(),
            parents: owned.getParentAddresses()
        )
    }
    return nil
}

access(all) struct EntrustedAccountDetails {
    let address: Address
    let entrustedBy: String
    let flowBalance: UFix64
    let feeSpent: UFix64
    let parents: [Address]

    init(
        address: Address,
        entrustedBy: String,
        flowBalance: UFix64,
        feeSpent: UFix64,
        parents: [Address]
    ) {
        self.address = address
        self.entrustedBy = entrustedBy
        self.flowBalance = flowBalance
        self.feeSpent = feeSpent
        self.parents = parents
    }
}
