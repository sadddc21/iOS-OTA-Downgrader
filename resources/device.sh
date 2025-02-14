#!/bin/bash

DisableBBUpdate="iPad2,3" # Disable baseband update for this device. You can also change this to your device if needed

FindDevice() {
    local DeviceIn
    local i=0
    local Timeout=999
    local USB
    if [[ $1 == "DFU" ]]; then
        USB=1227
    elif [[ $1 == "Recovery" ]]; then
        USB=1281
    elif [[ $1 == "Restore" ]]; then
        USB=1297
    fi
    [[ -n $2 ]] && Timeout=10
    
    Log "Finding device in $1 mode..."
    while (( i < Timeout )); do
        if [[ $platform == "linux" ]]; then
            DeviceIn=$(lsusb | grep -c "05ac:$USB")
        elif [[ $1 == "Restore" ]]; then
            ideviceinfo2=$($ideviceinfo -s)
            [[ $? == 0 ]] && DeviceIn=1
        else
            [[ $($irecovery -q 2>/dev/null | grep -w "MODE" | cut -c 7-) == "$1" ]] && DeviceIn=1
        fi
        if [[ $DeviceIn == 1 ]]; then
            Log "Found device in $1 mode."
            DeviceState="$1"
            break
        fi
        sleep 1
        ((i++))
    done
    
    if [[ $DeviceIn != 1 ]]; then
        [[ $2 == "error" ]] && Error "Failed to find device in $1 mode. (Timed out)"
        return 1
    fi
}

