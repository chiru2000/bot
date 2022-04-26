#!/bin/bash

export TOKEN=
export CHAT_ID=
export TGUSERNAME=
export JENKINS_URL=

[ "$JENKINS_URL" ] && JENKINS=true

if [ "$JENKINS" ]; then
    PROGESS="[Jenkins](${BUILD_URL}console)"
fi

if [ "$CLEAN" = "true" ]; then
    rm -rf out/target/product/${DEVICE}

fi

if [ "$DEL_ZIP" = "true" ]; then
    rm -rf out/target/product/${DEVICE}/${ROMZIP}*.zip
fi

if [ "$FULL_CLEAN" = "true" ]; then
    . build/envsetup.sh
    make clean && make clobber
fi

if [ "$GAPPS" = "true" ]; then
    export WITH_GAPPS=true
    export USES_GAPPS=true
fi

if [ "$SYNC" = "true" ]; then
    repo sync -j$( nproc --all ) --force-sync -c --no-clone-bundle --no-tags --optimized-fetch --prune
fi

if [ "$BUILD" = "true" ]; then
    . build/envsetup.sh

    #Extra's add here
    #export KBUILD_BUILD_USER=Spectar
    #export PREVIOUS_TARGET_FILES_PACKAGE="phoenix-target_files-sp2a.220305.013.a3.zip"

    lunch ${ROM}_${DEVICE}-${BUILD_TYPE}
    BUILD_START=$(date +"%s")

    # Report to tg group/channel
    read -r -d '' MESSAGE <<-_EOL_
    Build Started!
    CPUs : $(nproc --all) | RAM : $(awk '/MemTotal/ { printf "%.1f \n", $2/1024/1024 }' /proc/meminfo)GB
    Build Type : ${BUILD_TYPE}
    Device : ${DEVICE}
    By : ${TGUSERNAME}
    Log : ${PROGESS}
_EOL_
    curl -s -X POST -d chat_id="${CHAT_ID}" -d parse_mode=Markdown -d text="${MESSAGE}" https://api.telegram.org/bot"${TOKEN}"/sendMessage
    ${MAKE_COMMAND} | tee "${ROM}"-build.log
    BUILD_PROGRESS=$(sed -n '/ ninja/,$p' "${ROM}"-build.log | grep -Po '\d+% \d+/\d+' | tail -n1 | sed -e 's/ / \(/' -e 's/$/)/')
    finalzip="${OUT}/${ROMZIP}*.zip"

        if [ -f "${OUT}"/${ROMZIP}*.zip ]; then
            filename="$(basename $finalzip)"
            # Build Succuss
            BUILD_END=$(date +"%s")
            DIFF=$((BUILD_END - BUILD_START))
            # Send msg to telegram
            read -r -d '' MESSAGE_SUCCESS <<-_EOL_
            BUILD SUCCESSFULL!
        Time : $((DIFF / 60)) minutes and $((DIFF % 60)) seconds
        By : ${TGUSERNAME}
        Log : ${PROGESS}
_EOL_
            curl -s -X POST -d chat_id="${CHAT_ID}" -d parse_mode=Markdown -d text="${MESSAGE_SUCCESS}" https://api.telegram.org/bot"${TOKEN}"/sendMessage
        else
            echo -e "Build compilation failed"
            read -r -d '' MESSAGE_FAILED <<-_EOL_
            Build Failed!
        Status : ${BUILD_PROGRESS}
        By : ${TGUSERNAME}
        Log : ${PROGESS}
_EOL_
            curl -s -X POST -d chat_id="${CHAT_ID}" -d parse_mode=Markdown -d text="${MESSAGE_FAILED}" https://api.telegram.org/bot"${TOKEN}"/sendMessage
            exit 1
        fi
fi

if [ "$UPLOAD" = "true" ]; then
    zipdir=$(get_build_var PRODUCT_OUT)
    zippath=$(find "$zipdir"/"${ROMZIP}"*.zip | tail -n -1)
    rclone copy -P "$zippath" gdrive:roms
    FOLDER_LINK="https://chiru.chiranth.workers.dev/2:/${filename}"
    curl -s -X POST -d chat_id="${CHAT_ID}" -d parse_mode=Markdown -d text="Build Succussfully Uploaded [Here](${FOLDER_LINK})" https://api.telegram.org/bot"${TOKEN}"/sendMessage
fi
