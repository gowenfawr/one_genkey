#!/bin/bash

function usage {
	prog=`basename $0`
	echo "$prog - Generate Key/CSR with SAN entries all on the command line."
	echo ""
    echo "Usage: $prog -subjectdn \"C=US/ST=Iowa/.../CN=www.example.org\""
    echo "  -= OR =-"
    echo "Usage: $prog -c US -st Iowa -l Bode -o \"ACME Widgets\""
    echo "      [-ou \"IT Crowd\"] -cn www.example.org"
    echo ""
    echo "  -= AND to add SAN entries to either: =-"
    echo ""
    echo "      [-dns ftp.example.org] [-ip 1.2.3.4] [-email it@example.org] [-dn]"
    echo ""
    echo "  -= FINALLY, =-"
	echo ""
    echo "        [-bits 4096] (number of bits for key, default/min is 2048)"
	echo "        [-client] (make this a Client certificate (default is Server))"
    echo "        [-file basename] (base filename for .csr and .key output files)"
    echo "        [-print] (print generated openssl.cnf instead of generating key/csr)"
    echo "        [-h|-help] (this)"
    echo ""
    echo "      [bracketed] items are optional"
    echo "        Multiple -dns, -ip, and -email arguments may be specified"
    echo "          and will all be added to the Subject Alternative Name (SAN)"
    echo "        -cn/SubjectDN CNs with a '.' become SAN DNS entries automatically"
    echo "        -dn will insert the SubjectDN into the SAN as a dirName"
    if [ ! -z "$1" ]; then
        echo ""
        echo "$1"
    fi
    exit 1
}

# https://stackoverflow.com/questions/1527049/join-elements-of-an-array
function join_by { local IFS="$1"; shift; echo "$*"; }

# read the options
TEMP=`getopt --alternative -o h --long subjectdn:,bits:,c:,st:,l:,o:,ou:,cn:,email:,dns:,ip:,dn,client,file:,print,help -n 'test.sh' -- "$@"`
eval set -- "$TEMP"

declare opt_dn="No"
declare opt_print="No"
declare opt_eku="serverAuth"
declare -i opt_bits=2048
declare -i opt_dns_i=0
declare -i opt_email_i=0
declare -i opt_ip_i=0
declare -a dnkey
declare -a dnval

# extract options and their arguments into variables.
# NOTE despite the fact that we see "--arg" here, the use of
# "--alternatives" means that users can enter single-dash
# variants (e.g., -c instead of --c, -print i/o --print, ...)
while true ; do
    case "$1" in
        -h|--help)
            usage;;
        --bits)
            opt_bits=$2 
            # Not just enforcing a minimum, but non-numbers entered
            # at the command line will make opt_bits = 0, so fix that.
            if [[ $opt_bits -lt 2048 ]]; then
                opt_bits=2048
            fi
            shift 2 ;;
        --c)
            opt_c=$2; shift 2 ;;
        --st)
            opt_st=$2; shift 2 ;;
        --l)
            opt_l=$2; shift 2;;
        --o)
            opt_o=$2; shift 2;;
        --ou)
            case "$2" in
                "") opt_ou=""; shift 2;;
                *) opt_ou=$2; shift 2;;
            esac;;
        --cn)
            opt_cn=$2; shift 2;;
        --email)
			opt_email[$opt_email_i]=$2 
			((opt_email_i++))
			shift 2;;
        --dns)
			opt_dns[$opt_dns_i]=$2 
			((opt_dns_i++))
			shift 2;;
        --ip)
			opt_ip[$opt_ip_i]=$2; 
			((opt_ip_i++))
			shift 2;;
        --dn)
            opt_dn="Yes"; shift 1;;
        --print)
            opt_print="Yes"; shift 1;;
        --file)
            opt_file=$2; shift 2;;
        --client)
            opt_eku="clientAuth"; shift 1;;
		--subjectdn)
			case "$2" in
				"") shift 2;;
				*)  opt_subjectdn="$2"
					IFS='/' read -r -a dnarray <<< "$opt_subjectdn"
					i=0
					k=0
					if [[ -z "${dnarray[0]}" ]]; then
						i=1
					fi
					for j in `seq $i "${#dnarray[@]}"`
					do
						IFS='=' read -r -a dnitem <<< "${dnarray[$j]}"
						if [[ -n "${dnitem[0]}" && -n "${dnitem[1]}" ]]; then
							dnkey[$k]="${dnitem[0]}"
							dnval[$k]="${dnitem[1]}"
							((k++))
							if [[ "${dnitem[0]}" = "CN" ]]; then
								opt_cn="${dnitem[1]}"
							fi
						fi
					done
					shift 2;;
				esac;;
        --) shift ; break ;;
        *) echo "Illegal something"; exit 1;;
    esac
