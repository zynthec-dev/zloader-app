#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
work=$(mktemp -d /tmp/zloader-certificate-test.XXXXXX)
trap 'rm -rf "$work"' EXIT
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/private.pem" -out "$work/certificate.pem" -subj '/CN=zLoader Generated Test' -days 1 > /dev/null 2>&1
openssl x509 -in "$work/certificate.pem" -outform DER -out "$work/certificate.der"
openssl genrsa -out "$work/other.pem" 2048 > /dev/null 2>&1
swiftc -module-cache-path /tmp/zloader-crypto-modules zLoader/Features/Core/Certificates/PortablePKCS12.swift zLoader/Tests/PortablePKCS12Tests.swift -o "$work/test"
"$work/test" "$work"
openssl pkcs12 -in "$work/export0.p12" -passin pass:test-password -info -noout > "$work/openssl.txt" 2>&1
openssl pkcs12 -in "$work/export1.p12" -passin 'pass:Grün🔑123' -info -noout > /dev/null 2>&1
if openssl pkcs12 -in "$work/export0.p12" -passin pass:incorrect -noout > /dev/null 2>&1; then
    echo 'FAIL wrong OpenSSL password accepted'; exit 1
fi
rg -q 'Shrouded Keybag|Shrouded Key Bag' "$work/openssl.txt"
rg -q 'MAC: sha256' "$work/openssl.txt"
openssl req -in "$work/request.csr" -verify -noout > /dev/null 2>&1
openssl req -in "$work/request.csr" -pubkey -noout > "$work/csr.pub"
openssl pkey -in "$work/request.key" -pubout > "$work/derived.pub"
cmp "$work/csr.pub" "$work/derived.pub"
openssl pkey -pubin -in "$work/request.pub" -outform DER -out "$work/request-public.der"
openssl pkey -pubin -in "$work/derived.pub" -outform DER -out "$work/derived-public.der"
cmp "$work/request-public.der" "$work/derived-public.der"
echo 'PASS independent OpenSSL MAC, AES-encrypted keybag, wrong-password rejection, CSR signature and matching keys'
