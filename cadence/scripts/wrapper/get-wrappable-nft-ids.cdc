import "NonFungibleToken"
import "NFTCatalog"
import "MetadataViews"
import "Fixes"
import "FixesWrappedNFT"
import "FRC20NFTWrapper"
import "FRC20Indexer"

pub fun main(
    wrapper: Address,
    nftIdentifier: String,
    userAddr: Address,
): [UInt64] {
    let collectionType = FRC20NFTWrapper.asCollectionType(nftIdentifier)
    if let wrapper = FRC20NFTWrapper.borrowWrapperPublic(addr: wrapper) {
        if !wrapper.hasFRC20Strategy(nftType: collectionType) {
            return []
        }

        let acct = getAuthAccount(userAddr)
        var collectionRef: &NonFungibleToken.Collection? = nil

        let nftType = FRC20NFTWrapper.asNFTType(nftIdentifier)
        // get from NFTCatalog first
        if let entries: {String: Bool} = NFTCatalog.getCollectionsForType(nftTypeIdentifier: nftType.identifier) {
            for colId in entries.keys {
                if let catalogEntry = NFTCatalog.getCatalogEntry(collectionIdentifier: colId) {
                    let path = catalogEntry.collectionData.storagePath
                    collectionRef = acct.borrow<&NonFungibleToken.Collection>(from: path)
                    if collectionRef != nil {
                        break
                    }
                }
            }
        }

        // if not found, search all storage
        if collectionRef == nil {
            var found = false
            acct.forEachStored(fun (path: StoragePath, type: Type): Bool {
                if type.identifier == collectionType.identifier {
                    collectionRef = acct.borrow<&NonFungibleToken.Collection>(from: path)
                    if collectionRef != nil {
                        found = true  // stop
                    }
                }
                return !found // for each if not found
            })
        }

        // if still not found, return empty
        if collectionRef == nil {
            return []
        }

        // scan all NFTs in the collection to search all NFTs that can be wrapped
        let allIds = collectionRef!.getIDs()

        let ret: [UInt64] = []
        for id in allIds {
            let nft = collectionRef!.borrowNFT(id: id)
            if !wrapper.isFRC20NFTWrappered(nft: nft) {
                ret.append(id)
            }
        }
        return ret
    }
    return []
}
