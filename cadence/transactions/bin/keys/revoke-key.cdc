transaction(
    index: Int
) {
    prepare(signer: AuthAccount) {
        // revoke a key from an auth account.
        signer.keys.revoke(keyIndex: index)
    }
}
