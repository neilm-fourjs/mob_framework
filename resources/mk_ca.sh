
openssl x509 -in LetsEncryptAuthorityX3.p7c -text > letEncrpytCAList.pem
openssl x509 -in BuiltinObjectToken_DSTRootCAX3.p7c -text >> letEncrpytCAList.pem
