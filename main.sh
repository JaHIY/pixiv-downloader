#!/bin/sh -

COOKIE_FILE='cookie.txt'
USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
PIXIV_MEDIUM_PREFIX='http://www.pixiv.net/member_illust.php?mode=medium&illust_id='
PIXIV_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=big&illust_id='
PIXIV_MANGA_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga&illust_id='
PIXIV_MANGA_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id='

get_config() {
    local where_am_i
    if [ -h "$0" ]
    then
        where_am_i=$(readlink "$0")
    else
        where_am_i="$0"
    fi
    source "$(dirname "$where_am_i")/config"
}

get_cookie() {
    printf 'Now I am getting cookie......'
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" -d "mode=login&pixiv_id=${ACCOUNT}&pass=${PASSWORD}&skip=1" \
        'http://www.pixiv.net/login.php'
    printf 'Done!\n'
}

check_mode() {
    local pixiv_mode_search='class="works_display"'
    local pixiv_mode_regex='^.*class="works_display"><a href="member_illust.php?mode=\([^&]\+\).*$'
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "${PIXIV_MEDIUM_PREFIX}${1}" | \
        grep -F "$pixiv_mode_search" | \
        sed -e "s/${pixiv_mode_regex}/\1/"
}

get_pixiv_img_id() {
    local pixiv_img_id_regex='^.*illust_id=\([[:digit:]]\+\).*$'
    sed -e "s/${pixiv_img_id_regex}/\1/" <<< "$1"
}

download_pixiv_manga_imgs() {
    local pixiv_manga_img_regex='http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+_p[[:digit:]]\+\.[[:alpha:]]\+'
    local pixiv_manga_img_substitute='s;^\(http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+\)\(_p[[:digit:]]\+\.[[:alpha:]]\+\)$;\1_big\3;g'
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_MANGA_PREFIX}${1}" | \
        grep -o "$pixiv_manga_img_regex" | \
        sed -e "$pixiv_manga_img_substitute" | \
        xargs curl --remote-name-all -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MANGA_BIG_PREFIX}${1}"
}

download_pixiv_single_img() {
    local pixiv_single_img_regex='http:\/\/[^.]\+\.pixiv\.net\/\([^/]\+\/\)\{3\}[[:digit:]]\+\.[[:alpha:]]\+'
    local pixiv_img_url=$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" \
                            "${PIXIV_BIG_PREFIX}${1}" | 
                        grep -o "$pixiv_single_img_regex")
    curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_BIG_PREFIX}${1}" "$pixiv_img_url"
}

download_pixiv_img() {
    #echo 'download_pixiv_img() -> $1:' "$1" '$2:' "$2"
    case "$1" in
        'manga')
            printf '%s\n' \
                    "Pixiv id $2 is a set of illustrations!" \
                    'I am downloading them for you......'
            download_pixiv_manga_imgs "$2"
            printf "Done!\n"
        ;;
        'big')
            printf '%s\n' \
                    "Pixiv id $2 is a single illustration!" \
                    'I am downloading it for you......'
            download_pixiv_single_img "$2"
            printf "Done!\n"
        ;;
    esac
}

main() {
    local pixiv_img_id=''
    printf "Hello, master. My name is pixiv-downloader-$$. I am working for you now.\n"
    get_config
    get_cookie
    while read line
    do
        pixiv_img_id=$(get_pixiv_img_id "$line")
        download_pixiv_img $(check_mode "$pixiv_img_id") "$pixiv_img_id"
    done
    printf 'My work is complete. Goodbye, master~\n'
}

main "$@"