GetDeviceValues() {
    local ideviceinfo2
    local version
    DeviceState=

    if [[ $NoDevice == 1 ]]; then
        Log "NoDevice argument detected. Skipping device detection"
        DeviceState="NoDevice"
    else
        Log "Finding device in Normal mode..."
        ideviceinfo2=$($ideviceinfo -s)
        opt=$?
    fi

    if [[ $opt != 0 && $NoDevice != 1 ]]; then
        Log "Finding device in DFU/recovery mode..."
        DeviceState="$($irecovery -q 2>/dev/null | grep -w "MODE" | cut -c 7-)"
    elif [[ -n $ideviceinfo2 ]]; then
        DeviceState="Normal"
    fi

    if [[ $DeviceState == "DFU" || $DeviceState == "Recovery" ]]; then
        local ProdCut=7
        ProductType=$($irecovery -qv 2>&1 | grep "Connected to iP" | cut -c 14-)
        [[ $(echo $ProductType | cut -c 3) == 'h' ]] && ProdCut=9
        ProductType=$(echo $ProductType | cut -c -$ProdCut)
        UniqueChipID=$((16#$($irecovery -q | grep "ECID" | cut -c 9-)))
        ProductVer="Unknown"
    elif [[ $DeviceState == "Normal" ]]; then
        ProductType=$(echo "$ideviceinfo2" | grep "ProductType" | cut -c 14-)
        [[ ! $ProductType ]] && ProductType=$($ideviceinfo | grep "ProductType" | cut -c 14-)
        ProductVer=$(echo "$ideviceinfo2" | grep "ProductVer" | cut -c 17-)
        UniqueChipID=$(echo "$ideviceinfo2" | grep "UniqueChipID" | cut -c 15-)
        UniqueDeviceID=$(echo "$ideviceinfo2" | grep "UniqueDeviceID" | cut -c 17-)
        version="(iOS $ProductVer) "
    fi

    if [[ $EntryDevice == 1 ]]; then
        ProductType=
        UniqueChipID=
    fi

    if [[ -n $DeviceState ]]; then
        if [[ ! $ProductType ]]; then
            read -p "$(Input 'Enter ProductType (eg. iPad2,1):')" ProductType
        fi
        if [[ ! $UniqueChipID || $UniqueChipID == 0 ]]; then
            read -p "$(Input 'Enter UniqueChipID (ECID, must be decimal):')" UniqueChipID
        fi
    else
        echo -e "\n${Color_R}[Error] No device detected. Please put the device in normal mode before proceeding. ${Color_N}"
        echo "${Color_Y}* Make sure to also trust this computer by selecting \"Trust\" at the pop-up. ${Color_N}"
        echo "${Color_Y}* For Windows/macOS users, double-check if the device is being detected by iTunes/Finder. ${Color_N}"
        echo "${Color_Y}* Recovery or DFU mode is also applicable. ${Color_N}"
        echo "${Color_Y}* To perform operations without an iOS device connected, add NoDevice as an argument. ${Color_N}"
        echo "${Color_Y}* For more details, read the \"Troubleshooting\" wiki page in GitHub ${Color_N}"
        ExitWin 1
    fi
    
    Firmware=resources/firmware/$ProductType
    Baseband=0
    BasebandURL=$(cat $Firmware/13G37/url 2>/dev/null)
    LatestVer="9.3.6"
    
    if [[ $ProductType == "iPad2,2" ]]; then
        BasebandURL=$(cat $Firmware/13G36/url)
        Baseband="ICE3_04.12.09_BOOT_02.13.Release.bbfw"
        BasebandSHA1="e6f54acc5d5652d39a0ef9af5589681df39e0aca"
        LatestVer="9.3.5"
    
    elif [[ $ProductType == "iPad2,3" ]]; then
        Baseband="Phoenix-3.6.03.Release.bbfw"
        BasebandSHA1="8d4efb2214344ea8e7c9305392068ab0a7168ba4"

    elif [[ $ProductType == "iPhone3,3" ]]; then
        BasebandURL=$(cat $Firmware/11D257/url)
        Baseband="Phoenix-3.0.04.Release.bbfw"
        BasebandSHA1="a507ee2fe061dfbf8bee7e512df52ade8777e113"
    
    elif [[ $ProductType == "iPad2,6" || $ProductType == "iPad2,7" ]]; then
        Baseband="Mav5-11.80.00.Release.bbfw"
        BasebandSHA1="aa52cf75b82fc686f94772e216008345b6a2a750"
    
    elif [[ $ProductType == "iPad3,2" || $ProductType == "iPad3,3" ]]; then
        Baseband="Mav4-6.7.00.Release.bbfw"
        BasebandSHA1="a5d6978ecead8d9c056250ad4622db4d6c71d15e"
    
    elif [[ $ProductType == "iPhone4,1" ]]; then
        Baseband="Trek-6.7.00.Release.bbfw"
        BasebandSHA1="22a35425a3cdf8fa1458b5116cfb199448eecf49"
    
    elif [[ $ProductType == "iPad3,5" || $ProductType == "iPad3,6" ||
            $ProductType == "iPhone5,1" || $ProductType == "iPhone5,2" ]]; then
        BasebandURL=$(cat $Firmware/14G61/url)
        Baseband="Mav5-11.80.00.Release.bbfw"
        BasebandSHA1="8951cf09f16029c5c0533e951eb4c06609d0ba7f"
        LatestVer="10.3.4"

    elif [[ $ProductType == "iPad4,2" || $ProductType == "iPad4,3" || $ProductType == "iPad4,5" ||
            $ProductType == "iPhone5"* || $ProductType == "iPhone6"* ]]; then
        BasebandURL=$(cat $Firmware/14G60/url)
        Baseband="Mav7Mav8-7.60.00.Release.bbfw"
        BasebandSHA1="f397724367f6bed459cf8f3d523553c13e8ae12c"
        if [[ $ProductType == "iPhone5"* ]]; then
            Log "iPhone 5C detected. Your device does not support OTA downgrades."
            Echo "* Functions will be limited to entering kDFU and restoring with blobs."
        fi

    elif [[ $ProductType == "iPhone3"* ]]; then
        BasebandURL=$(cat $Firmware/11D257/url)
        Baseband="ICE3_04.12.09_BOOT_02.13.Release.bbfw"
        BasebandSHA1="007365a5655ac2f9fbd1e5b6dba8f4be0513e364"

    elif [[ $ProductType == "iPad2"* || $ProductType == "iPad3"* || $ProductType == "iPad4,1" ||
            $ProductType == "iPad4,4" || $ProductType == "iPod5,1" ]]; then
        BasebandURL=0
    else
        Error "Your device $ProductType ${version}is not supported."
    fi
    
    if [[ $ProductType == "iPhone3"* ]]; then
        DeviceProc=4
        if [[ $ProductType != "iPhone3,2" ]]; then
            Log "$ProductType detected. iPhone4Down functions enabled."
            Echo "* This script uses powdersn0w by dora2ios"
        else
            Log "$ProductType detected. Your device is not supported by powdersn0w (yet)"
            Echo "* Functions will be limited to entering kDFU and restoring with blobs."
        fi
    elif [[ $ProductType == "iPad2"* || $ProductType == "iPad3,1" || $ProductType == "iPad3,2" ||
          $ProductType == "iPad3,3" || $ProductType == "iPhone4,1" || $ProductType == "iPod5,1" ]]; then
        DeviceProc=5
    elif [[ $ProductType == "iPhone5"* || $ProductType == "iPad3"* ]]; then
        DeviceProc=6
    elif [[ $ProductType == "iPhone6"* || $ProductType == "iPad4"* ]]; then
        DeviceProc=7
    fi
    
    HWModel=$(cat $Firmware/hwmodel)
    
    if [[ ! $BasebandURL || ! $HWModel ]]; then
        Error "Missing BasebandURL and/or HWModel values. Is the firmware folder missing?" \
        "Reinstall dependencies and try again. For more details, read the \"Troubleshooting\" wiki page in GitHub"
    fi
    
    if [[ $ProductType == "iPod5,1" ]]; then
        iBSS="${HWModel}ap"
        iBSSBuildVer="10B329"
    elif [[ $ProductType == "iPad3,1" || $ProductType == "iPhone3"* ]]; then
        iBSS="${HWModel}ap"
        iBSSBuildVer="11D257"
    elif [[ $ProductType == "iPhone6"* ]]; then
        iBSS="iphone6"
        IPSWType="iPhone_4.0_64bit"
    elif [[ $ProductType == "iPad4"* ]]; then
        iBSS="ipad4"
        IPSWType="iPad_64bit"
    else
        iBSS="$HWModel"
        iBSSBuildVer="12H321"
    fi
    [[ ! $IPSWType ]] && IPSWType="$ProductType"
    iBEC="iBEC.$iBSS.RELEASE"
    iBECb="iBEC.${iBSS}b.RELEASE"
    iBSSb="iBSS.${iBSS}b.RELEASE"
    iBSS="iBSS.$iBSS.RELEASE"
    SEP="sep-firmware.$HWModel.RELEASE.im4p"
    
    Log "$ProductType ${version}connected in $DeviceState mode."
    Log "ECID: $UniqueChipID"
}

EnterPwnDFU() {
    local pwnDFUTool
    local pwnDFUDevice
    local pwnD=1
    local Selection=()
    
    if [[ $DeviceProc == 4 && $platform != "macos" ]]; then
        pwnDFUTool="$pwnedDFU"
        if [[ $platform == "win" ]]; then
            Log "iPhone 4 device detected in DFU mode."
            Echo "* Make sure that your device is already in pwnDFU mode."
            Echo "* If your device is not in pwnDFU mode, the restore will not proceed!"
            Input "Press Enter/Return to continue (or press Ctrl+C to cancel)"
            read -s
            return
        fi
    elif [[ $platform == "macos" ]]; then
        Selection+=("ipwnder_lite" "iPwnder32")
        Input "PwnDFU Tool Option"
        Echo "* This option selects what tool to use to put your device in pwnDFU mode."
        Echo "* If unsure, select 1. If 1 does not work, try selecting the other option."
        Echo "* This option is set to ${Selection[0]} by default (1)."
        Input "Select your option:"
        select opt in "${Selection[@]}"; do
        case $opt in
            "ipwnder_lite" ) pwnDFUTool="$ipwnder_lite"; break;;
            "iPwnder32" ) pwnDFUTool="$ipwnder32"; break;;
        esac
        done
    else
        Echo "* For Arch, install python2 first from AUR before using ipwndfu."
        pwnDFUTool="ipwndfu"
        SaveExternal ipwndfu
    fi
    
    Log "Entering pwnDFU mode with: $pwnDFUTool"
    if [[ $pwnDFUTool == "ipwndfu" ]]; then
        cd resources/ipwndfu
        $ipwndfu -p
        pwnDFUDevice=$?
        if [[ $DeviceProc == 7 ]]; then
            Log "Running rmsigchks.py..."
            $rmsigchks
            pwnDFUDevice=$?
            cd ../..
        else
            cd ../..
            SendPwnediBSS
        fi
    else
        $pwnDFUTool -p
        pwnDFUDevice=$?
    fi
    if [[ $DeviceProc == 4 || $DeviceProc == 7 ]]; then
        pwnD=$($irecovery -q | grep -c "PWND")
        SendiBSS=1
    fi
    
    if [[ $DeviceProc == 4 ]]; then
        if [[ $pwnD != 1 ]]; then
            Error "Failed to enter pwnDFU mode. Please run the script again. Note that kDFU mode will NOT work!" \
            "Exit DFU mode first by holding the TOP and HOME buttons for about 15 seconds."
        else
            Log "Device in pwnDFU mode detected."
        fi
    elif [[ $pwnDFUDevice != 0 && $pwnD != 1 ]]; then
        echo -e "\n${Color_R}[Error] Failed to enter pwnDFU mode. Please run the script again ${Color_N}"
        echo "${Color_Y}* If the screen is black, exit DFU mode first by holding the TOP and HOME buttons for about 15 seconds. ${Color_N}"
        echo "${Color_Y}* This step may fail a lot, especially on Linux, and unfortunately there is nothing I can do about the low success rates. ${Color_N}"
        echo "${Color_Y}* The only option is to make sure you are using an Intel or Apple Silicon device, and to try multiple times ${Color_N}"
        Echo "* For more details, read the \"Troubleshooting\" wiki page in GitHub"
        ExitWin 1
    elif [[ $pwnDFUDevice == 0 ]]; then
        Log "Device in pwnDFU mode detected."
    else
        Log "Warning - Failed to detect device in pwnDFU mode."
        Echo "* If the device entered pwnDFU mode successfully, you may continue"
        Echo "* If entering pwnDFU failed, you may have to force restart your device and start over"
        Input "Press Enter/Return to continue (or press Ctrl+C to cancel)"
        read -s
    fi
}

