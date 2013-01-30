#!/bin/sh -

. ./config


COOKIE_FILE='cookie.txt'
USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
PIXIV_MEDIUM_PREFIX='http://www.pixiv.net/member_illust.php?mode=medium&illust_id='
PIXIV_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=big&illust_id='
PIXIV_MANGA_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga&illust_id='
PIXIV_MANGA_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id='

get_cookie() {
    printf 'Now I am getting cookie......'
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" -d "mode=login&pixiv_id=${ACCOUNT}&pass=${PASSWORD}&skip=1" 'http://www.pixiv.net/login.php'
    printf 'Done!\n'
}

check_mode() {
    local PIXIV_MODE_SEARCH='class="works_display"'
    local PIXIV_MODE_REGEX='^.*class="works_display"><a href="member_illust.php?mode=\([^&]\+\).*$'
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "${PIXIV_MEDIUM_PREFIX}${1}" | grep -F "$PIXIV_MODE_SEARCH" | sed -e "s/${PIXIV_MODE_REGEX}/\1/"
}

get_pixiv_img_id() {
    local PIXIV_IMG_ID_REGEX='^.*illust_id=\([[:digit:]]\+\).*$'
    sed -e "s/${PIXIV_IMG_ID_REGEX}/\1/" <<< "$1"
}

download_pixiv_manga_imgs() {
    local PIXIV_MANGA_IMG_REGEX='http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+_p[[:digit:]]\+\.[[:alpha:]]\+'
    local PIXIV_MANGA_IMG_SUBSTITUTE='s;^\(http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+\)\(_p[[:digit:]]\+\.[[:alpha:]]\+\)$;\1_big\3;g'
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_MANGA_PREFIX}${1}" | grep -o "$PIXIV_MANGA_IMG_REGEX" | sed -e "$PIXIV_MANGA_IMG_SUBSTITUTE" | \
    while read pixiv_img_url
    do
        curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MANGA_BIG_PREFIX}${1}" "$pixiv_img_url"
    done
}

download_pixiv_single_img() {
    local PIXIV_SINGLE_IMG_REGEX='http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+\.[[:alpha:]]\+'
    local pixiv_img_url=$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_BIG_PREFIX}${1}" | grep -o "$PIXIV_SINGLE_IMG_REGEX")
    curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_BIG_PREFIX}${1}" "$pixiv_img_url"
}

download_pixiv_img() {
    #echo 'download_pixiv_img() -> $1:' "$1" '$2:' "$2"
    case "$1" in
        'manga')
            printf "Pixiv id $2 is a set of illustrations!\nI am downloading them for you......\n"
            download_pixiv_manga_imgs "$2"
            printf "Done!\n"
        ;;
        'big')
            printf "Pixiv id $2 is a single illustration!\nI am downloading it for you......\n"
            download_pixiv_single_img "$2"
            printf "Done!\n"
        ;;
    esac
}

main() {
    local pixiv_img_id=''
    printf "Hello, master. My name is pixiv-downloader-$$. I am working for you now.\n"
    get_cookie
    while read line
    do
        pixiv_img_id=$(get_pixiv_img_id "$line")
        download_pixiv_img $(check_mode "$pixiv_img_id") "$pixiv_img_id"
    done
    printf 'My work is complete. Goodbye, master!\n'
}

main
