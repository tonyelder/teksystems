This script was written as at the time, European servers had to be manually registered in the US CMDB.

This was a detailed process that took a long time per server, but I realised that most of the info could be pulled directly from the server after it was built. I then used Invoke-WebRequest to fill out the forms that the CMDB system used, and successfully automated the CI registration.

(Server names and domains redacted where appropriate)