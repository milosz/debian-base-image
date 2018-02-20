# Step by step instruction at:
#   https://blog.sleeplessbeastie.eu/2018/04/11/how-to-create-base-docker-image/

# Debian distribution
DISTRIBUTION=stretch

# Distribution key
DISTRIBUTION_KEY=EF0F382A1A7B6500
DISTRIBUTION_KEY_FILE=./debian-${DISTRIBUTION}.gpg
KEYSERVER=keys.gnupg.net

# Distribution settings
DISTRIBUTION_ARCH=amd64
DISTRIBUTION_VARIANT=minbase
DISTRIBUTION_COMPONENTS=main,contrib,non-free
DISTRIBUTION_INCLUDE=dirmngr,apt-transport-https
DISTRIBUTION_MIRROR=http://deb.debian.org/debian/
DISTRIBUTION_DIR=debian-${DISTRIBUTION}-${DISTRIBUTION_ARCH}

# Include dirmngr and apt-transport-https by default
DISTRIBUTION_INCLUDE:=$(if $(DISTRIBUTION_INCLUDE),$(DISTRIBUTION_INCLUDE),dirmngr,apt-transport-https)

# Mount /dev/, /dev/pts/, /proc/, /sys/ during customization phase?
MOUNT_FS_INSIDE=true

all: check_user clean_build build_base_image customize_base_image create_tar_archive
clean: clean_build
cleanall: clean_build clean_key

.PHONY: all clean cleanall

clean_build: check_user umount_fs_inside_chroot
	rm -rf ${DISTRIBUTION_DIR}
	rm -f  ${DISTRIBUTION_DIR}.tar

clean_key: check_user
	rm -f ${DISTRIBUTION_KEY_FILE}
	rm -f ${DISTRIBUTION_KEY_FILE}~

check_user:
ifneq ($(shell whoami),root)
  $(error Execute as root user)
endif

${DISTRIBUTION_KEY_FILE}:
	apt-key --keyring ${DISTRIBUTION_KEY_FILE} adv --keyserver ${KEYSERVER} --recv-keys ${DISTRIBUTION_KEY}

build_base_image: ${DISTRIBUTION_KEY_FILE}
	debootstrap --keyring ${DISTRIBUTION_KEY_FILE} --force-check-gpg --variant=${DISTRIBUTION_VARIANT} --components=${DISTRIBUTION_COMPONENTS} --include=${DISTRIBUTION_INCLUDE} --arch=${DISTRIBUTION_ARCH} ${DISTRIBUTION} ${DISTRIBUTION_DIR} ${DISTRIBUTION_MIRROR}

mount_fs_inside_chroot:
	if [ "$(MOUNT_FS_INSIDE)" = "true" ]; then \
		for directory in "dev" "dev/pts" "proc" "sys"; do \
			mountpoint $(DISTRIBUTION_DIR)/$$directory 1>/dev/null 2>/dev/null; \
			if [ "$$?" -eq "1" ]; then mount --bind /$$directory $(DISTRIBUTION_DIR)/$$directory &>/dev/null; fi \
		done \
	fi

umount_fs_inside_chroot:
	for directory in "dev/pts" "dev" "proc" "sys"; do \
		mountpoint $(DISTRIBUTION_DIR)/$$directory 1>/dev/null 2>/dev/null; \
		if [ "$$?" -eq "0" ]; then umount $(DISTRIBUTION_DIR)/$$directory &>/dev/null; fi \
	done

customize_base_image: mount_fs_inside_chroot
	chroot $(DISTRIBUTION_DIR) bash -c 'echo "APT::Get::Assume-Yes \"true\";" | tee /etc/apt/apt.conf.d/10-assume_yes';
	chroot $(DISTRIBUTION_DIR) bash -c "apt-get install --no-install-recommends git"; 
	chroot $(DISTRIBUTION_DIR) bash -c "apt-get remove --allow-remove-essential e2fsprogs e2fslibs nano pinentry-curses whiptail kmod iptables iproute2 dmidecode";
	chroot $(DISTRIBUTION_DIR) bash -c "apt-get clean"; 
	chroot $(DISTRIBUTION_DIR) bash -c "find /var/lib/apt/lists/ -maxdepth 2 -type f -delete";

create_tar_archive: umount_fs_inside_chroot
	tar --one-file-system --create --file $(DISTRIBUTION_DIR).tar --directory $(DISTRIBUTION_DIR) .



