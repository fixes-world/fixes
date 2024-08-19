import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"

transaction(
    wrapperAddr: Address,
    nftCollectionIdentifier: String,
    nftIds: [UInt64],
    keepWrapped: Bool,
) {
    let wrapper: &{FRC20NFTWrapper.WrapperPublic}
    let wrappedNFTCol: auth(NonFungibleToken.Withdraw) &FixesWrappedNFT.Collection
    let nftProvider: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}

    prepare(acct: auth(Storage, Capabilities) &Account) {
        self.wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapperAddr) ?? panic("Could not borrow public reference")

        // Create a new empty collection
        if acct.storage.borrow<&FixesWrappedNFT.Collection>(from: FixesWrappedNFT.CollectionStoragePath) == nil {
            // Create a new empty collection
            let collection <- FixesWrappedNFT.createEmptyCollection(nftType: Type<@FixesWrappedNFT.NFT>())

            // save it to the account
            acct.storage.save(<-collection, to: FixesWrappedNFT.CollectionStoragePath)

            // create a public capability for the collection
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FixesWrappedNFT.Collection>(FixesWrappedNFT.CollectionStoragePath),
                at: FixesWrappedNFT.CollectionPublicPath
            )
        }

        self.wrappedNFTCol = acct.storage
            .borrow<auth(NonFungibleToken.Withdraw) &FixesWrappedNFT.Collection>(from: FixesWrappedNFT.CollectionStoragePath)!

        // Find the nft to wrap
        let nftColType = FRC20NFTWrapper.asCollectionType(nftCollectionIdentifier)
        var nftProviderRef: auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}? = nil
        acct.storage.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == nftColType {
                if let colRef = acct.storage
                    .borrow<auth(NonFungibleToken.Withdraw) &{NonFungibleToken.Collection}>(from: path) {
                    nftProviderRef = colRef
                    return false
                }
            }
            return true
        })
        assert(
            nftProviderRef != nil,
            message: "Could not find NFT collection with identifier: ".concat(nftCollectionIdentifier)
        )
        self.nftProvider = nftProviderRef!
    }

    pre {
        nftIds.length > 0: "Must provide at least one NFT ID"
    }

    execute {
        for uid in nftIds {
            let nftToWrap <- self.nftProvider.withdraw(withdrawID: uid)

            let newWrappedNFTId = self.wrapper.wrap(
                recipient: self.wrappedNFTCol,
                nftToWrap: <- nftToWrap
            )

            // If we don't want to keep the wrapped NFT, unwrap it
            // and destroy the inscription
            if !keepWrapped {
                let wrappedNft <- self.wrappedNFTCol.withdraw(withdrawID: newWrappedNFTId) as! @FixesWrappedNFT.NFT
                let ins <- FixesWrappedNFT.unwrap(
                    recipient: self.nftProvider,
                    nftToUnwrap: <- wrappedNft
                )
                destroy ins
            }
        }
    }
}
