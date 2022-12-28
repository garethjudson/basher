#!/usr/bin/env bash
function output_basher_usage() {
  cat <<END
  basher is a script to launch concurrent load against an http endpoint
  it's not intended as a full load testing suite
  sometimes you just want to gauge rough performance, or easily generate load for debugging without using/learning/setting up a whole load test framework.


  usage:
  required options:
    -u --url                      the endpoint to hit (should be http or https)

  other options:
    -h --help                     display this help message

    -b --requestBody              the body of the request to send with the request
    -c --concurrentRequestCount   the number of requests to send concurrently, default 20
    -f --outputFileNameSuffix     file the reponse body, default 'output', resulting in ouput in the output directory of "\${id}_\${outputFileNameSuffix}"
    -k --contentType              the value to put the in the contentType header, default is application/json
    -m --requestMethod            the request method (GET, POST, PUT ...etc) default 'GET'
    -s --sleepTime                how many seconds to sleep between checking if the requests have completed, default 5
    -t --timeOut                  how many seconds before the script should stop checking for completions and kill outstanding requests, default 60s
END
}

function output_requester_usage() {
  cat <<END
  requester is a script that wraps a curl command. It does some rudimentary timing, records the output of the http requests and some additional information.

  usage:
  required options:
    -u --url                      the endpoint to hit (should be http or https)

  other options:
    -h --help                     display this help message
    -b --body                     the body of the request, default is empty
    -d --outputDirectory          directory to output the results of this request, default './report/run_stats/'
    -f --outputFileNameSuffix     file the reponse body, default 'output', resulting in ouput in the output directory of "\${id}_\${outputFileNameSuffix}"
    -i --id                       the id of this request (will be a random int if not passed in)
    -k --contentType              the content type header, default 'application/json'
    -m --requestMethod            the request method (GET, POST, PUT ...etc) default 'GET'
END
}

function date_exec_to_use () {
  # some systems don't support nanos from date, please try gdate from coreutils --works for many non-gnu systems e.g. osx
  # otherwise we f'd
  if which gdate >/dev/null; then
    echo 'gdate +%s%N'
  elif [[ "$(date +%s%N)" =~ .*N$ ]]; then
    # no precision dates ### oh dear, just add 000's to the end. No millis or nanos for you!
    echo 'date +%s000000000'
  else
    echo 'date +%s%N'
  fi
}

function requester() {
  local id method body content_type output_file_name_suffix url output_dir

  id="${RANDOM}"
  method="GET"
  body=""
  content_type='application/json'
  output_file_name_suffix="output"
  url=""
  output_dir="./report/run_stats/"

  if [[ -n "${1:-}" ]]; then
    while [[ "${1:-}" =~ ^- && ! "${1:-}" == "--" ]]; do
      case ${1} in
      -b | --body)
        shift
        body="${1}"
        ;;
      -d | --outputDirectory)
        shift
        output_dir="${1}"
        ;;
      -f | --outputFileName)
        shift
        output_file_name_suffix="${1}"
        ;;
      -i | --id)
        shift
        id="${1}"
        ;;
      -k | --contentType)
        shift
        content_type="${1}"
        ;;
      -m | --httpMethod)
        shift
        method="${1}"
        ;;
      -u | --url)
        shift
        url="${1}"
        ;;
      -*)
        output_requester_usage
        exit 1
        ;;
      esac
      shift
    done
    if [[ "${1:-}" == '--' ]]; then shift; fi
  fi

  if [[ "${url}" == "" ]]; then
    echo "Url (-u) must be provided"
    output_requester_usage
    exit 1
  fi

  local output_status date_exec start
  local output_file="${output_dir}/${id}_${output_file_name_suffix}"
  local stats_file="${output_dir}/${id}_stats.txt"

  mkdir -p "${output_dir}"

  date_exec="$(date_exec_to_use)"
  start=$($date_exec)
  if [[ "${body}" != "" ]]; then
      output_status="$(curl -s -X "${method}" -w "%{http_code}" --header "Content-Type:${content_type}" -d "${body}" --output "${output_file}" "${url}")"
  else
      output_status="$(curl -s -X "${method}" -w "%{http_code}" --output "${output_file}" "${url}")"
  fi
  end="$($date_exec)"
  nanos=$((end-start))
  milis=$(echo "${nanos} / 1000000" | bc)

  seconds=$(echo "scale=2; $milis / 1000" | bc)
  minutes=$(echo "scale=2; $seconds / 60" | bc)

  cat <<END > "${stats_file}"
endpoint: ${url}
method: ${method}
contentType: ${content_type}

outputStatus: ${output_status}
outputFile: ${output_file}
outputFileSizeH: $(du -h "${output_file}" | cut -f1)
outputFileSizeKB: $(du -k "${output_file}" | cut -f1)

run time (just different units):
nanos: ${nanos}
milis: ${milis}
seconds: ${seconds}
minutes: ${minutes}
END
}