Recovery() {
    local RecoveryDFU
    
    if [[ $DeviceState != "Recovery" ]]; then
        Log "Entering recovery mode..."
        $ideviceenterrecovery $UniqueDeviceID >/dev/null
        FindDevice "Recovery"
    fi
    
    Echo "* Get ready to enter DFU mode."
    read -p "$(Input 'Select Y to continue, N to exit recovery (Y/n)')" RecoveryDFU
    if [[ $RecoveryDFU == 'N' || $RecoveryDFU == 'n' ]]; then
        Log "Exiting recovery mode."
        $irecovery -n
        ExitWin 0
    fi
    
    Echo "* Hold TOP and HOME buttons for 10 seconds."
    for i in {10..01}; do
        echo -n "$i "
        sleep 1
    done
    echo -e "\n$(Echo '* Release TOP button and hold HOME button for 8 seconds.')"
    for i in {08..01}; do
        echo -n "$i "
        sleep 1
    done
    echo
    
    FindDevice "DFU" error
    EnterPwnDFU
}

RecoveryExit() {
    read -p "$(Input 'Attempt to exit recovery mode? (Y/n)')" Selection
    if [[ $Selection != 'N' && $Selection != 'n' ]]; then
        Log "Exiting recovery mode."
        $irecovery -n
    fi
    ExitWin 0
}

