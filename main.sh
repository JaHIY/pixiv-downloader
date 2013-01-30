#!/bin/sh -

. ./config

PIXIV_IMG_ID_REGEX='^.*illust_id=\([[:digit:]]\+\).*$'
COOKIE_FILE='cookie.txt'
USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
PIXIV_MEDIUM_PREFIX='http://www.pixiv.net/member_illust.php?mode=medium&illust_id='
PIXIV_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=big&illust_id='
PIXIV_MANGA_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga&illust_id='
PIXIV_MANGA_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id='
PIXIV_SINGLE_IMG_REGEX='http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+\.[[:alpha:]]\+'
PIXIV_MODE_SEARCH='class="works_display"'
PIXIV_MODE_REGEX='^.*class="works_display"><a href="member_illust.php?mode=\([^&]\+\).*$'
PIXIV_MANGA_IMG_REGEX='http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+_p[[:digit:]]\+\.[[:alpha:]]\+'
PIXIV_MANGA_IMG_SUBSTITUTE='s;^\(http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+\)\(_p[[:digit:]]\+\.[[:alpha:]]\+\)$;\1_big\3;g'

get_cookie() {
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" -d "mode=login&pixiv_id=${ACCOUNT}&pass=${PASSWORD}&skip=1" 'http://www.pixiv.net/login.php'
}

check_mode() {
    curl -b "$COOKIE_FILE" -A "$USER_AGENT" "${PIXIV_MEDIUM_PREFIX}${1}" | grep -F "$PIXIV_MODE_SEARCH" | sed -e "s/${PIXIV_MODE_REGEX}/\1/"
}

get_pixiv_img_id() {
    sed -e "s/${PIXIV_IMG_ID_REGEX}/\1/" <<< "$1"
}

download_pixiv_manga_imgs() {
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_MANGA_PREFIX}${1}" | grep -o "$PIXIV_MANGA_IMG_REGEX" | sed -e "$PIXIV_MANGA_IMG_SUBSTITUTE" | \
    while read pixiv_img_url
    do
        curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MANGA_BIG_PREFIX}${1}" "$pixiv_img_url"
    done
}

download_pixiv_single_img() {
    local pixiv_img_url=$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_BIG_PREFIX}${1}" | grep -o "$PIXIV_SINGLE_IMG_REGEX")
    curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_BIG_PREFIX}${1}" "$pixiv_img_url"
}

download_pixiv_img() {
    echo 'download_pixiv_img() -> $1:' "$1" '$2:' "$2"
    case "$1" in
        'manga')
            download_pixiv_manga_imgs "$2"
        ;;
        'big')
            download_pixiv_single_img "$2"
        ;;
    esac
}

main() {
    local pixiv_img_id=''
    get_cookie
    while read line
    do
        pixiv_img_id=$(get_pixiv_img_id "$line")
        download_pixiv_img $(check_mode "$pixiv_img_id") "$pixiv_img_id"
    done
}

main
