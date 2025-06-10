#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`

# Array of color codes excluding black and white
TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

# Pick random colors
RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

#----------------------------------------------------start--------------------------------------------------#

echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD}Starting Execution${RESET}"

# Step 1: Set Compute Zone
echo "${BOLD}${BLUE}Setting Compute Zone${RESET}"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

# Step 2: Set Compute Region
echo "${BOLD}${GREEN}Setting Compute Region${RESET}"
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

# Step 3: Get Project Number
echo "${BOLD}${YELLOW}Getting Project Number${RESET}"
export PROJECT_NUMBER="$(gcloud projects describe $DEVSHELL_PROJECT_ID --format='get(projectNumber)')"

# ----------------- FIX STARTS HERE: ADD THIS BLOCK ----------------- #
# Step 3.5: Grant Dataproc Service Agent Role
echo "${BOLD}${WHITE}Granting Dataproc Service Agent role to the Dataproc service account${RESET}"
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:service-$PROJECT_NUMBER@dataproc-accounts.iam.gserviceaccount.com \
    --role roles/dataproc.serviceAgent
# ------------------------- FIX ENDS HERE ------------------------- #

# Step 4: Grant Storage Admin Role to Compute Service Account (for workers)
echo "${BOLD}${MAGENTA}Granting Storage Admin Role to Compute Service Account${RESET}"
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --role roles/storage.objectAdmin

# Step 5: Grant Dataproc Worker Role to Compute Service Account (for workers)
echo "${BOLD}${CYAN}Granting Dataproc Worker Role to Compute Service Account${RESET}"
gcloud projects add-iam-policy-binding $DEVSHELL_PROJECT_ID \
    --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com \
    --role roles/dataproc.worker

# Step 6: Create Dataproc Cluster
echo "${BOLD}${RED}Creating Dataproc Cluster${RESET}"
gcloud dataproc clusters create example-cluster \
    --enable-component-gateway \
    --region $REGION \
    --zone $ZONE \
    --master-machine-type e2-standard-2 \
    --master-boot-disk-size 30 \
    --num-workers 2 \
    --worker-machine-type e2-standard-2 \
    --worker-boot-disk-size 30 \
    --image-version 2.2-debian12 \
    --project $DEVSHELL_PROJECT_ID

# Step 7: Submit Spark Job
echo "${BOLD}${BLUE}Submitting Spark Job to Cluster${RESET}"
gcloud dataproc jobs submit spark \
    --cluster example-cluster \
    --region $REGION \
    --class org.apache.spark.examples.SparkPi \
    --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
    -- 1000

# Step 8: Update Cluster Worker Count
echo "${BOLD}${GREEN}Updating Cluster to Increase Number of Workers${RESET}"
gcloud dataproc clusters update example-cluster \
    --region $REGION \
    --num-workers 4

echo

# Function to display a random congratulatory message
function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab! Keep up the great work!${RESET}"
        "${CYAN}Well done! Your hard work and effort have paid off!${RESET}"
        "${YELLOW}Amazing job! You’ve successfully completed the lab!${RESET}"
    )
    RANDOM_INDEX=$((RANDOM % ${#MESSAGES[@]}))
    echo -e "${BOLD}${MESSAGES[$RANDOM_INDEX]}"
}

# Display a random congratulatory message
random_congrats

echo -e "\n"

cd

remove_files() {
    for file in *; do
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            if [[ -f "$file" ]]; then
                rm "$file"
                echo "File removed: $file"
            fi
        fi
    done
}

remove_files
