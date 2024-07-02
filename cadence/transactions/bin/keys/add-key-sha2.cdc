transaction(
    key: String
) {
    prepare(signer: AuthAccount) {
        let key = PublicKey(
            publicKey: key.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
        )
        signer.keys.add(publicKey: key, hashAlgorithm: HashAlgorithm.SHA2_256, weight: 1000.0)
    }
}
