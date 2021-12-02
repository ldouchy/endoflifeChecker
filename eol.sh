#!/bin/bash

# brew install dateutils jq

DEBUG="0"

# command line options
if [ $# -eq "0" ] ; then echo "Usage: eol.sh image tag" ; fi

if [ $# -eq "1" ] ; then
  IMAGE=$( echo $1 | awk -F: '{print $1}' )
  TAG=$( echo $1 | awk -F: '{print $2}' )
else
  IMAGE=$1
  TAG=$2
fi
if [ ${DEBUG} -gt "0" ] ; then echo "IMAGE: ${IMAGE}" ; fi
if [ ${DEBUG} -gt "0" ] ; then echo "TAG: ${TAG}" ; fi


# variables
OS_DETECTED="0"
OS_ID=""
OS_VERSION_ID=""
EOLURL=""
EOLDATE=""
EOLDELTA=""

# Pull docker image locally for analysis
# on pull error try to login before pulling again
Docker pull -q ${IMAGE}:${TAG} > /dev/null 2>&1
if [ $? -eq "1" ] ; then
  # Add your private repository login
  # docker login ... 
  Docker pull -q ${IMAGE}:${TAG} > /dev/null 2>&1
  if [ $? -eq "1" ] ; then echo "${IMAGE},${TAG},image not found" ; fi
fi

# Retrieve OS information and define EOL URL
OS_ID=$( docker run --rm --entrypoint ""  ${IMAGE}:${TAG} /bin/sh -c "grep \"^ID\" /etc/os-release" | awk -F= '{print $2}' | sed 's/\"//g' )
# Sanitize OS_ID
OS_ID=${OS_ID//[^a-zA-Z0-9_]/}
if [ ${DEBUG} -gt "0" ] ; then echo "OS_ID: ${OS_ID}" ; fi

if [[ ${OS_ID} = "alpine" ]] || [[ ${OS_ID} = "debian" ]] ; then
    case ${OS_ID} in
        alpine)
            OS_DETECTED="1"
            OS_VERSION_ID=$(docker run --rm --entrypoint ""  ${IMAGE}:${TAG} /bin/sh -c "grep \"^VERSION_ID\" /etc/os-release" | awk -F= '{print $2}' | awk -F\. '{print $1"."$2}' | sed 's/\"//g')
            EOLURL="https://endoflife.date/api/alpine.json"
            ;;

        debian)
            OS_DETECTED="1"
            OS_VERSION_ID=$(docker run --rm --entrypoint ""  ${IMAGE}:${TAG} /bin/sh -c "grep \"^VERSION_ID\" /etc/os-release" | awk -F= '{print $2}' | sed 's/\"//g')
            EOLURL="https://endoflife.date/api/debian.json"
            ;;

        *)
            echo "${IMAGE},${TAG},OS not suported"
            exit 2
            ;;
    esac
    # Sanitize OS_VERSION_ID
    OS_VERSION_ID=${OS_VERSION_ID//[^a-zA-Z0-9_\.]/}
    if [ ${DEBUG} -gt "0" ] ; then echo "OS_DETECTED: ${OS_DETECTED}" ; fi
    if [ ${DEBUG} -gt "0" ] ; then echo "OS_VERSION_ID: ${OS_VERSION_ID}" ; fi
    if [ ${DEBUG} -gt "0" ] ; then echo "EOLURL: ${EOLURL}" ; fi
else
  echo "${IMAGE},${TAG},/etc/os-release not found or OS not suported"
  exit 2
fi

# Retrieve EOL date and delta to EOL
EOLDATE=$(curl -s ${EOLURL} | jq -r --arg OS_VERSION_ID "${OS_VERSION_ID}" '.[] | select(.cycle | contains($OS_VERSION_ID)) | .eol')
if [ ${DEBUG} -gt "0" ] ; then echo "EOLDATE: ${EOLDATE}" ; fi

EOLDELTA=$(/usr/local/bin/datediff $(date +%Y-%m-%d) ${EOLDATE})
if [ ${DEBUG} -gt "0" ] ; then echo "EOLDELTA: ${EOLDELTA}" ; fi

echo "${IMAGE},${TAG},${EOLDELTA},${EOLDATE}"

# more human redable output
# Print EOL status
# if [ ${EOLDELTA} -gt "0" ]
# then
#   echo "image ${IMAGE}:${TAG} is using ${OS_ID} ${OS_VERSION_ID} EOL in ${EOLDELTA} days"
#   exit 0
# else
#   EOLDELTA=${EOLDELTA//-/}
#   echo "image ${IMAGE}:${TAG} is using ${OS_ID} ${OS_VERSION_ID} EOL SINCE ${EOLDATE} (${EOLDELTA} days)"
#   exit 2
# fi