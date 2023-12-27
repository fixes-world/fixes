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

    /// The event that is emitted when the whitelist is updated
    pub event AuthorizedWhitelistUpdated(
        addr: Address,
        isAuthorized: Bool,
    )

    /// The event that is emitted when an NFT is unwrapped
    pub event FRC20StrategyRegistered(
        deployer: Address,
        nftType: Type,
        tick: String,
        alloc: UFix64,
        copies: UInt64,
    )
    /// The event that is emitted when an NFT is wrapped
    pub event NFTWrappedWithFRC20Allocated(
        nftType: Type,
        srcNftId: UInt64,
        wrappedNftId: UInt64,
        tick: String,
        alloc: UFix64,
        address: Address,
    )

    /* --- Variable, Enums and Structs --- */
    access(all)
    let FRC20NFTWrapperStoragePath: StoragePath
    access(all)
    let FRC20NFTWrapperPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    pub struct FRC20Strategy {
        pub let tick: String
        pub let nftType: Type
        pub let alloc: UFix64
        pub let copies: UInt64
        pub var usedAmt: UInt64

        init(
            tick: String,
            nftType: Type,
            alloc: UFix64,
            c: UInt64
        ) {
            self.tick = tick
            self.nftType = nftType
            self.alloc = alloc
            self.copies = c
            self.usedAmt = 0
        }

        access(contract)
        fun use() {
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
            ins: &Fixes.Inscription,
        )

        /// Xerox an NFT and wrap it to the FixesWrappedNFT collection
        ///
        access(all)
        fun wrap(
            recipient: &FixesWrappedNFT.Collection{FixesWrappedNFT.FixesWrappedNFTCollectionPublic, NonFungibleToken.CollectionPublic},
            nftToWrap: @NonFungibleToken.NFT,
        )
        /// Unwrap an NFT to its original collection
        ///
        access(all)
        fun unwrap(
            recipient: &{NonFungibleToken.CollectionPublic},
            nftToUnwrap: @FixesWrappedNFT.NFT,
        ): @Fixes.Inscription?
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
        let minterCap: Capability<&FixesWrappedNFT.NFTMinter{FixesWrappedNFT.Minter}>
        access(self)
        let whitelist: {Address: Bool}

        init(
            _ cap: Capability<&FixesWrappedNFT.NFTMinter{FixesWrappedNFT.Minter}>,
        ) {
            pre {
                cap.check() && cap.borrow() != nil: "Capability not authorized"
            }
            self.histories = {}
            self.strategies = {}
            self.whitelist = {}
            self.minterCap = cap
            self.internalFlowVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
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
        fun isAuthorizedToRegister(addr: Address): Bool {
            return self.whitelist[addr] ?? false
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
                data["tick"] != nil,
                message: "The inscription does not have a tick"
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

            // apply inscription
            if data["op"] == "transfer" {
                indexer.transfer(ins: ins)
            } else if data["op"] == "mint" {
                indexer.mint(ins: ins)
            }
            // ensure frc20 is enough
            let indexerAddr = FRC20Indexer.getAddress()
            let frc20BalanceForContract = indexer.getBalance(tick: tick, addr: indexerAddr)
            assert(
                frc20BalanceForContract >= alloc * UFix64(copies),
                message: "The FRC20 balance for the contract is not enough"
            )

            // setup strategy
            self.strategies[nftType] = FRC20Strategy(
                tick: tick,
                nftType: nftType,
                alloc: alloc,
                c: copies
            )
            // setup history
            self.histories[nftType] = {}

            // emit event
            emit FRC20StrategyRegistered(
                deployer: fromAddr,
                nftType: nftType,
                tick: tick,
                alloc: alloc,
                copies: copies,
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
            let minter = self.borrowMinter()
            let newId = minter.wrap(recipient: recipient, nftToWrap: <- nftToWrap, inscription: <- newIns)

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
                nftType: nftType,
                srcNftId: srcNftId,
                wrappedNftId: newId,
                tick: strategy.tick,
                alloc: strategy.alloc,
                address: recipientAddr,
            )
        }

        /// Unwrap an NFT to its original collection
        ///
        access(all)
        fun unwrap(
            recipient: &{NonFungibleToken.CollectionPublic},
            nftToUnwrap: @FixesWrappedNFT.NFT,
        ): @Fixes.Inscription? {
            let minter = self.borrowMinter()
            return <- minter.unwrap(recipient: recipient, nftToUnwrap: <- nftToUnwrap)
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

        /// Borrow the minter for the FixesWrappedNFT collection
        ///
        access(self)
        fun borrowMinter(): &FixesWrappedNFT.NFTMinter{FixesWrappedNFT.Minter} {
            return self.minterCap.borrow() ?? panic("Could not borrow minter")
        }

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

    /// Donate to the internal flow vault
    ///
    access(all)
    fun donate(
        addr: Address,
        _ value: @FlowToken.Vault
    ): Void {
        let ref = self.borrowWrapperPublic(addr: addr)
        ref.donate(value: <- value)
    }

    /// Create a new Wrapper resourceTON
    ///
    access(all)
    fun createNewWrapper(
        _ minterCap: Capability<&FixesWrappedNFT.NFTMinter{FixesWrappedNFT.Minter}>,
    ): @Wrapper {
        return <- create Wrapper(minterCap)
    }

    /// Borrow the public reference to the Wrapper resource
    ///
    access(all)
    fun borrowWrapperPublic(
        addr: Address,
    ): &FRC20NFTWrapper.Wrapper{WrapperPublic} {
        return getAccount(addr)
            .getCapability<&FRC20NFTWrapper.Wrapper{WrapperPublic}>(self.FRC20NFTWrapperPublicPath)
            .borrow() ?? panic("Could not borrow Xerox public reference")
    }

    /// init
    init() {
        let identifier = "FixesFRC20NFTWrapper_".concat(self.account.address.toString())
        self.FRC20NFTWrapperStoragePath = StoragePath(identifier: identifier)!
        self.FRC20NFTWrapperPublicPath = PublicPath(identifier: identifier)!

        emit ContractInitialized()
    }
}
