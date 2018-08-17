```
one_genkey.sh - Generate Key/CSR with SAN entries all on the command line.

Usage: one_genkey.sh -subjectdn "C=US/ST=Iowa/.../CN=www.example.org"
  -= OR =-
Usage: one_genkey.sh -c US -st Iowa -l Bode -o "ACME Widgets"
      [-ou "IT Crowd"] -cn www.example.org

  -= AND to add SAN entries to either: =-

      [-dns ftp.example.org] [-ip 1.2.3.4] [-email it@example.org] [-dn]

  -= FINALLY, =-

        [-bits 4096] (number of bits for key, default/min is 2048)
        [-client] (make this a Client certificate (default is Server))
        [-file basename] (base filename for .csr and .key output files)
        [-print] (print generated openssl.cnf instead of generating key/csr)
        [-h|-help] (this)

      [bracketed] items are optional
        Multiple -dns, -ip, and -email arguments may be specified
          and will all be added to the Subject Alternative Name (SAN)
        -cn/SubjectDN CNs with a '.' become SAN DNS entries automatically
        -dn will insert the SubjectDN into the SAN as a dirName
```
