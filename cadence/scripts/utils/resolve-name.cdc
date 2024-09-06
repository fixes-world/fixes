import "FIND"
import "Domains"

access(all)
fun main(
    address: Address
): String? {
    if let name = FIND.reverseLookup(address) {
        return name.concat(".find")
    } else {
        let account = getAccount(address)
        let exists = account.capabilities.exists(Domains.CollectionPublicPath)
        if exists == false {
            return nil
        }

        var flownsName: String? = nil

        if let collection = account.capabilities.get<&Domains.Collection>(Domains.CollectionPublicPath).borrow() {
            var counter = 0
            collection.forEachID(fun (id: UInt64): Bool {
                let domain = collection.borrowDomain(id: id)!
                flownsName = domain.getDomainName()
                counter = counter + 1
                if domain.getText(key: "isDefault") == "true" || counter > 10 {
                    return false
                }
                return true
            })
        }
        return flownsName
    }
}
