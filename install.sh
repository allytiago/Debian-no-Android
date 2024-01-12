#!/data/data/com.termux/files/usr/bin/bash
pkg install wget -y 
folder=debian-fs
cur=`pwd`
extralink="https://raw.githubusercontent.com/allytiago/Debian-no-Android/main/config"
if [ -d "$folder" ]; then
	first=1
	echo "skipping downloading"
fi
tarball="debian-rootfs.tar.xz"

termux-setup-storage

if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		echo "Download Rootfs, this may take a while base on your internet speed."
		case `dpkg --print-architecture` in
		aarch64)
			archurl="arm64" ;;
		arm)
			archurl="armhf" ;;
		amd64)
			archurl="amd64" ;;
		x86_64)
			archurl="amd64" ;;	
		i*86)
			archurl="i386" ;;
		x86)
			archurl="i386" ;;
		*)
			echo "unknown architecture"; exit 1 ;;
		esac
        wget "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-ec2-${archurl}.tar.xz" -O $tarball
        #wget "https://partner-images.canonical.com/core/jammy/current/ubuntu-jammy-core-cloudimg-${archurl}-root.tar.gz" -O $tarball
    fi
	mkdir -p "$folder"
	cd "$folder"
	echo "Decompressing Rootfs, please be patient."
	proot --link2symlink tar -xf ${cur}/${tarball} --exclude=dev||:
	cd "$cur"
fi

mkdir -p debian-binds

bin=start-debian.sh
echo "writing launch script"
cat > $bin <<- EOM
#!/bin/bash
cd \$(dirname \$0)
## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD
command="proot"
command+=" --kill-on-exit"
command+=" --link2symlink"
command+=" -0"
command+=" -r $folder"
if [ -n "\$(ls -A debian12-binds)" ]; then
    for f in debian12-binds/* ;do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /proc"
command+=" -b /sys"
command+=" -b /data"
command+=" -b debian-fs/root:/dev/shm"
command+=" -b /proc/self/fd/2:/dev/stderr"
command+=" -b /proc/self/fd/1:/dev/stdout"
command+=" -b /proc/self/fd/0:/dev/stdin"
command+=" -b /dev/urandom:/dev/random"
command+=" -b /proc/self/fd:/dev/fd"
command+=" -b ${cur}/${folder}/proc/fakethings/stat:/proc/stat"
command+=" -b ${cur}/${folder}/proc/fakethings/vmstat:/proc/vmstat"
command+=" -b ${cur}/${folder}/proc/fakethings/version:/proc/version"
## uncomment the following line to have access to the home directory of termux
#command+=" -b /data/data/com.termux/files/home:/root"
command+=" -b /sdcard"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" MOZ_FAKE_NO_SANDBOX=1"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" /bin/bash --login"
command+=" -b /data/data/com.termux/files/home/debian-fs/usr/local/bin/startvncserver"
com="\$@"
if [ -z "\$1" ];then
    exec \$command
else
    \$command -c "\$com"
fi
EOM

#mkdir -p debian-fs/var/tmp
#rm -rf debian-fs/usr/local/bin/*
#echo "127.0.0.1 localhost localhost" > $folder/etc/hosts
#wget -q  -P debian-fs/usr/local/bin > /dev/null

echo "fixing shebang of $bin"
termux-fix-shebang $bin
echo "making $bin executable"
chmod +x $bin
echo "removing image for some space"
rm $tarball


# Script de instalação adicional
wget --tries=20 $extralink/install.sh -O $folder/root/debian-config.sh


#GUI de interface
export USER=$(whoami)
HEIGHT=0
WIDTH=0
CHOICE_HEIGHT=5
TITLE="Select"
MENU="Escolha algumas das seguintes opções: \n \nChoose any of the following options: "
export PORT=1

OPTIONS=(1 "debian LXDE"
	 2 "debian XFCE")

CHOICE=$(dialog --clear \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
1)
echo "Você escolheu a interface LXDE"
echo "Configurando a instalação do servidor vnc para o LXDE"
wget --tries=20 $extralink/lxde/lxde-config.sh -O $folder/root/ui-config.sh
;;
2)
echo "Você escolheu a interface XFCE"
echo "Configurando a instalação do servidor vnc para o XFCE"
wget --tries=20 $extralink/xfce/xfce-config.sh -O $folder/root/ui-config.sh
wget --tries=20 $extralink/xfce/xfce4-panel.tar.bz2 $folder/root/xfce4-panel.tar.bz2
chmod +x $folder/root/xfce4-themes-config.sh
;;
esac

clear

chmod +x $folder/root/debian-config.sh
chmod +x $folder/root/ui-config.sh
chmod +x debian12-fs/usr/local/bin/startvncserver


echo "APT::Acquire::Retries \"3\";" > $folder/etc/apt/apt.conf.d/80-retries #Setting APT retry count
touch $folder/root/.hushlogin
echo "#!/bin/bash
rm -rf /etc/resolv.conf
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
mkdir -p ~/.vnc
apt update -y && apt install sudo wget -y > /dev/null
clear

bash ~/debian-config.sh
bash ~/ui-config.sh

chmod +x /usr/local/bin/stopvnc
chmod +x /usr/local/bin/startvnc
chmod +x /usr/local/bin/startvncserver

if [ ! -f /usr/bin/vncserver ]; then
    apt install tigervnc-standalone-server -y
fi

rm -rf /root/debian-config.sh
rm -rf /root/ui-config.sh
rm -rf ~/.bash_profile" > $folder/root/.bash_profile 

bash $bin