import "AddressUtils"
import "PublicPriceOracle"

access(all) fun main(): UFix64 {
    let network = AddressUtils.currentNetwork()
    // reference: https://docs.increment.fi/protocols/decentralized-price-feed-oracle/deployment-addresses
    let oracleAddress: Address? = network == "MAINNET"
        ? Address.fromString("0xe385412159992e11")
        : nil
    if oracleAddress == nil {
        return 1.0
    } else {
        return PublicPriceOracle.getLatestPrice(oracleAddr: oracleAddress!)
    }
}