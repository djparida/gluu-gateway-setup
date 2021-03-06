#!/bin/bash

DISTRIBUTION=$1
OP_HOST=$2
HOST=$3
HOST_IP=$4
OXD_HOST=$5

function prepareSourcesBionic {
    sleep 120
    apt-get update
    echo "deb https://repo.gluu.org/ubuntu/ bionic-devel main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    pkill .*upgrade.*
    rm /var/lib/dpkg/lock-frontend
    sleep 500
}

function prepareSourcesXenial {
    sleep 120
    apt-get update
    echo "deb https://repo.gluu.org/ubuntu/ xenial-devel main" > /etc/apt/sources.list.d/gluu-repo.list
    curl https://repo.gluu.org/ubuntu/gluu-apt.key | apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/psql.list
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
    pkill .*upgrade.*
    rm /var/lib/dpkg/lock
    sleep 120
}

function prepareSourcesCentos7 {
    dd if=/dev/zero of=/myswap count=4096 bs=1MiB
    chmod 600 /myswap
    mkswap /myswap
    swapon /myswap
    yum -y install wget curl lsof xvfb
    wget https://repo.gluu.org/centos/Gluu-centos-7-testing.repo -O /etc/yum.repos.d/Gluu.repo
    wget https://repo.gluu.org/centos/RPM-GPG-KEY-GLUU -O /etc/pki/rpm-gpg/RPM-GPG-KEY-GLUU
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-GLUU
    rpm -Uvh https://yum.postgresql.org/10/redhat/rhel-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    curl -sL https://rpm.nodesource.com/setup_10.x | sudo -E bash -
}

function prepareSourcesForDistribution {
    case $DISTRIBUTION in
        "bionic") prepareSourcesBionic ;;
        "xenial") prepareSourcesXenial ;;
        "centos7") prepareSourcesCentos7 ;;
    esac
}

function installGGDeb {
    apt-get update
    sleep 120
    apt-get install gluu-gateway -y
}

function installGGRpm {
    yum clean all
    yum -y install gluu-gateway
}

function installGG {
    case $DISTRIBUTION in
        "bionic") installGGDeb ;;
        "xenial") installGGDeb ;;
        "centos7") installGGRpm ;;
    esac
}

function configureGG {
 # Used to open port publicly
 sed -i "77s/explicitHost: process.env.EXPLICIT_HOST || 'localhost'/explicitHost: '0.0.0.0'/" /opt/gluu-gateway-setup/templates/local.js
 sed -i "78s/ggUIRedirectURLHost: process.env.GG_UI_REDIRECT_URL_HOST || 'localhost'/ggUIRedirectURLHost: 'dev1.gluu.org'/" /opt/gluu-gateway-setup/templates/local.js

 cd /opt/gluu-gateway-setup
 python setup-gluu-gateway.py '{"gluu_gateway_ui_redirect_uri":"'$HOST'","gluu_gateway_ui_oxd_web":"https://'$OXD_HOST':8443","license":true,"ip":"'$HOST_IP'","host_name":"'$HOST'","country_code":"US","state":"US","city":"NY","org_name":"Test","admin_email":"test@test.com","pg_pwd":"admin","install_oxd":true,"gluu_gateway_ui_op_host":"'$OP_HOST'","generate_client":true}'
}

function createSwap {
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
}

function displayLogs {
    echo ""
    echo "--------------------------------/var/log/konga.log-----------------------------------------"
    echo ""
    cat /var/log/konga.log
    echo ""
    echo "----------------------/opt/gluu-gateway/setup/gluu-gateway-setup_error.log-----------------------------------"
    echo ""
    cat /opt/gluu-gateway-setup/gluu-gateway-setup_error.log
    echo ""
    echo "----------------------/opt/gluu-gateway/setup/gluu-gateway-setup.log-----------------------------------"
    echo ""
    cat /opt/gluu-gateway-setup/gluu-gateway-setup.log
    echo ""
    echo "----------------------netstat -tulpn----------------------------------"
    echo ""
    netstat -tulpn
    echo ""
    echo "----------------------services----------------------------------"
    echo ""
    service kong status
    service konga status
}

function checkKonga {
    if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
        echo "Konga is running"
    else
        echo "ERROR: Konga is not running. Waiting 1 min more"
        if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
            echo "Konga is running"
        else
            echo "ERROR: Konga is not running. Waiting 1 min more"
            if lsof -Pi :1338 -sTCP:LISTEN -t >/dev/null ; then
                echo "Konga is running"
            else
                exit 1
            fi
        fi
    fi
}

function checkKong {
    if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null ; then
        echo "Kong is running"
    else
        echo "ERROR: Kong is not running"
        exit 1
    fi
}
function checkServices {
    checkKonga
    checkKong
}

createSwap
prepareSourcesForDistribution
installGG
configureGG
sleep 60
displayLogs
checkServices
