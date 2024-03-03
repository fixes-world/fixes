// Thirdparty imports
import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FRC20Indexer"
import "FGameLottery"
import "FGameLotteryRegistry"
import "FGameLotteryFactory"

access(all)
fun main(): [LotteryPoolInfo] {
    let ret: [LotteryPoolInfo] = []

    let registry = FGameLotteryRegistry.borrowRegistry()
    let poolNames = registry.getLotteryPoolNames()
    for poolName in poolNames {
        if let poolAddr = registry.getLotteryPoolAddress(poolName) {
            if let poolRef = FGameLottery.borrowLotteryPool(poolAddr) {
                let name = poolRef.getName()
                let extra: {String: AnyStruct} = {}
                if name == FGameLotteryFactory.getFIXESMintingLotteryPoolName()
                || name == FGameLotteryFactory.getFIXESLotteryPoolName() {
                    extra["isMintable"] = FGameLotteryFactory.isFIXESMintingAvailable()
                }
                let currentEpochIndex = poolRef.getCurrentEpochIndex()
                let currentLotteryRef = poolRef.borrowCurrentLottery()
                let lastLotteryRef = currentEpochIndex > 0
                    ? poolRef.borrowLottery(currentEpochIndex - 1)
                    : nil
                ret.append(LotteryPoolInfo(
                    // Pool Info
                    name: name,
                    address: poolRef.getAddress(),
                    lotteryToken: poolRef.getLotteryToken(),
                    ticketPrice: poolRef.getTicketPrice(),
                    epochInterval: poolRef.getEpochInterval(),
                    jackpotPoolBalance: poolRef.getJackpotPoolBalance(),
                    // Extra Info
                    extra: extra,
                    // Lottery Data
                    currentEpochIndex: currentEpochIndex,
                    currentLottery: currentLotteryRef?.getInfo(),
                    lastLottery: lastLotteryRef?.getInfo(),
                    lastLotteryResult: lastLotteryRef?.getResult() ?? nil
                ))
            }
        }
    }
    return ret
}

access(all) struct LotteryPoolInfo {
    // Pool Info
    access(all) let name: String
    access(all) let address: Address
    access(all) let lotteryToken: String
    access(all) let ticketPrice: UFix64
    access(all) let epochInterval: UFix64
    access(all) let jackpotPoolBalance: UFix64
    access(all) let extra: {String: AnyStruct}
    // Lottery Data
    access(all) let currentEpochIndex: UInt64
    access(all) let currentLottery: FGameLottery.LotteryBasicInfo?
    access(all) let lastLottery: FGameLottery.LotteryBasicInfo?
    access(all) let lastLotteryResult: FGameLottery.LotteryResult?

    init(
        name: String,
        address: Address,
        lotteryToken: String,
        ticketPrice: UFix64,
        epochInterval: UFix64,
        jackpotPoolBalance: UFix64,
        extra: {String: AnyStruct},
        currentEpochIndex: UInt64,
        currentLottery: FGameLottery.LotteryBasicInfo?,
        lastLottery: FGameLottery.LotteryBasicInfo?,
        lastLotteryResult: FGameLottery.LotteryResult?
    ) {
        self.name = name
        self.address = address
        self.lotteryToken = lotteryToken
        self.ticketPrice = ticketPrice
        self.epochInterval = epochInterval
        self.jackpotPoolBalance = jackpotPoolBalance
        self.extra = extra
        self.currentEpochIndex = currentEpochIndex
        self.currentLottery = currentLottery
        self.lastLottery = lastLottery
        self.lastLotteryResult = lastLotteryResult
    }
}
