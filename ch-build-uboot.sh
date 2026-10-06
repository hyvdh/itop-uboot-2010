#!/bin/bash
# ch-build-uboot.sh - iTOP-4412 POP 1G U-Boot 2010.03 编译脚本
# 仅修复 GCC 11 编译兼容性问题, 不改动任何功能代码(MMC/PMIC/bootcmd 保持原样)
# 用法: ./ch-build-uboot.sh

set -u

TOOLCHAIN_DIR="/home/chh/toolchains/arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-linux-gnueabihf"
CROSS_PREFIX="arm-none-linux-gnueabihf-"
UBOOT_DIR="/home/chh/source_code/ensy4412/iTop4412_uboot"
SEC_DIR="/home/chh/source_code/ensy4412/CodeSign4SecureBoot_POP"
VARIANT="POP_1GDDR"

echo "=============================================="
echo " iTOP-4412 POP 1G U-Boot 2010.03 编译"
echo " (仅编译兼容性修复, 功能代码不动)"
echo "=============================================="

GCC="${TOOLCHAIN_DIR}/bin/${CROSS_PREFIX}gcc"
[ -x "$GCC" ] || { echo "[错误] 工具链不存在: $GCC"; exit 1; }
[ -f "${UBOOT_DIR}/build_uboot.sh" ] || { echo "[错误] 找不到工程: $UBOOT_DIR"; exit 1; }
[ -d "$SEC_DIR" ] || { echo "[错误] 签名材料缺失: $SEC_DIR"; exit 1; }

cd "$UBOOT_DIR" || exit 1
export PATH="${TOOLCHAIN_DIR}/bin:$PATH"
export CROSS_COMPILE="$CROSS_PREFIX"
CPU_JOBS=$(nproc)

echo "[环境] $(${GCC} --version | head -1)"
echo "[环境] ${CPU_JOBS} 线程"

echo ""
echo "[清理]"
make distclean

echo ""
echo "[配置] ${VARIANT}"
# 先删除变体部署文件, 让 config 步骤重新部署 POP 版本(防止残留其他变体)
rm -f board/samsung/smdkc210/lowlevel_init.S
rm -f cpu/arm_cortexa9/s5pc210/cpu_init.S
make itop_4412_android_config_pop_1GDDR

echo ""
echo "[编译] make -j${CPU_JOBS}"
make -j${CPU_JOBS} 2>&1 | tee ch-build.log | tail -5

if [ ! -f u-boot.bin ]; then
    echo ""
    echo "[错误] 编译失败, 请检查 ch-build.log"
    exit 1
fi

echo ""
echo "[打包] 拼接安全启动链"

cp -f u-boot.bin "$SEC_DIR/"

cd "$SEC_DIR"

cat E4412.S.BL1.SSCR.EVT1.1.bin \
    E4412.BL2.TZ.SSCR.EVT1.1.bin \
    all00_padding.bin \
    u-boot.bin \
    E4412.TZ.SSCR.EVT1.1.bin > u-boot-iTOP-4412.bin

mv u-boot-iTOP-4412.bin "$UBOOT_DIR/"
rm -f u-boot.bin

cd "$UBOOT_DIR"

echo ""
echo "=============================================="
echo " 构建成功!"
echo "=============================================="
ls -lh u-boot-iTOP-4412.bin
echo ""
echo "烧录: sudo dd if=u-boot-iTOP-4412.bin of=/dev/sdX bs=512 seek=1 conv=notrunc"
