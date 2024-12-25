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
fun main(
    addr: Address,
    page: Int,
    size: Int,
): [TicketEntry] {
    let ticketsCol = FGameLottery.getUserTicketCollection(addr)
    if let colRef = ticketsCol.borrow() {
        let sliced = colRef.slicedIDs(page, size)
        let ret: [TicketEntry] = []
        let poolNameCache: {Address: String} = {}
        let prizeTokenCache: {Address: String} = {}
        for id in sliced {
            if let ticket = colRef.borrowTicket(ticketId: id) {
                let poolAddr = ticket.pool
                if poolNameCache[poolAddr] == nil {
                    let poolRef = FGameLottery.borrowLotteryPool(poolAddr)!
                    poolNameCache[poolAddr] = poolRef.getName()
                    prizeTokenCache[poolAddr] = poolRef.getLotteryToken()
                }
                let lotteryRef = ticket.borrowLottery()
                ret.append(TicketEntry(
                    ticketOwner: ticket.getTicketOwner(),
                    ticketId: ticket.getTicketId(),
                    poolName: poolNameCache[poolAddr] ?? panic("Invalid pool address"),
                    poolAddr: poolAddr,
                    lotteryId: ticket.lotteryId,
                    numbers: FGameLottery.TicketNumber(white: *ticket.numbers.white, red: ticket.numbers.red),
                    boughtAt: ticket.boughtAt,
                    status: ticket.getStatus(),
                    powerup: ticket.getPowerup(),
                    prizeToken: prizeTokenCache[poolAddr] ?? panic("Invalid pool address"),
                    drawnResult: lotteryRef.getResult()?.numbers,
                    prizeRank: ticket.getWinPrizeRank(),
                    prizeAmount: ticket.getEstimatedPrizeAmount(),
                ))
            }
        }
        return ret
    }
    return []
}

access(all) struct TicketEntry {
    access(all) let ticketOwner: Address
    access(all) let ticketId: UInt64
    access(all) let poolName: String
    access(all) let poolAddr: Address
    access(all) let lotteryId: UInt64
    access(all) let numbers: FGameLottery.TicketNumber
    access(all) let boughtAt: UFix64
    access(all) let status: FGameLottery.TicketStatus
    access(all) let powerup: UFix64
    access(all) let prizeToken: String
    access(all) let drawnResult: FGameLottery.TicketNumber?
    access(all) let prizeRank: FGameLottery.PrizeRank?
    access(all) let prizeAmount: UFix64?

    init(
        ticketOwner: Address,
        ticketId: UInt64,
        poolName: String,
        poolAddr: Address,
        lotteryId: UInt64,
        numbers: FGameLottery.TicketNumber,
        boughtAt: UFix64,
        status: FGameLottery.TicketStatus,
        powerup: UFix64,
        prizeToken: String,
        drawnResult: FGameLottery.TicketNumber?,
        prizeRank: FGameLottery.PrizeRank?,
        prizeAmount: UFix64?
    ) {
        self.ticketOwner = ticketOwner
        self.ticketId = ticketId
        self.poolName = poolName
        self.poolAddr = poolAddr
        self.lotteryId = lotteryId
        self.numbers = numbers
        self.boughtAt = boughtAt
        self.status = status
        self.powerup = powerup
        self.prizeToken = prizeToken
        self.drawnResult = drawnResult
        self.prizeRank = prizeRank
        self.prizeAmount = prizeAmount
    }
}
