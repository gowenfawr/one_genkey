# one_genkey
A script for creating Certificate Signing Requests from the CLI, hiding the OpenSSL config file complexity.

A common complaint about OpenSSL is that some aspects of CSR creation cannot be specified on the command line, but only made by modifying the OpenSSL configuration file.  The necessary modifications to that file may be unclear, and even when finally updated, it will need to be modified again for the next certificate, or may have been lost by the time certificate renewal rolls around.

one_genkey.sh compensates for this by writing the "config file" in memory for you and feeding it directly into OpenSSL (although you can print it for hand-tooling and later use, of course!)  Because the config file is generated in the script, you don't need to keep track of the config file; the script is entirely self-contained.

A simple example of creating a CSR for "host.example.com" with a SAN DNS entry "www.example.com":

```
$ ./one_genkey.sh -c US -st Iowa -l Bode -o "ACME Widgets" -cn host.example.com -dns www.example.com
Generating a 2048 bit RSA private key
.................................................................................................+++
....+++
writing new private key to 'host.example.com.key'
-----
$ openssl req -text -noout -in host.example.com.csr 
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: C = US, ST = Iowa, L = Bode, O = ACME Widgets, CN = host.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:e7:54:e2:df:b9:21:33:6f:e5:8d:1e:d4:a0:56:
                    ...
                    e7:87:a5:e2:44:9c:cc:c5:f7:f8:12:69:d9:ae:31:
                    57:0d
                Exponent: 65537 (0x10001)
        Attributes:
        Requested Extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Subject Alternative Name: 
                DNS:host.example.com, DNS:www.example.com
    Signature Algorithm: sha256WithRSAEncryption
         da:99:48:01:f9:76:63:28:69:22:0c:5b:94:9e:0a:c9:33:56:
         ...
         c2:90:78:93:96:7b:66:ca:7a:25:e8:56:39:29:99:01:73:9c:
         b3:fe:20:39
 ```
