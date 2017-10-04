$inputFile = Read-Host "Enter the Input CSV filename"
$outputFile = Read-Host "Enter the Output TXT filename"
$outputFileFailed = Read-Host "Enter the Failed Results TXT filename"


$trimmedAndDedupped = (Get-Content $inputFile) |
    # removes blank lines
    where {$_} |
    # blanks first '/', then zero or more(*) characters(.) to the end of the line($)
    ForEach-Object {$_ -replace '/.*$', ''} |
    # blanks 'www.' at the beginning of the line. the [1-9]? takes into account 'www2.' examples
    ForEach-Object {$_ -replace '^w{3}[1-9]?\.',''} |
    sort -Unique

# The following code block takes the trimmed and deduped input from above and sends slices of that array to the
# Test-Connection cmdlet. Thankfully the Test-Connection cmdlet has the -AsJob switch, which allows it to be
# backgrounded as concurrent jobs to allow for multi-threading which greatly speeds the script up. The only downside
# is that if there are more than ~500 objects to process the Receive-Job cmdlet throws a Quota Violation error. Hence,
# the need to send slices of the $trimmedAndDedupped array to Test-Connection as opposed to the whole thing. I
# received tremendous help from beefarino's answer to this question on stackoverflow,
# http://stackoverflow.com/questions/4740698/powershell-receive-job-quota-violation-when-invoking-command-as-a-job/, as
# well as this blog post, http://myitramblings.blogspot.com/2016/01/its-been-long-time-since-my-last-post.html, which
# also gained help from the same stackoverflow question and answer.
########################################################################################################################
# Choose how many targets each Test-Connection job will process
$i = 100
# j provides bottom end number of every array slice sent to a test-connection background job as well as parameter to
# tell script when to stop in the While loop condition
$j = 0
While ($j -le $trimmedAndDedupped.length)
{
   Test-Connection -ComputerName $trimmedAndDedupped[$j..$i] -ErrorAction SilentlyContinue -Count 1 -AsJob
   $j=$i+1
   $i+=100
}
Get-Job|Wait-Job
$testConnectionResults = Get-Job | Receive-Job -Wait -AutoRemoveJob | Select-Object address,ipv4address
########################################################################################################################


$testConnectionResults | Where-Object {$_.ipv4address -match "\."} | Select-Object -ExpandProperty address |
Sort-Object | Out-File -FilePath $outputFile

$testConnectionResults | Where-Object {$_.ipv4address -notmatch "\."} | Select-Object -ExpandProperty address |
Sort-Object | Out-File -FilePath $outputFileFailed