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
import "EVMAgent"
import "StringUtils"

transaction(
    nftIds: [UInt64],
    hexPublicKey: String,
    hexSignature: String,
    timestamp: UInt64,
) {
    let semiNFTColRef: auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection

    prepare(signer: auth(Storage, Capabilities) &Account) {
        /** ------------- EVMAgency: verify and borrow AuthAccount ------------- */
        let agency = EVMAgent.borrowAgencyByEVMPublicKey(hexPublicKey)
            ?? panic("Could not borrow a reference to the EVMAgency!")

        var arrParams: [String] = []
        for one in nftIds {
            arrParams.append(one.toString())
        }
        let acct = agency.verifyAndBorrowEntrustedAccount(
            methodFingerprint: "claim-rewards([UInt64])",
            params: [StringUtils.join(arrParams, "&")],
            hexPublicKey: hexPublicKey,
            hexSignature: hexSignature,
            timestamp: timestamp
        )
        /** ------------- EVMAgency: End --------------------------------------- */


        /** ------------- Start -- FRC20 Semi NFT Collection Initialization ------------  */
        // ensure resource
        if acct.storage.borrow<&AnyResource>(from: FRC20SemiNFT.CollectionStoragePath) == nil {
            acct.storage.save(<- FRC20SemiNFT.createEmptyCollection(nftType: Type<@FRC20SemiNFT.NFT>()), to: FRC20SemiNFT.CollectionStoragePath)
        }

        // link to public capability
        if acct
            .capabilities.get<&FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20SemiNFT.CollectionPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20SemiNFT.Collection>(
                    FRC20SemiNFT.CollectionStoragePath
                ),
                at: FRC20SemiNFT.CollectionPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */

        let cap = acct.capabilities.storage
            .issue<auth(NonFungibleToken.Withdraw, NonFungibleToken.Update) &FRC20SemiNFT.Collection>(FRC20SemiNFT.CollectionStoragePath)
        self.semiNFTColRef = cap.borrow()
            ?? panic("Could not borrow a reference to the NFT Collection")

        /** ------------- Start -- FRC20 Delegator General Initialization -------------  */
        if acct.storage.borrow<&AnyResource>(from: FRC20Staking.DelegatorStoragePath) == nil {
            acct.storage.save(<- FRC20Staking.createDelegator(cap), to: FRC20Staking.DelegatorStoragePath)
        }

        if acct
            .capabilities.get<&FRC20Staking.Delegator>(FRC20Staking.DelegatorPublicPath)
            .borrow() == nil {
            acct.capabilities.unpublish(FRC20Staking.DelegatorPublicPath)
            acct.capabilities.publish(
                acct.capabilities.storage.issue<&FRC20Staking.Delegator>(
                    FRC20Staking.DelegatorStoragePath
                ),
                at: FRC20Staking.DelegatorPublicPath
            )
        }
        /** ------------- End ---------------------------------------------------------- */
    }

    execute {
        FRC20StakingManager.claimRewards(self.semiNFTColRef, nftIds: nftIds)
        log("Rewards claimed")
    }
}
