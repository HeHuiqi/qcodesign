# echo $0 $1 $3
useage="usage: sh qresign.sh [your_ipa_file] [your_profile]"



ipa=$1
# 使用 % 号操作符。用途是从右边开始删除第一次出现子字符串即其右边字符，保留左边字符
ipa_name=${ipa%".ipa"}
resign_ipa_name="${ipa_name}_resigned"

# 描述文件profile.mobileprovision
new_profile=$2

if [ ! -n "$ipa" ] ;then
    echo ${useage}
    exit 1
fi
if [ ! -n "$new_profile" ] ;then
    echo ${useage}
    exit 1
fi


echo $ipa
echo $new_profile


# echo ${ipa_name}
echo "Copy files and deal files start ......"

cp ${ipa} ${ipa}.zip
unzip -q -o ${ipa}.zip

echo "Copy files and deal files end"



echo "Resing start ......"

app_exe_name=$(ls ./Payload)
app_exe_name=${app_exe_name%".app"}
echo ${app_exe_name}

security cms -D -i ${new_profile} > entitlement_full.plist
/usr/libexec/PlistBuddy -x -c 'Print:Entitlements' entitlement_full.plist > entitlements.plist

#处理证书的subject
/usr/libexec/PlistBuddy -c 'Print DeveloperCertificates:0' entitlement_full.plist | openssl x509 -inform DER -noout -subject > certificate_subject.txt
subject=""
while read line_txt
do
    subject=$subject$line_txt
done < certificate_subject.txt
echo ${subject}

subject=${subject#*"/"}
# echo ${subject}
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

cp ./${new_profile} ./Payload/${app_exe_name}.app/embedded.mobileprovision
#移除签名
codesign --remove-signature .Payload/${app_exe_name}.app
#签名
/usr/bin/codesign -f -s "${dev_account}" --entitlements entitlements.plist ./Payload/${app_exe_name}.app
chmod +x .Payload/${app_exe_name}.app/${app_exe_name}

echo "Resign end"

echo "Pack start ......"
zip -q -r ${resign_ipa_name}.ipa ./Payload
echo "Pack end"

echo "Clean temp files"
rm certificate_subject.txt
rm entitlements.plist
rm entitlement_full.plist
rm -rf ${ipa}.zip
rm -rf ./Payload

