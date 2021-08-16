
useage="usage: sh hqsign_sample.sh  [your_profile]"


# 描述文件profile.mobileprovision
new_profile=$1

if [ ! -n "$new_profile" ] ;then
    echo ${useage}
    exit 1
fi

echo $new_profile
payload_path="./Payload"
app_exe_name=$(ls ${payload_path})
app_exe_name=${app_exe_name%".app"}
echo ${app_exe_name}

security cms -D -i ${new_profile} > entitlement_full.plist
/usr/libexec/PlistBuddy -x -c 'Print:Entitlements' entitlement_full.plist > entitlements.plist

#处理subject
/usr/libexec/PlistBuddy -c 'Print DeveloperCertificates:0' entitlement_full.plist | openssl x509 -inform DER -noout -subject > certificate_subject.txt
subject=""
while read line_txt
do
    subject=$subject$line_txt
done < certificate_subject.txt
echo ${subject}

#解析subject
subject=${subject#*"/"}
last_end=${subject}
subject_codes=("UID=" "CN=" "OU=" "O=" "C=")
dev_account=""
for subject_code in ${subject_codes[@]}
do
    uid_end=${last_end#*"/"}
    uid=${last_end%"/$uid_end"}
    uid=${uid#$subject_code}
    echo "$subject_code"$uid
    if [ "$subject_code" = "CN=" ];then
        dev_account=$uid
    fi
    last_end=$uid_end
done
if [ ! -n "$dev_account" ] ;then
    echo ${useage}
    exit 1
fi
echo ${dev_account}

#移除签名

cp ./${new_profile} ${payload_path}/${app_exe_name}.app/embedded.mobileprovision

#开始重签名
echo "Start Resign"

codesign --remove-signature ${payload_path}/${app_exe_name}.app

/usr/bin/codesign -f -s "${dev_account}" --entitlements entitlements.plist ${payload_path}/${app_exe_name}.app
chmod +x ${payload_path}/${app_exe_name}.app/${app_exe_name}

echo "Resing End"

#重写打包
echo "Packing"

zip -qr ${app_exe_name}_resigned.ipa ${payload_path}/
# rm -rf ${payload_path}
rm certificate_subject.txt
rm entitlement_full.plist
rm entitlements.plist 