PatchiBSS() {
    if [[ $iBSSBuildVer == $BuildVer && -e "$IPSW.ipsw" ]]; then
        Log "Extracting iBSS from IPSW..."
        mkdir -p saved/$ProductType 2>/dev/null
        unzip -o -j $IPSW.ipsw Firmware/dfu/$iBSS.dfu -d saved/$ProductType
    fi

    if [[ ! -e saved/$ProductType/$iBSS.dfu ]]; then
        Log "Downloading iBSS..."
        $partialzip "$(cat $Firmware/$iBSSBuildVer/url)" Firmware/dfu/$iBSS.dfu $iBSS.dfu
        mkdir -p saved/$ProductType 2>/dev/null
        mv $iBSS.dfu saved/$ProductType
    fi

    if [[ ! -e saved/$ProductType/$iBSS.dfu ]]; then
        Error "Failed to save iBSS. Please run the script again"
    fi

    Log "Patching iBSS..."
    $bspatch saved/$ProductType/$iBSS.dfu tmp/pwnediBSS resources/patches/$iBSS.patch
}

SendPwnediBSSA5() {
    Echo "* Make sure that your device is in pwnDFU mode using an Arduino+USB Host Shield!"
    Echo "* This option will not work if your device is not in pwnDFU mode."
    Input "Press Enter/Return to continue (or press Ctrl+C to cancel)"
    read -s
    Input "No iBSS Option"
    Echo "* If you already have sent pwned iBSS manually, select Y. If not, select N."
    Echo "* This option is disabled by default (N)."
    read -p "$(Input 'Enable this option? (y/N):')" SendiBSS
    if [[ $SendiBSS == 'Y' || $SendiBSS == 'y' ]]; then
        Log "No iBSS option enabled by user."
        return
    fi
    echo
    Input "Send iBSS Option"
    Echo "* To send pwned iBSS using ipwndfu, select Y. (does not work on ARM Macs)"
    Echo "* To let futurerestore send iBSS, select N. (likely does not work)"
    Echo "* For Arch, macOS 12 and newer, install python2 first before selecting ipwndfu."
    Echo "* This option is enabled by default (Y)."
    read -p "$(Input 'Enable this option? (Y/n):')" SendiBSS
    if [[ $SendiBSS == 'N' || $SendiBSS == 'n' ]]; then
        Log "Send iBSS option disabled by user."
        SendiBSS=1
        return
    fi
    SendPwnediBSS
}

