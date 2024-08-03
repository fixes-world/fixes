import "HybridCustody"
import "CapabilityFactory"
import "CapabilityFilter"
import "CapabilityDelegator"
import "MetadataViews"
// Import the Fixes contract
import "EVMAgent"

transaction(
    factoryAddress: Address,
    filterAddress: Address,
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    prepare(_appSigner: AuthAccount, userAcct: AuthAccount) {
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
        let owned = acct.borrow<&HybridCustody.OwnedAccount>(from: HybridCustody.OwnedAccountStoragePath)
            ?? panic("owned account not found")
        let childAcctAddr = acct.address
        let factory = getAccount(factoryAddress).getCapability<&CapabilityFactory.Manager{CapabilityFactory.Getter}>(CapabilityFactory.PublicPath)
        assert(factory.check(), message: "factory address is not configured properly")
        let filter = getAccount(filterAddress).getCapability<&{CapabilityFilter.Filter}>(CapabilityFilter.PublicPath)
        assert(filter.check(), message: "capability filter is not configured properly")

        owned.publishToParent(parentAddress: userAcct.address, factory: factory, filter: filter)

        // ---------- Redeem account from inbox ----------
        if userAcct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath) == nil {
            let m <- HybridCustody.createManager(filter: filter)
            userAcct.save(<- m, to: HybridCustody.ManagerStoragePath)
            // @deprecated after Cadence 1.0
            userAcct.unlink(HybridCustody.ManagerPublicPath)
            userAcct.unlink(HybridCustody.ManagerPrivatePath)
            userAcct.link<&HybridCustody.Manager{HybridCustody.ManagerPrivate, HybridCustody.ManagerPublic}>(HybridCustody.ManagerPrivatePath, target: HybridCustody.ManagerStoragePath)
            userAcct.link<&HybridCustody.Manager{HybridCustody.ManagerPublic}>(HybridCustody.ManagerPublicPath, target: HybridCustody.ManagerStoragePath)
        }

        let inboxName = HybridCustody.getChildAccountIdentifier(userAcct.address)
        let cap = userAcct.inbox
            .claim<&HybridCustody.ChildAccount{HybridCustody.AccountPrivate, HybridCustody.AccountPublic, MetadataViews.Resolver}>(
                inboxName,
                provider: childAcctAddr
            )
            ?? panic("child account cap not found")

        let manager = userAcct.borrow<&HybridCustody.Manager>(from: HybridCustody.ManagerStoragePath)
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
