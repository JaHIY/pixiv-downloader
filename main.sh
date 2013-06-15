#!/bin/sh -

USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
PIXIV_MEDIUM_PREFIX='http://www.pixiv.net/member_illust.php?mode=medium&illust_id='
PIXIV_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=big&illust_id='
PIXIV_MANGA_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga&illust_id='
PIXIV_MANGA_BIG_PREFIX='http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id='
PIXIV_SERIES_PREFIX='http://www.pixiv.net/member_illust.php?id='

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
    rm_err="$(rm "$COOKIE_FILE" 2>&1)"
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
        where_am_i="$(readlink -f "$0")"
    else
        where_am_i="$0"
    fi
    source "$(dirname "$where_am_i")/config"
}

get_cookie() {
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" -d "mode=login&pixiv_id=${ACCOUNT}&pass=${PASSWORD}&skip=1" \
        'http://www.pixiv.net/login.php'
}

get_url_type() {
    local pixiv_img_mode_search='class="works_display"'
    local pixiv_img_mode_regex='^.*class="works_display"><a href="member_illust.php?mode=\([^&]\{1,\}\).*$'
    local pixiv_img_mode="$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "${1}" |
        grep -F "$pixiv_img_mode_search" |
        sed -e "s/${pixiv_img_mode_regex}/\1/")"
    local pixiv_series_url="$(grep "^$PIXIV_SERIES_PREFIX" <<< "${1}")"
    
    if [[ "$pixiv_img_mode" != "" ]]; then
        echo "$pixiv_img_mode"
    elif [[ "$pixiv_series_url" != "" ]]; then
        local series_page="$(get_pixiv_page "${1}")"
        
        if [[ "$series_page" != "" ]]; then
            echo "page"
        else
            echo "series"
        fi
    fi
}

get_pixiv_page() {
    result="$(sed -e "s/^.*&p=\(.*\)$/\1/" <<< "$1")"
    
    if [[ "$result" != "$1" ]]; then
        echo $result
    else
        echo ""
    fi
}

get_pixiv_series() {
    local pixiv_series_regex='^.*id=\(.*\)$'
    local result="$(sed -e "s/${pixiv_series_regex}/\1/" <<< "$1")"
    local no_pages="$(sed -e "s/^\(.*\)&p=.*$/\1/" <<< "$result")"
    echo "$no_pages"
}

get_pixiv_id() {
    local pixiv_id_regex='^.*id=\([[:digit:]]\{1,\}\).*$'
    local result="$(sed -e "s/${pixiv_id_regex}/\1/" <<< "$1")"
    grep -s '[[:digit:]]\{1,\}' <<< "$result"
}

download_pixiv_manga_imgs() {
    local pixiv_manga_img_regex='http:\/\/[^.]\{1,\}\.pixiv\.net\/\([^/]\{1,\}\/\)\{3\}[[:digit:]]\{1,\}_p[[:digit:]]\{1,\}\.[[:alpha:]]\{1,\}'
    local pixiv_manga_img_substitute='s;^\(http:\/\/[^.]\{1,\}\.pixiv\.net\/\([^/]\{1,\}\/\)\{3\}[[:digit:]]\{1,\}\)\(_p[[:digit:]]\{1,\}\.[[:alpha:]]\{1,\}\)$;\1_big\3;g'
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" "${PIXIV_MANGA_PREFIX}${1}" | \
        grep -o "$pixiv_manga_img_regex" | \
        sed -e "$pixiv_manga_img_substitute" | \
        xargs curl --remote-name-all -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MANGA_BIG_PREFIX}${1}"
}

download_pixiv_single_img() {
    local pixiv_single_img_regex='http:\/\/[^.]\{1,\}\.pixiv\.net\/\([^/]\{1,\}\/\)\{3\}[[:digit:]]\{1,\}\.[[:alpha:]]\{1,\}'
    local pixiv_img_url="$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${1}" \
                            "${PIXIV_BIG_PREFIX}${1}" | 
                        grep -o "$pixiv_single_img_regex")"
    curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_BIG_PREFIX}${1}" "$pixiv_img_url"
}

download_pixiv_page() {
    curl -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${1}" "${1}" |
        grep -o "a href=\"/member_illust.php?mode=medium&amp;illust_id=\([[:digit:]]*\)\"" |
        grep -o "[[:digit:]]*" |
    while read line || [ -n "$line" ]
    do
        download_pixiv_url "${PIXIV_MEDIUM_PREFIX}${line}"
    done
}

download_pixiv_series() {
    local curr_page="1"
    while [[ "$curr_page" != "" ]]; do
        local url="${PIXIV_SERIES_PREFIX}${1}&p=$curr_page"
        
        curl -b "$COOKIE_FILE" -A "$USER_AGENT" -e "$url" "$url" |
            grep -q "'_trackEvent','User Access','member_illust','no list'"
        local bad_page="$?"
        
        if [[ $bad_page == "1" ]]; then
            download_pixiv_url "$url"
            curr_page="$(expr $curr_page + 1)"
        else
            curr_page=""
        fi
    done
}

download_pixiv_url() {
    local url="${1}"
    local url_type="$(get_url_type "$url")"
    
    case "$url_type" in
        'manga')
            local id="$(get_pixiv_id "$url")"
            sub_msg "Found pixiv id ${id}... a set of illustrations"
            download_pixiv_manga_imgs "${id}"
        ;;
        'big')
            local id="$(get_pixiv_id "$url")"
            sub_msg "Found pixiv id ${id}... a single illustration"
            download_pixiv_single_img "${id}"
        ;;
        'page')
            local series="$(get_pixiv_series "$url")"
            local page="$(get_pixiv_page "$url")"
            sub_msg "Found pixiv series ${series}... page $page"
            download_pixiv_page $url
        ;;
        'series')
            local series="$(get_pixiv_series "$url")"
            sub_msg "Found pixiv series ${series}... a set of pages"
            download_pixiv_series $series
        ;;
    esac
}

main() {
    trap 'clean_up_on_exit' HUP INT QUIT TERM
    COOKIE_FILE="$(mktemp --tmpdir cookie-pixiv.XXXXXXXXXX)"
    msg "My name is pixiv-downloader-$$. I am working for you now."
    msg 'Preparing for task...'
    sub_msg 'Loading config...'
    load_config
    sub_msg 'Getting cookie...'
    get_cookie
    msg 'Downloading...'
    while read line || [ -n "$line" ]
    do
        download_pixiv_url "$line"
    done
    msg 'Cleaning up...'
    clean_up
    msg "Finished downloading: $(date)"
}

main "$@"
