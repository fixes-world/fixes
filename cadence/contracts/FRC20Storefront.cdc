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
    pub event StorefrontDestroyed(uuid: UInt64)

    // TODO - Add event detail
        // seller: Address,
        // listingUUID: UInt64,
        // saleTick: String,
        // saleAmount: UFix64,
        // salePrice: UFix64,
        // customID: String?,
        // commissionAmount: UFix64,
        // commissionReceivers: [Address]?,
        // expiry: UInt64
    pub event ListingAvailable()
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

    pub enum SaleCutType: UInt8 {
        pub case Consumer
        pub case TokenTreasury
        pub case PlatformTreasury
    }

    pub enum ListingStatus: UInt8 {
        pub case Available
        pub case Purchased
        pub case Cancelled
    }

    pub struct SaleCut {
        access(all)
        let type: SaleCutType
        access(all)
        let receiver: Capability<&{FungibleToken.Receiver}>?
        access(all)
        let amount: UFix64

        init(type: SaleCutType, amount: UFix64, receiver: Capability<&{FungibleToken.Receiver}>?) {
            if type == SaleCutType.Consumer {
                assert(receiver != nil, message: "Receiver should not be nil for consumer cut")
            } else {
                assert(receiver == nil, message: "Receiver should be nil for non-consumer cut")
            }
            self.type = type
            self.amount = amount
            self.receiver = receiver
        }
    }

    /// ListingDetails
    /// A struct containing a Listing's data.
    ///
    pub struct ListingDetails {
        // constants
        access(all)
        let storefrontId: UInt64
        access(all)
        let saleTick: String
        access(all)
        let saleAmount: UFix64
        // Currently, we only support $FLOW as a payment vault.
        access(all)
        let salePaymentVaultType: Type
        // Sale price is the sum of the commission amount and the sale amount.
        access(all)
        let salePrice: UFix64
        /// Commission available to be claimed by whoever facilitates the sale.
        access(all)
        let commissionAmount: UFix64
        /// Sale cuts
        access(all)
        let saleCuts: [SaleCut]
        /// Expiry of listing
        access(all)
        let expiry: UInt64
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
            saleTick: String,
            saleAmount: UFix64,
            salePaymentVaultType: Type,
            saleCuts: [SaleCut],
            customID: String?,
            commissionAmount: UFix64,
            expiry: UInt64
        ) {
            pre {
                // Validate the expiry
                expiry > UInt64(getCurrentBlock().timestamp) : "Expiry should be in the future"
                // Validate the length of the sale cut
                saleCuts.length > 0: "Listing must have at least one payment cut recipient"
            }

            self.storefrontId = storefrontId
            self.saleTick = saleTick
            self.saleAmount = saleAmount
            self.salePaymentVaultType = salePaymentVaultType
            self.commissionAmount = commissionAmount
            self.expiry = expiry

            self.saleCuts = saleCuts
            self.customID = customID
            self.status = ListingStatus.Available

            // Calculate the total price from the cuts
            var salePrice = commissionAmount
            // Perform initial check on capabilities, and calculate sale price from cut amounts.
            for cut in self.saleCuts {
                // Make sure we can borrow the receiver.
                // We will check this again when the token is sold.
                if cut.type == SaleCutType.Consumer {
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

        access(all)
        fun isPurchased(): Bool {
            return self.status == ListingStatus.Purchased
        }

        access(all)
        fun isExpired(): Bool {
            return self.expiry < UInt64(getCurrentBlock().timestamp)
        }

        /// Irreversibly set this listing as purchased.
        ///
        access(contract) fun setToPurchased() {
            pre {
                self.status == ListingStatus.Available: "Listing must be available"
            }
            self.status = ListingStatus.Purchased
        }

        /// Irreversibly set this listing as cancelled.
        ///
        access(contract) fun setToCancelled() {
            pre {
                self.status == ListingStatus.Available: "Listing must be available"
            }
            self.status = ListingStatus.Cancelled
        }

        access(contract) fun setCustomID(customID: String?){
            self.customID = customID
        }
    }

    /// ListingPublic
    /// An interface providing a useful public interface to a Listing.
    ///
    pub resource interface ListingPublic {
        /// The listing frc20 token name
        ///
        pub fun getTickName(): String

        /// borrow the listing token Meta for the selling FRC20 token
        ///
        pub fun getTickMeta(): FRC20Indexer.FRC20Meta

        /// The frc20 token amount of the listing.
        ///
        pub fun frozenTickBalance(): UFix64

        /// getDetails
        /// Fetches the details of the listing.
        pub fun getDetails(): ListingDetails

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        pub fun purchase(
            payment: @FungibleToken.Vault,
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @FRC20FTShared.Change

        /// getAllowedCommissionReceivers
        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        ///
        pub fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?
    }


    /// Listing
    /// A resource that allows an NFT to be sold for an amount of a given FungibleToken,
    /// and for the proceeds of that sale to be split between several recipients.
    ///
    pub resource Listing: ListingPublic {
        /// The simple (non-Capability, non-complex) details of the sale
        access(self) let details: ListingDetails
        /// The frozen change for this listing.
        access(contract) let frozenChange: @FRC20FTShared.Change
        /// An optional list of marketplaces capabilities that are approved
        /// to receive the marketplace commission.
        access(contract) let marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?

        /// initializer
        ///
        init (
            storefrontId: UInt64,
            frc20Change: @FRC20FTShared.Change,
            saleCuts: [SaleCut],
            commissionAmount: UFix64,
            expiry: UInt64,
            customID: String?,
            marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
        ) {
            // Store the change first
            self.frozenChange <- frc20Change
            // Store the marketplaces capability
            self.marketplacesCapability = marketplacesCapability
            // Store the sale information
            self.details = ListingDetails(
                storefrontId: storefrontId,
                saleTick: self.frozenChange.tick,
                saleAmount: self.frozenChange.getBalance(),
                salePaymentVaultType: Type<@FlowToken.Vault>(), // Currently, we only support $FLOW as a payment vault.
                saleCuts: saleCuts,
                customID: customID,
                commissionAmount: commissionAmount,
                expiry: expiry
            )
        }

        /// destructor
        ///
        destroy () {
            pre {
                self.details.status == ListingStatus.Purchased || self.details.status == ListingStatus.Cancelled:
                    "Listing must be purchased or cancelled"
            }
            destroy self.frozenChange
        }

        // ListingPublic interface implementation

        /// The listing frc20 token name
        ///
        pub fun getTickName(): String {
            return self.frozenChange.tick
        }

        /// borrow the Token Meta for the selling FRC20 token
        ///
        pub fun getTickMeta(): FRC20Indexer.FRC20Meta {
            let indexer = FRC20Indexer.getIndexer()
            return indexer.getTokenMeta(tick: self.details.saleTick)
                ?? panic("Unable to fetch the token meta")
        }

        /// The frc20 token amount of the listing.
        ///
        pub fun frozenTickBalance(): UFix64 {
            return self.frozenChange.getBalance()
        }

        /// getDetails
        /// Get the details of listing.
        ///
        pub fun getDetails(): ListingDetails {
            return self.details
        }

        /// getAllowedCommissionReceivers
        /// Fetches the allowed marketplaces capabilities or commission receivers.
        /// If it returns `nil` then commission is up to grab by anyone.
        pub fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]? {
            return self.marketplacesCapability
        }

        /// purchase
        /// Purchase the listing, buying the token.
        /// This pays the beneficiaries and returns the token to the buyer.
        ///
        pub fun purchase(
            payment: @FungibleToken.Vault,
            commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
        ): @FRC20FTShared.Change {
            pre {
                self.details.status == ListingStatus.Available: "Listing must be available"
                payment.isInstance(self.details.salePaymentVaultType): "payment vault is not requested fungible token"
                payment.balance == self.details.salePrice: "payment vault does not contain requested price"
                self.details.expiry > UInt64(getCurrentBlock().timestamp): "Listing is expired"
                self.owner != nil : "Resource doesn't have the assigned owner"
            }
            // Make sure the listing cannot be purchased again.
            self.details.setToPurchased()

            // Pay the commission
            if self.details.commissionAmount > 0.0 {
                // If commission recipient is nil, Throw panic.
                let commissionReceiver = commissionRecipient ?? panic("Commission recipient can't be nil")
                if self.marketplacesCapability != nil {
                    var isCommissionRecipientHasValidType = false
                    var isCommissionRecipientAuthorised = false
                    for cap in self.marketplacesCapability! {
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
                let commissionPayment <- payment.withdraw(amount: self.details.commissionAmount)
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
                if cut.type == SaleCutType.Consumer {
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
                }
            }

            assert(residualReceiver != nil, message: "No valid payment receivers")

            // At this point, if all receivers were active and available, then the payment Vault will have
            // zero tokens left, and this will functionally be a no-op that consumes the empty vault
            residualReceiver!.deposit(from: <-payment)

            // If the listing is purchased, we regard it as completed here.
            // Otherwise we regard it as completed in the destructor.

            emit ListingCompleted(
                listingResourceID: self.uuid,
                storefrontResourceID: self.details.storefrontID,
                purchased: self.details.purchased,
                nftType: self.details.nftType,
                nftUUID: self.details.nftUUID,
                nftID: self.details.nftID,
                salePaymentVaultType: self.details.salePaymentVaultType,
                salePrice: self.details.salePrice,
                customID: self.details.customID,
                commissionAmount: self.details.commissionAmount,
                commissionReceiver: self.details.commissionAmount != 0.0 ? commissionRecipient!.address : nil,
                expiry: self.details.expiry
            )

            return <-nft
        }

        /* ---- Internal methods ---- */

        /// Borrow the change for this listing.
        ///
        access(self)
        fun borrowChange(): &FRC20FTShared.Change {
            return &self.frozenChange as &FRC20FTShared.Change
        }
    }

    // TODO

    init() {
        let identifier = "FRC20Storefront_".concat(self.account.address.toString())
        self.StorefrontStoragePath = StoragePath(identifier: identifier)!
        self.StorefrontPublicPath = PublicPath(identifier: identifier)!
    }
}
