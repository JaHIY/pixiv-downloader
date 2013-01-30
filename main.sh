#!/bin/sh -

. ./config

PIXIV_NUM_REGEX='^.*illust_id=\([[:alnum:]]\+\).*$'
COOKIE_FILE='cookie.txt'
USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
PIXIV_MEDIUM_PREFIX='http://www.pixiv.net/member_illust.php?mode=medium&illust_id='
PIXIV_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=big&illust_id='
PIXIV_MANGA_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga&illust_id='
PIXIV_MANGA_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id='
PIXIV_IMG_REGEX='http:\/\/[^.]\+\.pixiv\.net\/[^"]\+'

get_cookie() {
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" -d "mode=login&pixiv_id=${ACCOUNT}&pass=${PASSWORD}&skip=1" 'http://www.pixiv.net/login.php'
}

get_pixiv_img_id() {
    sed -e "s/${PIXIV_NUM_REGEX}/\1/" <<< $1
}

download_pixiv_img() {
    local pixiv_img_url=$(curl -s -c "$COOKIE_FILE" -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_BIG_PREFIX}${1}" | grep -o "$PIXIV_IMG_REGEX")
    curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_BIG_PREFIX}${1}" $pixiv_img_url
}

main() {
    get_cookie
    while read line
    do
        download_pixiv_img $(get_pixiv_img_id $line)
    done
}

main
