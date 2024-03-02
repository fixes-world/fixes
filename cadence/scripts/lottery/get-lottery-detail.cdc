// Thirdparty imports
import "FungibleToken"
import "FlowToken"
// Fixes Imports
import "Fixes"
import "FRC20Indexer"
import "FGameLottery"
import "FGameLotteryRegistry"

access(all)
fun main(
    poolAddr: Address,
    epochId: UInt64?
): LotteryDetail? {
    if let poolRef = FGameLottery.borrowLotteryPool(poolAddr) {
        if let lotteryRef = epochId == nil
            ? poolRef.borrowCurrentLottery()
            : poolRef.borrowLottery(epochId!) {
            let currentLotteryRef = poolRef.borrowCurrentLottery()
            return LotteryDetail(
                name: poolRef.getName(),
                address: poolRef.getAddress(),
                lotteryToken: poolRef.getLotteryToken(),
                ticketPrice: poolRef.getTicketPrice(),
                epochInterval: poolRef.getEpochInterval(),
                jackpotPoolBalance: poolRef.getJackpotPoolBalance(),
                // Lottery Data
                info: lotteryRef.getInfo(),
                result: lotteryRef.getResult()
            )
        }
    }
    return nil
}

access(all) struct LotteryDetail {
    access(all) let name: String
    access(all) let address: Address
    access(all) let lotteryToken: String
    access(all) let ticketPrice: UFix64
    access(all) let epochInterval: UFix64
    access(all) let jackpotPoolBalance: UFix64
    // Lottery Data
    access(all) let epochIndex: UInt64
    access(all) let info: FGameLottery.LotteryBasicInfo
    access(all) let result: FGameLottery.LotteryResult?

    init(
        name: String,
        address: Address,
        lotteryToken: String,
        ticketPrice: UFix64,
        epochInterval: UFix64,
        jackpotPoolBalance: UFix64,
        info: FGameLottery.LotteryBasicInfo,
        result: FGameLottery.LotteryResult?
    ) {
        self.name = name
        self.address = address
        self.lotteryToken = lotteryToken
        self.ticketPrice = ticketPrice
        self.epochInterval = epochInterval
        self.jackpotPoolBalance = jackpotPoolBalance
        self.epochIndex = info.epochIndex
        self.info = info
        self.result = result
    }
}
