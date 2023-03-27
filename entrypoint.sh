function trigger_workflow {
  echo "Triggering ${INPUT_EVENT_TYPE} in ${INPUT_OWNER}/${INPUT_REPO}"
  resp=$(curl -X POST -s "https://api.github.com/repos/${INPUT_OWNER}/${INPUT_REPO}/dispatches" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${INPUT_TOKEN}" \
    -d "{\"event_type\": \"${INPUT_EVENT_TYPE}\", \"client_payload\": ${INPUT_CLIENT_PAYLOAD} }")

  if [ -z "$resp" ]
  then
    sleep 2
  else
    echo "Workflow failed to trigger"
    echo "$resp"
    exit 1
  fi
}

function find_workflow {
  counter=0
  while [[ true ]]
  do
    counter=$(( $counter + 1 ))
    workflow=$(curl -s "https://api.github.com/repos/${INPUT_OWNER}/${INPUT_REPO}/actions/runs?event=repository_dispatch&sort:created" \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: Bearer ${INPUT_TOKEN}" |jq '[.workflow_runs[] | select(.display_title == $title)][0]' --arg title ${INPUT_EVENT_TYPE})

    wtime=$(echo $workflow | jq -r '.created_at')
    atime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ "$wtime" == null ]]
      then
        echo "Last workflow run not found"
        checkCounter
        continue
    fi

    wfid=$(echo $workflow | jq '.id')
    echo -e "\nAttempt #${counter}, workflow id: ${wfid}"
    echo "Last running action start time: ${wtime}"
    echo "Current time: ${atime}"

    tdif=$(( $(date -d "$atime" +"%s") - $(date -d "$wtime" +"%s") ))
    echo "Invoked ${tdif} seconds ago"

    if [[ "$tdif" -gt "10" ]]
    then
      checkCounter
    else
      break
    fi
  done

  conclusion=$(echo $workflow | jq '.conclusion')

  echo "Workflow id is ${wfid}"
}

function checkCounter {
  if [[ "$counter" -gt "3" ]]
    then
      echo "Workflow not found"
      exit 1
    else
      sleep 2
  fi
}

function wait_on_workflow {
  counter=0
  while [[ $conclusion == "null" ]]
  do
    if [[ "$counter" -ge "$INPUT_MAX_TIME" ]]
    then
      echo "Time limit exceeded"
      exit 1
    fi
    sleep $INPUT_WAIT_TIME
    conclusion=$(curl -s "https://api.github.com/repos/${INPUT_OWNER}/${INPUT_REPO}/actions/runs/${wfid}" \
    	-H "Accept: application/vnd.github.v3+json" \
    	-H "Authorization: Bearer ${INPUT_TOKEN}" | jq '.conclusion')
    counter=$(( $counter + $INPUT_WAIT_TIME ))
  done

  if [[ $conclusion == "\"success\"" ]]
  then
    echo "Workflow run successful"
  else
    echo "Workflow run failed"
    exit 1
  fi
}

function main {
  trigger_workflow
  find_workflow
  wait_on_workflow
}

main
