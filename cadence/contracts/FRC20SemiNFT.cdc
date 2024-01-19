/**
#
# Author: FIXeS World <https://fixes.world/>
#
*/
// Third party imports
import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"
import "FungibleToken"
import "FlowToken"
// Fixes Import
import "Fixes"
import "FRC20FTShared"

access(all) contract FRC20SemiNFT: NonFungibleToken, ViewResolver {

    /* --- Events --- */

    /// Total supply of FRC20SemiNFTs in existence
    access(all) var totalSupply: UInt64

    /// The event that is emitted when the contract is created
    access(all) event ContractInitialized()

    /// The event that is emitted when an NFT is withdrawn from a Collection
    access(all) event Withdraw(id: UInt64, from: Address?)

    /// The event that is emitted when an NFT is deposited to a Collection
    access(all) event Deposit(id: UInt64, to: Address?)

    /// The event that is emitted when an NFT is wrapped
    access(all) event Wrapped(id: UInt64, pool: Address, tick: String, balance: UFix64)

    /// The event that is emitted when an NFT is unwrapped
    access(all) event Unwrapped(id: UInt64, pool: Address, tick: String, balance: UFix64)

    /// The event that is emitted when an NFT is merged
    access(all) event Merged(id: UInt64, mergedId: UInt64, pool: Address, tick: String, mergedBalance: UFix64)

    /// The event that is emitted when an NFT is splitted
    access(all) event Split(id: UInt64, splittedId: UInt64, pool: Address, tick: String, splitBalance: UFix64)

    /// The event that is emitted when the claiming record is updated
    access(all) event ClaimingRecordUpdated(id: UInt64, tick: String, pool: Address, strategy: String, time: UInt64, globalYieldRate: UFix64, totalClaimedAmount: UFix64)

    /* --- Variable, Enums and Structs --- */

    /// Storage and Public Paths
    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let CollectionPrivatePath: PrivatePath

    /* --- Interfaces & Resources --- */

    /// Reward Claiming Record Struct, stored in SemiNFT
    ///
    access(all) struct RewardClaimRecord {
        // The pool address
        access(all)
        let poolAddress: Address
        // The reward strategy name
        access(all)
        let rewardStrategy: String
        // The last claimed time
        access(all)
        var lastClaimedTime: UInt64
        // The last global yield rate
        access(all)
        var lastGlobalYieldRate: UFix64
        // The total claimed amount by this record
        access(all)
        var totalClaimedAmount: UFix64

        init (
            address: Address,
            name: String,
        ) {
            self.poolAddress = address
            self.rewardStrategy = name
            self.lastClaimedTime = 0
            self.lastGlobalYieldRate = 0.0
            self.totalClaimedAmount = 0.0
        }

        /// Update the claiming record
        ///
        access(contract)
        fun updateClaiming(currentGlobalYieldRate: UFix64, time: UInt64?) {
            self.lastClaimedTime = time ?? UInt64(getCurrentBlock().timestamp)
            self.lastGlobalYieldRate = currentGlobalYieldRate
        }

        access(contract)
        fun addClaimedAmount(amount: UFix64) {
            self.totalClaimedAmount = self.totalClaimedAmount.saturatingAdd(amount)
        }

        access(contract)
        fun subtractClaimedAmount(amount: UFix64) {
            self.totalClaimedAmount = self.totalClaimedAmount.saturatingSubtract(amount)
        }
    }

    /// Public Interface of the FRC20SemiNFT
    access(all) resource interface IFRC20SemiNFT {
        /// The unique ID that each NFT has
        access(all) let id: UInt64

        access(all) view
        fun getOriginalTick(): String

        access(all) view
        fun isStakedTick(): Bool

        access(all) view
        fun isBackedByVault(): Bool

        access(all) view
        fun getVaultType(): Type?

        access(all) view
        fun getBalance(): UFix64

        access(all) view
        fun getRewardStrategies(): [String]

        access(all) view
        fun getClaimingRecord(_ uniqueName: String): RewardClaimRecord?

        access(all) view
        fun buildUniqueName(_ addr: Address, _ strategy: String): String
    }

    /// The core resource that represents a Non Fungible Token.
    /// New instances will be created using the NFTMinter resource
    /// and stored in the Collection resource
    ///
    access(all) resource NFT: IFRC20SemiNFT, NonFungibleToken.INFT, MetadataViews.Resolver {
        /// The unique ID that each NFT has
        access(all) let id: UInt64

        /// Wrapped FRC20FTShared.Change
        access(self)
        var wrappedChange: @FRC20FTShared.Change
        /// Claiming Records for staked FRC20FTShared.Change
        /// Unique Name => Reward Claim Record
        access(self)
        let claimingRecords: {String: RewardClaimRecord}

        init(
            _ change: @FRC20FTShared.Change
        ) {
            pre {
                change.isBackedByVault() == false: "Cannot wrap a vault backed FRC20 change"
            }
            self.id = self.uuid
            self.wrappedChange <- change
            self.claimingRecords = {}

            FRC20SemiNFT.totalSupply = FRC20SemiNFT.totalSupply + 1

            // emit the event
            emit Wrapped(
                id: self.id,
                pool: self.wrappedChange.from,
                tick: self.wrappedChange.tick,
                balance: self.wrappedChange.getBalance()
            )
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.wrappedChange
        }

        /** ----- MetadataViews.Resolver ----- */

        /// Function that returns all the Metadata Views implemented by a Non Fungible Token
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        access(all)
        fun getViews(): [Type] {
            var nftViews: [Type] = [
                // collection data
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                // nft view data
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Royalties>()
            ]
            return nftViews
        }

        /// Function that resolves a metadata view for this token.
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        access(all)
        fun resolveView(_ view: Type): AnyStruct? {
            let colViews = [
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
            if colViews.contains(view) {
                return FRC20SemiNFT.resolveView(view)
            } else {
                switch view {
                case Type<MetadataViews.Display>():
                    let tick = self.getOriginalTick()
                    let isStaked = self.isStakedTick()
                    let fullName = (isStaked ? "Staked " : "").concat(tick)
                    let balance = self.getBalance()
                    return MetadataViews.Display(
                        title: "𝔉rc20 - ".concat(fullName),
                        description: "This is a 𝔉rc20 Semi-NFT that contains a certain number of ".concat(fullName).concat(" tokens. \n")
                            .concat("The balance of this Semi-NFT is ").concat(balance.toString()).concat(". \n"),
                        thumbnail: MetadataViews.HTTPFile(
                            // TODO, FIXME: using the SVG dataimage URI
                            url: "https://i.imgur.com/hs3U5CY.png"
                        ),
                    )
                case Type<MetadataViews.Traits>():
                    let traits = MetadataViews.Traits([])
                    let changeRef: &FRC20FTShared.Change = self.borrowChange()
                    traits.addTrait(MetadataViews.Trait(name: "originTick", value: changeRef.getOriginalTick(), nil, nil))
                    traits.addTrait(MetadataViews.Trait(name: "tick", value: changeRef.tick, nil, nil))
                    traits.addTrait(MetadataViews.Trait(name: "balance", value: changeRef.getBalance(), nil, nil))
                    let isVault = changeRef.isBackedByVault()
                    traits.addTrait(MetadataViews.Trait(name: "isFlowFT", value: isVault, nil, nil))
                    if isVault {
                        traits.addTrait(MetadataViews.Trait(name: "ftType", value: changeRef.getVaultType()!.identifier, nil, nil))
                    }
                    return traits
                case Type<MetadataViews.Royalties>():
                    // Royalties for FRC20SemiNFT is 5% to Deployer account
                    let deployerAddr = FRC20SemiNFT.account.address
                    let flowCap = getAccount(deployerAddr)
                        .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                    return MetadataViews.Royalties([
                        MetadataViews.Royalty(
                            receiver: flowCap,
                            cut: 0.05,
                            description: "5% of the sale price of this NFT goes to the FIXeS platform account"
                        )
                    ])
                }
                return nil
            }
        }

        /** ----- Semi-NFT Methods ----- */

        access(all) view
        fun getOriginalTick(): String {
            return self.wrappedChange.getOriginalTick()
        }

        access(all) view
        fun isStakedTick(): Bool {
            return self.wrappedChange.isStakedTick()
        }

        access(all) view
        fun isBackedByVault(): Bool {
            return self.wrappedChange.isBackedByVault()
        }

        access(all) view
        fun getVaultType(): Type? {
            return self.wrappedChange.getVaultType()
        }

        access(all) view
        fun getBalance(): UFix64 {
            return self.wrappedChange.getBalance()
        }

        /// Get the reward strategies
        ///
        access(all) view
        fun getRewardStrategies(): [String] {
            return self.claimingRecords.keys
        }

        /// Get the the claiming record(copy) by the unique name
        ///
        access(all) view
        fun getClaimingRecord(_ uniqueName: String): RewardClaimRecord? {
            pre {
                self.isStakedTick(): "The tick must be a staked 𝔉rc20 token"
            }
            return self.claimingRecords[uniqueName]
        }

        // Merge the NFT
        //
        access(all)
        fun merge(_ other: @FRC20SemiNFT.NFT) {
            pre {
                self.getOriginalTick() == other.getOriginalTick(): "The tick must be the same"
                self.isBackedByVault() == other.isBackedByVault(): "The vault type must be the same"
            }
            // check tick and pool address
            let otherChangeRef = other.borrowChange()
            assert(
                self.wrappedChange.from == otherChangeRef.from,
                message: "The pool address must be the same"
            )

            let otherId = other.id
            let otherBalance = otherChangeRef.getBalance()

            // calculate the new balance
            let newBalance = self.getBalance() + otherChangeRef.getBalance()

            // merge the claiming records
            if self.isStakedTick() && other.isStakedTick() {
                let strategies = self.getRewardStrategies()
                // merge each strategy
                for name in strategies {
                    if let otherRecordRef = other._borrowClaimingRecord(name) {
                        // update claiming record
                        let recordRef = self._borrowOrCreateClaimingRecord(
                            poolAddress: otherRecordRef.poolAddress,
                            rewardStrategy: otherRecordRef.rewardStrategy
                        )
                        // calculate the new claiming record
                        var newGlobalYieldRate = 0.0
                        // Weighted average
                        if newBalance > 0.0 {
                            newGlobalYieldRate = (recordRef.lastGlobalYieldRate * self.getBalance() + otherRecordRef.lastGlobalYieldRate * otherChangeRef.getBalance()) / newBalance
                        }
                        let newLastClaimedTime = recordRef.lastClaimedTime > otherRecordRef.lastClaimedTime ? recordRef.lastClaimedTime : otherRecordRef.lastClaimedTime

                        // update the record
                        self.updateClaimingRecord(
                            poolAddress: otherRecordRef.poolAddress,
                            rewardStrategy: otherRecordRef.rewardStrategy,
                            currentGlobalYieldRate: newGlobalYieldRate,
                            currentTime: newLastClaimedTime,
                            amount: otherRecordRef.totalClaimedAmount,
                            isSubtract: false
                        )
                    }
                }
            }

            // unwrap and merge the wrapped change
            let unwrappedChange <- FRC20SemiNFT.unwrapStakedFRC20(nftToUnwrap: <- other)
            self.wrappedChange.merge(from: <- unwrappedChange)

            assert(
                newBalance == self.getBalance(),
                message: "The merged balance must be correct"
            )

            // emit event
            emit Merged(
                id: self.id,
                mergedId: otherId,
                pool: self.wrappedChange.from,
                tick: self.wrappedChange.tick,
                mergedBalance: otherBalance
            )
        }

        // Split the NFT
        access(all)
        fun split(_ percent: UFix64): @FRC20SemiNFT.NFT {
            pre {
                percent > 0.0: "The split percent must be greater than 0"
                percent < 1.0: "The split percent must be less than 1"
            }
            let oldBalance = self.getBalance()
            // calculate the new balance
            let splitBalance = oldBalance * percent

            // split the wrapped change
            let splitChange <- self.wrappedChange.withdrawAsChange(amount: splitBalance)

            // create a new NFT
            let newNFT <- create NFT(<- splitChange)

            // check balance of the new NFT and the old NFT
            assert(
                self.getBalance() + newNFT.getBalance() == oldBalance,
                message: "The splitted balance must be correct"
            )

            // split the claiming records
            if self.isStakedTick() {
                let strategies = self.getRewardStrategies()
                // split each strategy
                for name in strategies {
                    if let recordRef = self._borrowClaimingRecord(name) {
                        let splitAmount = recordRef.totalClaimedAmount * percent
                        // update the record for current NFT
                        self.updateClaimingRecord(
                            poolAddress: recordRef.poolAddress,
                            rewardStrategy: recordRef.rewardStrategy,
                            currentGlobalYieldRate: recordRef.lastGlobalYieldRate,
                            currentTime: recordRef.lastClaimedTime,
                            amount: splitAmount,
                            isSubtract: true
                        )
                        // update the record for new NFT
                        newNFT.updateClaimingRecord(
                            poolAddress: recordRef.poolAddress,
                            rewardStrategy: recordRef.rewardStrategy,
                            currentGlobalYieldRate: recordRef.lastGlobalYieldRate,
                            currentTime: recordRef.lastClaimedTime,
                            amount: splitAmount,
                            isSubtract: false
                        )
                    }
                }
            }

            // emit event
            emit Split(
                id: self.id,
                splittedId: newNFT.id,
                pool: self.wrappedChange.from,
                tick: self.wrappedChange.tick,
                splitBalance: splitBalance
            )

            return <-newNFT
        }

        /** ---- Account level methods ---- */

        /// Get the unique name of the reward strategy
        ///
        access(all) view
        fun buildUniqueName(_ addr: Address, _ strategy: String): String {
            let ref = self.borrowChange()
            return addr.toString().concat("_").concat(ref.getOriginalTick()).concat("_").concat(strategy)
        }

        /// Hook method: Update the claiming record
        ///
        access(account)
        fun onClaimingReward(
            poolAddress: Address,
            rewardStrategy: String,
            amount: UFix64,
            currentGlobalYieldRate: UFix64
        ) {
            self.updateClaimingRecord(
                poolAddress: poolAddress,
                rewardStrategy: rewardStrategy,
                currentGlobalYieldRate: currentGlobalYieldRate,
                currentTime: nil,
                amount: amount,
                isSubtract: false
            )
        }

        /// Update the claiming record
        ///
        access(account)
        fun updateClaimingRecord(
            poolAddress: Address,
            rewardStrategy: String,
            currentGlobalYieldRate: UFix64,
            currentTime: UInt64?,
            amount: UFix64,
            isSubtract: Bool,
        ) {
            pre {
                self.isStakedTick(): "The tick must be a staked 𝔉rc20 token"
            }
            // update claiming record
            let recordRef = self._borrowOrCreateClaimingRecord(
                poolAddress: poolAddress,
                rewardStrategy: rewardStrategy
            )
            recordRef.updateClaiming(currentGlobalYieldRate: currentGlobalYieldRate, time: currentTime)

            if isSubtract {
                recordRef.subtractClaimedAmount(amount: amount)
            } else {
                recordRef.addClaimedAmount(amount: amount)
            }

            // emit event
            emit ClaimingRecordUpdated(
                id: self.id,
                tick: self.getOriginalTick(),
                pool: poolAddress,
                strategy: rewardStrategy,
                time: recordRef.lastClaimedTime,
                globalYieldRate: recordRef.lastGlobalYieldRate,
                totalClaimedAmount: recordRef.totalClaimedAmount
            )
        }

        /** Internal Method */

        /// Borrow the wrapped FRC20FTShared.Change
        ///
        access(contract)
        fun borrowChange(): &FRC20FTShared.Change {
            return &self.wrappedChange as &FRC20FTShared.Change
        }

        /// Borrow or create the claiming record(writeable reference) by the unique name
        ///
        access(self)
        fun _borrowOrCreateClaimingRecord(
            poolAddress: Address,
            rewardStrategy: String
        ): &RewardClaimRecord {
            let uniqueName = self.buildUniqueName(poolAddress, rewardStrategy)
            if self.claimingRecords[uniqueName] == nil {
                self.claimingRecords[uniqueName] = RewardClaimRecord(
                    address: self.wrappedChange.from,
                    name: uniqueName,
                )
            }
            return self._borrowClaimingRecord(uniqueName) ?? panic("Claiming record must exist")
        }

        /// Borrow the claiming record(writeable reference) by the unique name
        ///
        access(self)
        fun _borrowClaimingRecord(_ uniqueName: String): &RewardClaimRecord? {
            return &self.claimingRecords[uniqueName] as &RewardClaimRecord?
        }
    }

    /// Defines the public methods that are particular to this NFT contract collection
    ///
    access(all) resource interface FRC20SemiNFTCollectionPublic {
        access(all)
        fun deposit(token: @NonFungibleToken.NFT)
        access(all)
        fun getIDs(): [UInt64]
        access(all)
        fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        /** ----- Specific Methods For SemiNFT ----- */
        access(all) view
        fun getIDsByTick(tick: String): [UInt64]
        access(all)
        fun borrowFRC20SemiNFTPublic(id: UInt64): &FRC20SemiNFT.NFT{IFRC20SemiNFT, NonFungibleToken.INFT, MetadataViews.Resolver}? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FRC20SemiNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    /// Defines the private methods that are particular to this NFT contract collection
    ///
    access(all) resource interface FRC20SemiNFTBorrowable {
        /** ----- Specific Methods For SemiNFT ----- */
        access(all) view
        fun getIDsByTick(tick: String): [UInt64]
        access(all)
        fun borrowFRC20SemiNFT(id: UInt64): &FRC20SemiNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FRC20SemiNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    /// The resource that will be holding the NFTs inside any account.
    /// In order to be able to manage NFTs any account will need to create
    /// an empty collection first
    ///
    access(all) resource Collection: FRC20SemiNFTCollectionPublic, FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        access(all) var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
        // Tick => NFT ID Array
        access(self)
        let tickIDsMapping: {String: [UInt64]}

        init () {
            self.ownedNFTs <- {}
            self.tickIDsMapping = {}
        }

        /// @deprecated after Cadence 1.0
        destroy() {
            destroy self.ownedNFTs
        }

        /// Removes an NFT from the collection and moves it to the caller
        ///
        /// @param withdrawID: The ID of the NFT that wants to be withdrawn
        /// @return The NFT resource that has been taken out of the collection
        ///
        access(all)
        fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- (self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")) as! @FRC20SemiNFT.NFT

            // remove from tickIDsMapping
            let tick = token.getOriginalTick()
            let tickIDs = self._borrowTickIDs(tick) ?? panic("Tick IDs must exist")
            let index = tickIDs.firstIndex(of: token.id) ?? panic("Token ID must exist in tickIDs")
            tickIDs.remove(at: index)

            // emit the event
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        /// Adds an NFT to the collections dictionary and adds the ID to the id array
        ///
        /// @param token: The NFT resource to be included in the collection
        ///
        access(all)
        fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FRC20SemiNFT.NFT

            let id: UInt64 = token.id
            let tick = token.getOriginalTick()

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            // add to tickIDsMapping
            let tickIDs = self._borrowOrCreateTickIDs(tick)
            tickIDs.append(id)

            // emit the event
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        /// Helper method for getting the collection IDs
        ///
        /// @return An array containing the IDs of the NFTs in the collection
        ///
        access(all)
        fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /// Gets a reference to an NFT in the collection so that
        /// the caller can read its metadata and call its methods
        ///
        /// @param id: The ID of the wanted NFT
        /// @return A reference to the wanted NFT resource
        ///
        access(all)
        fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        /// Gets an array of NFT IDs in the collection by the tick
        ///
        access(all) view
        fun getIDsByTick(tick: String): [UInt64] {
            if let ids = self.tickIDsMapping[tick] {
                return ids
            }
            return []
        }

        /// Gets a reference to an NFT in the collection with the public interface
        ///
        access(all)
        fun borrowFRC20SemiNFTPublic(id: UInt64): &FRC20SemiNFT.NFT{IFRC20SemiNFT, NonFungibleToken.INFT, MetadataViews.Resolver}? {
            return self.borrowFRC20SemiNFT(id: id)
        }

        /// Gets a reference to an NFT in the collection for detailed operations
        ///
        access(all)
        fun borrowFRC20SemiNFT(id: UInt64): &FRC20SemiNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FRC20SemiNFT.NFT
            }
            return nil
        }

        /** ----- ViewResolver ----- */

        /// Gets a reference to the NFT only conforming to the `{MetadataViews.Resolver}`
        /// interface so that the caller can retrieve the views that the NFT
        /// is implementing and resolve them
        ///
        /// @param id: The ID of the wanted NFT
        /// @return The resource reference conforming to the Resolver interface
        ///
        access(all)
        fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FRC20SemiNFT = nft as! &FRC20SemiNFT.NFT
            return FRC20SemiNFT as &AnyResource{MetadataViews.Resolver}
        }

        /** ------ Internal Methods ------ */

        /// Borrow the tick IDs mapping
        ///
        access(self)
        fun _borrowTickIDs(_ tick: String): &[UInt64]? {
            return &self.tickIDsMapping[tick] as &[UInt64]?
        }

        /// Borrow or create the tick IDs mapping
        ///
        access(self)
        fun _borrowOrCreateTickIDs(_ tick: String): &[UInt64] {
            if self.tickIDsMapping[tick] == nil {
                self.tickIDsMapping[tick] = []
            }
            return self._borrowTickIDs(tick) ?? panic("Tick IDs must exist")
        }
    }

    /// Allows anyone to create a new empty collection
    ///
    /// @return The new Collection resource
    ///
    access(all)
    fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /// Mints a new NFT with a new ID and deposit it in the
    /// recipients collection using their collection reference
    /// -- recipient, the collection of FRC20SemiNFT
    ///
    access(all)
    fun wrap(
        recipient: &FRC20SemiNFT.Collection{NonFungibleToken.CollectionPublic},
        change: @FRC20FTShared.Change,
    ): UInt64 {
        pre {
            change.isBackedByVault() == false: "Cannot wrap a vault backed FRC20 change"
        }
        let poolAddress = change.from
        let tick = change.tick
        let balance = change.getBalance()
        // create a new NFT
        var newNFT <- create NFT(<- change)
        let nftId = newNFT.id
        // deposit it in the recipient's account using their reference
        recipient.deposit(token: <-newNFT)
        return nftId
    }

    /// Unwraps an NFT and deposits it in the recipients collection
    /// using their collection reference
    ///
    access(all)
    fun unwrapFRC20(
        nftToUnwrap: @FRC20SemiNFT.NFT,
    ): @FRC20FTShared.Change {
        pre {
            nftToUnwrap.isStakedTick() == false: "Cannot unwrap a staked 𝔉rc20 token by this method."
        }
        return <- self._unwrap(<- nftToUnwrap)
    }

    /// Unwraps the SemiNFT and returns the wrapped FRC20FTShared.Change
    /// Account level method
    ///
    access(account)
    fun unwrapStakedFRC20(
        nftToUnwrap: @FRC20SemiNFT.NFT,
    ): @FRC20FTShared.Change {
        pre {
            nftToUnwrap.isStakedTick() == true: "Cannot unwrap a non-staked 𝔉rc20 token by this method."
        }
        return <- self._unwrap(<- nftToUnwrap)
    }

    /// Unwraps the SemiNFT and returns the wrapped FRC20FTShared.Change
    /// Contract level method
    ///
    access(contract)
    fun _unwrap(
        _ nftToUnwrap: @FRC20SemiNFT.NFT,
    ): @FRC20FTShared.Change {
        let nftId = nftToUnwrap.id

        let changeRef = nftToUnwrap.borrowChange()
        let allBalance = changeRef.getBalance()
        // withdraw all balance from the wrapped change
        let newChange <- changeRef.withdrawAsChange(amount: allBalance)

        // destroy the FRC20SemiNFT
        destroy nftToUnwrap

        // decrease the total supply
        FRC20SemiNFT.totalSupply = FRC20SemiNFT.totalSupply - 1

        // emit the event
        emit Unwrapped(
            id: nftId,
            pool: changeRef.from,
            tick: changeRef.tick,
            balance: allBalance
        )
        // return the inscription
        return <- newChange
    }


    /// Function that resolves a metadata view for this contract.
    ///
    /// @param view: The Type of the desired view.
    /// @return A structure representing the requested view.
    ///
    access(all)
    fun resolveView(_ view: Type): AnyStruct? {
        switch view {
            case Type<MetadataViews.ExternalURL>():
                return MetadataViews.ExternalURL("https://fixes.world/")
            case Type<MetadataViews.NFTCollectionData>():
                return MetadataViews.NFTCollectionData(
                    storagePath: FRC20SemiNFT.CollectionStoragePath,
                    publicPath: FRC20SemiNFT.CollectionPublicPath,
                    providerPath: FRC20SemiNFT.CollectionPrivatePath,
                    publicCollection: Type<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic}>(),
                    publicLinkedType: Type<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                    providerLinkedType: Type<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                    createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                        return <-FRC20SemiNFT.createEmptyCollection()
                    })
                )
            case Type<MetadataViews.NFTCollectionDisplay>():
                let bannerMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://i.imgur.com/Wdy3GG7.jpg"
                    ),
                    mediaType: "image/jpeg"
                )
                let squareMedia = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://i.imgur.com/hs3U5CY.png"
                    ),
                    mediaType: "image/png"
                )
                return MetadataViews.NFTCollectionDisplay(
                    name: "The Fixes 𝔉rc20 Semi-NFT Collection",
                    description: "This collection is used to wrap 𝔉rc20 token as semi-NFTs.",
                    externalURL: MetadataViews.ExternalURL("https://fixes.world/"),
                    squareImage: squareMedia,
                    bannerImage: bannerMedia,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/fixesOnFlow")
                    }
                )
        }
        return nil
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
    access(all)
    fun getViews(): [Type] {
        return [
            Type<MetadataViews.ExternalURL>(),
            Type<MetadataViews.NFTCollectionData>(),
            Type<MetadataViews.NFTCollectionDisplay>()
        ]
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        let identifier = "FRC20SemiNFT_".concat(self.account.address.toString())
        self.CollectionStoragePath = StoragePath(identifier: identifier.concat("collection"))!
        self.CollectionPublicPath = PublicPath(identifier: identifier.concat("collection"))!
        self.CollectionPrivatePath = PrivatePath(identifier: identifier.concat("collection"))!

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&FRC20SemiNFT.Collection{NonFungibleToken.CollectionPublic, FRC20SemiNFT.FRC20SemiNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
