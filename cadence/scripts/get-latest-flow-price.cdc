// import "AddressUtils"
// import "PublicPriceOracle"

access(all) fun main(): UFix64 {
    let network = "MAINNET" // AddressUtils.currentNetwork()
    // config flow address by network
    // reference: https://docs.increment.fi/protocols/decentralized-price-feed-oracle/deployment-addresses
    let oracleAddress: Address? = network == "MAINNET"
        ? Address.fromString("0xe385412159992e11")
        : nil
    if oracleAddress == nil {
        return 1.0
    } else {
        return 1.0
        // return PublicPriceOracle.getLatestPrice(oracleAddr: oracleAddress!)
    }
}