SendPwnediBSS() {
    SaveExternal ipwndfu
    PatchiBSS
    cd resources/ipwndfu
    Log "Sending iBSS..."
    $ipwndfu -l ../../tmp/pwnediBSS
    cd ../..
}

kDFU() {
    local kloader
    local VerDetect=$(echo $ProductVer | cut -c 1)
    
    if [[ $DeviceState != "Normal" ]]; then
        Log "Device is already in $DeviceState mode"
        return
    fi

    PatchiBSS

    [[ $VerDetect == 1 ]] && kloader="kloader_hgsp"
    [[ $VerDetect == 5 ]] && kloader="kloader5"
    [[ ! $kloader ]] && kloader="kloader"
    
    Log "Running iproxy for SSH..."
    $iproxy 2222 22 &
    iproxyPID=$!
    sleep 2

    echo
    Log "Copying stuff to device via SSH..."
    Echo "* Make sure OpenSSH/Dropbear is installed on the device and running!"
    Echo "* Dropbear is only needed for devices on iOS 10"
    Echo "* To make sure that SSH is successful, try these steps:"
    Echo "* Reinstall OpenSSH/Dropbear, reboot and rejailbreak, then reinstall them again"
    echo
    Input "Enter the root password of your iOS device when prompted."
    Echo "* Note that you will be prompted twice. Do not worry that your input is not visible, it is still being entered."
    Echo "* The default password is \"alpine\""
    $SCP -P 2222 resources/tools/$kloader tmp/pwnediBSS root@127.0.0.1:/tmp
    if [[ $? == 0 ]]; then
        $SSH -p 2222 root@127.0.0.1 "chmod +x /tmp/$kloader; /tmp/$kloader /tmp/pwnediBSS" &
    else
        Log "Cannot connect to device via USB SSH."
        Echo "* Please try the steps above to make sure that SSH is successful"
        Echo "* Alternatively, you may use kDFUApp by tihmstar (from my repo, see \"Troubleshooting\" wiki page)"
        Input "Press Enter/Return to continue anyway (or press Ctrl+C to cancel and try again)"
        read -s
        Log "Will try again with Wi-Fi SSH..."
        Echo "* Make sure that the device and your PC/Mac are on the same network!"
        Echo "* You can check for your device's IP Address in: Settings > WiFi/WLAN > tap the 'i' next to your network name"
        read -p "$(Input 'Enter the IP Address of your device:')" IPAddress
        Log "Copying stuff to device via SSH..."
        $SCP resources/tools/$kloader tmp/pwnediBSS root@$IPAddress:/tmp
        if [[ $? == 1 ]]; then
            Error "Cannot connect to device via SSH." \
            "Please try the steps above to make sure that SSH is successful"
        fi
        $SSH root@$IPAddress "chmod +x /tmp/$kloader; /tmp/$kloader /tmp/pwnediBSS" &
    fi
    
    Log "Entering kDFU mode..."
    Echo "* Press TOP or HOME button when the device disconnects and its screen goes black"
    Echo "* You may also try to unplug and replug your device"
    FindDevice "DFU"
}

