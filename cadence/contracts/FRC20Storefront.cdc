// Third-party imports
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20FTShared"
import "FRC20Indexer"
import "FRC20AccountsPool"

pub contract FRC20Storefront {

    /* --- Events --- */

    pub event StorefrontInitialized(uuid: UInt64)

    pub event ListingAvailable(
        storefrontAddress: Address,
        storefrontId: UInt64,
        listingResourceID: UInt64,
        inscriptionId: UInt64,
        type: UInt8,
        tick: String,
        amount: UFix64,
        price: UFix64,
        customID: String?,
        commissionReceivers: [Address]?,
    )
    pub event ListingCompleted(
        storefrontId: UInt64,
        listingResourceID: UInt64,
        inscriptionId: UInt64,
        type: UInt8,
        tick: String,
        amount: UFix64,
        price: UFix64,
        customID: String?,
        commissionAmount: UFix64,
        commissionReceiver: Address?,
    )
    pub event ListingCancelled(
        storefrontId: UInt64,
        listingResourceID: UInt64,
        inscriptionId: UInt64,
        type: UInt8,
        tick: String,
        amount: UFix64,
        price: UFix64,
        customID: String?,
    )
    pub event ListingRemoved(
        storefrontId: UInt64,
        listingResourceID: UInt64,
        inscriptionId: UInt64,
        customID: String?,
        withStatus: UInt8,
    )

    /// UnpaidReceiver
    /// A entitled receiver has not been paid during the sale of the NFT.
    ///
    pub event UnpaidReceiver(receiver: Address, entitledSaleCut: UFix64)


    /* --- Variable, Enums and Structs --- */
    pub let StorefrontStoragePath: StoragePath
    pub let StorefrontPublicPath: PublicPath

    /* --- Interfaces & Resources --- */

    pub enum ListingStatus: UInt8 {
        pub case Available
        pub case Completed
        pub case Cancelled
    }

    pub enum ListingType: UInt8 {
        pub case FixedPriceBuyNow
        pub case FixedPriceSellNow
        pub case FixedPricePrivate
    }

    /// ListingDetails
    /// A struct containing a Listing's data.
    ///
    pub struct ListingDetails {
        // constants data values
        access(all)
        let storefrontId: UInt64
        access(all)
        let inscriptionId: UInt64
        access(all)
        let type: ListingType
        access(all)
        let tick: String
        access(all)
        let amount: UFix64
        /// Sale cuts
        access(all)
        let saleCuts: [FRC20FTShared.SaleCut]
        // Calculated values
        access(all)
        let price: UFix64
        access(all)
        let priceValuePerMint: UFix64
        /// Created time of the listing
        access(all)
        let createdAt: UInt64
        // variables
        /// Whether this listing has been purchased or not.
        access(all)
        var status: ListingStatus
        /// Allow different dapp teams to provide custom strings as the distinguished string
        /// that would help them to filter events related to their customID.
        access(all)
        var customID: String?

        /// Initializer
        ///
        init (
            storefrontId: UInt64,
            inscriptionId: UInt64,
            type: ListingType,
            tick: String,
            amount: UFix64,
            saleCuts: [FRC20FTShared.SaleCut],
            customID: String?
        ) {
            pre {
                // Validate the length of the sale cut
                saleCuts.length > 0: "Listing must have at least one payment cut recipient"
                amount > 0.0: "Listing must have non-zero amount"
            }
            let tokenMeta = FRC20Indexer.getIndexer().getTokenMeta(tick: tick)
                ?? panic("Unable to fetch the token meta")

            self.storefrontId = storefrontId
            self.inscriptionId = inscriptionId
            self.type = type
            self.tick = tick
            self.amount = amount
            self.createdAt = UInt64(getCurrentBlock().timestamp)

            self.saleCuts = saleCuts
            self.customID = customID
            self.status = ListingStatus.Available

            // Calculate the total price from the cuts
            var salePrice = 0.0
            // Perform initial check on capabilities, and calculate sale price from cut amounts.
            for cut in self.saleCuts {
                // Make sure we can borrow the receiver.
                // We will check this again when the token is sold.
                if cut.type == FRC20FTShared.SaleCutType.SellMaker {
                    cut.receiver?.borrow()
                        ?? panic("Cannot borrow receiver")
                }
                // Add the cut amount to the total price
                salePrice = salePrice + cut.amount
            }
            assert(salePrice > 0.0, message: "Listing must have non-zero price")

            // Store the calculated sale price
            self.price = salePrice
            // Store the calculated price value per mint
            self.priceValuePerMint = salePrice / amount * tokenMeta.limit
        }

        /// Get the price rank
        access(all)
        fun priceRank(): UInt64 {
            return UInt64(self.price * 100000.0)
        }

        /// Return if the listing is completed.
        ///
        access(all)
        fun isCompleted(): Bool {
            return self.status == ListingStatus.Completed
        }

        /// Return if the listing is cancelled.
        ///
        access(all)
        fun isCancelled(): Bool {
            return self.status == ListingStatus.Cancelled
        }

        /// Irreversibly set this listing as completed.
        ///
        access(contract)
        fun setToCompleted() {
            pre {
                self.status == ListingStatus.Available: "Listing must be available"
            }
            self.status = ListingStatus.Completed
        }

        /// Irreversibly set this listing as cancelled.
        ///
        access(contract)
        fun setToCancelled() {
            pre {
                self.status == ListingStatus.Available: "Listing must be available"
            }
            self.status = ListingStatus.Cancelled
        }

        /// Set the customID
        ///
        access(contract)
        fun setCustomID(customID: String?){
            self.customID = customID
        }
    }

    /// ListingPublic
    /// An interface providing a useful public interface to a Listing.
    ///
    pub resource interface ListingPublic {
        /** ---- Public Methods ---- */

        /// Get the address of the owner of the NFT that is being sold.
        access(all) view
        fun getOwnerAddress(): Address

        /// The listing frc20 token name
        access(all) view
        fun getTickName(): String

        /// Borrow the listing token Meta for the selling FRC20 token
        access(all) view
        fun getTickMeta(): FRC20Indexer.FRC20Meta

        /// Fetches the details of the listing.
        access(all) view
        fun getDetails(): ListingDetails

        /// Fetches the status
        access(all) view
        fun getStatus(): ListingStatus

        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        access(all) view
        fun getAllowedCommissionReceivers(): [Capability<&FlowToken.Vault{FungibleToken.Receiver}>]?

        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        access(all)
        fun takeBuyNow(
            ins: &Fixes.Inscription,
            commissionRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
        )

        /// Purchase the listing, selling the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        access(all)
        fun takeSellNow(
            ins: &Fixes.Inscription,
            paymentRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
            commissionRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
        )

        /** ---- Internal Methods ---- */

        /// borrow the inscription reference
        access(contract)
        fun borrowInspection(): &Fixes.Inscription
    }


    /// Listing
    /// A resource that allows an NFT to be sold for an amount of a given FungibleToken,
    /// and for the proceeds of that sale to be split between several recipients.
    ///
    pub resource Listing: ListingPublic {
        /// The simple (non-Capability, non-complex) details of the sale
        access(self)
        let details: ListingDetails
        /// An optional list of marketplaces capabilities that are approved
        /// to receive the marketplace commission.
        access(contract)
        let commissionRecipientCaps: [Capability<&FlowToken.Vault{FungibleToken.Receiver}>]?
        /// The frozen change for this listing.
        access(contract)
        var frozenChange: @FRC20FTShared.Change?

        /// initializer
        ///
        init (
            storefrontId: UInt64,
            listIns: &Fixes.Inscription,
            commissionRecipientCaps: [Capability<&FlowToken.Vault{FungibleToken.Receiver}>]?,
            customID: String?
        ) {
            // Store the commission recipients capability
            self.commissionRecipientCaps = commissionRecipientCaps
            // TODO: check the commission recipients address before storing them

            // Analyze the listing inscription and build the details
            let indexer = FRC20Indexer.getIndexer()
            // find the op first
            let meta = indexer.parseMetadata(&listIns.getData() as &Fixes.InscriptionData)
            let op = meta["op"] as! String

            var order: @FRC20FTShared.ValidFrozenOrder? <- nil
            var listType: ListingType = ListingType.FixedPriceBuyNow
            switch op {
            case "list-buynow":
                order <-! indexer.buildBuyNowListing(ins: listIns)
                assert(
                    order?.tick == order?.change?.tick && order?.amount == order?.change?.getBalance(),
                    message: "Tick and amount in the inscription and the change should be the same"
                )
                listType = ListingType.FixedPriceBuyNow
                break
            case "list-sellnow":
                order <-! indexer.buildSellNowListing(ins: listIns)
                listType = ListingType.FixedPriceSellNow
                break
            default:
                panic("Unsupported listing operation")
            }

            // Store the change
            self.frozenChange <- order?.extract() ?? panic("Unable to extract the change")
            // Store the list information
            self.details = ListingDetails(
                storefrontId: storefrontId,
                inscriptionId: listIns.getId(),
                type: listType,
                tick: order?.tick ?? panic("Unable to fetch the tick"),
                amount: order?.amount ?? panic("Unable to fetch the amount"),
                saleCuts: order?.cuts ?? panic("Unable to fetch the cuts"),
                customID: customID
            )
            // Destroy stored order
            destroy order
        }

        /// destructor
        ///
        destroy() {
            pre {
                self.details.status == ListingStatus.Completed || self.details.status == ListingStatus.Cancelled:
                    "Listing must be purchased or cancelled"
                self.frozenChange == nil: "Frozen change must be nil"
            }
            destroy self.frozenChange
        }

        // ListingPublic interface implementation

        /// getOwnerAddress
        /// Fetches the address of the owner of the NFT that is being sold.
        ///
        access(all) view
        fun getOwnerAddress(): Address {
            return self.owner?.address ?? panic("Get owner address failed")
        }

        /// The listing frc20 token name
        ///
        access(all) view
        fun getTickName(): String {
            return self.details.tick
        }

        /// borrow the Token Meta for the selling FRC20 token
        ///
        access(all) view
        fun getTickMeta(): FRC20Indexer.FRC20Meta {
            let indexer = FRC20Indexer.getIndexer()
            return indexer.getTokenMeta(tick: self.details.tick)
                ?? panic("Unable to fetch the token meta")
        }

        /// Fetches the status
        ///
        access(all) view
        fun getStatus(): ListingStatus {
            return self.details.status
        }

        /// Get the details of listing.
        ///
        access(all) view
        fun getDetails(): ListingDetails {
            return self.details
        }

        /// getAllowedCommissionReceivers
        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        access(all) view
        fun getAllowedCommissionReceivers(): [Capability<&FlowToken.Vault{FungibleToken.Receiver}>]? {
            return self.commissionRecipientCaps
        }

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        access(all)
        fun takeBuyNow(
            ins: &Fixes.Inscription,
            commissionRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
        ) {
            pre {
                self.details.type == ListingType.FixedPriceBuyNow: "Listing must be a buy now listing"
                self.details.status == ListingStatus.Available: "Listing must be available"
                self.owner != nil : "Resource doesn't have the assigned owner"
                ins.getInscriptionValue() >= self.details.price + ins.getMinCost(): "Insufficient payment value"
            }

            // Make sure the listing cannot be completed again.
            self.details.setToCompleted()

            // just check if the inscription is valid, the further check will be done in applyListedOrder
            assert(
                FRC20Storefront.isListFRC20Inscription(ins: ins),
                message: "Given inscription is not a valid FRC20 listing inscription"
            )

            // The indexer for all the FRC20 tokens.
            let frc20Indexer = FRC20Indexer.getIndexer()
            // The payment vault for the sale.
            let paymentChange <- frc20Indexer.extractFlowVaultChangeFromInscription(ins, amount: self.details.price)

            // Pay the sale cuts to the recipients.
            let commissionAmount = self._payToSaleCuts(
                paymentChange: <- paymentChange,
                commissionRecipient: commissionRecipient,
                paymentRecipient: nil,
            )

            // give the change to the buyer
            var frc20TokenChange: @FRC20FTShared.Change? <- nil
            frc20TokenChange <-> self.frozenChange

            assert(
                frc20TokenChange != nil && frc20TokenChange?.isBackedByVault() == false,
                message: "Frozen change should be backed by a non-vault change"
            )

            // apply the change and both inscriptions in frc20 indexer
            frc20Indexer.applyBuyNowOrder(
                makerIns: self.borrowInspection(),
                takerIns: ins,
                change: <- (frc20TokenChange ?? panic("Unable to extract the change")),
            )

            // TODO: Record the transction record

            // emit ListingCompleted event
            emit ListingCompleted(
                storefrontId: self.details.storefrontId,
                listingResourceID: self.uuid,
                inscriptionId: self.details.inscriptionId,
                type: self.details.type.rawValue,
                tick: self.details.tick,
                amount: self.details.amount,
                price: self.details.price,
                customID: self.details.customID,
                commissionAmount: commissionAmount,
                commissionReceiver: commissionAmount != 0.0 ? commissionRecipient!.address : nil,
            )
        }

        /// Purchase the listing, selling the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        access(all)
        fun takeSellNow(
            ins: &Fixes.Inscription,
            paymentRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
            commissionRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
        ) {
            pre {
                self.details.type == ListingType.FixedPriceSellNow: "Listing must be a buy now listing"
                self.details.status == ListingStatus.Available: "Listing must be available"
                self.owner != nil : "Resource doesn't have the assigned owner"
                ins.getInscriptionValue() >= self.details.price + ins.getMinCost(): "Insufficient payment value"
            }

            // Make sure the listing cannot be completed again.
            self.details.setToCompleted()

            // just check if the inscription is valid, the further check will be done in applyListedOrder
            assert(
                FRC20Storefront.isListFRC20Inscription(ins: ins),
                message: "Given inscription is not a valid FRC20 listing inscription"
            )

            // The indexer for all the FRC20 tokens.
            let frc20Indexer = FRC20Indexer.getIndexer()

            // give the change to the buyer
            var flowTokenChange: @FRC20FTShared.Change? <- nil
            flowTokenChange <-> self.frozenChange

            assert(
                flowTokenChange != nil && flowTokenChange?.isBackedByFlowTokenVault() == true,
                message: "Frozen change should be backed by a vault change"
            )

            // Pay the sale cuts to the recipients.
            let commissionAmount = self._payToSaleCuts(
                paymentChange: <- (flowTokenChange ?? panic("Change is nil")),
                commissionRecipient: commissionRecipient,
                paymentRecipient: paymentRecipient,
            )

            frc20Indexer.applySellNowOrder(
                makerIns: self.borrowInspection(),
                takerIns: ins
            )

            // TODO: Record the transction record

            // emit ListingCompleted event
            emit ListingCompleted(
                storefrontId: self.details.storefrontId,
                listingResourceID: self.uuid,
                inscriptionId: self.details.inscriptionId,
                type: self.details.type.rawValue,
                tick: self.details.tick,
                amount: self.details.amount,
                price: self.details.price,
                customID: self.details.customID,
                commissionAmount: commissionAmount,
                commissionReceiver: commissionAmount != 0.0 ? commissionRecipient!.address : nil,
            )
        }

        /** ---- Account or contract methods ---- */

        access(contract)
        fun cancel() {
            pre {
                self.details.status == ListingStatus.Available: "Listing must be available"
                self.owner != nil : "Resource doesn't have the assigned owner"
            }

            self.details.setToCancelled()

            // The indexer for all the FRC20 tokens.
            let frc20Indexer = FRC20Indexer.getIndexer()

            var changeToReturn: @FRC20FTShared.Change? <- nil
            changeToReturn <-> self.frozenChange

            assert(
                changeToReturn != nil,
                message: "Frozen change should not be nil"
            )

            // apply the change and rollback inscriptions in frc20 indexer
            frc20Indexer.cancelListing(
                listedIns: self.borrowInspection(),
                change: <- (changeToReturn ?? panic("Unable to extract the change"))
            )

            emit ListingCancelled(
                storefrontId: self.details.storefrontId,
                listingResourceID: self.uuid,
                inscriptionId: self.details.inscriptionId,
                type: self.details.type.rawValue,
                tick: self.details.tick,
                amount: self.details.amount,
                price: self.details.price,
                customID: self.details.customID,
            )
        }

        /// borrow the inscription reference
        ///
        access(contract)
        fun borrowInspection(): &Fixes.Inscription {
            return self._borrowStorefront().borrowInspection(self.details.inscriptionId)
        }

        /* ---- Internal methods ---- */

        /// Pay the sale cuts to the recipients.
        /// Returns the amount of commission paid.
        ///
        access(self)
        fun _payToSaleCuts(
            paymentChange: @FRC20FTShared.Change,
            commissionRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
            paymentRecipient: Capability<&FlowToken.Vault{FungibleToken.Receiver}>?,
        ): UFix64 {
            // Some singleton resources
            let frc20Indexer = FRC20Indexer.getIndexer()
            let acctsPool = FRC20AccountsPool.borrowAccountsPool()
            let sharedStore = FRC20FTShared.borrowStoreRef()

            // some constants
            let stakingFRC20Tick = (sharedStore.get("marketplaceStakingFRC20Tick") as! String?) ?? "flows"

            // Token treasuries
            let tokenTreasury = frc20Indexer.borrowTokenTreasuryReceiver(tick: self.details.tick)
            let platformTreasury = frc20Indexer.borowPlatformTreasuryReceiver()

            // The function to pay to marketplace staking pool
            let payToMarketplaceStakingPool = fun (_ payment: @FungibleToken.Vault) {
                if let flowVault = acctsPool.borrowFRC20StakingFlowTokenReceiver(tick: stakingFRC20Tick) {
                    flowVault.deposit(from: <- payment)
                } else {
                    // if the staking pool doesn't exist, pay to token treasury
                    tokenTreasury.deposit(from: <- payment)
                }
            }

            // The function to pay to marketplace campaign pool
            let payToMarketplaceCampaignPool = fun (_ payment: @FungibleToken.Vault) {
                if let flowVault = acctsPool.borrowMarketSharedFlowTokenReceiver() {
                    flowVault.deposit(from: <- payment)
                } else {
                    // if the campaign pool doesn't exist, pay to token treasury
                    tokenTreasury.deposit(from: <- payment)
                }
            }

            // All the commission receivers that are eligible to receive the commission.
            let eligibleCommissionReceivers = self.commissionRecipientCaps
            // The function to pay the commission
            let payCommissionFunc = fun (payment: @FungibleToken.Vault) {
                // If commission recipient is nil, Throw panic.
                if let commissionReceiver = commissionRecipient {
                    if eligibleCommissionReceivers != nil {
                        var isCommissionRecipientHasValidType = false
                        var isCommissionRecipientAuthorised = false
                        for cap in eligibleCommissionReceivers! {
                            // Check 1: Should have the same type
                            if cap.getType() == commissionReceiver.getType() {
                                isCommissionRecipientHasValidType = true
                                // Check 2: Should have the valid market address that holds approved capability.
                                if cap.address == commissionReceiver.address && cap.check() {
                                    isCommissionRecipientAuthorised = true
                                    break
                                }
                            }
                        }
                        assert(isCommissionRecipientHasValidType, message: "Given recipient does not has valid type")
                        assert(isCommissionRecipientAuthorised,   message: "Given recipient is not authorised to receive the commission")
                    }
                    let recipient = commissionReceiver.borrow() ?? panic("Unable to borrow the recipient capability")
                    recipient.deposit(from: <- payment)
                } else {
                    payToMarketplaceCampaignPool(<- payment)
                }
            }

            // Rather than aborting the transaction if any receiver is absent when we try to pay it,
            // we send the cut to the token or platform treasury, and emit an event to let the
            // receiver know that they have unclaimed funds.
            var residualReceiver: &FlowToken.Vault{FungibleToken.Receiver}? = nil

            // The commission amount
            var commissionAmount = 0.0

            // Pay each beneficiary their amount of the payment.
            for cut in self.details.saleCuts {
                switch cut.type {
                case FRC20FTShared.SaleCutType.TokenTreasury:
                    tokenTreasury.deposit(from: <- paymentChange.withdrawAsVault(amount: cut.amount))
                    // If the residual receiver is not set, set it to the token treasury.
                    if residualReceiver == nil {
                        residualReceiver = tokenTreasury
                    }
                    break
                case FRC20FTShared.SaleCutType.PlatformTreasury:
                    platformTreasury.deposit(from: <- paymentChange.withdrawAsVault(amount: cut.amount))
                    // If the residual receiver is not set, set it to the token treasury.
                    if residualReceiver == nil {
                        residualReceiver = platformTreasury
                    }
                    break
                case FRC20FTShared.SaleCutType.MarketplaceStakers:
                    payToMarketplaceStakingPool(<- paymentChange.withdrawAsVault(amount: cut.amount))
                    break
                case FRC20FTShared.SaleCutType.MarketplaceCampaign:
                    payToMarketplaceCampaignPool(<- paymentChange.withdrawAsVault(amount: cut.amount))
                    break
                case FRC20FTShared.SaleCutType.Commission:
                    commissionAmount = cut.amount
                    payCommissionFunc(<- paymentChange.withdrawAsVault(amount: cut.amount))
                    break
                case FRC20FTShared.SaleCutType.SellMaker:
                    let receiverCap = cut.receiver ?? panic("Receiver capability should not be nil")
                    if let receiver = receiverCap.borrow() {
                        receiver.deposit(from: <- paymentChange.withdrawAsVault(amount: cut.amount))
                    } else {
                        emit UnpaidReceiver(receiver: receiverCap.address, entitledSaleCut: cut.amount)
                    }
                    break
                case FRC20FTShared.SaleCutType.BuyTaker:
                    let receiver = paymentRecipient?.borrow() ?? panic("Payment recipient should not be nil")
                    assert(
                        receiver != nil,
                        message: "Payment recipient capability is not valid"
                    )
                    receiver!.deposit(from: <- paymentChange.withdrawAsVault(amount: cut.amount))
                default:
                    panic("Unsupported cut type")
                }
            }

            assert(residualReceiver != nil, message: "No valid payment receivers")

            // At this point, if all receivers were active and available, then the payment Vault will have
            // zero tokens left, and this will functionally be a no-op that consumes the empty vault
            residualReceiver!.deposit(from: <- paymentChange.extractAsVault())
            // destory the payment change
            destroy paymentChange

            // Return the commission amount
            return commissionAmount
        }

        /// Borrow the storefront resource.
        ///
        access(self)
        fun _borrowStorefront(): &Storefront{StorefrontPublic} {
            return FRC20Storefront.borrowStorefront(address: self.owner!.address)
                ?? panic("Storefront not found")
        }
    }



    /// StorefrontManager
    /// An interface for adding and removing Listings within a Storefront,
    /// intended for use by the Storefront's owner
    ///
    pub resource interface StorefrontManager {
        /// createListing
        /// Allows the Storefront owner to create and insert Listings.
        ///
        access(all)
        fun createListing(
            ins: @Fixes.Inscription,
            commissionRecipientCaps: [Capability<&FlowToken.Vault{FungibleToken.Receiver}>]?,
            customID: String?
        ): UInt64

        /// Allows the Storefront owner to remove any sale listing, accepted or not.
        ///
        access(all)
        fun removeListing(listingResourceID: UInt64): @Fixes.Inscription
    }

    /// StorefrontPublic
    /// An interface to allow listing and borrowing Listings, and purchasing items via Listings
    /// in a Storefront.
    ///
    pub resource interface StorefrontPublic {
        /** ---- Public Methods ---- */
        /// get all listingIDs
        access(all)
        fun getListingIDs(): [UInt64]
        // Borrow the listing reference
        access(all)
        fun borrowListing(_ listingResourceID: UInt64): &Listing{ListingPublic}?
        // Cleanup methods
        access(all)
        fun cleanupFinishedListings(_ listingResourceID: UInt64)
        /** ---- Contract Methods ---- */
        /// borrow the inscription reference
        access(contract)
        fun borrowInspection(_ id: UInt64): &Fixes.Inscription
   }

    /// Storefront
    /// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
    /// in order to query their details and purchase the NFTs that they represent.
    ///
    pub resource Storefront : StorefrontManager, StorefrontPublic {
        /// The dictionary of stored inscriptions.
        access(contract)
        var inscriptions: @{UInt64: Fixes.Inscription}
        /// The dictionary of Listing uuids to Listing resources.
        access(contract)
        var listings: @{UInt64: Listing}
        /// Dictionary to keep track of listing ids for listing.
        /// tick -> [listing resource ID]
        access(contract)
        var listedTicks: {String: [UInt64]}

        /// destructor
        ///
        destroy() {
            destroy self.inscriptions
            destroy self.listings
        }

        /// constructor
        ///
        init () {
            self.listings <- {}
            self.inscriptions <- {}
            self.listedTicks = {}

            // Let event consumers know that this storefront exists
            emit StorefrontInitialized(uuid: self.uuid)
        }

        /** ---- Public Methods ---- */

        /// getListingIDs
        /// Returns an array of the Listing resource IDs that are in the collection
        ///
        access(all)
        fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        /// borrowSaleItem
        /// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        ///
        access(all)
        fun borrowListing(_ listingResourceID: UInt64): &Listing{ListingPublic}? {
             if self.listings[listingResourceID] != nil {
                return &self.listings[listingResourceID] as &Listing{ListingPublic}?
            } else {
                return nil
            }
        }

        /** ---- Private Methods ---- */

        /// insert
        /// Create and publish a Listing for an NFT.
        ///
        access(all)
        fun createListing(
            ins: @Fixes.Inscription,
            commissionRecipientCaps: [Capability<&FlowToken.Vault{FungibleToken.Receiver}>]?,
            customID: String?
         ): UInt64 {
            pre {
                self.owner != nil : "Resource doesn't have the assigned owner"
            }

            let insRef = &ins as &Fixes.Inscription
            assert(
                FRC20Storefront.isListFRC20Inscription(ins: insRef),
                message: "Given inscription is not a valid FRC20 listing inscription"
            )

            // store the inscription to local
            let uuid = insRef.uuid
            let nothing <- self.inscriptions[ins.uuid] <- ins
            destroy nothing

            // Instead of letting an arbitrary value be set for the UUID of a given NFT, the contract
            // should fetch it itself
            let listing <- create Listing(
                storefrontId: self.uuid,
                listIns: insRef,
                commissionRecipientCaps: commissionRecipientCaps,
                customID: customID
            )

            let listingResourceID = listing.uuid
            let details = listing.getDetails()
            // Add the new listing to the dictionary.
            let oldListing <- self.listings[listingResourceID] <- listing
            // Note that oldListing will always be nil, but we have to handle it.

            destroy oldListing

            // Scraping addresses from the capabilities to emit in the event.
            var allowedCommissionReceivers : [Address]? = nil
            if let allowedReceivers = commissionRecipientCaps {
                // Small hack here to make `allowedCommissionReceivers` variable compatible to
                // array properties.
                allowedCommissionReceivers = []
                for receiver in allowedReceivers {
                    allowedCommissionReceivers!.append(receiver.address)
                }
            }

            emit ListingAvailable(
                storefrontAddress: self.owner?.address ?? panic("Storefront owner is not set"),
                storefrontId: self.uuid,
                listingResourceID: listingResourceID,
                inscriptionId: details.inscriptionId,
                type: details.type.rawValue,
                tick: details.tick,
                amount: details.amount,
                price: details.price,
                customID: customID,
                commissionReceivers: allowedCommissionReceivers
            )

            return listingResourceID
        }

        /// Remove a Listing that has not yet been purchased from the collection and destroy it.
        /// It can only be executed by the StorefrontManager resource owner.
        ///
        access(all)
        fun removeListing(listingResourceID: UInt64): @Fixes.Inscription {
            let listingRef = self.borrowListingPrivate(listingResourceID)

            let currentStatus: FRC20Storefront.ListingStatus = listingRef.getStatus()
            // If the listing is already completed, then we don't need to do anything.
            if currentStatus == ListingStatus.Available {
                listingRef.cancel()
            } else if currentStatus == ListingStatus.Cancelled {
                // If the listing is already cancelled, then we don't need to do anything.
            } else if currentStatus == ListingStatus.Completed {
                // If the listing is already completed, then we don't need to do anything.
            }

            // ensure the change in listing is nil
            assert(
                listingRef.frozenChange == nil,
                message: "Listing change should be nil"
            )

            let listing <- self.listings.remove(key: listingResourceID)
                ?? panic("missing Listing")
            let details = listing.getDetails()

            emit ListingRemoved(
                storefrontId: self.uuid,
                listingResourceID: listingResourceID,
                inscriptionId: details.inscriptionId,
                customID: details.customID,
                withStatus: currentStatus.rawValue
            )

            destroy listing

            // return the inscription
            return <- self.inscriptions.remove(key: details.inscriptionId)!
        }

        /// Allows anyone to remove already completed listings.
        ///
        access(all)
        fun cleanupFinishedListings(_ listingResourceID: UInt64) {
            let listingRef = self.borrowListing(listingResourceID)
                ?? panic("Could not find listing with given id")
            let details = listingRef.getDetails()

            assert(
                details.isCompleted() || details.isCancelled(),
                message: "Given listing is not completed or cancelled"
            )

            let listing <- self.listings.remove(key: listingResourceID)!

            emit ListingRemoved(
                storefrontId: self.uuid,
                listingResourceID: listingResourceID,
                inscriptionId: details.inscriptionId,
                customID: details.customID,
                withStatus: details.status.rawValue
            )
            // destroy listing
            destroy listing
            // destory the inscription
            let ins <- self.inscriptions.remove(key: details.inscriptionId)
            destroy ins
        }

        /** ---- Internal Method ---- */

        /// borrow the inscription reference
        ///
        access(contract)
        fun borrowInspection(_ id: UInt64): &Fixes.Inscription {
            return &self.inscriptions[id] as &Fixes.Inscription? ?? panic("Inscription not found")
        }

        /// borrow the listing reference
        ///
        access(contract)
        fun borrowListingPrivate(_ id: UInt64): &Listing {
            return &self.listings[id] as &Listing? ?? panic("Listing not found")
        }
    }

    /* --- Public Resource Interfaces --- */

    /// Check if the given inscription is a valid FRC20 listing inscription.
    ///
    access(all)
    fun isListFRC20Inscription(ins: &Fixes.Inscription): Bool {
        let indexer = FRC20Indexer.getIndexer()
        if !indexer.isValidFRC20Inscription(ins: ins) {
            return false
        }
        let meta = indexer.parseMetadata(&ins.getData() as &Fixes.InscriptionData)
        let op = meta["op"]
        if op == nil || op!.slice(from: 0, upTo: 5) != "list-" {
            return false
        }
        return true
    }

    /// createStorefront
    /// Make creating a Storefront publicly accessible.
    ///
    access(all)
    fun createStorefront(): @Storefront {
        return <-create Storefront()
    }

    /// Borrow a Storefront from an account.
    ///
    access(all)
    fun borrowStorefront(address: Address): &Storefront{StorefrontPublic}? {
        return getAccount(address)
            .getCapability<&Storefront{StorefrontPublic}>(self.StorefrontPublicPath)
            .borrow()
    }

    init() {
        let identifier = "FRC20Storefront_".concat(self.account.address.toString())
        self.StorefrontStoragePath = StoragePath(identifier: identifier)!
        self.StorefrontPublicPath = PublicPath(identifier: identifier)!
    }
}
