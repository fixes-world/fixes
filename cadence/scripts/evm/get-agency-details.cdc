import "EVMAgent"

access(all)
fun main(
    addr: Address
): AgencyInfo? {
    let acct = getAuthAccount(addr)
    if let agencyMgr = acct.borrow<&EVMAgent.AgencyManager>(from: EVMAgent.evmAgencyManagerStoragePath) {
        let agency = agencyMgr.borrowAgency()
        return AgencyInfo(
            address: agency.getOwnerAddress(),
            balance: agency.getFlowBalance(),
            details: agency.getDetails()
        )
    }
    return nil
}

access(all) struct AgencyInfo {
    access(all) let address: Address
    access(all) let balance: UFix64
    access(all) let details: EVMAgent.AgencyStatus
    init(
        address: Address,
        balance: UFix64,
        details: EVMAgent.AgencyStatus
    ) {
        self.address = address
        self.balance = balance
        self.details = details
    }
}
