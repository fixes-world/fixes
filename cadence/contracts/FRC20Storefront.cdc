// Third-party imports
import "FungibleToken"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20FTShared"
import "FRC20Indexer"

pub contract FRC20Storefront {

    /* --- Events --- */

    pub event StorefrontInitialized(uuid: UInt64)

    pub event ListingAvailable(
        storefrontAddress: Address,
        listingResourceID: UInt64,
        tick: String,
        type: UInt8,
        paymentVaultType: Type,
        price: UFix64,
        customID: String?,
        commissionReceivers: [Address]?,
    )
    pub event ListingCompleted()
    pub event ListingCancelled()

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
        pub case Purchased
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
        // constants
        access(all)
        let storefrontId: UInt64
        access(all)
        let type: ListingType
        access(all)
        let tick: String
        access(all)
        let amount: UFix64
        // Currently, we only support $FLOW as a payment vault.
        access(all)
        let paymentVaultType: Type
        access(all)
        let salePrice: UFix64
        /// Sale cuts
        access(all)
        let saleCuts: [FRC20FTShared.SaleCut]
        /// Expiry of listing
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
            type: ListingType,
            tick: String,
            amount: UFix64,
            paymentVaultType: Type,
            saleCuts: [FRC20FTShared.SaleCut],
            customID: String?
        ) {
            pre {
                // Validate the length of the sale cut
                saleCuts.length > 0: "Listing must have at least one payment cut recipient"
            }

            self.storefrontId = storefrontId
            self.type = type
            self.tick = tick
            self.amount = amount
            self.paymentVaultType = paymentVaultType
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
            self.salePrice = salePrice
        }

        /// Return if the listing is purchased.
        ///
        access(all)
        fun isPurchased(): Bool {
            return self.status == ListingStatus.Purchased
        }

        /// Return if the listing is cancelled.
        ///
        access(all)
        fun isCancelled(): Bool {
            return self.status == ListingStatus.Cancelled
        }

        /// Irreversibly set this listing as purchased.
        ///
        access(contract)
        fun setToPurchased() {
            pre {
                self.status == ListingStatus.Available: "Listing must be available"
            }
            self.status = ListingStatus.Purchased
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

        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        access(all) view
        fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?

        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        access(all)
        fun takeBuyNow(
            payment: @FungibleToken.Vault,
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @FRC20FTShared.Change

        /// Purchase the listing, selling the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        access(all)
        fun takeSellNow(
            change: @FRC20FTShared.Change,
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @FRC20FTShared.Change

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
        /// The inscriptions reference
        access(contract)
        let inscriptionId: UInt64
        /// The frozen change for this listing.
        access(contract)
        let frozenChange: @FRC20FTShared.Change
        /// An optional list of marketplaces capabilities that are approved
        /// to receive the marketplace commission.
        access(contract)
        let commissionRecipientCaps: [Capability<&{FungibleToken.Receiver}>]?

        /// initializer
        ///
        init (
            storefrontId: UInt64,
            listIns: &Fixes.Inscription,
            commissionRecipientCaps: [Capability<&{FungibleToken.Receiver}>]?,
            customID: String?
        ) {
            // set the inscription id
            self.inscriptionId = listIns.getId()
            // Store the commission recipients capability
            self.commissionRecipientCaps = commissionRecipientCaps

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
                type: listType,
                tick: order?.tick ?? panic("Unable to fetch the tick"),
                amount: order?.amount ?? panic("Unable to fetch the amount"),
                paymentVaultType: Type<@FungibleToken.Vault>(), // Currently, we only support $FLOW as a payment vault.
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
                self.details.status == ListingStatus.Purchased || self.details.status == ListingStatus.Cancelled:
                    "Listing must be purchased or cancelled"
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
            return self.frozenChange.tick
        }

        /// borrow the Token Meta for the selling FRC20 token
        ///
        access(all) view
        fun getTickMeta(): FRC20Indexer.FRC20Meta {
            let indexer = FRC20Indexer.getIndexer()
            return indexer.getTokenMeta(tick: self.details.tick)
                ?? panic("Unable to fetch the token meta")
        }

        /// getDetails
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
        fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]? {
            return self.commissionRecipientCaps
        }

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        access(all)
        fun takeBuyNow(
            payment: @FungibleToken.Vault,
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @FRC20FTShared.Change {
            pre {
                self.details.status == ListingStatus.Available: "Listing must be available"
                self.owner != nil : "Resource doesn't have the assigned owner"
                payment.isInstance(self.details.paymentVaultType): "payment vault is not requested fungible token"
                payment.balance == self.details.salePrice: "payment vault does not contain requested price"
            }

            // Make sure the listing cannot be purchased again.
            self.details.setToPurchased()

            // All the commission receivers that are eligible to receive the commission.
            let eligibleCommissionReceivers = self.commissionRecipientCaps
            // The function to pay the commission
            let payCommissionFunc = fun (commissionPayment: @FungibleToken.Vault) {
                // If commission recipient is nil, Throw panic.
                let commissionReceiver = commissionRecipient ?? panic("Commission recipient can't be nil")
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
                recipient.deposit(from: <- commissionPayment)
            }

            // Rather than aborting the transaction if any receiver is absent when we try to pay it,
            // we send the cut to the first valid receiver.
            // The first receiver should therefore either be the seller, or an agreed recipient for
            // any unpaid cuts.
            var residualReceiver: &{FungibleToken.Receiver}? = nil

            // Pay each beneficiary their amount of the payment.
            for cut in self.details.saleCuts {
                switch cut.type {
                case FRC20FTShared.SaleCutType.Consumer:
                    let reciverCap = cut.receiver ?? panic("Receiver capability should not be nil")
                    if let receiver = reciverCap.borrow() {
                        let paymentCut <- payment.withdraw(amount: cut.amount)
                        receiver.deposit(from: <-paymentCut)
                        if residualReceiver == nil {
                            residualReceiver = receiver
                        }
                    } else {
                        emit UnpaidReceiver(receiver: reciverCap.address, entitledSaleCut: cut.amount)
                    }
                // TODO
                default:
                    panic("Unsupported cut type")
                }
            }

            assert(residualReceiver != nil, message: "No valid payment receivers")

            // At this point, if all receivers were active and available, then the payment Vault will have
            // zero tokens left, and this will functionally be a no-op that consumes the empty vault
            residualReceiver!.deposit(from: <-payment)

            // TODO - add more details
            emit ListingCompleted()

            return <-nft
        }

        /// Purchase the listing, selling the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        access(all)
        fun takeSellNow(
            change: @FRC20FTShared.Change,
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @FRC20FTShared.Change {

        }

        /** ---- Account methods ---- */

        access(account)
        fun cancel(): @FRC20FTShared.Change {
            pre {
                self.details.status == ListingStatus.Available: "Listing must be available"
                self.owner != nil : "Resource doesn't have the assigned owner"
            }
            // TODO
        }

        /// borrow the inscription reference
        ///
        access(contract)
        fun borrowInspection(): &Fixes.Inscription {

        }

        /* ---- Internal methods ---- */

        access(self)
        fun borrowStorefront(): &Storefront{StorefrontPublic} {
            return FRC20Storefront.borrowStorefront(address: self.owner!.address)
                ?? panic("Storefront not found")
        }

        /// Borrow the change for this listing.
        ///
        access(self)
        fun borrowChange(): &FRC20FTShared.Change {
            return &self.frozenChange as &FRC20FTShared.Change
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
        pub fun createListing(
            ins: @Fixes.Inscription,
            commissionRecipientCaps: [Capability<&{FungibleToken.Receiver}>]?,
            customID: String?
        ): UInt64

        /// removeListing
        /// Allows the Storefront owner to remove any sale listing, accepted or not.
        ///
        pub fun removeListing(listingResourceID: UInt64)
    }

    /// StorefrontPublic
    /// An interface to allow listing and borrowing Listings, and purchasing items via Listings
    /// in a Storefront.
    ///
    pub resource interface StorefrontPublic {
        /** ---- Public Methods ---- */
        access(all)
        fun getListingIDs(): [UInt64]
        access(all)
        fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
        // Cleanup methods
        access(all)
        fun cleanupPurchasedListings(listingResourceID: UInt64)
        access(all)
        fun cleanupGhostListings(listingResourceID: UInt64)
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
        pub fun getListingIDs(): [UInt64] {
            return self.listings.keys
        }

        /// borrowSaleItem
        /// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
        ///
        pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}? {
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
         pub fun createListing(
            ins: @Fixes.Inscription,
            commissionRecipientCaps: [Capability<&{FungibleToken.Receiver}>]?,
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
                listingResourceID: listingResourceID,
                tick: details.tick,
                type: details.type.rawValue,
                paymentVaultType: details.paymentVaultType,
                price: details.salePrice,
                customID: customID,
                commissionReceivers: allowedCommissionReceivers
            )

            return listingResourceID
        }

        /// removeListing
        /// Remove a Listing that has not yet been purchased from the collection and destroy it.
        /// It can only be executed by the StorefrontManager resource owner.
        ///
        pub fun removeListing(listingResourceID: UInt64) {
            let listing <- self.listings.remove(key: listingResourceID)
                ?? panic("missing Listing")
            let listingDetails = listing.getDetails()

            // TODO: a lot of remove lising logic

            // This will emit a ListingCompleted event.
            destroy listing
        }

        /// cleanupPurchasedListings
        /// Allows anyone to remove already purchased listings.
        ///
        pub fun cleanupPurchasedListings(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "could not find listing with given id"
                self.borrowListing(listingResourceID: listingResourceID)!.getDetails().isPurchased() == true: "listing not purchased yet"
            }
            let listing <- self.listings.remove(key: listingResourceID)!
            let details = listing.getDetails()

            // TODO: a lot of remove lising logic

            destroy listing
        }

        /// cleanupGhostListings
        /// Allow anyone to cleanup ghost listings
        /// Listings will become ghost listings if stored provider capability doesn't hold
        /// the NFT anymore.
        ///
        /// @param listingResourceID ID of the listing resource which would get removed if it become ghost listing.
        pub fun cleanupGhostListings(listingResourceID: UInt64) {
            pre {
                self.listings[listingResourceID] != nil: "Could not find listing with given id"
            }
            let listingRef = self.borrowListing(listingResourceID: listingResourceID)!
            let details = listingRef.getDetails()
            assert(!details.isPurchased(), message: "Given listing is already purchased")
            // assert(!listingRef.hasListingBecomeGhosted(), message: "Listing is not ghost listing")
            let listing <- self.listings.remove(key: listingResourceID)!

            // TODO: a lot of remove lising logic

            destroy listing
        }

        /** ---- Internal Method ---- */

        /// borrow the inscription reference
        ///
        access(contract)
        fun borrowInspection(_ id: UInt64): &Fixes.Inscription {
            return &self.inscriptions[id] as &Fixes.Inscription? ?? panic("Inscription not found")
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
