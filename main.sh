#!/bin/sh -

USER_AGENT='Mozilla/5.0 (Windows NT 6.1; WOW64; rv:23.0) Gecko/20130406 Firefox/23.0'
PIXIV_PREFIX='http://www.pixiv.net'
PIXIV_MEDIUM_PREFIX="${PIXIV_PREFIX}/member_illust.php?mode=medium&illust_id="
PIXIV_BIG_PREFIX="${PIXIV_PREFIX}/member_illust.php?mode=big&illust_id="
PIXIV_MANGA_PREFIX="${PIXIV_PREFIX}/member_illust.php?mode=manga&illust_id="
PIXIV_MANGA_BIG_PREFIX="${PIXIV_PREFIX}/member_illust.php?mode=manga_big&illust_id="

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

rm_files_if_exists() {
    while [ $# -gt 0 ]; do
        local file_name="$1"
        [ -f "$file_name" ] && rm "$file_name"
        shift
    done
}

clean_up() {
    rm_files_if_exists "$COOKIE_FILE" "$URL_LIST"
}

clean_up_on_exit() {
    msg 'Exiting...'
    sub_msg 'Cleaning up...'
    clean_up
}

clean_up_on_error() {
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

get_image_id() {
    local url="$1"
    printf "%s\n" "$(printf '%s\n' "$url" | grep -o 'illust_id=[[:digit:]]\{1,\}' | \
        sed 's/illust_id=\([[:digit:]]\{1,\}\)/\1/' )"
}

get_url_type() {
    local url="$1"
    local url_type='unknown'
    local image_id="$(get_image_id "$url")"

    if [ -n "$image_id" ]; then
        url_type='image'
    fi

    printf "${url_type}\n"
}

download_pixiv_image() {
    local image_id="$1"
    local image_page="$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "${PIXIV_MEDIUM_PREFIX}${image_id}" \
        "${PIXIV_MEDIUM_PREFIX}${image_id}")"
    local single_image_url="$(printf '%s\n' "$image_page" | \
        xidel -q -e '<img data-src="{.}" class="original-image">?' -)"
    local multiple_images_url="$(printf '%s\n' "$image_page" | \
        xidel -q -e '<div class="works_display"><a href="{.}"></a></div>?' -)"

    if [ -n "$single_image_url" ]; then
        sub_msg 'image_type: single'
        sub_msg "Get download url ${single_image_url}"
        printf '%s %s\n' "$single_image_url" "${PIXIV_MEDIUM_PREFIX}${image_id}" >> "$URL_LIST"
    elif [ -n "$multiple_images_url" ]; then
        sub_msg 'image_type: multiple'
        curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
            -e "${PIXIV_MEDIUM_PREFIX}${image_id}" "${PIXIV_PREFIX}/${multiple_images_url}" | \
            xidel -q -e '<div class="item-container"><a href="{.}"></a></div>*' - | \
            while read line || [ -n "$line" ]; do
                local image_download_url="$(curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" \
                    -e "${PIXIV_PREFIX}/${multiple_images_url}" "${PIXIV_PREFIX}${line}" | \
                    xidel -q -e '<img src="{.}">?' -)"
                sub_msg "Get download url ${image_download_url}"
                printf '%s %s\n' "$image_download_url" "${PIXIV_MEDIUM_PREFIX}${image_id}" >> "$URL_LIST"
            done
    else
        sub_err 'image_type: unknown'
    fi
}

download_pixiv_url() {
    local url="$1"
    local url_type="$(get_url_type "$url")"

    case "$url_type" in
        'image')
            local image_id="$(get_image_id "$url")"
            sub_msg "Found image id ${image_id}..."
            download_pixiv_image "$image_id"
        ;;
        *)
            err "I don't know which type the url is."
            sub_err "url: ${url}"
            sub_err "url_type: ${url_type}"
        ;;
    esac
}

main() {
    trap 'clean_up_on_error' INT TERM HUP
    local COOKIE_FILE="$(mktemp "${TMPDIR-/tmp}/cookie-pixiv.XXXXXXXXXX")"
    local URL_LIST="$(mktemp "${TMPDIR-/tmp}/urllist-pixiv.XXXXXXXXXX")"
    msg "My name is pixiv-downloader-$$. I am working for you now."
    msg 'Preparing for task...'
    sub_msg 'Loading config...'
    load_config
    sub_msg 'Getting cookie...'
    get_cookie
    msg 'Analyzing...'
    while read line || [ -n "$line" ]; do
        download_pixiv_url "$line"
    done
    msg 'Downloading...'
    parallel --bar --colsep ' ' -q curl -s -O --retry 10 -b "$COOKIE_FILE" -A "$USER_AGENT" \
        -e "{2}" "{1}" :::: "$URL_LIST"
    msg "Finished downloading: $(date)"
    clean_up_on_exit
}

main "$@"
