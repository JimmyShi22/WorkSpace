#!/bin/bash

# This script download latest tars of FISCO-BCOS and console
# bash download_tar.sh output_path
# */20 * * * * bash /data/app/cdn/download_tar.sh -p /data/app/cdn/ -f > /data/app/cdn/download.log 2>&1
# */20 * * * * bash /data/app/cdn/download_tar.sh -p /data/app/cdn/ -c > /data/app/cdn/download.log 2>&1
# */20 * * * * bash /data/app/cdn/download_tar.sh -p /data/app/cdn/ -w > /data/app/cdn/download.log 2>&1
# * */4 * * * bash /data/app/cdn/download_tar.sh -p /data/app/cdn/ -l > /data/app/cdn/download.log 2>&1
LANG=en_US.utf8

output_dir=./
download_repo=()
timeout=250
console_timeout=1000
wecross_repo=WeBankFinTech

#set -e

failed_clean()
{
    local path=${1}
    echo "failed, clean ${path}"
    rm -rf ${path}
    exit 1
}

help() {
    echo $1
    cat << EOF
Usage:
    -p <Download Path>                  [Required]
    -f <Download fisco-bcos>            Include fisco-bcos.tar.gz fisco-bcos-gm.tar.gz fisco-bcos-macOS.tar.gz
    -c <Download console>               Include console.tar.gz
    -w <Download WeCross>               Include WeCross.tar.gz WeCross-Console.tar.gz
    -h Help
e.g
    $0 -p ~/data -f -c
EOF
exit 0
}

LOG_INFO()
{
    local content=${1}
    echo -e "\033[32m[INFO] ${content}\033[0m"
}

LOG_ERROR()
{
    local content=${1}
    echo -e "\033[31m[ERROR] ${content}\033[0m"
}

parse_params()
{
while getopts "p:cfwlh" option;do
    case $option in
    p) output_dir=$OPTARG;;
    f) download_repo+=('FISCO-BCOS');;
    c) download_repo+=('console');;
    w) download_repo+=('wecross');;
    l) download_repo+=('LargeFiles');;
    h) help;;
    esac
done
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
    if [ "v${latest_version}" != "${local_latest}" ];then
        LOG_INFO "latest fisco-bcos is v${latest_version}, downloading fisco-bcos v${latest_version} ..."
        download_fisco_artifacts ${latest_version}
    else
        LOG_INFO "latest fisco-bcos is v${latest_version}, local has ${output_dir}/fisco-bcos/releases/download/v${latest_version}"
    fi
}

