#!/bin/bash

INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
opkg_updated=false

required_packages=("wget-ssl" "bash" "curl")
for package in "${required_packages[@]}"; do
    if ! opkg list-installed | grep -q "^$package -"; then
        echo -e "${INFO} Package $package to initialize setup not found. Installing..."
        [ "$opkg_updated" = false ] && opkg update && opkg_updated=true
        opkg install $package
    else
        echo -e "${INFO} $package Installed!."
    fi
done

openclash_api="https://api.github.com/repos/vernesong/OpenClash/releases"
openclash_file="luci-app-openclash"
openclash_file_down="$(curl -s "${openclash_api}" | grep "browser_download_url" | grep -oE "https.*${openclash_file}.*.ipk" | head -n 1)"
patchoc="https://raw.githubusercontent.com/frizkyiman/friWrt-MyWrtBuilder/main/files/usr/bin/patchoc.sh"

if [ "$1" == "install" ]; then
  echo -e "${INFO} Start installing [ ${openclash_file} ] dependencies first"
  if opkg list-installed | grep -q '^dnsmasq\b'; then echo -e "${INFO} dnsmasq is already installed. Removing..."; opkg remove dnsmasq; fi
  if [ -n "$(command -v fw4)" ]; then
    echo -e "${INFO} Firewall 4 nftables detected"
    [ "$opkg_updated" = false ] && opkg update && opkg_updated=true
    opkg install coreutils-nohup bash dnsmasq-full curl ca-certificates ipset ip-full libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag unzip kmod-nft-tproxy luci-compat luci luci-base
  else
    echo -e "${INFO} Firewall 3 iptables detected"
    [ "$opkg_updated" = false ] && opkg update && opkg_updated=true
    opkg install coreutils-nohup bash iptables dnsmasq-full curl ca-certificates ipset ip-full iptables-mod-tproxy iptables-mod-extra libcap libcap-bin ruby ruby-yaml kmod-tun kmod-inet-diag unzip luci-compat luci luci-base
  fi
fi

echo -e "${INFO} Start downloading [ ${openclash_file} ]."
if wget -q -N -P /root "${openclash_file_down}" && wget -q -N -P /usr/bin "$patchoc"; then
  echo -e "${SUCCESS} The [ $(basename "${openclash_file_down}") ] is downloaded successfully."
  echo -e "${INFO} Start installing [ ${openclash_file} ]"
  [ "$opkg_updated" = false ] && opkg update && opkg_updated=true
  if opkg install /root/*openclash*.ipk --force-reinstall; then
    echo -e "${INFO} Start applying patch for [ ${openclash_file} ]."
    chmod +x /usr/bin/patchoc.sh && /usr/bin/patchoc.sh
    [ "${?}" -eq "0" ] && echo -e "${SUCCESS} Openclash successfully installed and patched." || echo -e "${ERROR} Failed to apply patch! Check for errors during patching."
  else
    echo -e "${ERROR} Failed to install [ ${openclash_file} ]! Check for errors during installation."
  fi
  rm /root/*openclash*.ipk
else
  echo -e "${ERROR} [ ${openclash_file} ] download failed! Make sure the connection is accessible."
fi
