#!/bin/bash

# This script download latest tars of FISCO-BCOS and console
# bash download_tar.sh output_path
# */30 * * * * bash /data/app/cdn/download_tar.sh /data/app/cdn/ > /data/app/cdn/download.log 2>&1

org=FISCO-BCOS
output_dir=${1}
timeout=250
console_timeout=1000

#set -e

failed_clean()
{
    local path=${1}
    echo "failed, clean ${path}"
    rm -rf ${path}
    exit 1
}

download_fisco_artifacts()
{
    local version=${1}
    local from=https://github.com/FISCO-BCOS/FISCO-BCOS/releases/download/v${version}
    local to=${output_dir}/fisco-bcos/releases/download/v${version}
    mkdir -p ${to}
    local tars=(fisco-bcos.tar.gz fisco-bcos-gm.tar.gz fisco-bcos-macOS.tar.gz)
    for file in ${tars[*]}
    do
        curl -Lo ${to}/${file} ${from}/${file} -m ${timeout} || failed_clean ${to}
    done
}

download_fisco()
{
    local latest_version=$(curl -s https://api.github.com/repos/FISCO-BCOS/FISCO-BCOS/releases | grep "tag_name" | grep "\"v2\.[0-9]\.[0-9]\"" | sort -u | tail -n 1 | cut -d \" -f 4 | sed "s/^[vV]//")
    mkdir -p ${output_dir}/fisco-bcos/releases/download/
    local local_latest=$(ls -1 ${output_dir}/fisco-bcos/releases/download/ | sort -u | tail -n 1)
    echo "latest fisco-bcos is v${latest_version}, local is ${local_latest}"
    if [ "v${latest_version}" != "${local_latest}" ];then
        echo "    download fisco-bcos v${latest_version} ..."
        download_fisco_artifacts ${latest_version}
    else
        echo "    fisco-bcos v${latest_version} already exist."
    fi
}

download_console()
{
    local latest_version=$(curl -s https://api.github.com/repos/FISCO-BCOS/console/releases/latest | grep "tag_name" | sort -u | tail -n 1 | cut -d \" -f 4 | sed "s/^[vV]//")
    mkdir -p ${output_dir}/console/releases/download/
    local local_latest=$(ls -1 ${output_dir}/console/releases/download/ | sort -u | tail -n 1)
    echo "latest console is v${latest_version}, local is ${local_latest}"
    local dist_dir=${output_dir}/console/releases/download/v${latest_version}
    if [ "v${latest_version}" != "${local_latest}" ];then
        echo "    download console v${latest_version} ..."
        mkdir -p ${dist_dir}
        curl -Lo ${dist_dir}/console.tar.gz https://github.com/FISCO-BCOS/console/releases/download/v${latest_version}/console.tar.gz -m ${console_timeout} || failed_clean ${dist_dir}
    else
        echo "    console v${latest_version} already exist."
    fi
}

echo "======== start at $(date +"%Y-%m-%d %H:%M:%S") ========"
download_fisco
download_console

echo "======== exit at $(date +"%Y-%m-%d %H:%M:%S") ========"