download_console()
{
    local repo=FISCO-BCOS/console
    local latest_version=$(curl -s https://api.github.com/repos/${repo}/releases/latest | grep "tag_name" | sort -u | tail -n 1 | cut -d \" -f 4 | sed "s/^[vV]//")
    mkdir -p ${output_dir}/console/releases/download/
    local local_latest=$(ls -1 ${output_dir}/console/releases/download/ | sort -u | tail -n 1)
    local dist_dir=${output_dir}/console/releases/download/v${latest_version}
    if [ "v${latest_version}" != "${local_latest}" ];then
        LOG_INFO "latest console is v${latest_version}, downloading console v${latest_version} ..."
        mkdir -p ${dist_dir}
        curl -Lo ${dist_dir}/console.tar.gz https://github.com/${repo}/releases/download/v${latest_version}/console.tar.gz -m ${console_timeout} || failed_clean ${dist_dir}
    else
        LOG_INFO "latest console is v${latest_version}, local has ${dist_dir}"
    fi
}

download_largefiles()
{
    if [ -d "deps" ]; then
        LOG_INFO "cd deps && git pull"
        cd deps && git pull
    else
        LOG_INFO "git clone https://github.com/FISCO-BCOS/LargeFiles.git deps"
        git clone https://github.com/FISCO-BCOS/LargeFiles.git deps
    fi
}

download_wecross()
{
    local compatibility_version=${1}
    local release_url=https://github.com/${wecross_repo}/WeCross/releases/download/
    local latest_wecross=WeCross.tar.gz
    local latest_wecross_checksum_file=WeCross.tar.gz.md5
    local dist_dir=${output_dir}/wecross/releases/download/${compatibility_version}
    local dist_tmp=${dist_dir}/.tmp/
    mkdir -p ${dist_tmp}
    LOG_INFO "Download WeCross Release: ${compatibility_version}"

    # download md5 checksum
    curl -LO ${release_url}/${compatibility_version}/${latest_wecross_checksum_file}
    if [ ! -e ${latest_wecross_checksum_file} ];then
        LOG_ERROR "Download WeCross checksum failed! URL: ${release_url}/${compatibility_version}/${latest_wecross_checksum_file}"
        return
    fi
    cp ${latest_wecross_checksum_file} ${dist_tmp}

    # download wecross tar
    cd ${dist_tmp}
    if [ ! -e ${latest_wecross} ] || [ -z "$(md5sum -c ${latest_wecross_checksum_file}|grep OK)" ];then
        LOG_INFO "Download from: ${release_url}/${compatibility_version}/${latest_wecross}"
        curl -LO ${release_url}/${compatibility_version}/${latest_wecross}

        # check checksum
        if [ -z "$(md5sum -c ${latest_wecross_checksum_file}|grep OK)" ];then
            LOG_ERROR "Download WeCross package failed! URL: ${release_url}/${compatibility_version}/${latest_wecross}"
            cd -
            return
        fi

    else
        LOG_INFO "Release ${latest_wecross} exists."
    fi

    # publish
    if [ ! -e ../${latest_wecross_checksum_file} ] || [ ! -z "$(diff -q ${latest_wecross_checksum_file}  ../${latest_wecross_checksum_file})" ]; then
        cp -f ${latest_wecross} ${latest_wecross_checksum_file} ../
    fi
    cd -
}

download_all_wecross()
{
    LOG_INFO "Checking all WeCross releases"

    local compatibility_versions=

    # fetch latest version
    if [ -z "${compatibility_versions}" ];then
        compatibility_versions=($(curl -s https://api.github.com/repos/${wecross_repo}/WeCross/releases | grep "tag_name"|awk -F '\"' '{print $4}'))
    fi

    for compatibility_version in ${compatibility_versions[@]}
	do
        download_wecross ${compatibility_version}
    done
}

download_wecross_console()
{
    LOG_INFO "Checking WeCross-Console latest release"

    local compatibility_version=${1}
    local download_url=https://github.com/${wecross_repo}/WeCross-Console/releases/download/
    local latest_wecross=WeCross-Console.tar.gz
    local latest_wecross_checksum_file=WeCross-Console.tar.gz.md5
    local dist_dir=${output_dir}/wecross-console/releases/download/${compatibility_version}
    local dist_tmp=${dist_dir}/.tmp/
    mkdir -p ${dist_tmp}
    LOG_INFO "Download WeCross-Console release: ${compatibility_version}"


    # download md5 checksum
    curl -LO ${download_url}/${compatibility_version}/${latest_wecross_checksum_file}
    if [ ! -e ${latest_wecross_checksum_file} ];then
        LOG_ERROR "Download WeCross-Console checksum failed! URL: ${download_url}/${compatibility_version}/${latest_wecross_checksum_file}"
        return
    fi
    cp ${latest_wecross_checksum_file} ${dist_tmp}

    # download wecross tar
    cd ${dist_tmp}
    if [ ! -e ${latest_wecross} ] || [ -z "$(md5sum -c ${latest_wecross_checksum_file}|grep OK)" ];then
        LOG_INFO "Download from: ${download_url}/${compatibility_version}/${latest_wecross}"
        curl -LO ${download_url}/${compatibility_version}/${latest_wecross}

        # check checksum
        if [ -z "$(md5sum -c ${latest_wecross_checksum_file}|grep OK)" ];then
            LOG_ERROR "Download WeCross console package failed! URL: ${download_url}/${compatibility_version}/${latest_wecross}"
            cd -
            return
        fi

    else
        LOG_INFO "Release ${latest_wecross} exists."
    fi

    # publish
    if [ ! -e ../${latest_wecross_checksum_file} ] || [ ! -z "$(diff -q ${latest_wecross_checksum_file}  ../${latest_wecross_checksum_file})" ]; then
        cp -f ${latest_wecross} ${latest_wecross_checksum_file} ../
    fi
    cd -
}

download_all_wecross_console()
{
    LOG_INFO "Checking all WeCross-Console releases"

    local compatibility_versions=

    # fetch latest version
    if [ -z "${compatibility_versions}" ];then
        compatibility_versions=($(curl -s https://api.github.com/repos/${wecross_repo}/WeCross/releases | grep "tag_name"|awk -F '\"' '{print $4}'))
    fi

    for compatibility_version in ${compatibility_versions[@]}
	do
        download_wecross_console ${compatibility_version}
    done
}

download_wecross_demo()
{
    LOG_INFO "Checking WeCross Demo latest release"

    local compatibility_version=${1}
    local download_url=https://github.com/${wecross_repo}/WeCross/releases/download/
    local latest_wecross=demo.tar.gz
    local latest_wecross_checksum_file=demo.tar.gz.md5
    local dist_dir=${output_dir}/wecross/releases/download/${compatibility_version}
    local dist_tmp=${dist_dir}/.tmp/
    mkdir -p ${dist_tmp}
    LOG_INFO "Download WeCross Demo release: ${compatibility_version}"


    # download md5 checksum
    curl -LO ${download_url}/${compatibility_version}/${latest_wecross_checksum_file}
    if [ ! -e ${latest_wecross_checksum_file} ];then
        LOG_ERROR "Download WeCross Demo checksum failed! URL: ${download_url}/${compatibility_version}/${latest_wecross_checksum_file}"
        return
    fi
    cp ${latest_wecross_checksum_file} ${dist_tmp}

    # download wecross demo tar
    cd ${dist_tmp}
    if [ ! -e ${latest_wecross} ] || [ -z "$(md5sum -c ${latest_wecross_checksum_file}|grep OK)" ];then
        LOG_INFO "Download from: ${download_url}/${compatibility_version}/${latest_wecross}"
        curl -LO ${download_url}/${compatibility_version}/${latest_wecross}

        # check checksum
        if [ -z "$(md5sum -c ${latest_wecross_checksum_file}|grep OK)" ];then
            LOG_ERROR "Download WeCross demo package failed! URL: ${download_url}/${compatibility_version}/${latest_wecross}"
            cd -
            return
        fi

    else
        LOG_INFO "Release ${latest_wecross} exists."
    fi

    # publish
    if [ ! -e ../${latest_wecross_checksum_file} ] || [ ! -z "$(diff -q ${latest_wecross_checksum_file}  ../${latest_wecross_checksum_file})" ]; then
        cp -f ${latest_wecross} ${latest_wecross_checksum_file} ../
    fi
    cd -
}

download_all_wecross_demo()
{
    LOG_INFO "Checking all WeCross Demo releases"

    local compatibility_versions=

    # fetch latest version
    if [ -z "${compatibility_versions}" ];then
        compatibility_versions=($(curl -s https://api.github.com/repos/${wecross_repo}/WeCross/releases | grep "tag_name"|awk -F '\"' '{print $4}'))
    fi

    for compatibility_version in ${compatibility_versions[@]}
	do
        download_wecross_demo ${compatibility_version}
    done
}

main()
{
    for repo in ${download_repo[*]}
    do
        case $repo in
        FISCO-BCOS)
            download_fisco
            ;;
        console)
            download_console
            ;;
        LargeFiles)
            download_largefiles
            ;;
        wecross)
            # download_all_wecross
            # download_all_wecross_console
            download_all_wecross_demo
            ;;
        *)
            echo "unknow repo"
            ;;
        esac
    done
}

echo "======== start at $(date +"%Y-%m-%d %H:%M:%S") ========"
parse_params $@
main
echo "======== exit at $(date +"%Y-%m-%d %H:%M:%S") ========"
