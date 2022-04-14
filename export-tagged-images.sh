#!/bin/bash
PROJECT_ID=""
TRAINING_KEY=""
ENDPOINT_SUFFIX=".api.cognitive.microsoft.com/"
ENDPOINT_PREFIX="https://"
REGION=""
IMAGE_CHUNK_SIZE=25
OUTPUT_DIR=""

# Full reference:
#https://southcentralus.dev.cognitive.microsoft.com/docs/services/Custom_Vision_Training_3.3/operations/5eb0bcc6548b571998fddec1


function parse_arguments(){
    POSITIONAL_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project-id)

            export PROJECT_ID="$2"
            shift # past argument
            shift # past value
            ;;
            --training-key)
            export TRAINING_KEY="$2"
            shift # past argument
            shift # past value
            ;;
            --region)
            export REGION="$2"
            shift # past argument
            shift # past value
            ;;
            -*|--*)
            echo "Unknown option '$1'"
            echo "To run this script, please use the arguments '--project-id', '--training-key', '--region'"
            echo "Example execution:"
            echo './export-tagged-images.sh --project-id "123-456-789" -–training-key "ABC-DEF-GHI" -–region "eastus2"'
            exit 1
            ;;
            *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift # past argument
            ;;
        esac
    done

    set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

    echo "PROJECT_ID                = ${PROJECT_ID}"
    echo "TRAINING_KEY              = --hidden--"
    echo "ENDPOINT_SUFFIX           = ${ENDPOINT_SUFFIX}"
    echo "ENDPOINT_PREFIX           = ${ENDPOINT_PREFIX}"
    echo "REGION                    = ${REGION}"
    echo "IMAGE_CHUNK_SIZE          = ${IMAGE_CHUNK_SIZE}"
    echo "OUTPUT_DIR                = ${OUTPUT_DIR}"

}

function getImagesAndTags(){
    URL_PREFIX=${ENDPOINT_PREFIX}${REGION}${ENDPOINT_SUFFIX}

    TOTAL_IMAGE_COUNT=$(curl -s $URL_PREFIX/customvision/v3.3/Training/projects/$PROJECT_ID/images/tagged/count  -H "Training-key: $TRAINING_KEY")

    echo "IMAGE COUNT: $TOTAL_IMAGE_COUNT"


    CURRENT_IMAGE_COUNT=0
    FILE_LOOP=0

    echo "Getting tags (batches of $IMAGE_CHUNK_SIZE)..."
    while [ $CURRENT_IMAGE_COUNT -le $TOTAL_IMAGE_COUNT ]
        do
        BATCH_CAP=$( expr $CURRENT_IMAGE_COUNT + $IMAGE_CHUNK_SIZE)
        echo -n "...Batch #$FILE_LOOP ($CURRENT_IMAGE_COUNT - $BATCH_CAP)..."
        FULL_URL="$URL_PREFIX/customvision/v3.3/Training/projects/$PROJECT_ID/images/tagged?skip=$CURRENT_IMAGE_COUNT&take=$IMAGE_CHUNK_SIZE"
        JSON_VALUE=$(curl -s $FULL_URL -H "Training-key: $TRAINING_KEY")

        IMG_NUM=0
        echo -n "images..."
        for row in $(echo "${JSON_VALUE}" | jq -r '.[] | @base64'); do
            _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
            }

            curl -s -o $OUTPUT_DIR/$(_jq '.id').jpg $(_jq '.originalImageUri')
            echo $(_jq '.') > $OUTPUT_DIR/$(_jq '.id').json
            ((IMG_NUM++))
        done

        echo "done"

        ((CURRENT_IMAGE_COUNT=$CURRENT_IMAGE_COUNT + $IMAGE_CHUNK_SIZE))
        ((FILE_LOOP++))
    done
    echo "done"

}

function getImages(){
    #IMG=$(cat ./output/tags/tagged_images_0.json)

    FULL_URL="https://westus2.api.cognitive.microsoft.com//customvision/v3.3/Training/projects/bba40958-5c75-4737-ad8c-5a7cf9b806b1/images/tagged?skip=0&take=25"
    JSON_VALUE=$(curl -s $FULL_URL -H "Training-key: $TRAINING_KEY")

    IMG_NUM=0
    echo "...Downloading Images..."
    for row in $(echo "${JSON_VALUE}" | jq -r '.[] | @base64'); do
        echo "...Downloading $IMG_NUM..."
        _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
        }

        curl -s -o $OUTPUT_DIR/$(_jq '.id').jpg $(_jq '.originalImageUri')
        echo $(_jq '.') > $OUTPUT_DIR/$(_jq '.id').json
        ((IMG_NUM++))
    done

}
function main(){
    echo "CustomVision Tag Exporter"
    echo "----------------------------------------"

    OUTPUT_DIR=$(printf '%(%Y-%m-%d_%H-%M)T\n' -1)
    OUTPUT_DIR="$PWD/output/$OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
    parse_arguments $@

    getImagesAndTags

    echo "----------------------------------------"
    echo "All done!"
}


main $@