// Third Party Imports
import "NonFungibleToken"
import "MetadataViews"
import "FlowToken"
// Fixes imports
import "Fixes"
import "FRC20Indexer"
import "FRC20FTShared"
import "FRC20AccountsPool"
import "FRC20SemiNFT"
import "FRC20Staking"
import "FRC20StakingManager"

transaction(
    nftIds: [UInt64],
) {
    let semiNFTColCap: Capability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>

    prepare(acct: AuthAccount) {

        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.save(<- FRC20SemiNFT.createEmptyCollection(), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20SemiNFT.CollectionPublicPath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPublicPath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
            // Link private path (will be deprecated in Cadence 1.0)
            acct.unlink(FRC20SemiNFT.CollectionPrivatePath)
            acct.link<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
                FRC20SemiNFT.CollectionPrivatePath,
                target: FRC20SemiNFT.CollectionStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        self.semiNFTColCap = acct
                .getCapability<&FRC20SemiNFT.Collection{FRC20SemiNFT.FRC20SemiNFTCollectionPublic, FRC20SemiNFT.FRC20SemiNFTBorrowable, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(FRC20SemiNFT.CollectionPrivatePath)

        /** ------------- Start -- FRC20 Delegator General Initialization -------------  */
        if acct.borrow<&AnyResource>(from: FRC20Staking.DelegatorStoragePath) == nil {
            acct.save(<- FRC20Staking.createDelegator(self.semiNFTColCap), to: FRC20Staking.DelegatorStoragePath)
        }

        if acct
            .getCapability<&FRC20Staking.Delegator{FRC20Staking.DelegatorPublic}>(FRC20Staking.DelegatorPublicPath)
            .borrow() == nil {
            acct.unlink(FRC20Staking.DelegatorPublicPath)
            acct.link<&FRC20Staking.Delegator{FRC20Staking.DelegatorPublic}>(
                FRC20Staking.DelegatorPublicPath,
                target: FRC20Staking.DelegatorStoragePath
            )
        }
        /** ------------- End ---------------------------------------------------------- */
    }

    execute {
        FRC20StakingManager.claimRewards(self.semiNFTColCap, nftIds: nftIds)
        log("Rewards claimed")
    }
}