Remove4DL() {
    local Link
    if [[ ! -e saved/$ProductType/$1_p ]]; then
        Link=$(cat $Firmware/11D257/url)
        [[ -n $2 ]] && Link=$(cat $Firmware/$2/url)
        Log "Downloading $1..."
        $partialzip $Link Firmware/dfu/$1.${HWModel}ap.RELEASE.dfu $1
        mkdir -p saved/$ProductType 2>/dev/null
        cp $1 saved/$ProductType/$1_p
        mv $1 tmp
    else
        cp saved/$ProductType/$1_p tmp/$1
    fi
    Log "Patching $1..."
    if [[ -n $2 ]]; then
        $bspatch tmp/iBSS tmp/pwnediBSS resources/patches/$1.${HWModel}ap.$2.patch
    else
        $bspatch tmp/$1 tmp/pwned$1 resources/patches/$1.${HWModel}ap.RELEASE.patch
    fi
    Log "Booting $1..."
    $irecovery -f tmp/pwned$1
}

Remove4() {
    Input "Select option:"
    select opt in "Disable exploit" "Enable exploit" "(Any other key to exit)"; do
    case $opt in
        "Disable exploit" ) Rec=0; break;;
        "Enable exploit" ) Rec=2; break;;
        * ) exit 0;;
    esac
    done

    if [[ $ProductType == "iPhone3,1" ]]; then
        Remove4DL iBSS 8L1
    else
        Remove4DL iBSS
        Remove4DL iBEC
    fi
    sleep 2
    Log "Running commands..."
    $irecovery -c "setenv boot-partition $Rec"
    $irecovery -c "saveenv"
    $irecovery -c "setenv auto-boot true"
    $irecovery -c "saveenv"
    $irecovery -c "reset"
    Log "Done!"
    Echo "* If disabling the exploit did not work and the device is getting stuck after restore:"
    Echo "* You may try another method for clearing NVRAM. See the \"Troubleshooting\" wiki page for more details"
}

