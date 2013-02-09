#!/bin/sh -

COOKIE_FILE="/tmp/cookie-pixiv-$$.txt"
USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
PIXIV_MEDIUM_PREFIX='http://www.pixiv.net/member_illust.php?mode=medium&illust_id='
PIXIV_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=big&illust_id='
PIXIV_MANGA_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga&illust_id='
PIXIV_MANGA_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id='

msg() {
    printf '\033[32;1m==>\033[0m \033[1m%s\033[0m\n' "$@"
}

sub_msg() {
    printf '  \033[34;1m->\033[0m \033[1m%s\033[0m\n' "$@"
}

err() {
    printf '\033[31;1m==> ERROR:\033[0m \033[1m%s\033[0m\n' "$@" 1>&2
}

sub_err() {
    printf '  \033[33;1m->\033[0m \033[1m%s\033[0m\n' "$@" 1>&2
}

clean_up() {
    local rm_code
    rm_err=$(rm "$COOKIE_FILE" 2>&1)
    rm_code=$?
    [ $rm_code -eq 0 ] || err "[${rm_code}] ${rm_err}"
}

clean_up_on_exit() {
    printf '\n' 1>&2
    err 'Aborted by user! Exiting...'
    sub_err 'Cleaning up...'
    clean_up
    exit 1
}

load_config() {
    local where_am_i
    if [ -h "$0" ]
    then
        where_am_i=$(readlink -f "$0")
    else
        where_am_i="$0"
    fi
    source "$(dirname "$where_am_i")/config"
}

get_cookie() {
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" -d "mode=login&pixiv_id=${ACCOUNT}&pass=${PASSWORD}&skip=1" \
        'http://www.pixiv.net/login.php'
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
    case "$1" in
        'manga')
            sub_msg "Found pixiv id ${2}... a set of illustrations"
            download_pixiv_manga_imgs "$2"
        ;;
        'big')
            sub_msg "Found pixiv id ${2}... a single illustration"
            download_pixiv_single_img "$2"
        ;;
    esac
}

main() {
    local pixiv_img_id=''
    trap 'clean_up_on_exit' HUP INT QUIT TERM
    msg "My name is pixiv-downloader-$$. I am working for you now."
    msg 'Preparing for task...'
    sub_msg 'Loading config...'
    load_config
    sub_msg 'Getting cookie...'
    get_cookie
    msg 'Downloading...'
    while read line
    do
        pixiv_img_id=$(get_pixiv_img_id "$line")
        download_pixiv_img $(check_mode "$pixiv_img_id") "$pixiv_img_id"
    done
    msg 'Cleaning up...'
    clean_up
    msg "Finished downloading: $(date)"
}

main "$@"
