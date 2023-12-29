// Third party imports
import "NonFungibleToken"
import "MetadataViews"
import "NFTCatalog"
import "FindViews"
// Fixes imports
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

pub fun main(
    wrapper: Address,
    nftIdentifier: String,
    userAddr: Address,
    page: Int,
    size: Int
): [UInt64] {
    let collectionType = FRC20NFTWrapper.asCollectionType(nftIdentifier)
    if let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapper) {
        if !wrapper.hasFRC20Strategy(collectionType) {
            return []
        }

        let acct = getAuthAccount(userAddr)
        var collectionWithResolverRef: &AnyResource{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}? = nil
        var collectionRef: &AnyResource{NonFungibleToken.CollectionPublic}? = nil

        let nftType = FRC20NFTWrapper.asNFTType(nftIdentifier)
        // get from NFTCatalog first
        if let entries: {String: Bool} = NFTCatalog.getCollectionsForType(nftTypeIdentifier: nftType.identifier) {
            for colId in entries.keys {
                if let catalogEntry = NFTCatalog.getCatalogEntry(collectionIdentifier: colId) {
                    let path = catalogEntry.collectionData.storagePath
                    collectionWithResolverRef = acct.borrow<&{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(from: path)
                    collectionRef = collectionWithResolverRef
                    if collectionRef != nil {
                        break
                    }
                }
            }
        }

        // if not found, search all storage
        if collectionRef == nil {
            // search all storage
            var found = false
            acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
                if type.identifier == collectionType.identifier {
                    if acct.check<@AnyResource{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(from: path) {
                        collectionWithResolverRef = acct.borrow<&AnyResource{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(from: path)
                    }
                    if acct.check<@AnyResource{NonFungibleToken.CollectionPublic}>(from: path) {
                        collectionRef = acct.borrow<&AnyResource{NonFungibleToken.CollectionPublic}>(from: path)
                    }
                    if collectionRef != nil {
                        found = true  // stop
                    }
                }
                return !found // for each if not found
            })
        }

        // if still not found
        if collectionRef == nil {
            // return empty
            return []
        }

        // scan all NFTs in the collection to search all NFTs that can be wrapped
        let allIds = collectionRef!.getIDs()
        var endIdx = page * size + size
        if endIdx > allIds.length {
            endIdx = allIds.length
        }
        let sliced = allIds.slice(from: page * size, upTo: endIdx)
        // Soul bound view
        let soulBoundView = Type<FindViews.SoulBound>()

        let ret: [UInt64] = []
        for id in sliced {
            let nft = collectionRef!.borrowNFT(id: id)
            // check if it is wrapped or soul bound
            let isWrapped = wrapper.isFRC20NFTWrappered(nft: nft)
            var isSoulBound = false
            if collectionWithResolverRef != nil {
                let viewResolver = collectionWithResolverRef!.borrowViewResolver(id: id)
                isSoulBound = viewResolver.resolveView(soulBoundView) != nil
            }
            // if not wrapped and not soul bound, add to return list
            if !isWrapped && !isSoulBound {
                ret.append(id)
            }
        }
        return ret
    }
    return []
}