Ramdisk4() {
    Ramdisk=(
    058-1056-002.dmg
    DeviceTree.n90ap.img3
    iBEC.n90ap.RELEASE.dfu
    iBSS.n90ap.RELEASE.dfu
    kernelcache.release.n90
    )

    Echo "Mode: Ramdisk"
    Echo "* This uses files and script from 4tify by Zurac-Apps"
    Echo "* Make sure that your device is already in DFU mode"

    if [[ ! $(ls resources/ramdisk) ]]; then
        JailbreakLink=https://github.com/Zurac-Apps/4tify/raw/ad319e2774f54dc3a355812cc287f39f7c38cc66
        cd tmp
        mkdir ramdisk
        cd ramdisk
        Log "Downloading ramdisk files from 4tify repo..."
        for file in "${Ramdisk[@]}"; do
            curl -L $JailbreakLink/support_files/7.1.2/Ramdisk/$file -o $file
        done
        cd ..
        cp -rf ramdisk ../resources
        cd ..
    fi

    Log "Sending iBSS..."
    $irecovery -f resources/ramdisk/iBSS.n90ap.RELEASE.dfu
    sleep 2
    Log "Sending iBEC..."
    $irecovery -f resources/ramdisk/iBEC.n90ap.RELEASE.dfu
    FindDevice "Recovery" error

    Log "Booting..."
    $irecovery -f resources/ramdisk/DeviceTree.n90ap.img3
    $irecovery -c devicetree
    $irecovery -f resources/ramdisk/058-1056-002.dmg
    $irecovery -c ramdisk
    $irecovery -f resources/ramdisk/kernelcache.release.n90
    $irecovery -c bootx
    FindDevice "Restore" error

    Log "Device should now be in SSH ramdisk mode."
    echo
    Echo "* To access SSH ramdisk, run iproxy first:"
    Echo "    iproxy 2022 22"
    Echo "* Then SSH to 127.0.0.1:2022"
    Echo "    ssh -p 2022 -oHostKeyAlgorithms=+ssh-rsa root@127.0.0.1"
    Echo "* Enter root password: alpine"
    Echo "* Mount filesystems with these commands (iOS 5+):"
    Echo "    mount_hfs /dev/disk0s1s1 /mnt1"
    Echo "    mount_hfs /dev/disk0s1s2 /mnt1/private/var"
    Echo "* If your device is on iOS 4, use these commands instead:"
    Echo "    fsck_hfs /dev/disk0s1"
    Echo "    mount_hfs /dev/disk0s1 /mnt1"
    Echo "    mount_hfs /dev/disk0s2s1 /mnt/private/var"
    Echo "* To reboot, use this command:"
    Echo "    reboot_bak"
}

EnterPwnREC() {
    local Attempt=1

    if [[ $ProductType == "iPad4,4" || $ProductType == "iPad4,5" ]]; then
        Log "iPad mini 2 device detected. Setting iBSS and iBEC to \"ipad4b\""
        iBEC=$iBECb
        iBSS=$iBSSb
    fi

    while (( Attempt < 4 )); do
        Log "Entering pwnREC mode... (Attempt $Attempt)"
        Log "Sending iBSS..."
        $irecovery -f $IPSWCustom/Firmware/dfu/$iBSS.im4p
        $irecovery -f $IPSWCustom/Firmware/dfu/$iBSS.im4p
        Log "Sending iBEC..."
        $irecovery -f $IPSWCustom/Firmware/dfu/$iBEC.im4p
        sleep 3
        FindDevice "Recovery" timeout
        [[ $? == 0 ]] && break
        Echo "* You may also try to unplug and replug your device"
        ((Attempt++))
    done

    if (( Attempt == 4 )); then
        Error "Failed to enter pwnREC mode. You may have to force restart your device and start over entering pwnDFU mode again"
    fi
}
