import "MetadataViews"
import "FRC20NFTWrapper"
import "FRC20Indexer"

transaction(
    nftType: String,
    name: String,
    description: String,
    square: String,
    banner: String,
    website: String,
    twitter: String,
    discord: String,
) {
    prepare(acct: auth(Storage, Capabilities) &Account) {
        let wrapperIndexer = acct.storage.borrow<&FRC20NFTWrapper.WrapperIndexer>(from: FRC20NFTWrapper.FRC20NFTWrapperIndexerStoragePath)
            ?? panic("Could not borrow a reference to the NFT Wrapper")

        // set default values
        let bannerMedia = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: banner),
            mediaType: "image/jpeg"
        )
        let squareMedia = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: square),
            mediaType: "image/png"
        )
        let url = MetadataViews.ExternalURL(website)

        let collectionType = FRC20NFTWrapper.asCollectionType(nftType)
        wrapperIndexer.updateExtraNFTCollectionDisplay(
            nftType: collectionType,
            display: MetadataViews.NFTCollectionDisplay(
                name: name,
                description: description,
                externalURL: url,
                squareImage: squareMedia,
                bannerImage: bannerMedia,
                socials: {
                    "twitter": MetadataViews.ExternalURL(twitter),
                    "discord": MetadataViews.ExternalURL(discord)
                }
            )
        )
    }
}
