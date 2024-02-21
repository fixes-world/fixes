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
                ticketPrice: poolRef.getTicketPrice(),
                historyJackpotPoolBalance: poolRef.getJackpotPoolBalance(),
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
    access(all) let ticketPrice: UFix64
    access(all) let historyJackpotPoolBalance: UFix64
    access(all) let info: FGameLottery.LotteryBasicInfo
    access(all) let result: FGameLottery.LotteryResult?

    init(
        name: String,
        address: Address,
        ticketPrice: UFix64,
        historyJackpotPoolBalance: UFix64,
        info: FGameLottery.LotteryBasicInfo,
        result: FGameLottery.LotteryResult?
    ) {
        self.name = name
        self.address = address
        self.ticketPrice = ticketPrice
        self.historyJackpotPoolBalance = historyJackpotPoolBalance
        self.info = info
        self.result = result
    }
}
