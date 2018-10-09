config = {
    debug = true,
    jwt_keys = {
        verify = [[-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvPu3iG05nNhMQyaQmK/m
26SmwoeWncLCaNqsty3mx7cHjZom0Ywz0tbEahlW+YEt/Yjhfp0n4RpMID8NQoTG
S7AfApb7xwLFnlyTTMN+wibfnTB08Kr+93/PmQLY0A6zwX8tSIO+3FaGsg5F84JX
Uph0MRW5YznQADgBo933SgjtXLKdxzLEn5rbF7/Si0lzUnLbzs/IIGoV0Xoohyk6
iW/Q5lGNKtiqJ942LAxfnpqPSWFmkyhvWC5vX1PuSJvyZNBrchQBPtNrSibGAHv5
c0e0U4WFceDmRP/rbAeZ2l22Yg+Fz9oyUOynXEKbx+QhU37AiST8qwz4ABxkokVl
TwIDAQAB
-----END PUBLIC KEY-----]]
    }
-- auth0 pub key:
--   * download cert
--   * run openssl x509 -in bedis9.pem -text -pubkey
}