function basher() {
  local concurrent_requests sleep_seconds time_out url request_body request_method run_id output_file_name_suffix content_type

  run_id="${RANDOM}"
  concurrent_requests=20
  sleep_seconds=5
  time_out=60
  output_file_name_suffix="output"
  content_type="application/json"
  request_method="GET"

  if [[ -n "${1:-}" ]]; then
    while [[ "${1:-}" =~ ^- && ! "${1:-}" == "--" ]]; do
      case "${1}" in
      -b | --requestBody)
        shift
        request_body="${1}"
        ;;
      -c | --concurrentRequestCount)
        shift
        concurrent_requests="${1}"
        ;;
      -f | --outputFileNameSuffix)
        shift
        output_file_name_suffix="${1}"
        ;;
      -m | --requestMethod)
        shift
        request_method="${1}"
        ;;
      -k | --contentType)
        shift
        content_type="${1}"
        ;;
      -s | --sleepTime)
        shift
        sleep_seconds="${1}"
        ;;
      -t | --timeOut)
        shift
        time_out="${1}"
        ;;
      -u | --url)
        shift
        url="${1}"
        ;;
      -*)
        output_basher_usage
        exit 1
        ;;
      esac
      shift
    done
    if [[ "${1:-}" == '--' ]]; then shift; fi
  fi

  if [[ "${url}" == "" ]]; then
    echo "Url (-u) must be provided"
    output_basher_usage
    exit 1
  fi

  local processIds=()
  local output_dir="./report/run_stats/${run_id}"

  echo "Basher bash ${url} ${concurrent_requests} times!!! Run id is: ${run_id}. Results output to ${output_dir}"

  for ((i = 0 ; i < concurrent_requests ; i++)); do
   requester -m "${request_method}" -b "${request_body}" -k "${content_type}" -f "${output_file_name_suffix}" -u "${url}" -i "${i}" -d "${output_dir}" &
   processIds[i]=$!
  done

  local total_failures=0
  local killed_processes=""
  local date_exec start now counter seconds empty_respone_count

  date_exec="$(date_exec_to_use)"
  start=$(${date_exec})
  counter=0
  for i in "${processIds[@]}"; do
    while true; do
      if [[ -z "$(ps -o pid= "${i}")" ]]; then
        break
      fi
      now="$(${date_exec})"
      seconds="$(echo "scale=2; (${now} - ${start}) / 1000000 / 1000" | bc)"

      if [[ ${time_out} -eq 0 || $(echo "${seconds} < ${time_out}" | bc) == 1 ]]; then
        echo "Sleeping for ${sleep_seconds} seconds as process has not finished! ${seconds} seconds have elapsed total."
        sleep "${sleep_seconds}"
      else
        kill "${i}"
        wait "${i}" 2>/dev/null
        killed_processes="${killed_processes}${counter}[pid: ${i}] "
        total_failures=$((total_failures + 1))
        break
      fi
    done
    counter=$((counter + 1))
  done
  now="$(${date_exec})"
  seconds="$(echo "scale=2; (${now} - ${start}) / 1000000 / 1000" | bc)"

  if [[ "${killed_processes}" != "" ]]; then
    if [[ "${time_out}" -eq 0 ]]; then
      time_out="infinity"
    fi
    echo "Several processes did not complete within timeout of ${time_out} seconds. Request ids killed: ${killed_processes}"
  fi

  counter=0
  if [[ ${total_failures} -gt 0 ]]; then
    echo "There were ${total_failures} known request failures. Most likely they didn't complete within the ${time_out} seconds wait time!!"
  fi

  local failure_string=""
  while [[ ${counter} -lt ${concurrent_requests} ]]; do
    if [[ ! (-e "${output_dir}/${counter}_stats.txt") ]]; then
      failure_string="${failure_string}${counter} "
    fi
    counter=$((counter + 1))
  done

  if [[ "${failure_string}" != "" ]]; then
    echo "The following requests did not complete within ${time_out} seconds (elapsed ${seconds} seconds): ${failure_string}"
  else
    echo "All ${concurrent_requests} requests finished within ${time_out} seconds wait time, total time to complete all requests ${seconds} seconds!!"
  fi

  echo "status code counts:"
  for i in {2..5}; do
    echo "${i}xx: $(grep -rnw "${output_dir}"/*_stats.txt -e "outputStatus: ${i}[0-9][0-9]" | wc -l)"
  done
  echo "???: $(grep -rnw "${output_dir}"/*_stats.txt -e "outputStatus: [^2345][0-9][0-9]" | wc -l)"
  echo "tot: $(ls -dq "${output_dir}"/*_stats.txt | wc -l)"

  empty_respone_count="$(grep -rnw "${output_dir}"/*_stats.txt -e "outputFileSizeKB: 0\s+" | wc -l)"

  if [[ "${empty_respone_count}" -gt 0 ]]; then
    echo "There were ${empty_respone_count} empty responses"
  fi
}

basher "$@"
