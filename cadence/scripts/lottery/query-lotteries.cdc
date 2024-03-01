// Thirdparty imports
import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FRC20Indexer"
import "FGameLottery"
import "FGameLotteryRegistry"

access(all)
fun main(): [LotteryPoolInfo] {
    let ret: [LotteryPoolInfo] = []

    let registry = FGameLotteryRegistry.borrowRegistry()
    let poolNames = registry.getLotteryPoolNames()
    for poolName in poolNames {
        if let poolAddr = registry.getLotteryPoolAddress(poolName) {
            if let poolRef = FGameLottery.borrowLotteryPool(poolAddr) {
                let currentLotteryRef = poolRef.borrowCurrentLottery()
                ret.append(LotteryPoolInfo(
                    name: poolRef.getName(),
                    address: poolRef.getAddress(),
                    ticketPrice: poolRef.getTicketPrice(),
                    epochInterval: poolRef.getEpochInterval(),
                    jackpotPoolBalance: poolRef.getJackpotPoolBalance(),
                    currentEpochIndex: poolRef.getCurrentEpochIndex(),
                    currentLottery: currentLotteryRef?.getInfo()
                ))
            }
        }
    }
    return ret
}

access(all) struct LotteryPoolInfo {
    access(all) let name: String
    access(all) let address: Address
    access(all) let ticketPrice: UFix64
    access(all) let epochInterval: UFix64
    access(all) let jackpotPoolBalance: UFix64
    // Lottery Data
    access(all) let currentEpochIndex: UInt64
    access(all) let currentLottery: FGameLottery.LotteryBasicInfo?

    init(
        name: String,
        address: Address,
        ticketPrice: UFix64,
        epochInterval: UFix64,
        jackpotPoolBalance: UFix64,
        currentEpochIndex: UInt64,
        currentLottery: FGameLottery.LotteryBasicInfo?,
    ) {
        self.name = name
        self.address = address
        self.ticketPrice = ticketPrice
        self.epochInterval = epochInterval
        self.jackpotPoolBalance = jackpotPoolBalance
        self.currentEpochIndex = currentEpochIndex
        self.currentLottery = currentLottery
    }
}
