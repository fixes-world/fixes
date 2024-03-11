import "EVMAgent"

access(all)
fun main(
    addr: Address?
): [AgencyInfo] {
    let ret: [AgencyInfo] = []

    if let targetAddr = addr {
        if let agency = EVMAgent.borrowAgency(targetAddr) {
            ret.append(AgencyInfo(
                address: targetAddr,
                balance: agency.getFlowBalance(),
                details: agency.getDetails()
            ))
        }
    } else {
        // singleton resource
        let agencyCenter = EVMAgent.borrowAgencyCenter()
        let addrs = agencyCenter.getAgencies()
        for one in addrs {
            if let agency = EVMAgent.borrowAgency(one) {
                ret.append(AgencyInfo(
                    address: one,
                    balance: agency.getFlowBalance(),
                    details: agency.getDetails()
                ))
            }
        }
    }
    return ret
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
