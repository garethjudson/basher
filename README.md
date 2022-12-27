# basher
simple bash concurrent load generator

Sometimes you just want to gauge rough performance, or easily generate load for debugging without using/learning/setting up a whole load test framework.

## quick start
### dependencies
You need bash, curl and general shell utils (e.g. grep, ls, date, bc, ps)
Bash is required. Developed using GNU bash, version 3.2.57
If you want your timings more precise than seconds, you need gnu date. 
If not on system where the default date utility is gnu (e.g. mac) install coreutils and make sure 'gdate' is avialable to the script.

### how to use
Checkout/copy/get the script. Put it in a directory somewhere....
Simple test:

```
./basher.sh -u "http://localhost:8080" -t 10 -c 5 
```
The script will launch 5 concurrent curl requests (GET by default with no body). It will by default send all requests, then check if the processes are still live iteratively. Sleeps if the first process is still live. Waits the sleep time (5s by default), then checks again, until either all process have completed, or the time out has been reached. Timeout is approximate as, the sleep time could push the total time over slightly.

The script will output results to a directory (by default ./report/run_stats)
example script console output:

```
➜  basher git:(main) ✗ ./basher.sh -u "https://www.google.com" -t 10 -c 5
Basher bash https://www.google.com 5 times!!! Run id is: 8224. Results output to ./report/run_stats/8224
Sleeping for 5 seconds as process has not finished! 0 seconds have elapsed total.
All 5 requests finished within 10 seconds wait time, total time to complete all requests 5.03 seconds!!
status code counts:
2xx:        5
3xx:        0
4xx:        0
5xx:        0
???:        0
tot:        5
```

The output structure of the above:
```report -> 
  run_status ->
    8224 ->
      0_output
      0_stats.txt
      1_output
      1_stats.txt
      2_output
      2_stats.txt
      3_output
      3_stats.txt
      4_output
      4_stats.txt
```
Where the x_output files contain the html output body and the x_stats.txt are formated as follows:
```
endpoint: https://www.google.com
method: GET
contentType: application/json

outputStatus: 200
outputFile: ./report/run_stats/8224/0_output
outputFileSizeH:  16K
outputFileSizeKB: 16

run time (just different units):
nanos: 419897000
milis: 419
seconds: .41
minutes: 0
```

The intention is to have some rudimentary output for evaluation or debugging of a specific api or endpoint.

## usage docs from script
```
usage:
required options:
  -u --url                      the endpoint to hit (should be http or https)

other options:
  -h --help                     display this help message

  -b --requestBody              the body of the request to send with the request (supports a file with '@./filepath' syntax)
  -c --concurrentRequestCount   the number of requests to send concurrently, default 20
  -f --outputFileNameSuffix     file the reponse body, default 'output', resulting in ouput in the output directory of "\${id}_\${outputFileNameSuffix}"
  -k --contentType              the value to put the in the contentType header, default is application/json
  -m --requestMethod            the request method (GET, POST, PUT ...etc) default 'GET'
  -s --sleepTime                how many seconds to sleep between checking if the requests have completed, default 5
  -t --timeOut                  how many seconds before the script should stop checking for completions and kill outstanding requests, default 60s
```
## Docker Instructions
Don't want to install dependencies! No worries, Included a dockerfile. Build it yourself:
build the container

`docker build -t basher .`


run it with docker e.g.:


`docker run -v ./report:/report -u www.google.com`
