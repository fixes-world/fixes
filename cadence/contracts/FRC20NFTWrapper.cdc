import "MetadataViews"
import "NonFungibleToken"
import "FlowToken"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20Indexer"

pub contract FRC20NFTWrapper {

    /// The event that is emitted when the contract is created
    pub event ContractInitialized()

    /// The event that is emitted when the internal flow vault is donated to
    pub event InternalFlowVaultDonated(amount: UFix64)

    /// The event that is emitted when a new Wrapper is created
    pub event WrapperCreated()

    /// The event that is emitted when the whitelist is updated
    pub event AuthorizedWhitelistUpdated(
        addr: Address,
        isAuthorized: Bool,
    )

    /// The event that is emitted when an NFT is unwrapped
    pub event FRC20StrategyRegistered(
        wrapper: Address,
        deployer: Address,
        nftType: Type,
        tick: String,
        alloc: UFix64,
        copies: UInt64,
        cond: String?
    )
    /// The event that is emitted when an NFT is wrapped
    pub event NFTWrappedWithFRC20Allocated(
        wrapper: Address,
        nftType: Type,
        srcNftId: UInt64,
        wrappedNftId: UInt64,
        tick: String,
        alloc: UFix64,
        address: Address,
    )

    // Indexer
    /// The event that is emitted when a new wrapper is added to the indexer
    pub event WrapperAddedToIndexer(wrapper: Address)
    /// The event that is emitted when the wrapper options is updated
    pub event WrapperOptionsUpdated(wrapper: Address, key: String)
    /// The event that is emitted when the extra NFT collection display is updated
    pub event WrapperIndexerUpdatedNFTCollectionDisplay(nftType: Type, name: String, description: String)

    /* --- Variable, Enums and Structs --- */
    access(all)
    let FRC20NFTWrapperStoragePath: StoragePath
    access(all)
    let FRC20NFTWrapperPublicPath: PublicPath
    access(all)
    let FRC20NFTWrapperIndexerStoragePath: StoragePath
    access(all)
    let FRC20NFTWrapperIndexerPublicPath: PublicPath


    /* --- Interfaces & Resources --- */

    pub struct FRC20Strategy {
        pub let tick: String
        pub let nftType: Type
        pub let alloc: UFix64
        pub let copies: UInt64
        pub let cond: String?
        pub var usedAmt: UInt64

        init(
            tick: String,
            nftType: Type,
            alloc: UFix64,
            copies: UInt64,
            cond: String?
        ) {
            self.tick = tick
            self.nftType = nftType
            self.alloc = alloc
            self.copies = copies
            self.cond = cond
            self.usedAmt = 0
        }

        access(all)
        fun isUsedUp(): Bool {
            return self.usedAmt >= self.copies
        }

        access(contract)
        fun use() {
            pre {
                self.usedAmt < self.copies: "The strategy is used up"
            }
            self.usedAmt = self.usedAmt + 1
        }
    }


    pub resource interface WrapperPublic {
        // public methods ----

        /// Get the internal flow vault balance
        ///
        access(all) view
        fun getInternalFlowBalance(): UFix64

        access(all) view
        fun isFRC20NFTWrappered(nft: &NonFungibleToken.NFT): Bool

        access(all) view
        fun getFRC20Strategy(nft: &NonFungibleToken.NFT): FRC20Strategy?

        access(all) view
        fun getStrategiesAmount(all: Bool): UInt64

        access(all) view
        fun getStrategies(all: Bool): [FRC20Strategy]

        access(all) view
        fun isAuthorizedToRegister(addr: Address): Bool

        // write methods ----

        /// Donate to the internal flow vault
        access(all)
        fun donate(value: @FlowToken.Vault): Void

        /// Register a new FRC20 strategy
        access(all)
        fun registerFRC20Strategy(
            nftType: Type,
            alloc: UFix64,
            copies: UInt64,
            cond: String?,
            ins: &Fixes.Inscription,
        )

        /// Xerox an NFT and wrap it to the FixesWrappedNFT collection
        ///
        access(all)
        fun wrap(
            recipient: &FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic, NonFungibleToken.CollectionPublic},
            nftToWrap: @NonFungibleToken.NFT,
        )
    }

    /// The resource for the Wrapper contract
    ///
    pub resource Wrapper: WrapperPublic {
        access(self)
        let strategies: {Type: FRC20Strategy}
        access(self)
        let histories: {Type: {UInt64: Bool}}
        access(self)
        let internalFlowVault: @FlowToken.Vault
        access(self)
        let whitelist: {Address: Bool}

        init() {
            self.histories = {}
            self.strategies = {}
            self.whitelist = {}
            self.internalFlowVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

            emit WrapperCreated()
        }

        destroy() {
            destroy self.internalFlowVault
        }

        // public methods

        access(all) view
        fun getInternalFlowBalance(): UFix64 {
            return self.internalFlowVault.balance
        }

        access(all) view
        fun isFRC20NFTWrappered(nft: &NonFungibleToken.NFT): Bool {
            if let nftHistories = self.histories[nft.getType()] {
                return nftHistories[nft.id] ?? false
            }
            return false
        }

        access(all) view
        fun getFRC20Strategy(nft: &NonFungibleToken.NFT): FRC20Strategy? {
            return self.strategies[nft.getType()]
        }

        access(all) view
        fun getStrategiesAmount(all: Bool): UInt64 {
            if all {
                return UInt64(self.strategies.keys.length)
            }
            return UInt64(self.strategies.values.filter(fun (s: FRC20Strategy): Bool {
                return s.isUsedUp() == false
            }).length)
        }

        access(all) view
        fun getStrategies(all: Bool): [FRC20Strategy] {
            if all {
                return self.strategies.values
            }
            return self.strategies.values.filter(fun (s: FRC20Strategy): Bool {
                return s.isUsedUp() == false
            })
        }

        access(all) view
        fun isAuthorizedToRegister(addr: Address): Bool {
            return addr == self.owner?.address || (self.whitelist[addr] ?? false)
        }

        // write methods

        access(all)
        fun donate(value: @FlowToken.Vault): Void {
            pre {
                value.balance > UFix64(0.0): "Donation must be greater than 0"
            }
            let amt = value.balance
            self.internalFlowVault.deposit(from: <- value)
            emit InternalFlowVaultDonated(amount: amt)
        }

        /// Register a new FRC20 strategy
        access(all)
        fun registerFRC20Strategy(
            nftType: Type,
            alloc: UFix64,
            copies: UInt64,
            cond: String?,
            ins: &Fixes.Inscription,
        ) {
            pre {
                ins.isExtractable(): "The inscription is not extractable"
            }
            let indexer = FRC20Indexer.getIndexer()
            assert(
                indexer.isValidFRC20Inscription(ins: ins),
                message: "The inscription is not a valid FRC20 inscription"
            )
            let fromAddr = ins.owner?.address ?? panic("Inscription owner is nil")
            let data = indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
            assert(
                data["op"] == "transfer" && data["tick"] != nil && data["amt"] != nil && data["to"] != nil,
                message: "The inscription is not a valid FRC20 inscription for transfer"
            )
            let tick: String = data["tick"]!.toLower()
            let meta = indexer.getTokenMeta(tick: tick)
                ?? panic("Could not get token meta for ".concat(tick))

            /// check if the deployer is the owner of the inscription
            assert(
                meta.deployer == fromAddr,
                message: "The frc20 deployer is not the owner of the inscription"
            )

            // check if the deployer is authorized to register a new strategy
            assert(
                self.isAuthorizedToRegister(addr: fromAddr),
                message: "The deployer is not authorized to register a new strategy"
            )

            // check if the strategy already exists
            assert(
                self.strategies[nftType] == nil,
                message: "The strategy already exists"
            )

            // indexer address
            let indexerAddr = FRC20Indexer.getAddress()

            // check if the allocation is enough
            let amt = UFix64.fromString(data["amt"]!) ?? panic("The amount is not a valid UFix64")
            let to = Address.fromString(data["to"]!) ?? panic("The receiver is not a valid address")
            let toAllocateAmt = alloc * UFix64(copies)
            assert(
                amt >= toAllocateAmt,
                message: "The amount is not enough to allocate"
            )
            assert(
                to == indexerAddr,
                message: "The receiver is not the indexer"
            )

            // apply inscription for transfer
            indexer.transfer(ins: ins)

            // ensure frc20 is enough
            let frc20BalanceForContract = indexer.getBalance(tick: tick, addr: indexerAddr)
            assert(
                frc20BalanceForContract >= toAllocateAmt,
                message: "The FRC20 balance for the contract is not enough"
            )

            // setup strategy
            self.strategies[nftType] = FRC20Strategy(
                tick: tick,
                nftType: nftType,
                alloc: alloc,
                copies: copies,
                cond: cond,
            )
            // setup history
            self.histories[nftType] = {}

            // emit event
            emit FRC20StrategyRegistered(
                wrapper: self.owner?.address ?? panic("Wrapper owner is nil"),
                deployer: fromAddr,
                nftType: nftType,
                tick: tick,
                alloc: alloc,
                copies: copies,
                cond: cond,
            )
        }

        /// Wrap an NFT and wrap it to the FixesWrappedNFT collection
        ///
        access(all)
        fun wrap(
            recipient: &FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic, NonFungibleToken.CollectionPublic},
            nftToWrap: @NonFungibleToken.NFT
        ) {
            // check if the NFT is owned by the signer
            let recipientAddr = recipient.owner?.address ?? panic("Recipient owner is nil")
            // get the NFT type
            let nftType = nftToWrap.getType()
            let srcNftId = nftToWrap.id
            // check if the strategy exists, and borrow it
            let strategy = self.borrowStrategy(nftType: nftType)
            // check if the strategy is used up
            assert(
                strategy.usedAmt < strategy.copies,
                message: "The strategy is used up"
            )

            // borrow the history
            let history = self.borrowHistory(nftType: nftType)
            // check if the NFT is already wrapped
            assert(
                history[nftToWrap.id] == nil,
                message: "The NFT is already wrapped"
            )

            // basic attributes
            let mimeType = "text/plain"
            let metaProtocol = "frc20"
            let dataStr = "op=alloc,tick=".concat(strategy.tick)
                .concat(",amt=").concat(strategy.alloc.toString())
                .concat(",to=").concat(recipientAddr.toString())
            let metadata = dataStr.utf8

            // estimate the required storage
            let estimatedReqValue = Fixes.estimateValue(
                index: Fixes.totalInscriptions,
                mimeType: mimeType,
                data: metadata,
                protocol: metaProtocol,
                encoding: nil
            )

            // Get a reference to the signer's stored vault
            let flowToReserve <- self.internalFlowVault.withdraw(amount: estimatedReqValue)

            // Create the Inscription first
            let newIns <- Fixes.createInscription(
                // Withdraw tokens from the signer's stored vault
                value: <- (flowToReserve as! @FlowToken.Vault),
                mimeType: mimeType,
                metadata: metadata,
                metaProtocol: metaProtocol,
                encoding: nil,
                parentId: nil
            )
            // mint the wrapped NFT
            let newId = FixesWrappedNFT.wrap(recipient: recipient, nftToWrap: <- nftToWrap, inscription: <- newIns)

            // borrow the inscription
            let nft = recipient.borrowFixesWrappedNFT(id: newId) ?? panic("Could not borrow FixesWrappedNFT")
            let insRef = nft.borrowInscription() ?? panic("Could not borrow inscription")

            // get FRC20 indexer
            let indexer: &FRC20Indexer.InscriptionIndexer{FRC20Indexer.IndexerPublic} = FRC20Indexer.getIndexer()
            let used <- indexer.allocate(ins: insRef)

            // deposit the unused flow back to the internal flow vault
            self.internalFlowVault.deposit(from: <- used)

            // update strategy used one time
            strategy.use()

            // update histories
            history[srcNftId] = true

            // emit event
            emit NFTWrappedWithFRC20Allocated(
                wrapper: self.owner?.address ?? panic("Wrapper owner is nil"),
                nftType: nftType,
                srcNftId: srcNftId,
                wrappedNftId: newId,
                tick: strategy.tick,
                alloc: strategy.alloc,
                address: recipientAddr,
            )
        }

        // private methods

        /// Update the whitelist
        ///
        access(all)
        fun updateWhitelist(addr: Address, isAuthorized: Bool): Void {
            self.whitelist[addr] = isAuthorized

            emit AuthorizedWhitelistUpdated(
                addr: addr,
                isAuthorized: isAuthorized,
            )
        }

        // internal methods

        /// Borrow the strategy for an NFT type
        ///
        access(self)
        fun borrowStrategy(nftType: Type): &FRC20Strategy {
            return &self.strategies[nftType] as &FRC20Strategy?
                ?? panic("Could not borrow strategy")
        }

        /// Borrow the history for an NFT type
        ///
        access(self)
        fun borrowHistory(nftType: Type): &{UInt64: Bool} {
            return &self.histories[nftType] as &{UInt64: Bool}?
                ?? panic("Could not borrow history")
        }
    }

    /// The public resource interface for the Wrapper Indexer
    ///
    pub resource interface WrapperIndexerPublic {
        // public methods ----

        /// Check if the wrapper is registered
        ///
        access(all) view
        fun hasRegisteredWrapper(addr: Address): Bool

        /// Get all the wrappers
        access(all) view
        fun getAllWrappers(includeNoStrategy: Bool): [Address]

        /// Get the public reference to the Wrapper resource
        ///
        access(all)
        fun borrowWrapperPublic(addr: Address): &Wrapper{WrapperPublic}? {
            return FRC20NFTWrapper.borrowWrapperPublic(addr: addr)
        }

        /// Get the extra NFT collection display
        ///
        access(all) view
        fun getExtraNFTCollectionDisplay(
            nftType: Type,
        ): MetadataViews.NFTCollectionDisplay?

        // write methods ----

        /// Register a new Wrapper
        access(all)
        fun registerWrapper(wrapper: &Wrapper)

        /// Update the wrapper options
        access(all)
        fun updateWrapperOptions(wrapper: &Wrapper, key: String, value: AnyStruct)
    }

    /// The resource for the Wrapper indexer contract
    ///
    pub resource WrapperIndexer: WrapperIndexerPublic {
        /// The event that is emitted when the contract is created
        access(self)
        let wrappers: {Address: Bool}
        access(self)
        let wrapperOptions: {Address: {String: AnyStruct}}
        access(self)
        let displayHelper: {Type: MetadataViews.NFTCollectionDisplay}

        init() {
            self.wrappers = {}
            self.wrapperOptions = {}
            self.displayHelper = {}
        }

        // public methods ----

        /// Check if the wrapper is registered
        ///
        access(all) view
        fun hasRegisteredWrapper(addr: Address): Bool {
            return self.wrappers[addr] != nil
        }

        /// Get all the wrappers
        ///
        access(all) view
        fun getAllWrappers(includeNoStrategy: Bool): [Address] {
            return self.wrappers.keys.filter(fun (addr: Address): Bool {
                if let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: addr) {
                    return includeNoStrategy ? true : wrapper.getStrategiesAmount(all: false) > 0
                } else {
                    return false
                }
            })
        }

        /// Get the extra NFT collection display
        ///
        access(all) view
        fun getExtraNFTCollectionDisplay(
            nftType: Type,
        ): MetadataViews.NFTCollectionDisplay? {
            return self.displayHelper[nftType]
        }

        // write methods ----

        /// Register a new Wrapper
        access(all)
        fun registerWrapper(wrapper: &Wrapper) {
            pre {
                wrapper.owner != nil: "Wrapper owner is nil"
            }
            let ownerAddr = wrapper.owner!.address
            self.wrappers[ownerAddr] = true
            self.wrapperOptions[ownerAddr] = {}

            emit WrapperAddedToIndexer(wrapper: ownerAddr)
        }

        /// Update the wrapper options
        access(all)
        fun updateWrapperOptions(wrapper: &Wrapper, key: String, value: AnyStruct) {
            pre {
                wrapper.owner != nil: "Wrapper owner is nil"
            }
            let ownerAddr = wrapper.owner!.address
            if self.wrappers[ownerAddr] == nil {
                self.registerWrapper(wrapper: wrapper)
            }

            let optionsRef = self.borrowWrapperOptions(addr: ownerAddr)
            optionsRef[key] = value

            emit WrapperOptionsUpdated(wrapper: wrapper.owner?.address ?? panic("Wrapper owner is nil"), key: key)
        }

        // private write methods ----

        access(all)
        fun updateExtraNFTCollectionDisplay(
            nftType: Type,
            display: MetadataViews.NFTCollectionDisplay,
        ): Void {
            self.displayHelper[nftType] = display

            emit WrapperIndexerUpdatedNFTCollectionDisplay(
                nftType: nftType,
                name: display.name,
                description: display.description,
            )
        }

        /// Borrow the wrapper options
        ///
        access(self)
        fun borrowWrapperOptions(addr: Address): &{String: AnyStruct} {
            return &self.wrapperOptions[addr] as &{String: AnyStruct}?
                ?? panic("Could not borrow wrapper options")
        }
    }

    /// Donate to the internal flow vault
    ///
    access(all)
    fun donate(
        addr: Address,
        _ value: @FlowToken.Vault
    ): Void {
        let ref = self.borrowWrapperPublic(addr: addr)
             ?? panic("Could not borrow Xerox public reference")
        ref.donate(value: <- value)
    }

    /// Create a new Wrapper resourceTON
    ///
    access(all)
    fun createNewWrapper(): @Wrapper {
        return <- create Wrapper()
    }

    /// Borrow the public reference to the Wrapper resource
    ///
    access(all)
    fun borrowWrapperPublic(
        addr: Address,
    ): &FRC20NFTWrapper.Wrapper{WrapperPublic}? {
        return getAccount(addr)
            .getCapability<&FRC20NFTWrapper.Wrapper{WrapperPublic}>(self.FRC20NFTWrapperPublicPath)
            .borrow()
    }

    /// init
    init() {
        let identifier = "FixesFRC20NFTWrapper_".concat(self.account.address.toString())
        self.FRC20NFTWrapperStoragePath = StoragePath(identifier: identifier)!
        self.FRC20NFTWrapperPublicPath = PublicPath(identifier: identifier)!

        self.FRC20NFTWrapperIndexerStoragePath = StoragePath(identifier: identifier.concat("_indexer"))!
        self.FRC20NFTWrapperIndexerPublicPath = PublicPath(identifier: identifier.concat("_indexer"))!

        self.account.save(<- self.createNewWrapper(), to: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
        self.account.link<&FRC20NFTWrapper.Wrapper{FRC20NFTWrapper.WrapperPublic}>(
            FRC20NFTWrapper.FRC20NFTWrapperPublicPath,
            target: FRC20NFTWrapper.FRC20NFTWrapperStoragePath
        )

        // create indexer
        let indexer <- create WrapperIndexer()

        // register the wrapper to the indexer
        let wrapper = self.account.borrow<&Wrapper>(from: FRC20NFTWrapper.FRC20NFTWrapperStoragePath)
            ?? panic("Could not borrow wrapper public reference")
        indexer.registerWrapper(wrapper: wrapper)

        // save the indexer
        self.account.save(<- indexer, to: self.FRC20NFTWrapperIndexerStoragePath)
        self.account.link<&FRC20NFTWrapper.WrapperIndexer{FRC20NFTWrapper.WrapperIndexerPublic}>(
            self.FRC20NFTWrapperIndexerPublicPath,
            target: self.FRC20NFTWrapperIndexerStoragePath
        )

        emit ContractInitialized()
    }
}
