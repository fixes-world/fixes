/**
> Author: FIXeS World <https://fixes.world/>

# FGameLottery

This contract is a lottery game contract. It allows users to buy tickets and participate in the lottery.
The lottery is drawn every epoch. The winner is selected randomly from the participants.

*/
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20Staking"
import "FRC20AccountsPool"

access(all) contract FGameLottery {
    /* --- Events --- */
    /// Event emitted when the contract is initialized
    access(all) event ContractInitialized()

    /// Event emitted when a new lottery ticket is created
    access(all) event TicketAdded(
        poolId: UInt64,
        lotteryId: UInt64,
        address: Address,
        ticketId: UInt64,
        numbers: [UInt8;6]
    )
    /// Event emitted when a ticket's powerup is updated
    access(all) event TicketPowerupChanged(
        poolId: UInt64,
        lotteryId: UInt64,
        address: Address,
        ticketId: UInt64,
        powerup: UInt64
    )
    /// Event emitted when a ticket status is updated
    access(all) event TicketStatusChanged(
        poolId: UInt64,
        lotteryId: UInt64,
        address: Address,
        ticketId: UInt64,
        fromStatus: UInt8,
        toStatus: UInt8,
    )

    /* --- Variable, Enums and Structs --- */

    access(all) let userCollectionStoragePath: StoragePath
    access(all) let userCollectionPublicPath: PublicPath
    access(all) let lotteryPoolStoragePath: StoragePath
    access(all) let lotteryPoolPublicPath: PublicPath
    access(all) let registryStoragePath: StoragePath
    access(all) let registryPublicPath: PublicPath

    access(all) var MAX_WHITE_NUMBER: UInt8
    access(all) var MAX_RED_NUMBER: UInt8

    /* --- Interfaces & Resources --- */

    /// Struct for the ticket number
    /// The ticket number is a combination of 5 white numbers and 1 red number
    /// The white numbers are between 1 and MAX_WHITE_NUMBER
    /// The red number is between 1 and MAX_RED_NUMBER
    ///
    access(all) struct TicketNumber {
        // White numbers
        access(all) let white: [UInt8;5]
        // Red number
        access(all) let red: UInt8

        init(white: [UInt8;5], red: UInt8) {
            // Check if the white numbers are valid
            for number in white {
                assert(
                    number >= 1 && number <= FGameLottery.MAX_WHITE_NUMBER,
                    message: "White numbers must be between 1 and MAX_WHITE_NUMBER"
                )
            }
            // Check if the red number is valid
            assert(
                red >= 1 && red <= FGameLottery.MAX_RED_NUMBER,
                message: "Red number must be between 1 and MAX_RED_NUMBER"
            )
            self.white = white
            self.red = red
        }
    }

    /// Enum for the ticket status
    ///
    access(all) enum TicketStatus: UInt8 {
        case ACTIVE
        case LOSE
        case WIN
        case WIN_CLAIMED
    }

    /// Ticket entry resource interface
    ///
    access(all) resource interface TicketEntryPublic {
        // variables
        access(all) let poolId: UInt64
        access(all) let lotteryId: UInt64
        access(all) let numbers: TicketNumber
        // view functions
        access(all) view fun getStatus(): TicketStatus
        access(all) view fun getTicketId(): UInt64
        access(all) view fun getTicketOwner(): Address
        access(all) view fun getNumbers(): [UInt8;6]
        access(all) view fun getPowerup(): UInt64
    }

    /// Resource for the ticket entry
    ///
    access(all) resource TicketEntry: TicketEntryPublic {
        /// Lottery Pool ID for the ticket
        access(all) let poolId: UInt64
        /// Lottery ID for the ticket
        access(all) let lotteryId: UInt64
        /// Ticket numbers
        access(all) let numbers: TicketNumber
        /// Ticket powerup, default is 1, you can increase the powerup to increase the winning amount
        access(self) var powerup: UInt64
        /// Ticket status
        access(self) var status: TicketStatus

        init(
            poolId: UInt64,
            lotteryId: UInt64,
        ) {
            self.poolId = poolId
            self.lotteryId = lotteryId
            // Set the default powerup to 1
            self.powerup = 1
            // Generate random numbers for the ticket
            var whiteNumbers: [UInt8;5] = [0, 0, 0, 0, 0]
            // generate the random white numbers, the numbers are between 1 and MAX_WHITE_NUMBER
            var i = 0
            while i < 5 {
                let rndUInt8 = UInt8(revertibleRandom() % UInt64(UInt8.max))
                let newNum = rndUInt8 % FGameLottery.MAX_WHITE_NUMBER + 1
                // we need to check if the number is already in the array
                if !whiteNumbers.contains(newNum) {
                    whiteNumbers[i] = newNum
                    i = i + 1
                }
            }
            // generate the random red number, the number is between 1 and MAX_RED_NUMBER
            let rndUInt8 = UInt8(revertibleRandom() % UInt64(UInt8.max))
            var redNumber: UInt8 = rndUInt8 % FGameLottery.MAX_RED_NUMBER + 1
            // Set the ticket numbers
            self.numbers = TicketNumber(white: whiteNumbers, red: redNumber)
            // Set the ticket status to ACTIVE
            self.status = TicketStatus.ACTIVE
        }

        /// Get the ticket ID
        ///
        access(all) view
        fun getTicketId(): UInt64 {
            return self.uuid
        }

        /// Get the ticket owner
        ///
        access(all) view
        fun getTicketOwner(): Address {
            return self.owner?.address ?? panic("Ticket owner is missing")
        }

        /// Get the ticket numbers
        ///
        access(all) view
        fun getNumbers(): [UInt8;6] {
            return [
                self.numbers.white[0],
                self.numbers.white[1],
                self.numbers.white[2],
                self.numbers.white[3],
                self.numbers.white[4],
                self.numbers.red
            ]
        }

        /// Get the ticket powerup
        ///
        access(all) view
        fun getPowerup(): UInt64 {
            return self.powerup
        }

        /// Get the ticket status
        ///
        access(all) view
        fun getStatus(): TicketStatus {
            return self.status
        }

        /** Update Ticket Data */

        access(contract)
        fun setPowerup(powerup: UInt64) {
            pre {
                powerup > 0: "Powerup must be greater than 0"
                powerup <= 10: "Powerup must be less than or equal to 10"
                powerup > self.powerup: "New powerup must be greater than the current powerup"
            }
            self.powerup = powerup

            emit TicketPowerupChanged(
                poolId: self.poolId,
                lotteryId: self.lotteryId,
                address: self.getTicketOwner(),
                ticketId: self.getTicketId(),
                powerup: powerup
            )
        }

        access(contract)
        fun setLose() {
            pre {
                self.status == TicketStatus.ACTIVE: "Ticket status must be ACTIVE"
            }
            self._setStatus(toStatus: TicketStatus.LOSE)
        }

        access(contract)
        fun setWin() {
            pre {
                self.status == TicketStatus.ACTIVE: "Ticket status must be ACTIVE"
            }
            self._setStatus(toStatus: TicketStatus.WIN)
        }

        access(contract)
        fun setWinClaimed() {
            pre {
                self.status == TicketStatus.WIN: "Ticket status must be WIN"
            }
            self._setStatus(toStatus: TicketStatus.WIN_CLAIMED)
        }

        /** --- Internal Methods --- */

        access(self)
        fun _setStatus(toStatus: TicketStatus) {
            let oldStatus = self.status
            self.status = toStatus

            emit TicketStatusChanged(
                poolId: self.poolId,
                lotteryId: self.lotteryId,
                address: self.getTicketOwner(),
                ticketId: self.getTicketId(),
                fromStatus: oldStatus.rawValue,
                toStatus: toStatus.rawValue
            )
        }
    }

    /// User's ticket collection resource interface
    ///
    access(all) resource interface TicketCollectionPublic {
        // --- read methods ---
        access(all) view
        fun getIDs(): [UInt64]

        access(all) view
        fun getTicketAmount(): Int

        access(all)
        fun borrowTicket(ticketId: UInt64): &TicketEntry{TicketEntryPublic}?

        // --- write methods ---
        access(all)
        fun addTicket(ticket: @TicketEntry)
    }

    /// User's ticket collection
    ///
    access(all) resource TicketCollection: TicketCollectionPublic {
        access(self)
        let tickets: @{UInt64: TicketEntry}

        init() {
            self.tickets <- {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.tickets
        }

        /** ---- Public Methods ---- */

        /// Get the ticket IDs
        ///
        access(all) view
        fun getIDs(): [UInt64] {
            return self.tickets.keys
        }

        /// Get the ticket amount
        ///
        access(all) view
        fun getTicketAmount(): Int {
            return self.tickets.keys.length
        }

        /// Borrow a ticket from the collection
        ///
        access(all)
        fun borrowTicket(ticketId: UInt64): &TicketEntry{TicketEntryPublic}? {
            return &self.tickets[ticketId] as &TicketEntry{TicketEntryPublic}?
        }

        /** ---- Private Methods ---- */

        /// Add a new ticket to the collection
        ///
        access(all)
        fun addTicket(ticket: @TicketEntry) {
            pre {
                self.owner != nil: "Only the collection with an owner can add a ticket"
                self.tickets[ticket.getTicketId()] == nil: "Ticket already exists"
            }
            // Basic information
            let ticketId = ticket.getTicketId()

            self.tickets[ticketId] <-! ticket

            let ref = self.borrowTicketRef(ticketId: ticketId)

            emit TicketAdded(
                poolId: ref.poolId,
                lotteryId: ref.lotteryId,
                address: self.owner!.address,
                ticketId: ticketId,
                numbers: ref.getNumbers()
            )
        }

        /** --- Internal Methods --- */

        /// Borrow a ticket reference
        ///
        access(self)
        fun borrowTicketRef(ticketId: UInt64): &TicketEntry {
            return &self.tickets[ticketId] as &TicketEntry? ?? panic("Ticket not found")
        }
    }

    /// Enum for the lottery status
    ///
    access(all) enum LotteryStatus: UInt8 {
        case ACTIVE
        case READY_TO_DRAW
        case DRAWN
    }

    /// Lottery public resource interface
    ///
    access(all) resource interface LotteryPublic {
        /// Lottery status
        access(all) view fun getStatus(): LotteryStatus
    }

    /// Lottery resource
    ///
    access(all) resource Lottery: LotteryPublic {
        /// Lottery epoch index
        access(all)
        let epochIndex: UInt64
        /// Lottery epoch start time
        access(all)
        let epochStartAt: UFix64
        /// Participants tickets: [Address: [TicketID]]
        access(self)
        let participants: {Address: [UInt64]}
        /// Lottery final status
        var drawnNumbers: TicketNumber?
        /// Jackpot information
        var jackpotAmount: UFix64?
        var jackpotWinner: Address?

        init(
            epochIndex: UInt64
        ) {
            self.epochIndex = epochIndex
            self.epochStartAt = getCurrentBlock().timestamp
            self.participants = {}
            self.drawnNumbers = nil
            self.jackpotAmount = nil
            self.jackpotWinner = nil
        }

        /** ---- Public Methods ---- */

        access(all) view
        fun getStatus(): LotteryStatus {
            let now = getCurrentBlock().timestamp
            let poolRef = self.borrowLotteryPool()
            let interval = poolRef.getEpochInterval()
            let epochCloseTime = self.epochStartAt + interval
            if now < epochCloseTime {
                return LotteryStatus.ACTIVE
            } else if self.drawnNumbers == nil {
                return LotteryStatus.READY_TO_DRAW
            } else {
                return LotteryStatus.DRAWN
            }
        }

        /** ---- Contract level Methods ----- */

        /** ---- Internal Methods ----- */

        access(self)
        fun borrowLotteryPool(): &LotteryPool {
            let ownerAddr = self.owner?.address ?? panic("Owner is missing")
            let ref = FGameLottery.borrowLotteryPool(ownerAddr)
                ?? panic("Lottery pool not found")
            return ref.borrowSelf()
        }
    }

    access(all) resource interface LotteryPoolPublic {
        // --- read methods ---
        access(all) view
        fun getCurrentEpochIndex(): UInt64
        access(all) view
        fun getEpochInterval(): UFix64
        // --- write methods ---

        // --- borrow methods ---
        // Public usage
        access(all)
        fun borrowCurrentLottery(): &Lottery{LotteryPublic}?
        // Internal usage
        access(contract)
        fun borrowSelf(): &LotteryPool
    }

    /// Lottery pool resource
    ///
    access(all) resource LotteryPool: LotteryPoolPublic, FixesHeartbeat.IHeartbeatHook {
        /// Lottery pool constants
        access(self)
        let epochInterval: UFix64
        access(self)
        let ticketPrice: UFix64
        // Lottery pool variables
        access(self)
        var currentEpochIndex: UInt64
        access(self)
        let rewardPool: @FRC20FTShared.Change
        access(self)
        let lotteries: @{UInt64: Lottery}

        init(
            rewardTick: String,
            ticketPrice: UFix64,
            epochInterval: UFix64
        ) {
            pre {
                ticketPrice > 0.0: "Ticket price must be greater than 0"
                epochInterval > 0.0: "Epoch interval must be greater than 0"
            }
            let accountAddr = FGameLottery.account.address
            if rewardTick != "" {
                self.rewardPool <- FRC20FTShared.createEmptyChange(tick: rewardTick, from: accountAddr)
            } else {
                self.rewardPool <- FRC20FTShared.createEmptyFlowChange(from: accountAddr)
            }
            self.ticketPrice = ticketPrice
            self.epochInterval = epochInterval
            self.currentEpochIndex = 0
            self.lotteries <- {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.rewardPool
            destroy self.lotteries
        }

        /** ---- Public Methods ---- */

        access(all) view
        fun getCurrentEpochIndex(): UInt64 {
            return self.currentEpochIndex
        }

        access(all) view
        fun getEpochInterval(): UFix64 {
            return self.epochInterval
        }

        access(all)
        fun borrowCurrentLottery(): &Lottery{LotteryPublic}? {
            return self.borrowCurrentLotteryRef()
        }

        /** ---- Heartbeat Implementation Methods ----- */

        /// The methods that is invoked when the heartbeat is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onHeartbeat(_ deltaTime: UFix64) {
            // TODO
        }

        // --- Internal Methods ---

        access(contract)
        fun borrowSelf(): &LotteryPool {
            return &self as &LotteryPool
        }

        access(self)
        fun borrowCurrentLotteryRef(): &Lottery? {
            return &self.lotteries[self.currentEpochIndex] as &Lottery?
        }
    }

    /// Resource inferface for the Lottery registry
    ///
    access(all) resource interface RegistryPublic {

    }

    /// Resource for the Lottery registry
    ///
    access(all) resource Registry: RegistryPublic {

    }

    /* --- Public methods  --- */

    /// Borrow Lottery Pool
    ///
    access(all)
    fun borrowLotteryPool(_ addr: Address): &LotteryPool{LotteryPoolPublic, FixesHeartbeat.IHeartbeatHook}? {
        return getAccount(addr)
            .getCapability<&LotteryPool{LotteryPoolPublic, FixesHeartbeat.IHeartbeatHook}>(FGameLottery.lotteryPoolPublicPath)
            .borrow()
    }

    /// Borrow Lottery Pool Registry
    ///
    access(all)
    fun borrowRegistry(): &Registry{RegistryPublic} {
        return getAccount(self.account.address)
            .getCapability<&Registry{RegistryPublic}>(FGameLottery.registryPublicPath)
            .borrow()
            ?? panic("Registry not found")
    }

    init() {
        // Set the maximum white and red numbers
        self.MAX_WHITE_NUMBER = 33
        self.MAX_RED_NUMBER = 16

        // Identifiers
        let identifier = "FGameLottery_".concat(self.account.address.toString())
        self.userCollectionStoragePath = StoragePath(identifier: identifier.concat("_UserCollection"))!
        self.userCollectionPublicPath = PublicPath(identifier: identifier.concat("_UserCollection"))!

        self.lotteryPoolStoragePath = StoragePath(identifier: identifier.concat("_LotteryPool"))!
        self.lotteryPoolPublicPath = PublicPath(identifier: identifier.concat("_LotteryPool"))!

        self.registryStoragePath = StoragePath(identifier: identifier.concat("_Registry"))!
        self.registryPublicPath = PublicPath(identifier: identifier.concat("_Registry"))!

        // save registry
        let registry <- create Registry()
        self.account.save(<- registry, to: self.registryStoragePath)

        // @deprecated in Cadence 1.0
        self.account.link<&Registry{RegistryPublic}>(self.registryPublicPath, target: self.registryStoragePath)

        // Emit the ContractInitialized event
        emit ContractInitialized()
    }
}
