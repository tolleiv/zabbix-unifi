# zabbix-unifi
Monitoring Unifi APs with Zabbix.

These repository holds the original scripts from Sadman and some of my
changes (separate branch). The original source can be found in the
[Zabbix
Forum](https://www.zabbix.com/forum/showthread.php?p=164987#post164987).

Here's a installation guide:
---------------------------

* Include the unifi.conf into your Zabbix Agent configuration
* Push the perl miner script to the Unifi Appliance
* Import the XML into your Zabbix templates
* Adjust the Zabbix Macros to use the correct username and password

Miner Script Parameters:
------------------------

Command:

    unifi_miner.pl [-o object] [-i id] [-k key] [-l location] [-s site] [-u username] [-p password] [-v controller_ver] [-a action] [-d debug_level] [-n null_replacer]
   
   
Parameters:

    -o [ wlan ] Controller object type: `ap` or `wlan`
    -i Object ID. These are discovered through LLD
    -k metrics key, request a single value
    -l [ https://127.0.0.1:8443 ] URL of the Controller API
    -s [ default ] Unifi site name.
    -u [ stat ] username to access the Unifi API
    -p [ stat ] password to access the Unifi API
    -v [ v4 ] Unifi API version: `v2`, `v3`, `v4`
    -a [ count ] aggregation action which sshould be applied to the list of ojects (for example - all UAP): `count`, `sum`;
    -d [ 0 ] - debug level 0..3
    -n - substitude JSON:null values
    
Examples:

##### Get LLD-compatible JSON for a group of objects by default

     ./unifi_miner.pl

##### Get LLD-compatible JSON for access point groups

    ./unifi_miner.pl -o ap

##### Same thing, but when working with the controller v3, responsible for https://127.0.0.2:8443

    ./unifi_miner.pl -o ap -v v3 -l https://127.0.0.2:8443

##### Number of UAP, registered on the controller

    ./unifi_miner.pl -o ap -k items_num

##### Number of UAP, in a state of `adopted`

     ./unifi_miner.pl -o ap -k adopted -a sum

  * A quick note: some metrics, such as the adopted / isolated / is_guest have
  * Boolean nature and their number is calculated by simply summing the values.       

##### The number of clients served at the moment all the UAP

    ./unifi_miner.pl -o ap -k num_sta -a sum

##### The number of clients served at the moment a particular UAP

    ./unifi_miner.pl -o ap -i 5523fe519932508ffaf3b404 -k guest-num_sta

#####  The value in the table tx_dropped stat particular UAP

    ./unifi_miner.pl -o ap -i 5523fe519932508ffaf3b404 -k stat.tx_dropped

#####  Firmware version (software) specific UAP

    ./unifi_miner.pl -o ap -i 5523fe519932508ffaf3b404 -k version

#####  The number of guest networks to support specific UAP

    ./unifi_miner.pl -o ap -i 5523fe519932508ffaf3b404 -k vap_table.is_guest -a sum

##### Getting all object IDs and keys

    ./unifi_miner.pl -o ap -d 3> report.txt
    
    
Cedits
------

The initial scripts, command documentation and command exmaples where provided by [Sadman](https://www.zabbix.com/forum/member.php?u=38123). All credit /copyright/ cheering should go to him.

