#!/bin/bash

wget https://raw.githubusercontent.com/michalteofan/jenklab/master/vminit.sh
chmod +x vminit.sh
./vminit.sh DBROOTPASSWD DBNAME DBUSER DBPASSWORD
