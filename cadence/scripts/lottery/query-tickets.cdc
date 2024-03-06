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
        let ids = colRef.getIDs()
        var startAt = page * size
        if startAt >= ids.length {
            return []
        }
        var upTo = startAt + size
        if upTo > ids.length {
            upTo = ids.length
        }
        let sliced = ids.slice(from: startAt, upTo: upTo)
        let ret: [TicketEntry] = []
        for id in sliced {
            if let ticket = colRef.borrowTicket(ticketId: id) {
                ret.append(TicketEntry(
                    ticketOwner: ticket.getTicketOwner(),
                    ticketId: ticket.getTicketId(),
                    pool: ticket.pool,
                    lotteryId: ticket.lotteryId,
                    numbers: ticket.numbers,
                    boughtAt: ticket.boughtAt,
                    status: ticket.getStatus(),
                    powerup: ticket.getPowerup(),
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
    access(all) let pool: Address
    access(all) let lotteryId: UInt64
    access(all) let numbers: FGameLottery.TicketNumber
    access(all) let boughtAt: UFix64
    access(all) let status: FGameLottery.TicketStatus
    access(all) let powerup: UFix64
    access(all) let prizeRank: FGameLottery.PrizeRank?
    access(all) let prizeAmount: UFix64?

    init(
        ticketOwner: Address,
        ticketId: UInt64,
        pool: Address,
        lotteryId: UInt64,
        numbers: FGameLottery.TicketNumber,
        boughtAt: UFix64,
        status: FGameLottery.TicketStatus,
        powerup: UFix64,
        prizeRank: FGameLottery.PrizeRank?,
        prizeAmount: UFix64?
    ) {
        self.ticketOwner = ticketOwner
        self.ticketId = ticketId
        self.pool = pool
        self.lotteryId = lotteryId
        self.numbers = numbers
        self.boughtAt = boughtAt
        self.status = status
        self.powerup = powerup
        self.prizeRank = prizeRank
        self.prizeAmount = prizeAmount
    }
}
