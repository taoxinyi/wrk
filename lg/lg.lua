-- the global thread counter
local thread_count = 1
-- 2d array thread_urls_map[thread_id] = [url1, url2, url3, ...] is the urls thread_id responsible for
thread_urls_map = {}
-- whether the file is loaded or not
loaded = false
local threads = {}
local length = {}
local BUFSIZE = 2 ^ 30


-- In the setup phase, the first thread will read the whole file,
-- and distribute the lines evenly to all threads in **thread_url_map**, which is a 2-d array
-- lines[thread_id] = [url1, url2, url3, ...]
-- then put the urls array to that thread
-- Therefore, the file will be read only once and separated to each thread
--
function setup(thread)
    table.insert(threads, thread)

    local file = os.getenv("FILE")
    local n_threads = tonumber(os.getenv("THREADS"))

    if (file == nil) then
        print("No file is specified\n")
        os.exit()
    end

    -- set thread id for each thread, for debugging purposes
    thread:set("id", thread_count)
    thread_count = thread_count + 1

    -- the file is already loaded, just set the urls to the thread
    if (loaded) then
        thread:set("urls", thread_urls_map[thread_count - 1])
        printf("Urls set for thread %d \n", thread_count - 1)
        return
    end

    -- the first time load the file
    -- initialize the lines with the number of threads
    for i = 1, n_threads do
        thread_urls_map[i] = {}
        length[i] = 1
    end

    -- make sure file exists
    local f = io.open(file, "r")
    if f == nil then
        printf("%s cannot be found\n")
        os.exit()
    end
    f.close()

    -- read the files and update lines
    -- so each thread i will responsible for the line_no i, thread_count + i, 2 * thread_count + i, ....
    local thread_idx = 1

    for line in io.lines(file) do
        thread_urls_map[thread_idx][length[thread_idx]] = line
        length[thread_idx] = length[thread_idx] + 1
        thread_idx = thread_idx + 1
        if (thread_idx > n_threads) then
            thread_idx = 1
        end
    end


    -- the file is loaded for the first time
    loaded = true
    printf("%s is loaded\n", file)
    -- set the lines to the for the first thread. Subsequently threads don't need to read it again
    thread:set("urls", thread_urls_map[1])
    printf("Urls set for thread %d \n", thread_count - 1)

end

printf = function(s, ...)
    return io.write(s:format(...))
end
init = function(args)
    non_200 = 0
end

local line_no = 1
-- For each thread, sending its corresponding urls
request = function()
    local path = urls[line_no]
    line_no = line_no + 1
    -- If the line_no is larger than the array length then reset it
    if line_no > #urls then
        line_no = 1
    end
    -- printf("%d send %s\n", id, path)
    -- Return the request object with the current URL path
    return wrk.format(nil, path)
end
-- record non 200 response for each thread
response = function(status, headers, body)
    if status ~= 200 then
        non_200 = non_200 + 1
    end
    --print(body)
end

done = function(summary, latency, requests)
    print("Details")
    print("[Latency]")
    for _, p in pairs({ 50, 90, 99, 99.999 }) do
        n = latency:percentile(p) / 1000
        printf("%-22s %.3fms\n", string.format("%g%%", p), n)
    end
    printf("%-22s %.3fms\n", "Min", latency.min / 1000)
    printf("%-22s %.3fms\n", "Max", latency.max / 1000)
    printf("%-22s %.3fms\n", "Mean", latency.mean / 1000)
    printf("%-22s %.3fms\n", "Stdev", latency.stdev / 1000)

    print("[Errors]")
    local errors = summary.errors;
    -- sum non 200 response for each thread
    local non_200_sum = 0
    for _, thread in ipairs(threads) do
        non_200_sum = non_200_sum + thread:get("non_200")
    end
    local total_errors = errors.read + errors.write + errors.timeout + non_200_sum
    printf("%-22s %d\n", "Connect", errors.connect)
    printf("%-22s %d\n", "Read", errors.read)
    printf("%-22s %d\n", "Write", errors.write)
    printf("%-22s %d\n", "Timeout", errors.timeout)
    printf("%-22s %d\n", "Non 200", non_200_sum)
    printf("%-22s %d\n", "Total", total_errors)

    print("[Summary]")
    local duration_sec = summary.duration / 1000000
    local bytes_mb = summary.bytes / 1048576

    printf("%-22s %.5fs\n", "Duration", duration_sec)
    printf("%-22s %.5fMB\n", "Total Bytes", bytes_mb)
    printf("%-22s %d\n", "Total Requests", summary.requests)
    printf("%-22s %s\n", "Connection Error Rate", string.format("%g%%", errors.connect * 100 / tonumber(os.getenv("CONNECTIONS"))))
    printf("%-22s %s\n", "Request Error Rate", string.format("%g%%", total_errors * 100 / summary.requests))
    printf("%-22s %.5fMB/s\n", "Throughput", bytes_mb / duration_sec)
    printf("%-22s %.2f\n", "Requests/sec", summary.requests / duration_sec)
end