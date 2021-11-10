## Set up the Prisma Cloud WAAS 

written by Kyle Butler

last edited by John Chavanne

* Step 1: Go to Prisma Console > Compute (Enterprise Edition ONLY) > Defend > WAAS
* Step 2: Click ‘Add Rule’
* Step 3: Rule Name: SQL Injection Defense
* Step 4: Then click in the 'Scope' field
* Step 5: Check boxes of all images that have dvwa in them.
  * Step 5a: If there are none, click 'Add Collection', type in a name, type in 'dvwa' in the image field, select the image(s), and click 'Save'
  * Step 5b: Ensure you have the 'dvwa' boxes checked and click 'Select collections'
* Step 6: Click ‘Add New App’
* Step 7: On the next pop-up click the ‘+ Add Endpoint’ 
* Step 8: Enter 80 for App port (internal port) then hit ‘Create’
* Step 9: Click the ‘App Firewall' tab and under SQL Injection confirm it is set to Alert. 
* Step 10: Click ‘Save’

## Log into the DVWA Web App

* username: admin
* password: password

## Click the SQL Injection Link on the right-hand menu

Explain how a SQL Injection attack works:

* Whenever you're interacting with a web app there's a high probability that it's leveraging PHP on the back-end. At the time of this writing PHP is used by 79.2% of all websites according to [W3tech.com](https://w3techs.com/technologies/details/pl-php). Any place on a website where a user is entering information is a potential attack surface for a hacker or bad actor. 
* In this demo we'll show how the Prisma Cloud Compute's WAAS (Web Application and API Security) can quickly and efficiently protect a client's website. 
* Below is the function which is running on the backend of the DVWA web app. 

```
<?php

if( isset( $_REQUEST[ 'Submit' ] ) ) {
    // Get input
    $id = $_REQUEST[ 'id' ];

    // Check database
    $query  = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";
    $result = mysqli_query($GLOBALS["___mysqli_ston"],  $query ) or die( '<pre>' . ((is_object($GLOBALS["___mysqli_ston"])) ? mysqli_error($GLOBALS["___mysqli_ston"]) : (($___mysqli_res = mysqli_connect_error()) ? $___mysqli_res : false)) . '</pre>' );

    // Get results
    while( $row = mysqli_fetch_assoc( $result ) ) {
        // Get values
        $first = $row["first_name"];
        $last  = $row["last_name"];

        // Feedback for end user
        echo "<pre>ID: {$id}<br />First name: {$first}<br />Surname: {$last}</pre>";
    }

    mysqli_close($GLOBALS["___mysqli_ston"]);
}

?>
```
* In this example we'll take advantage of the query section of the function: `$query  = "SELECT first_name, last_name FROM users WHERE user_id = '$id';";`

* As a first step we'll enter a `1` into the username field and then hit enter. Notice the web address in the browser address bar changes from `https://dvwa-master-kbtestv2.kbutlerv2.demo.twistlock.com/vulnerabilities/sqli/` to `https://dvwa-master-kbtestv2.kbutlerv2.demo.twistlock.com/vulnerabilities/sqli/?id=1&Submit=Submit#`.
* This tells us a very important piece of information. Notice the end of this address `id=1&Submit=Submit#`. If we enter a `2` in the username field we'll see that value at the end of the address update to `id=2&Submit=Submit#`. 
* We'll quickly walkthrough a chain of modifications an attacker might use to get the user names and passwords back from the DVWA database. 

    * The first thing we'll do is set the query to return all the users from database by entering `1' or '1=1'#`. This changes the query to `$query  = "SELECT first_name, last_name FROM users WHERE user_id = '1' or '1=1'#;";`; where the `#` comments out the rest of the code in the PHP function. The `1` in this instance is really just a guess, but the `1=1` allows the statement to always be true. So in essence it will loop through the table and return every user. 
    * The next thing we'd want to do is attempt and get the version of the database running on the backend by expanding our injection to `1' or '1=1' union select null, version ()#`. Note the last entry that's displayed under the last Users Surname. 
    * Next we'll get the service account from the backend database which is ultimately executing our queries. We'll alter our query slightly to `1' or '1=1' union select null, user()#`. This provides us with the database account executing the queries, which could be userful for other attacks down the line. 
    * After that it makes sense to get the name of the database by entering `1' or '1=1' union select null, database ()#`
    * And the table which contains the user passwords `1' and '1=0' union select null, table_name from information_schema.tables where table_name like 'user%'#`
    * The second to the last query will allow us to get the name of the column containing the passwords `1' and '1=0' union select null, concat(table_name,0x0a,column_name) from information_schema.columns where table_name = 'users' #`
    * Finally, because the attacker now knows the all the pieces of the puzzle they'll be able to execute the last query which will provide the attacker with the encrypted passwords and the usernames. `1' and '1=0' union select null, concat(first_name,0x0a,last_name,0x0a,user,0x0a,password) from users #`. 
    

## (OPTIONAL) Retrieve the passwords using Kali Linux and John the Ripper
    
John the ripper (From Kali Linux 2021.1) commands:

* From terminal `nano password.txt` copy and paste the username and the encrypted password into the text document one line at time in a format like this: `<USERNAME>:<ENCRYPTED_PASSWORD>`. Save the file and exit (ctl + X; respond with Y and hit enter)
* To install john-the-ripper in the lab: `sudo snap install john-the-ripper` password is `5minuteabs!`
* At the terminal prompt enter: `john --format=Raw-MD5 password.txt`; then `john --show --format=Raw-MD5 password.txt`


## Check on WAAS Events in Prisma Cloud Compute

* Go to the Prisma Console and check the alerts under Monitor > Events > select WAAS for Containers 
  --note the time stamp of alert and your time.
* Set the WAAS Firewall behavior to Ban on SQL Injection detection. 
* Then go back to DVWA to attempt the SQL injection attacks again. 
* Watch the user account get banned permanently. 

## Links/Articles pertaining to SQL Injection

* [Dark Reading - SQL injection attacks represent two thirds of all web app attacks](https://www.darkreading.com/attacks-breaches/sql-injection-attacks-represent-two-third-of-all-web-app-attacks/d/d-id/1334960)

* [SQL Injection Vulnerability In Sophos XG Firewall That Was Under Active Exploit - April 28 2020](https://latesthackingnews.com/2020/04/28/sql-injection-vulnerability-in-sophos-xg-firewall-that-was-under-active-exploit/)

* [Types of SQL Injection Attacks](https://latesthackingnews.com/2017/10/31/types-of-sql-injection/)
