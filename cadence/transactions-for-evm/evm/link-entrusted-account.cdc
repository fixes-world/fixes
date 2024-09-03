import "HybridCustody"
import "CapabilityFactory"
import "CapabilityFilter"
import "CapabilityDelegator"
import "MetadataViews"
import "ViewResolver"
// Import the Fixes contract
import "EVMAgent"

transaction(
    factoryAddress: Address,
    filterAddress: Address,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    prepare(
        _appSigner: &Account,
        userAcct: auth(Storage, Capabilities, Inbox) &Account
    ) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "link-entrusted-account(Address|Address)",
            params: [factoryAddress.toString(), filterAddress.toString()],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */

        // ---------- Publish the account to the parent ----------
        let owned = acct.storage
            .borrow<auth(HybridCustody.Owner) &HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let childAcctAddr = acct.address
        let factory = getAccount(factoryAddress).capabilities
            .get<&CapabilityFactory.Manager>(CapabilityFactory.PublicPath)
        assert(factory.check(), message: "factory address is not configured properly")
        let filter = getAccount(filterAddress).capabilities
            .get<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filter.check(), message: "capability filter is not configured properly")

        owned.publishToParent(parentAddress: userAcct.address, factory: factory, filter: filter)

        // ---------- Redeem account from inbox ----------
        if userAcct.storage.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            userAcct.storage.save(<- m, to: HybridCustody.ManagerStoragePath)

            userAcct.capabilities.unpublish(HybridCustody.ManagerPublicPath)
            userAcct.capabilities.publish(
                userAcct.capabilities.storage.issue<&HybridCustody.Manager>(HybridCustody.ManagerStoragePath),
                at: HybridCustody.ManagerPublicPath
            )
        }

        let inboxName = HybridCustody.getChildAccountIdentifier(userAcct.address)
        let cap = userAcct.inbox
            .claim<auth(HybridCustody.Child) &{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, ViewResolver.Resolver}>(
                inboxName,
                provider: childAcctAddr
            )
            ?? panic("child account cap not found")

        let manager = userAcct.storage
            .borrow<auth(HybridCustody.Manage) &HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
            ?? panic("manager no found")

        manager.addAccount(cap: cap)

        manager.setChildAccountDisplay(address: childAcctAddr, MetadataViews.Display(
                name: "Fixes Entrusted",
                description: "Fixes World Entrusted Account",
                thumbnail: MetadataViews.HTTPFile(url: "https://i.imgur.com/hs3U5CY.png")
            )
        )
    }

    execute {
        log("Account Linked")
    }
}
