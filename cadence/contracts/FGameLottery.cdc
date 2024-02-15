/**
> Author: FIXeS World <https://fixes.world/>

# FGameLottery

This contract is a lottery game contract. It allows users to buy tickets and participate in the lottery.
The lottery is drawn every epoch. The winner is selected randomly from the participants.

*/
// Fixes Imports
import "Fixes"
import "FixesHeartbeat"
import "FRC20Indexer"
import "FRC20Staking"

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

    /* --- Variable, Enums and Structs --- */

    access(all)
    let userCollectionStoragePath: StoragePath
    access(all)
    let userCollectionPublicPath: PublicPath
    access(all)
    let registryStoragePath: StoragePath
    access(all)
    let registryPublicPath: PublicPath

    access(all)
    var MAX_WHITE_NUMBER: UInt8
    access(all)
    var MAX_RED_NUMBER: UInt8

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
        access(all) view fun getTicketId(): UInt64
        access(all) view fun getTicketOwner(): Address
        access(all) view fun getNumbers(): [UInt8;6]
        access(all) view fun getPowerup(): UInt64
        access(all) view fun getStatus(): TicketStatus
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
    }

    /// User's ticket collection resource interface
    ///
    access(all) resource interface TicketCollectionPublic {
        access(all)
        fun borrowTicket(ticketId: UInt64): &TicketEntry{TicketEntryPublic}?
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

    /// Lottery resource
    ///
    access(all) resource Lottery {
        access(self)
        let participants: {Address: UInt32}

        init() {
            self.participants = {}
        }
    }

    /// Lottery pool resource
    ///
    access(all) resource LotteryPool {

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

    init() {
        // Set the maximum white and red numbers
        self.MAX_WHITE_NUMBER = 33
        self.MAX_RED_NUMBER = 16

        // Identifiers
        let identifier = "FGameLottery_".concat(self.account.address.toString())
        self.userCollectionStoragePath = StoragePath(identifier: identifier.concat("_UserCollection"))!
        self.userCollectionPublicPath = PublicPath(identifier: identifier.concat("_UserCollection"))!

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
