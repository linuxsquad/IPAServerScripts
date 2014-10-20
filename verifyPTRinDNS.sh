#!/bin/bash
# 
# AUTHOR:         Linuxsquad
# 
# DATE:           Oct-1-2014
#                                                                                         
# DESCRIPTION:    connect to IPA/DNS to find out A records w/out corresponding PTRs, adding missing PTRs
#
# PRE-REQUISIT:   - IPA server with DNS plugin enabled
#                 - all ARPA zones (relevant to your installastion) should be created in DNS 
#                   prior to running this scrupt. Otherwise the script fails.
#                 - This script does not detect subnet CLASS (A,B,C ) in fully automated way (anyone?). 
#                   You have to modify couple lines in the script to reflect proper ARPA subnets
#
# INPUT:          N/A
#
# OUTPUT:        log showing PTR records added
#
# RELEASE NOTE:  0.1


#
# change to your subnet, IPA/DNS does handle subnet by its CLASS
typeset OFFICESUBNET="2.168.192"
typeset CLOUDSUBNET="25.172"
typeset CORPDOMAIN="exmaple.lan"

ipa dnsrecord-find ${CORPDOMAIN} | egrep "name: [a-z]" | cut -d':' -f2 | while read name
do 

    ipaddress=$(ipa dnsrecord-show ${CORPDOMAIN} $name | grep "^\ *A" | cut -d':' -f2 | tr -d ' ') 
    wait
    if [ ! -z ${ipaddress} ]
    then
	echo -n "${name} >> ${ipaddress} "
    else
	echo ${name}" >> NOT A RECORD"
	continue
    fi
    
    # update IF statement to reflect your subnets
    if [[ "X"${ipaddress//192*/OK} == "XOK" ]]
    then
	SUBNET=${OFFICESUBNET}
    elif [[ "X"${ipaddress//172*/OK} == "XOK" ]]
    then
	SUBNET=${CLOUDSUBNET}
    else
	echo "WARN: UNKNOWN SUBNET"
	continue
    fi

    ipa dnsrecord-find ${SUBNET}.in-addr.arpa --ptr-rec=$name"."${CORPDOMAIN} > /dev/null 2>&1 
    if [ "X"$? == "X1" ]
    then 
	echo " NO PTR, "
	reverseIP=$(echo ${ipaddress} | awk 'BEGIN{FS=".";ORS="."} {for (i = NF; i > 0; i--){print $i}}' | sed 's/\.*$//')
	numIP=${reverseIP//${SUBNET}}
	ipa dnsrecord-add ${SUBNET}.in-addr.arpa. ${numIP%%\.} --ptr-hostname=$name"."${CORPDOMAIN}"."
	wait
    else
	echo " PTR Record EXIST, "
    fi
done
