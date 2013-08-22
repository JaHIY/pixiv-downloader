#!/bin/sh -

USER_AGENT='Mozilla/5.0 (Windows NT 6.1; WOW64; rv:23.0) Gecko/20130406 Firefox/23.0'
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
    [ -f "$COOKIE_FILE" ] && rm "$COOKIE_FILE"
}

clean_up_on_exit() {
    printf '\n' 1>&2
    err 'Exiting...'
    sub_err 'Cleaning up...'
    clean_up
    exit 1
}

load_config() {
    local where_am_i=''
    if [ -L "$0" ]; then
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
    local pixiv_img_mode_regex='^.*class="works_display"><a href="member_illust\.php?mode=\([^&]\{1,\}\).*$'
    local pixiv_series_url="$(grep "^http:\/\/www\.pixiv\.net\/member_illust\.php?id=" <<< "$1")"

    if [ -n "$pixiv_series_url" ]; then
        local series_page="$(get_pixiv_page "$1")"

        if [ -n "$series_page" ]; then
            printf 'page\n'
        else
            printf 'series\n'
        fi
    else
        local pixiv_bookmarks_url="$(grep "^http:\/\/www\.pixiv\.net\/bookmark\.php" <<< "$1")"
        if [ -n "$pixiv_bookmarks_url" ]; then
            local series_page="$(get_pixiv_page "$1")"

            if [ -n "$series_page" ]; then
                printf 'bookmark\n'
            else
                printf 'bookmarks\n'
            fi
        else
            local pixiv_img_mode="$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" "$1" | \
                grep -F "$pixiv_img_mode_search" | \
                sed -e "s/${pixiv_img_mode_regex}/\1/")"
            if [ -n "$pixiv_img_mode" ]; then
                printf "${pixiv_img_mode}\n"
            else
                printf 'unknown\n'
            fi
        fi
    fi
}

get_pixiv_bookmark_tag() {
    printf '%b\n' "$(sed -n -e 's/^.*bookmark\.php.*[?&]tag=\(.\{1,\}\)$/\1/' -e 's/^\(.*\)&.*$/\1/' -e 's/%/\\x/gp' <<< "$1")"
}

get_pixiv_page() {
    local result="$(sed -e "s/^.*&p=\(.*\)$/\1/" <<< "$1")"

    if [ "$result" != "$1" ]; then
        printf "${result}\n"
    else
        printf "\n"
    fi
}

get_pixiv_series() {
    local pixiv_series_regex='^.*id=\(.*\)$'
    local result="$(sed -e "s/${pixiv_series_regex}/\1/" <<< "$1")"
    local no_pages="$(sed -e 's/^\(.*\)&p=.*$/\1/' <<< "$result")"
    printf "${no_pages}\n"
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
                            "${PIXIV_BIG_PREFIX}${1}" | \
                        grep -o "$pixiv_single_img_regex")"
    curl -O -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_BIG_PREFIX}${1}" "$pixiv_img_url"
}

download_pixiv_page() {
    curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${1}" "${1}" | \
        grep -o "a href=\"/\?member_illust\.php?mode=medium&amp;illust_id=[[:digit:]]\{1,\}\"" | \
        grep -o "[[:digit:]]\{1,\}" | \
    while read line || [ -n "$line" ]; do
        download_pixiv_url "${PIXIV_MEDIUM_PREFIX}${line}"
    done
}

download_pixiv_series() {
    local curr_page='1'
    local url=''
    local bad_page=''
    while [ -n "$curr_page" ]; do
        url="${1}&p=${curr_page}"

        curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "$url" "$url" | \
            grep -q "'_trackEvent','User Access','[^']\{1,\}','no list'"
        bad_page="$?"

        if [ "$bad_page" -eq 1 ]; then
            download_pixiv_url "$url"
            curr_page="$(expr "$curr_page" + 1)"
        else
            curr_page=''
        fi
    done
}

download_pixiv_url() {
    local url="$1"
    local url_type="$(get_url_type "$url")"

    case "$url_type" in
        'manga')
            local id="$(get_pixiv_id "$url")"
            sub_msg "Found pixiv id ${id}... a set of illustrations"
            download_pixiv_manga_imgs "$id"
        ;;
        'big')
            local id="$(get_pixiv_id "$url")"
            sub_msg "Found pixiv id ${id}... a single illustration"
            download_pixiv_single_img "$id"
        ;;
        'page')
            local series="$(get_pixiv_series "$url")"
            local page="$(get_pixiv_page "$url")"
            sub_msg "Found pixiv series ${series}... page ${page}"
            download_pixiv_page "$url"
        ;;
        'series')
            local series="$(get_pixiv_series "$url")"
            sub_msg "Found pixiv series ${series}... a set of pages"
            download_pixiv_series "$url"
        ;;
        'bookmark')
            local tag="$(get_pixiv_bookmark_tag "$url")"
            local page="$(get_pixiv_page "$url")"
            if [ -n "$tag" ]; then
                sub_msg "Found my bookmarks... tag ${tag}... page ${page}"
            else
                sub_msg "Found my bookmarks... page ${page}"
            fi
            download_pixiv_page "$url"
        ;;
        'bookmarks')
            local tag="$(get_pixiv_bookmark_tag "$url")"
            if [ -n "$tag" ]; then
                sub_msg "Found my bookmarks... tag ${tag}... a set of pages"
            else
                sub_msg "Found my bookmarks... a set of pages"
            fi
            download_pixiv_series "$url"
        ;;
        *)
            err "I don't know which type the url is."
            sub_err "url: ${1}"
            sub_err "url_type: ${url_type}"
        ;;
    esac
}

main() {
    trap 'clean_up_on_exit' EXIT
    local COOKIE_FILE="$(mktemp "${TMPDIR-/tmp}/cookie-pixiv.XXXXXXXXXX")"
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
    msg "Finished downloading: $(date)"
}

main "$@"