done

# If not specified, file basename is the CN stripped down to limited chars
declare -a fconflict
if [[ -z "$opt_file" ]]; then
    opt_file=`echo "$opt_cn" | tr -cd 'a-zA-Z0-9._\-'`
fi
if [[ -f "$opt_file.csr" ]]; then
    fconflict+=("$opt_file.csr")
fi
if [[ -f "$opt_file.key" ]]; then
    fconflict+=("$opt_file.key")
fi
if [[ "$opt_print" == "No" && "${#fconflict[@]}" > 0 ]]; then
    fileopts=`join_by , "${fconflict[@]}"`
    usage "ERROR: Existing output file(s) ($fileopts)"
fi

TxSA_SubjectDN=""
if [[ -n "$opt_subjectdn" ]]; then
	iter=1
	for i in `seq 0 ${#dnkey[@]}`
	do
		if [[ -n "${dnkey[$i]}" && -n "${dnval[$i]}" ]]; then
			printf -v TxSA_SubjectDN "%s%d.%s	= %s\n" "$TxSA_SubjectDN" $iter "${dnkey[$i]}" "${dnval[$i]}" 
			((iter++))
		fi
	done
	printf -v TxSA_SubjectDN "%s" "$TxSA_SubjectDN"
else
	declare -a missing
	if [[ -z "$opt_c" ]]; then
		missing+=('--c')
	fi
	if [[ -z "$opt_st" ]]; then
		missing+=('--st')
	fi
	if [[ -z "$opt_l" ]]; then
		missing+=('--l')
	fi
	if [[ -z "$opt_o" ]]; then
		missing+=('--o')
	fi
	if [[ -z "$opt_cn" ]]; then
		missing+=('--cn')
	fi
	if [[ "${#missing[@]}" > 0 ]]; then
		missopts=`join_by , "${missing[@]}"`
		usage "ERROR: Required arguments --subjectdn or ($missopts) are missing" 
	fi

    if [[ -n "$opt_ou" ]]; then
	    printf -v opt_ou "organizationalUnitName	= %s\n" "$opt_ou"
    fi

	TxSA_SubjectDN=$(cat <<EOF
countryName             = $opt_c
stateOrProvinceName     = $opt_st
localityName            = $opt_l
organizationName        = $opt_o
${opt_ou}commonName              = $opt_cn

EOF
)

fi

#
# Inlining the openssl.cnf file allows this to be a single-file solution.
#
TxSA_Config=$(cat <<EOF
[ req ]
default_bits            = $opt_bits
default_md              = sha256
distinguished_name      = req_distinguished_name
req_extensions          = req_ext
prompt                  = no

[ req_distinguished_name ]
$TxSA_SubjectDN

[ req_ext ]
basicConstraints    	= CA:FALSE
extendedKeyUsage        = $opt_eku
EOF
)

TxSA_SAN=""
if [[ -n "$opt_cn" && "$opt_cn" = *"."* ]]; then
	printf -v TxSA_SAN "DNS:%s" "$opt_cn"
fi
((opt_dns_i--))
for i in `seq 0 $opt_dns_i`
do
	printf -v TxSA_SAN "%s,DNS:%s" "$TxSA_SAN" "${opt_dns[$i]}"
done

((opt_ip_i--))
for i in `seq 0 $opt_ip_i`
do
	printf -v TxSA_SAN "%s,IP:%s" "$TxSA_SAN" "${opt_ip[$i]}"
done

((opt_email_i--))
for i in `seq 0 $opt_email_i`
do
	printf -v TxSA_SAN "%s,email:%s" "$TxSA_SAN" "${opt_email[$i]}"
done


if [[ "$opt_dn" = "Yes" ]]; then
	printf -v TxSA_SAN "%s,dirName:dn_again\n\n" "$TxSA_SAN" 
TxSA_SAN=${TxSA_SAN}$(cat <<EOF
[ dn_again ]
$TxSA_SubjectDN
EOF
)
fi
# Remove the leading comma if we skipped initial CN->DNS
TxSA_SAN=`echo "$TxSA_SAN" | sed -e 's/^,//'`

printf -v TxSA_Config "%s\nsubjectAltName          = %s\n" "$TxSA_Config" "$TxSA_SAN"


#
# Everything has led us up to this point...
#
if [[ "$opt_print" = "Yes" ]]; then
	echo "$TxSA_Config"
else 
	openssl req -new -nodes  -out $opt_file.csr -keyout $opt_file.key -config <(echo "$TxSA_Config")
fi

