
import "AddressUtils"
import "PublicPriceOracle"

access(all)
fun main(): UFix64 {
    let network = AddressUtils.currentNetwork()
    // reference: https://docs.increment.fi/protocols/decentralized-price-feed-oracle/deployment-addresses
    var oracleAddress: Address? = nil
    if network == "MAINNET" {
        // TO FIX stupid fcl bug
        oracleAddress = Address.fromString("0x".concat("e385412159992e11"))
    }
    if oracleAddress == nil {
        return 1.0
    } else {
        return PublicPriceOracle.getLatestPrice(oracleAddr: oracleAddress!)
    }
}
