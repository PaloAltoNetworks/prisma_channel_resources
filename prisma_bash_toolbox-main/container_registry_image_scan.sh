#!/bin/bash
# Written by Kyle Butler
# Scans Container images in a container registry if you've enabled that through the Prisma Cloud Compute in the registry settings. 


source ./secrets/secrets

# USER ASSIGNED VARIABLES

# Container registry
IMAGE_REGISTRY="<BASE_ADDRESS_FOR_CONTAINER_REGISTRY>"

# image name (ie nginx or alpine)
IMAGE_REPOSITORY="<OWNER/IMAGE>"

# image tag version (ie latest or 1.21.5)
IMAGE_TAG="1.21.5"

# okay to leave blank
IMAGE_DIGEST=""

# int value time in seconds. How many seconds to wait for scan to complete. 
SCAN_WAIT_TIME="30"



#### NO EDITS NEEDED BELOW



# The script name
readonly SCRIPT_NAME=$(basename $0)
# The script name without the extension
readonly SCRIPT_BASE_NAME=${SCRIPT_NAME%.*}
# Script directory
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Arguments
readonly ARGS="$*"
# Arguments number
readonly ARGNUM="$#"

usage() {
	echo "Script description"
	echo
	echo -e "Usage: \033[34mbash $SCRIPT_NAME --image-registry <container_registry> --image-repository <container_repository> --image-tag <container_tag_version> \033[0m[options]..."
	echo
	echo "Options:"
	echo
	echo "  -h, --help"
	echo "      Displays this help text."
	echo
	echo -e "   --image-registry \033[31m(REQUIRED)\033[0m container registry base path"
	echo
	echo
	echo -e "   --image-repository \033[31m(REQUIRED)\033[0m container repository (ie alpine or nginx or <owner>/alpine or <owner>/nginx)"
  echo
  echo
	echo -e "   --image-tag \033[31m(REQUIRED)\033[0m image tag version (ie latest or v1.23.1)"
	echo
	echo
	echo -e "   --scan-time \033[31m(REQUIRED)\033[0m time to wait in seconds for registry scan to happen"
	echo
	echo "  --"
	echo "      Do not interpret any more arguments as options."
	echo
}


while [ "$#" -gt 0 ]
do
	case "$1" in
	-h|--help)
		usage
		exit 0
		;;
	--image-registry)
		IMAGE_REGISTRY="$2"
		shift
		;;
	--image-repository)
		IMAGE_REPOSITORY="$2"
		;;
  --image-tag)
    IMAGE_TAG="$2"
    ;;
	--scan-time)
    SCAN_WAIT_TIME="$2"
    ;;
  --image-digest)
    IMAGE_DIGEST="$2"
		;;
	--)
		break
		;;
	-*)
		echo "Invalid option '$1'. Use --help to see the valid options" >&2
		exit 1
		;;
	# an option argument, continue
	*)	;;
	esac
	shift
done









# Request Body for authentication to return token
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_USER", "password": "$TL_PASSWORD"}
EOF
)


# Request Body for scan request
IMAGE_SCAN_REQUEST_PAYLOAD=$(cat << EOF
{
  "tag": {
    "registry": "$IMAGE_REGISTRY",
    "repo": "$IMAGE_REPOSITORY",
    "tag": "$IMAGE_TAG",
    "digest": "$IMAGE_DIGEST"
  }
}
EOF
)

# Checks the response of api request outputs the error code for curl if the request fails and exits
function quick_check {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res"
    exit
  fi
}


# Auth request
AUTH_RESPONSE=$(curl -H "Content-Type: application/json" \
                     -X POST \
                     -d "$AUTH_PAYLOAD" \
                     $TL_CONSOLE/api/v1/authenticate)

quick_check "/api/v1/authenticate"

# Gets the auth token ready for subsequent requests
AUTH_TOKEN=$(printf %s $AUTH_RESPONSE | jq -r '.token')


curl -H "Authorization: Bearer $AUTH_TOKEN" \
     -H 'Content-Type: application/json' \
     -X POST \
     -d "$IMAGE_SCAN_REQUEST_PAYLOAD"\
     $TL_CONSOLE/api/v1/registry/scan


quick_check "/api/v1/registry/scan"

FULL_IMAGE_ID="$IMAGE_REGISTRY/$IMAGE_REPOSITORY:$IMAGE_TAG"


# Retrieves all the scanned images in the registry
GET_ALL_IMAGES=$(curl -H "Authorization: Bearer $AUTH_TOKEN" \
                      -H 'Content-Type: application/json' \
                      -X GET \
                      $TL_CONSOLE/api/v1/registry/names)

quick_check "/api/v1/registry/names"


# Ensures there's a scan entry in the Prisma Compute Console under registries
IMAGE_SCAN_CHECK=$(printf %s $GET_ALL_IMAGES | jq -r '.[]'| grep "$FULL_IMAGE_ID")

# If there is no entry wait the amount of time in seconds specified by the user and check again. If it fails a second time exit the script.
if [ -z "$IMAGE_SCAN_CHECK" ]
then echo "scan result not available yet, waiting $SCAN_WAIT_TIME seconds" & sleep $SCAN_WAIT_TIME
      GET_ALL_IMAGES=$(curl -H "Authorization: Bearer $AUTH_TOKEN" \
                            -H 'Content-Type: application/json' \
                            -X GET \
                            $TL_CONSOLE/api/v1/registry/names)

    quick_check "/api/v1/registry/names"
    IMAGE_SCAN_CHECK=$(printf %s $GET_ALL_IMAGES | jq -r '.[]' | grep "$FULL_IMAGE_ID")
      if [ -z "$IMAGE_SCAN_CHECK" ]
        then echo "Image scan report not available yet. Try later" & exit
      fi
  else echo "image scan result available, pulling report"
fi

REPORT_DATE=$(date  +%m_%d_%y)



# Retrieves the vulnerability report for the scanned image in the registry
curl -H "Authorization: Bearer $AUTH_TOKEN" \
     -H 'Content-Type: application/json' \
     -X GET \
     "$TL_CONSOLE/api/v1/registry/download?compact=false&repository=$IMAGE_REPOSITORY&registry=$IMAGE_REGISTRY" > "./$REPORT_DATE-$IMAGE_REPOSITORY:$IMAGE_TAG-scan_report.csv"


quick_check "api/v1/registry/download"

echo "report generated here: $PWD/$REPORT_DATE-$IMAGE_REPOSITORY:$IMAGE_TAG-scan_report.csv"
