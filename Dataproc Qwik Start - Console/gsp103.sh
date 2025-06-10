#!/bin/bash
clear

#---------------------------------- Colors ----------------------------------#
BOLD=$(tput bold)
RESET=$(tput sgr0)

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

BG_BLACK=$(tput setab 0)
BG_RED=$(tput setab 1)
BG_GREEN=$(tput setab 2)
BG_YELLOW=$(tput setab 3)
BG_BLUE=$(tput setab 4)
BG_MAGENTA=$(tput setab 5)
BG_CYAN=$(tput setab 6)
BG_WHITE=$(tput setab 7)

TEXT_COLORS=($RED $GREEN $YELLOW $BLUE $MAGENTA $CYAN)
BG_COLORS=($BG_RED $BG_GREEN $BG_YELLOW $BG_BLUE $BG_MAGENTA $BG_CYAN)

RANDOM_TEXT_COLOR=${TEXT_COLORS[$RANDOM % ${#TEXT_COLORS[@]}]}
RANDOM_BG_COLOR=${BG_COLORS[$RANDOM % ${#BG_COLORS[@]}]}

echo "${RANDOM_BG_COLOR}${RANDOM_TEXT_COLOR}${BOLD}Starting Execution${RESET}"

#------------------------------- Pre-checks ---------------------------------#
if [[ -z "$DEVSHELL_PROJECT_ID" ]]; then
    echo "${RED}${BOLD}Error: DEVSHELL_PROJECT_ID is not set.${RESET}"
    exit 1
fi

#----------------------------- Set Variables -------------------------------#
echo "${BOLD}${BLUE}Setting Compute Zone...${RESET}"
export ZONE=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-zone])")

echo "${BOLD}${GREEN}Setting Compute Region...${RESET}"
export REGION=$(gcloud compute project-info describe \
--format="value(commonInstanceMetadata.items[google-compute-default-region])")

echo "${BOLD}${YELLOW}Fetching Project Number...${RESET}"
export PROJECT_NUMBER=$(gcloud projects describe "$DEVSHELL_PROJECT_ID" --format="get(projectNumber)")

#--------------------------- IAM Role Binding ------------------------------#
echo "${BOLD}${MAGENTA}Granting Storage Admin Role...${RESET}"
gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"

echo "${BOLD}${CYAN}Granting Dataproc Worker Role...${RESET}"
gcloud projects add-iam-policy-binding "$DEVSHELL_PROJECT_ID" \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/dataproc.worker"

#----------------------------- Dataproc Setup -------------------------------#
echo "${BOLD}${RED}Creating Dataproc Cluster...${RESET}"
# Get subnet name in the current region (us-west4)
export SUBNET_NAME=$(gcloud compute networks subnets list \
  --filter="region=$REGION" \
  --format="value(name)" | head -n 1)

# Create Dataproc cluster with explicit subnet
gcloud dataproc clusters create example-cluster \
    --enable-component-gateway \
    --region "$REGION" \
    --zone "$ZONE" \
    --subnet "$SUBNET_NAME" \
    --master-machine-type e2-standard-2 \
    --master-boot-disk-size 30 \
    --num-workers 2 \
    --worker-machine-type e2-standard-2 \
    --worker-boot-disk-size 30 \
    --image-version 2.2-debian12 \
    --project "$DEVSHELL_PROJECT_ID"


#----------------------------- Submit Spark Job -----------------------------#
echo "${BOLD}${BLUE}Submitting Spark Job...${RESET}"
if ! gcloud dataproc jobs submit spark \
    --cluster example-cluster \
    --region "$REGION" \
    --class org.apache.spark.examples.SparkPi \
    --jars file:///usr/lib/spark/examples/jars/spark-examples.jar \
    -- 1000; then
    echo "${RED}${BOLD}Spark Job submission failed. Exiting.${RESET}"
    exit 1
fi

#-------------------------- Scale Cluster Up -------------------------------#
echo "${BOLD}${GREEN}Scaling Worker Count to 4...${RESET}"
gcloud dataproc clusters update example-cluster \
    --region "$REGION" \
    --num-workers 4

#------------------ Show Random Congrats Message ---------------------------#
function random_congrats() {
    MESSAGES=(
        "${GREEN}Congratulations For Completing The Lab!${RESET}"
        "${CYAN}Well done! Your hard work paid off!${RESET}"
        "${YELLOW}Amazing job!${RESET}"
        "${BLUE}Outstanding! You're a star!${RESET}"
        "${MAGENTA}Great work! Keep going!${RESET}"
        "${RED}Fantastic effort!${RESET}"
    )
    echo -e "${BOLD}${MESSAGES[$RANDOM % ${#MESSAGES[@]}]}"
}

echo
random_congrats
echo -e "\n"

#------------------------- Optional File Cleanup ---------------------------#
cd
read -p "${BOLD}${YELLOW}Do you want to remove lab files (gsp*, arc*, shell*)? (y/n): ${RESET}" confirm
if [[ "$confirm" == [yY] ]]; then
    for file in *; do
        if [[ "$file" == gsp* || "$file" == arc* || "$file" == shell* ]]; then
            if [[ -f "$file" ]]; then
                rm "$file"
                echo "File removed: $file"
            fi
        fi
    done
else
    echo "Cleanup skipped."
fi
