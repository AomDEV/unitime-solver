#!/bin/bash

export $(grep -v '^#' .env | xargs)
TASK_ID=$1

echo ":: CPSolver ::"
sleep 5

# CHECK `TASK_ID` IS NOT EMPTY
if [ -z "$TASK_ID" ]; then
    # FETCH TASK_ID FROM API (POST)
    echo "[LOG] Fetching task ID from $API_URL/task/accept"
    ACCEPTED_TASK=$(curl -s "$API_URL/task/accept")
    TASK_ID=$(echo $ACCEPTED_TASK | jq -r '.data.id')

    if [ -z "$TASK_ID" ]; then
        echo "Usage: solver.sh <task_id>"
        exit 1
    fi
fi

# CHECK `TASK_ID` IS NULLABLE OR EQUALS TO "null"
if [ "$TASK_ID" = "null" ]; then
    echo "Error: No task ID provided"
    exit 1
fi
if [ -z "$TASK_ID" ]; then
    echo "Error: No task ID provided"
    exit 1
fi

# CHECK `TASK_ID` IS NUMERIC
if ! [[ "$TASK_ID" =~ ^[0-9]+$ ]]; then
    echo "Error: Task ID must be numeric ($TASK_ID)"
    exit 1
fi

# CREATE FOLDER `task` IF NOT EXISTS
if [ ! -d "task" ]; then
    mkdir task
fi

# DELETE ALL FILE IN `task`
rm -rf task/*

echo "[INFO] Task ID is $TASK_ID"
echo "[INFO] Version is $BUILD_VERSION"

# REMOVE OLD SOLVER AND DEPENDENCIES
rm -rf cpsolver

# CREATE FOLDER `cpsolver` IF NOT EXISTS
if [ ! -d "cpsolver" ]; then
    mkdir cpsolver
fi

# DOWNLOAD SOLVER FROM GITHUB
echo "[LOG] Downloading solver v$BUILD_VERSION"
SOLVER_URL="https://builds.unitime.org/cpsolver-$BUILD_VERSION.zip"
curl -s -o cpsolver.zip "$SOLVER_URL"
unzip -qq cpsolver.zip -d cpsolver/tmp
rm -rf cpsolver.zip

# SETUP SOLVER
echo "[LOG] Setting up solver"
mv ./cpsolver/tmp/bin/cpsolver-all-$SOLVER_VERSION.jar ./cpsolver/cpsolver.jar
mv ./cpsolver/tmp/lib/* ./cpsolver/
rm -rf cpsolver/tmp

# DOWNLOAD XML FROM URL
FILE_PATH="task/$TASK_ID.xml"
echo "[LOG] Downloading XML from $API_URL/task/$TASK_ID"
curl -s -X POST "$API_URL/task/$TASK_ID/accept" -H 'Content-Type: application/json' -d "{\"key\": \"$SECRET_KEY\"}" -o $FILE_PATH
echo "[LOG] Checking XML file $FILE_PATH"

# CHECK IF FILE EXISTS
if [ ! -f "$FILE_PATH" ]; then
  echo "[ERROR] XML file $FILE_PATH not found"
  exit 1
fi

echo "[LOG] Reading XML"
# CHECK FILE SIZE
FILE_SIZE=$(wc -c < "$FILE_PATH")
echo "[INFO] XML file size is $FILE_SIZE bytes"

echo "[LOG] Executing solver"

# RUN SOLVER
echo "============================================"
java -Xmx1g -cp cpsolver/cpsolver.jar org.cpsolver.exam.Test config.default.cfg $FILE_PATH ./task/out_$TASK_ID.xml
echo "============================================"

# CLEAN UP
echo "[LOG] Cleaning up"
rm -rf cpsolver/*

# SEND XML TO API
echo "[LOG] Sending XML to server"
# Read file and encode to base64
FILE_CONTENT=$(cat ./task/out_$TASK_ID.xml | base64)
FILE_SIZE=$(wc -c < ./task/out_$TASK_ID.xml)
echo "[LOG] XML file content size is $FILE_SIZE bytes"

COMPLETION_CONTENT=$(curl -i -s -X POST "$API_URL/task/$TASK_ID/complete" -H 'Content-Type: application/json' -d "{\"key\": \"$SECRET_KEY\", \"output\": \"$FILE_CONTENT\"}")
echo "[LOG] Server response: $COMPLETION_CONTENT"