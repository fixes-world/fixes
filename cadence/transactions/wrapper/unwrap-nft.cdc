import "NonFungibleToken"
import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"

transaction(
    wrappedNftId: UInt64,
) {
    let targetNFTCol: &{NonFungibleToken.CollectionPublic}
    let nftToUnwrap: @FixesWrappedNFT.NFT

    prepare(acct: AuthAccount) {
        let wrappedNFTCol = acct
            .borrow<&FixesWrappedNFT.Collection>(from: FixesWrappedNFT.CollectionStoragePath)
            ?? panic("Could not borrow FixesWrappedNFT collection")

        self.nftToUnwrap <- wrappedNFTCol.withdraw(withdrawID: wrappedNftId) as! @FixesWrappedNFT.NFT

        let srcNftType = self.nftToUnwrap.getWrappedType() ?? panic("Could not get wrapped type")

        // Find the nft to wrap
        let nftColType = FRC20NFTWrapper.asCollectionType(srcNftType.identifier)
        var nftProviderRef: &{NonFungibleToken.CollectionPublic}? = nil
        acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
            if type == nftColType {
                if let colRef = acct.borrow<&{NonFungibleToken.CollectionPublic}>(from: path) {
                    nftProviderRef = colRef
                    return false
                }
            }
            return true
        })
        assert(
            nftProviderRef != nil,
            message: "Could not find NFT collection with identifier: ".concat(nftColType.identifier)
        )
        self.targetNFTCol = nftProviderRef!
    }

    execute {
        let ins <- FixesWrappedNFT.unwrap(
            recipient: self.targetNFTCol,
            nftToUnwrap: <- self.nftToUnwrap
        )
        destroy ins
    }
}
