import "FungibleTokenManager"

transaction(page: Int) {
    prepare(acct: AuthAccount) {
        let ftAdmin = acct.borrow<&FungibleTokenManager.Admin>(from: FungibleTokenManager.AdminStoragePath)
            ?? panic("Missing FungibleTokenManager.Admin")
        ftAdmin.stageChildrenContracts(page: page)
    }
}
