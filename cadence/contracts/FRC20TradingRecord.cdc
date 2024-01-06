import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"

pub contract FRC20TradingRecord {
    /* --- Events --- */

    /// Event emitted when the contract is initialized
    pub event ContractInitialized()

    /// Event emitted when a record is created
    pub event RecordCreated(
        recorder: Address,
        storefront: Address,
        buyer: Address,
        seller: Address,
        tick: String,
        dealAmount: UFix64,
        dealPrice: UFix64,
        dealPricePerMint: UFix64,
    )

    /* --- Variable, Enums and Structs --- */
    access(all)
    let TradingRecordsStoragePath: StoragePath
    access(all)
    let TradingRecordsPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    /// The struct containing the transaction record
    ///
    pub struct TransactionRecord {
        access(all)
        let storefront: Address
        access(all)
        let buyer: Address
        access(all)
        let seller: Address
        access(all)
        let tick: String
        access(all)
        let dealAmount: UFix64
        access(all)
        let dealPrice: UFix64
        access(all)
        let dealPricePerMint: UFix64
        access(all)
        let timestamp: UInt64

        init(
            storefront: Address,
            buyer: Address,
            seller: Address,
            tick: String,
            dealAmount: UFix64,
            dealPrice: UFix64,
            dealPricePerMint: UFix64,
        ) {
            self.storefront = storefront
            self.buyer = buyer
            self.seller = seller
            self.tick = tick
            self.dealAmount = dealAmount
            self.dealPrice = dealPrice
            self.dealPricePerMint = dealPricePerMint
            self.timestamp = UInt64(getCurrentBlock().timestamp)
        }

        access(all)
        fun getDealPricePerToken(): UFix64 {
            return self.dealPricePerMint / self.dealAmount
        }
    }

    /// The struct containing the trading status
    ///
    pub struct TradingStatus {
        access(all)
        var dealFloorPricePerToken: UFix64
        access(all)
        var dealFloorPricePerMint: UFix64
        access(all)
        var dealCeilingPricePerToken: UFix64
        access(all)
        var dealCeilingPricePerMint: UFix64
        access(all)
        var volume: UFix64
        access(all)
        var sales: UInt64

        init() {
            self.dealFloorPricePerToken = 0.0
            self.dealFloorPricePerMint = 0.0
            self.dealCeilingPricePerToken = 0.0
            self.dealCeilingPricePerMint = 0.0
            self.volume = 0.0
            self.sales = 0
        }

        access(contract)
        fun updateByNewRecord(
            _ recordRef: &TransactionRecord
        ) {
            // update the trading price
            let dealPricePerToken = recordRef.getDealPricePerToken()
            let dealPricePerMint = recordRef.dealPricePerMint

            // update the floor price per token
            if self.dealFloorPricePerToken == 0.0 || dealPricePerToken < self.dealFloorPricePerToken {
                self.dealFloorPricePerToken = dealPricePerToken
            }
            // update the floor price per mint
            if self.dealFloorPricePerMint == 0.0 || dealPricePerMint < self.dealFloorPricePerMint {
                self.dealFloorPricePerMint = dealPricePerMint
            }
            // update the ceiling price per token
            if dealPricePerToken > self.dealCeilingPricePerToken {
                self.dealCeilingPricePerToken = dealPricePerToken
            }
            // update the ceiling price per mint
            if dealPricePerMint > self.dealCeilingPricePerMint {
                self.dealCeilingPricePerMint = dealPricePerMint
            }
            // update the volume
            self.volume = self.volume + recordRef.dealAmount
            // update the sales
            self.sales = self.sales + 1
        }
    }

    /// The interface for viewing the trading status
    ///
    pub resource interface TradingStatusViewer {
        access(all) view
        fun getStatus(): TradingStatus
    }

    /// The interface for viewing the daily records
    ///
    pub resource interface DailyRecordsPublic {
        /// Get the length of the records
        access(all) view
        fun getRecordLength(): UInt64
        /// Get the records of the page
        access(all) view
        fun getRecords(page: Int, pageSize: Int): [TransactionRecord]
    }

    /// The resource containing the daily records
    //
    pub resource DailyRecords: DailyRecordsPublic, TradingStatusViewer {
        /// The date of the records, in seconds
        access(all)
        let date: UInt64
        /// The trading status of the day
        access(all)
        let status: TradingStatus
        /// Deal records, sorted by timestamp, descending
        access(contract)
        let records: [TransactionRecord]

        init(date: UInt64) {
            self.date = date
            self.status = TradingStatus()
            self.records = []
        }

        /** Public methods */

        access(all) view
        fun getRecordLength(): UInt64 {
            return UInt64(self.records.length)
        }

        access(all) view
        fun getRecords(page: Int, pageSize: Int): [TransactionRecord] {
            let start = page * pageSize
            let end = start + pageSize
            return self.records.slice(from: start, upTo: end)
        }

        access(all) view
        fun getStatus(): TradingStatus {
            return self.status
        }

        /** Internal Methods */

        access(contract)
        fun borrowStatus(): &TradingStatus {
            return &self.status as &TradingStatus
        }

        access(contract)
        fun addRecord(record: TransactionRecord) {
            // timestamp is in seconds, not milliseconds
            let timestamp = record.timestamp
            // ensure the timestamp is in the same day
            if timestamp / 86400 != self.date / 86400 {
                return // DO NOT PANIC
            }
            let recorder = self.owner?.address
            if recorder == nil {
                return // DO NOT PANIC
            }
            // update the trading status
            let statusRef = self.borrowStatus()
            statusRef.updateByNewRecord(&record as &TransactionRecord)

            // add the record
            self.records.append(record)

            // emit the event
            emit RecordCreated(
                recorder: recorder!,
                storefront: record.storefront,
                buyer: record.buyer,
                seller: record.seller,
                tick: record.tick,
                dealAmount: record.dealAmount,
                dealPrice: record.dealPrice,
                dealPricePerMint: record.dealPricePerMint
            )
        }
    }

    pub resource interface TradingRecordsPublic {
        // ---- Public Methods ----
        access(all) view
        fun isSharedRecrds(): Bool

        access(all) view
        fun getTickerName(): String?

        access(all) view
        fun getMarketCap(): UFix64?

        access(all)
        fun borrowDailyRecords(_ date: UInt64): &DailyRecords{DailyRecordsPublic, TradingStatusViewer}?

        // ---- Contract Methods ----
        /// Add a record
        access(contract)
        fun addRecord(record: TransactionRecord)
    }

    /// The resource containing the trading volume
    ///
    pub resource TradingRecords: TradingRecordsPublic, TradingStatusViewer {
        access(self)
        let tick: String?
        /// Trading status
        access(self)
        let status: TradingStatus
        /// Date => DailyRecords
        access(self)
        let dailyRecords: @{UInt64: DailyRecords}

        init(
            _ tick: String?
        ) {
            self.tick = tick
            self.status = TradingStatus()
            self.dailyRecords <- {}
        }

        destroy() {
            destroy self.dailyRecords
        }

        access(all) view
        fun getStatus(): TradingStatus {
            return self.status
        }

        access(all) view
        fun isSharedRecrds(): Bool {
            return self.tick == nil
        }

        /// Get the ticker name
        ///
        access(all) view
        fun getTickerName(): String? {
            return self.tick
        }

        /// Get the market cap
        ///
        access(all) view
        fun getMarketCap(): UFix64? {
            if self.tick == nil {
                return nil
            }
            let frc20Indexer = FRC20Indexer.getIndexer()
            if let meta = frc20Indexer.getTokenMeta(tick: self.tick!) {
                let status = self.borrowStatus()
                return status.dealCeilingPricePerToken * meta.max
            }
            return nil
        }

        /// Get the public daily records
        ///
        access(all)
        fun borrowDailyRecords(_ date: UInt64): &DailyRecords{DailyRecordsPublic, TradingStatusViewer}? {
            return self.borrowDailyRecordsPriv(date)
        }

        /** Internal Methods */

        access(contract)
        fun addRecord(record: TransactionRecord) {
            // timestamp is in seconds, not milliseconds
            let timestamp = record.timestamp
            // date is up to the timestamp of UTC 00:00:00
            let date = timestamp - timestamp % 86400

            var dailyRecordsRef = self.borrowDailyRecordsPriv(date)
            if dailyRecordsRef == nil {
                self.dailyRecords[date] <-! create DailyRecords(date: date)
                dailyRecordsRef = self.borrowDailyRecordsPriv(date)
            }
            if dailyRecordsRef == nil {
                return // DO NOT PANIC
            }

            // update the trading status
            let statusRef = self.borrowStatus()
            statusRef.updateByNewRecord(&record as &TransactionRecord)

            // add to the daily records
            dailyRecordsRef!.addRecord(record: record)
        }

        access(contract)
        fun borrowStatus(): &TradingStatus {
            return &self.status as &TradingStatus
        }

        access(self)
        fun borrowDailyRecordsPriv(_ date: UInt64): &DailyRecords? {
            return &self.dailyRecords[date] as &DailyRecords?
        }
    }

    /// The resource containing the trading volume of a token
    //
    pub resource TradingRecordingHook: FRC20FTShared.TransactionHook {

        /// The method that is invoked when the transaction is executed
        /// Before try-catch is deployed, please ensure that there will be no panic inside the method.
        ///
        access(account)
        fun onDeal(
            storefront: Address,
            listingId: UInt64,
            seller: Address,
            buyer: Address,
            tick: String,
            dealAmount: UFix64,
            dealPrice: UFix64,
            totalAmountInListing: UFix64,
        ) {
            if self.owner == nil {
                return // DO NOT PANIC
            }

            let frc20Indexer = FRC20Indexer.getIndexer()
            let meta = frc20Indexer.getTokenMeta(tick: tick)
            if meta == nil {
                return // DO NOT PANIC
            }
            let newRecord = TransactionRecord(
                storefront: storefront,
                buyer: buyer,
                seller: seller,
                tick: tick,
                dealAmount: dealAmount,
                dealPrice: dealPrice,
                dealPricePerMint: meta!.limit / dealAmount * dealPrice
            )

            // check owner's trading records
            if let marketRecords = FRC20TradingRecord.borrowTradingRecords(self.owner!.address) {
                marketRecords.addRecord(record: newRecord)
            }

            // check seller's trading records
            if let sellerRecords = FRC20TradingRecord.borrowTradingRecords(seller) {
                sellerRecords.addRecord(record: newRecord)
            }

            // check buyer's trading records
            if let buyerRecords = FRC20TradingRecord.borrowTradingRecords(buyer) {
                buyerRecords.addRecord(record: newRecord)
            }
        }
    }

    /** ---– Public methods ---- */

    /// The helper method to get the market resource reference
    ///
    access(all)
    fun borrowTradingRecords(_ addr: Address): &TradingRecords{TradingRecordsPublic, TradingStatusViewer}? {
        return getAccount(addr)
            .getCapability<&TradingRecords{TradingRecordsPublic, TradingStatusViewer}>(self.TradingRecordsPublicPath)
            .borrow()
    }

    /// Create a trading records resource
    ///
    access(all)
    fun createTradingRecords(_ tick: String?): @TradingRecords {
        return <-create TradingRecords(tick)
    }

    /// Create a trading recorder resource
    /// This method should be called by the contracts in the same account
    ///
    access(account)
    fun createTradingRecordingHook(): @TradingRecordingHook {
        return <-create TradingRecordingHook()
    }

    init() {
        let identifier = "FRC20TradingRecords_".concat(self.account.address.toString())
        self.TradingRecordsStoragePath = StoragePath(identifier: identifier)!
        self.TradingRecordsPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
